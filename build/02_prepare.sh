#!/bin/bash
set -euo pipefail

# =============================================================================
# 02_prepare.sh — Package preparation for BPI-R4 firmware build
# =============================================================================
# MUST run from inside the openwrt/ directory: cd openwrt && ../build/02_prepare.sh
#
# Usage: cd openwrt && bash ../build/02_prepare.sh [--variant full|minimal]
#
# full    — Full prep: feeds, kernel patches, bootloader, third-party packages
# minimal — Minimal prep: feeds + bootloader + WiFi only (no third-party)
# =============================================================================

cd "$(dirname "$0")/../openwrt" 2>/dev/null || {
  echo "[PREP] ERROR: Must run from repo root as: cd openwrt && bash ../build/02_prepare.sh" >&2
  exit 1
}

# --- Argument parsing --------------------------------------------------------
VARIANT="full"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --variant|-v) VARIANT="$2"; shift 2 ;;
    --help|-h) echo "Usage: $0 [--variant full|minimal]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# --- Helpers -----------------------------------------------------------------
sed_in_place() {
  if sed --version >/dev/null 2>&1; then sed -i "$@"; else sed -i '' "$@"; fi
}

is_openwrt_package_wrapper() {
  local pkg_dir="$1"
  local makefile="$pkg_dir/Makefile"
  [ -f "$makefile" ] || return 1
  grep -qE 'include \$\(TOPDIR\)/rules\.mk|BuildPackage|PKG_SOURCE_(PROTO|URL|DATE|VERSION)' "$makefile"
}

restore_openwrt_boot_package() {
  local pkg_name="$1"
  local src_dir="../openwrt_snap/package/boot/$pkg_name"
  local dst_dir="./package/boot/$pkg_name"
  if is_openwrt_package_wrapper "$dst_dir"; then return 0; fi
  if [ ! -d "$src_dir" ]; then echo "[BOOT] Unable to restore $pkg_name: $src_dir not found"; return 1; fi
  rm -rf "$dst_dir"
  cp -rf "$src_dir" "$dst_dir"
  echo "[BOOT] Restored $pkg_name from openwrt_snap"
}

replace_with_custom_package_wrapper() {
  local src_dir="$1" dst_dir="$2" label="$3"
  [ -d "$src_dir" ] || return 1
  if ! is_openwrt_package_wrapper "$src_dir"; then
    echo "[BOOT] Skipping $label: source is not an OpenWrt package wrapper"; return 1
  fi
  rm -rf "$dst_dir"; cp -rf "$src_dir" "$dst_dir"
  echo "[BOOT] Replaced $label with custom package wrapper"
}

configure_package_use_source_dir() {
  local pkg_dir="$1" source_dir_rel="$2" label="$3"
  local makefile="$pkg_dir/Makefile"
  [ -d "$source_dir_rel" ] && [ -f "$makefile" ] || return 1
  local temp_file; temp_file="$(mktemp)"
  awk -v source_dir="$source_dir_rel" '
    /^USE_SOURCE_DIR:=/ { next }
    /^include \$\(INCLUDE_DIR\)\/package\.mk/ && !inserted {
      print "USE_SOURCE_DIR:=$(TOPDIR)/" source_dir; inserted=1
    }
    { print }
    END { if (!inserted) print "USE_SOURCE_DIR:=$(TOPDIR)/" source_dir }
  ' "$makefile" > "$temp_file"
  mv "$temp_file" "$makefile"
  echo "[BOOT] Configured $label → USE_SOURCE_DIR=$source_dir_rel"
}

patch_custom_atf_sdmmc_flags() {
  local bl2_mk="$1"
  [ -f "$bl2_mk" ] || return 1
  perl -0pi -e 's/ifeq \(\$\(BOOT_DEVICE\),sdmmc\)\n\$\(eval \$\(call BL2_BOOT_SD\)\)\nBL2_SOURCES\t\t\+=\t\+\$\(MTK_PLAT_SOC\)\/bl2\/bl2_dev_mmc\.c\nDEFINES\t\t\t\+=\t-DMSDC_INDEX=1\nDTS_NAME\t\t:=\tmt7988\nendif # END OF BOOTDEVICE = sdmmc/ifeq (\$(BOOT_DEVICE),sdmmc)\n\$(eval \$(call BL2_BOOT_SD))\nBL2_SOURCES\t\t+=\t\$(MTK_PLAT_SOC)\/bl2\/bl2_dev_mmc.c\nBL2_CPPFLAGS\t\t+=\t-DMSDC_INDEX=1\nDTS_NAME\t\t:=\tmt7988\nendif # END OF BOOTDEVICE = sdmmc/s' "$bl2_mk"
  echo "[BOOT] Patched ATF sdmmc flags (DEFINES → BL2_CPPFLAGS)"
}

fix_tfa_ldflags_compat() {
  local tfa_include="./include/trusted-firmware-a.mk"
  [ -f "$tfa_include" ] || return 1
  perl -0pi -e 's/LDFLAGS="-no-warn-rwx-segments"/LDFLAGS="-Wl,--no-warn-rwx-segments"/g' "$tfa_include"
  echo "[BOOT] Patched TF-A LDFLAGS compatibility"
}

ensure_file_has_line() {
  local file_path="$1" line="$2" label="$3"
  [ -f "$file_path" ] || return 1
  grep -Fqx "$line" "$file_path" || printf '%s\n' "$line" >> "$file_path"
  echo "$label: $(basename "$file_path") ← $line"
}

# ===========================================================================
# SECTION 1: Feeds
# ===========================================================================
echo "[PREP] === Section 1: Feed configuration ==="

rewrite_feeds() {
  local pkg_src="$1" luci_src="$2" routing_src="$3" telephony_src="$4"
  for feed_file in feeds.conf feeds.conf.default; do
    [ -f "$feed_file" ] || continue
    sed_in_place "s#https://git.openwrt.org/feed/packages.git[^ ]*#$pkg_src#g" "$feed_file"
    sed_in_place "s#https://git.openwrt.org/project/luci.git[^ ]*#$luci_src#g" "$feed_file"
    sed_in_place "s#https://git.openwrt.org/feed/routing.git[^ ]*#$routing_src#g" "$feed_file"
    sed_in_place "s#https://git.openwrt.org/feed/telephony.git[^ ]*#$telephony_src#g" "$feed_file"
  done
}

disable_mtk_feed() {
  for feed_file in feeds.conf feeds.conf.default; do
    [ -f "$feed_file" ] || continue
    sed_in_place '/^src-\(git\|link\)\(-full\)\? mtk /d' "$feed_file"
  done
  rm -rf ./feeds/mtk ./feeds/mtk.index
}

rewrite_feeds \
  "https://github.com/openwrt/packages.git;openwrt-24.10" \
  "https://github.com/openwrt/luci.git;openwrt-24.10" \
  "https://github.com/openwrt/routing.git;openwrt-24.10" \
  "https://github.com/openwrt/telephony.git;openwrt-24.10"

disable_mtk_feed

if ! ./scripts/feeds update -a; then
  rewrite_feeds \
    "https://git.openwrt.org/feed/packages.git;openwrt-24.10" \
    "https://git.openwrt.org/project/luci.git;openwrt-24.10" \
    "https://git.openwrt.org/feed/routing.git;openwrt-24.10" \
    "https://git.openwrt.org/feed/telephony.git;openwrt-24.10"
  disable_mtk_feed
  ./scripts/feeds update -a
fi

# ===========================================================================
# SECTION 2: Kernel config + feeds install
# ===========================================================================
echo "[PREP] === Section 2: Kernel config + feeds ==="

ensure_file_has_line \
  "./target/linux/mediatek/filogic/config-6.6" \
  "# CONFIG_USB_XHCI_MTK_DEBUGFS is not set" \
  "[KERNEL]"

fix_tfa_ldflags_compat

if ! ./scripts/feeds install -a; then
  echo "[PREP] WARNING: Some feeds failed to install (non-fatal)" >&2
fi

# ===========================================================================
# SECTION 3: Custom Bootloader
# ===========================================================================
echo "[PREP] === Section 3: Custom bootloader integration ==="

restore_openwrt_boot_package arm-trusted-firmware-mediatek || true
restore_openwrt_boot_package uboot-mediatek || true

if [ -d "../bl-mt798x-dhcpd" ]; then
  echo "[BOOT] Found custom bootloader: bl-mt798x-dhcpd"
  atf_custom_applied=0

  if replace_with_custom_package_wrapper \
    "../bl-mt798x-dhcpd/atf-20260123" \
    "./package/boot/arm-trusted-firmware-mediatek" "ATF"; then
    atf_custom_applied=1
  elif configure_package_use_source_dir \
    "./package/boot/arm-trusted-firmware-mediatek" \
    "../bl-mt798x-dhcpd/atf-20260123" "ATF"; then
    atf_custom_applied=1
  fi

  replace_with_custom_package_wrapper \
    "../bl-mt798x-dhcpd/uboot-mtk-20250711" \
    "./package/boot/uboot-mediatek" "U-Boot" || configure_package_use_source_dir \
    "./package/boot/uboot-mediatek" \
    "../bl-mt798x-dhcpd/uboot-mtk-20250711" "U-Boot" || true

  # GPT injection
  if [ "$atf_custom_applied" -eq 1 ] && [ -n "${BPI_R4_GPT_LAYOUT:-}" ] && [ -f "../patches/gpt/$BPI_R4_GPT_LAYOUT" ]; then
    mkdir -p "../bl-mt798x-dhcpd/atf-20260123/src/gpt"
    cp "../patches/gpt/$BPI_R4_GPT_LAYOUT" "../bl-mt798x-dhcpd/atf-20260123/src/gpt/"
    echo "[GPT] Injected: $BPI_R4_GPT_LAYOUT"
  elif [ -n "${BPI_R4_GPT_LAYOUT:-}" ] && [ "$atf_custom_applied" -ne 1 ]; then
    echo "[GPT] Skipping: no custom ATF applied"
  elif [ -n "${BPI_R4_GPT_LAYOUT:-}" ]; then
    echo "[GPT] Skipping: layout '$BPI_R4_GPT_LAYOUT' not found"
  else
    echo "[GPT] No GPT layout requested"
  fi

  if [ "$atf_custom_applied" -eq 1 ]; then
    patch_custom_atf_sdmmc_flags "../bl-mt798x-dhcpd/atf-20260123/plat/mediatek/mt7988/bl2/bl2.mk" || true
  fi
else
  echo "[BOOT] Custom bootloader not found, using default OpenWrt sources"
fi

# ===========================================================================
# SECTION 4: WiFi TX Power unlock
# ===========================================================================
echo "[PREP] === Section 4: WiFi TX power unlock ==="

rm -rf ./package/firmware/wireless-regdb/patches/*
cp ../patches/kernel/mtk-wifi/500-tx_power.patch ./package/firmware/wireless-regdb/patches/ 2>/dev/null || true
if [ -f "../patches/kernel/mtk-wifi/regdb.Makefile" ]; then
  cp ../patches/kernel/mtk-wifi/regdb.Makefile ./package/firmware/wireless-regdb/Makefile
fi

# ===========================================================================
# SECTION 5: Build system optimizations
# ===========================================================================
echo "[PREP] === Section 5: Build system optimizations ==="

sed_in_place 's/Os/O2/g' include/target.mk
sed_in_place 's,-SNAPSHOT,,g' include/version.mk
sed_in_place 's,-SNAPSHOT,,g' package/base-files/image-config.in
sed_in_place '/CONFIG_BUILDBOT/d' include/feeds.mk
sed_in_place 's/;)\s*\\;/; \\/' include/feeds.mk
sed_in_place 's,-mcpu=generic,-march=armv8-a+crc+crypto,g' include/target.mk
sed_in_place 's,CONFIG_WERROR=y,# CONFIG_WERROR is not set,g' target/linux/generic/config-6.6

# ===========================================================================
# SECTION 6+: Full-only (skipped for minimal)
# ===========================================================================
if [ "$VARIANT" = "full" ]; then

  echo "[PREP] === Section 6: Service tuning ==="
  if [ -f "feeds/packages/net/nginx-util/files/uci.conf.template" ]; then
    sed_in_place "s/large_client_header_buffers 2 1k/large_client_header_buffers 4 32k/g" feeds/packages/net/nginx-util/files/uci.conf.template
    sed_in_place "s/client_max_body_size 128M/client_max_body_size 2048M/g" feeds/packages/net/nginx-util/files/uci.conf.template
    sed_in_place '/client_max_body_size/a\\tclient_body_buffer_size 8192M;' feeds/packages/net/nginx-util/files/uci.conf.template
    sed_in_place '/client_max_body_size/a\\tserver_names_hash_bucket_size 128;' feeds/packages/net/nginx-util/files/uci.conf.template
  fi
  if [ -f "feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini" ]; then
    sed_in_place 's,buffer-size = 10000,buffer-size = 131072,g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
    sed_in_place 's,logger = luci,#logger = luci,g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
    sed_in_place 's/threads = 1/threads = 2/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
    sed_in_place 's/processes = 3/processes = 4/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
    sed_in_place 's/cheaper = 1/cheaper = 2/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
  fi
  if [ -f "package/system/rpcd/files/rpcd.config" ]; then
    sed_in_place 's/option timeout 30/option timeout 60/g' package/system/rpcd/files/rpcd.config
  fi

  echo "[PREP] === Section 7: Kernel patches ==="
  cp -rf ../patches/kernel/tcp/* ./target/linux/generic/backport-6.6/ 2>/dev/null || true
  cp -rf ../patches/kernel/fq/* ./target/linux/generic/backport-6.6/ 2>/dev/null || true
  cp -rf ../patches/kernel/bbr3/* ./target/linux/generic/backport-6.6/ 2>/dev/null || true
  cp -rf ../patches/kernel/perf-cc/* ./target/linux/generic/hack-6.6/ 2>/dev/null || true
  cp -rf ../patches/kernel/arm/* ./target/linux/generic/hack-6.6/ 2>/dev/null || true
  cp -rf ../patches/kernel/lrng/* ./target/linux/generic/hack-6.6/ 2>/dev/null || true

  cat >> ./target/linux/generic/config-6.6 <<'LRNG'

# CONFIG_RANDOM_DEFAULT_IMPL is not set
CONFIG_LRNG=y
CONFIG_LRNG_DEV_IF=y
# CONFIG_LRNG_IRQ is not set
CONFIG_LRNG_JENT=y
CONFIG_LRNG_CPU=y
# CONFIG_LRNG_SCHED is not set
CONFIG_LRNG_SELFTEST=y
# CONFIG_LRNG_SELFTEST_PANIC is not set
LRNG

  cp -rf ../patches/kernel/wg/* ./target/linux/generic/hack-6.6/ 2>/dev/null || true
  cp -rf ../patches/kernel/btf/* ./target/linux/generic/hack-6.6/ 2>/dev/null || true
  cp -rf ../patches/kernel/sfe/* ./target/linux/generic/hack-6.6/ 2>/dev/null || true
  cp -rf ../patches/kernel/bcmfullcone/* ./target/linux/generic/hack-6.6/ 2>/dev/null || true
  wget -q https://github.com/torvalds/linux/commit/95d0d094.patch -O target/linux/generic/pending-6.6/999-1-95d0d09.patch 2>/dev/null || true
  wget -q https://github.com/torvalds/linux/commit/1a3e9b7a.patch -O target/linux/generic/pending-6.6/999-2-1a3e9b7.patch 2>/dev/null || true
  wget -q https://github.com/torvalds/linux/commit/7eebd219.patch -O target/linux/generic/pending-6.6/999-3-7eebd21.patch 2>/dev/null || true
  echo "net.netfilter.nf_conntrack_tcp_max_retrans=5" >> ./package/kernel/linux/files/sysctl-nf-conntrack.conf

  echo "[PREP] === Section 8: Fullcone & Firewall4 ==="
  wget -q https://github.com/openwrt/openwrt/commit/bbf39d07.patch -O /tmp/bbf39d07.patch 2>/dev/null && patch -p1 < /tmp/bbf39d07.patch || true
  echo "net.netfilter.nf_conntrack_helper = 1" >> ./package/kernel/linux/files/sysctl-nf-conntrack.conf
  mkdir -p package/libs/libnftnl/patches
  cp -f ../patches/packages/firewall/libnftnl/*.patch ./package/libs/libnftnl/patches/ 2>/dev/null || true
  sed_in_place '/PKG_INSTALL:=/iPKG_FIXUP:=autoreconf' package/libs/libnftnl/Makefile
  mkdir -p package/network/utils/nftables/patches
  cp -f ../patches/packages/firewall/nftables/*.patch ./package/network/utils/nftables/patches/ 2>/dev/null || true
  mkdir -p package/network/config/firewall4/patches
  cp -f ../patches/packages/firewall/firewall4_patches/*.patch ./package/network/config/firewall4/patches/ 2>/dev/null || true
  (
    cd feeds/luci
    for p in \
      ../../../patches/packages/firewall/luci/0001-luci-app-firewall-add-nft-fullcone-and-bcm-fullcone-.patch \
      ../../../patches/packages/firewall/luci/0002-luci-app-firewall-add-shortcut-fe-option.patch \
      ../../../patches/packages/firewall/luci/0003-luci-app-firewall-add-ipv6-nat-option.patch \
      ../../../patches/packages/firewall/luci/0004-luci-add-firewall-add-custom-nft-rule-support.patch \
      ../../../patches/packages/firewall/luci/0005-luci-app-firewall-add-natflow-offload-support.patch \
      ../../../patches/packages/firewall/luci/0007-luci-app-firewall-add-fullcone6-option-for-nftables-.patch; do
      [ -f "$p" ] && patch -p1 < "$p" || true
    done
  )
  patch -p1 < ../patches/packages/firewall/100-openwrt-firewall4-add-custom-nft-command-support.patch 2>/dev/null || true

  echo "[PREP] === Section 9: Third-party packages ==="
  cp -rf ../OpenWrt-Add ./package/new 2>/dev/null || true
  rm -rf feeds/packages/net/{xray-core,v2ray-core,v2ray-geodata,sing-box,frp,microsocks,shadowsocks-libev,zerotier,daed} 2>/dev/null || true
  rm -rf feeds/luci/applications/{luci-app-frps,luci-app-frpc,luci-app-zerotier,luci-app-filemanager} 2>/dev/null || true
  rm -rf feeds/packages/utils/coremark 2>/dev/null || true
  rm -rf ./feeds/packages/lang/node 2>/dev/null || true
  rm -rf ./package/new/feeds_packages_lang_node-prebuilt 2>/dev/null || true
  cp -rf ../OpenWrt-Add/feeds_packages_lang_node-prebuilt ./feeds/packages/lang/node 2>/dev/null || true
  rm -rf ./feeds/packages/lang/golang 2>/dev/null || true
  cp -rf ../lede_pkg_ma/lang/golang ./feeds/packages/lang/golang 2>/dev/null || true
  ( cd feeds/packages && patch -p1 < ../../../patches/packages/cgroupfs-mount/0001-fix-cgroupfs-mount.patch 2>/dev/null || true )
  mkdir -p feeds/packages/utils/cgroupfs-mount/patches
  cp -rf ../patches/packages/cgroupfs-mount/90*.patch ./feeds/packages/utils/cgroupfs-mount/patches/ 2>/dev/null || true
  rm -rf ./feeds/packages/net/miniupnpd 2>/dev/null || true
  cp -rf ../openwrt_pkg_ma/net/miniupnpd ./feeds/packages/net/miniupnpd 2>/dev/null || true
  cp -rf ../patches/packages/miniupnpd/*.patch ./feeds/packages/net/miniupnpd/patches/ 2>/dev/null || true
  ( cd feeds/packages && patch -p1 < ../../../patches/packages/miniupnpd/01-set-presentation_url.patch 2>/dev/null || true; patch -p1 < ../../../patches/packages/miniupnpd/02-force_forwarding.patch 2>/dev/null || true )
  ( cd feeds/luci && patch -p1 < ../../../patches/packages/miniupnpd/luci-upnp-support-force_forwarding-flag.patch 2>/dev/null || true )
  rm -rf ./feeds/luci/applications/luci-app-dockerman 2>/dev/null || true
  cp -rf ../dockerman/applications/luci-app-dockerman ./feeds/luci/applications/luci-app-dockerman 2>/dev/null || true
  sed_in_place '/auto_start/d' feeds/luci/applications/luci-app-dockerman/root/etc/uci-defaults/luci-app-dockerman 2>/dev/null || true
  rm -rf ./feeds/luci/collections/luci-lib-docker 2>/dev/null || true
  cp -rf ../docker_lib/collections/luci-lib-docker ./feeds/luci/collections/luci-lib-docker 2>/dev/null || true
  patch -p1 < ../patches/packages/odhcp6c/1002-odhcp6c-support-dhcpv6-hotplug.patch 2>/dev/null || true
  rm -rf ./package/network/services/odhcpd; cp -rf ../openwrt_ma/package/network/services/odhcpd ./package/network/services/odhcpd 2>/dev/null || true
  rm -rf ./package/network/ipv6/odhcp6c; cp -rf ../openwrt_ma/package/network/ipv6/odhcp6c ./package/network/ipv6/odhcp6c 2>/dev/null || true

  echo "[PREP] === Section 10: TEO CPU idle scheduler ==="
  cat >> ./target/linux/mediatek/filogic/config-6.6 <<'TEO'

CONFIG_CPU_IDLE_GOV_MENU=n
CONFIG_CPU_IDLE_GOV_TEO=y
TEO

else
  echo "[PREP] === Skipping full sections (variant: $VARIANT) ==="
fi

# ===========================================================================
# Final: Rootfs overlay + cleanup
# ===========================================================================
echo "[PREP] === Rootfs overlay ==="
cp -rf ../files ./files

find ./ -name '*.orig' -delete
find ./ -name '*.rej' -delete

echo "[PREP] Package preparation complete (variant: $VARIANT)."
