#!/bin/bash
set -euo pipefail

# =============================================================================
# 02_prepare_minimal.sh — Minimal package prep (MTK/bootloader validation only)
# =============================================================================
# MUST run from inside the openwrt/ directory.
# No third-party feeds, no extra packages. Just base + bootloader + WiFi.
# =============================================================================

cd "$(dirname "$0")/../../openwrt" 2>/dev/null || {
  echo "[PREP] ERROR: Must run from repo root as: cd openwrt && ../build/02_prepare_minimal.sh" >&2
  exit 1
}

# --- Helpers -----------------------------------------------------------------
sed_in_place() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
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
  if [ ! -d "$src_dir" ]; then
    echo "[BOOT] Unable to restore $pkg_name: $src_dir not found"; return 1
  fi
  rm -rf "$dst_dir"
  cp -rf "$src_dir" "$dst_dir"
  echo "[BOOT] Restored $pkg_name from openwrt_snap"
}

replace_with_custom_package_wrapper() {
  local src_dir="$1" dst_dir="$2" label="$3"
  [ -d "$src_dir" ] || return 1
  if ! is_openwrt_package_wrapper "$src_dir"; then
    echo "[BOOT] Skipping $label: not an OpenWrt package wrapper"; return 1
  fi
  rm -rf "$dst_dir"
  cp -rf "$src_dir" "$dst_dir"
  echo "[BOOT] Replaced $label with custom wrapper"
}

configure_package_use_source_dir() {
  local pkg_dir="$1" source_dir_rel="$2" label="$3"
  local makefile="$pkg_dir/Makefile"
  [ -d "$source_dir_rel" ] && [ -f "$makefile" ] || return 1
  local temp_file
  temp_file="$(mktemp)"
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
  echo "[BOOT] Patched ATF sdmmc flags"
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

# --- Feeds ---
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

# Kernel config
ensure_file_has_line \
  "./target/linux/mediatek/filogic/config-6.6" \
  "# CONFIG_USB_XHCI_MTK_DEBUGFS is not set" \
  "[KERNEL]"

fix_tfa_ldflags_compat

# Install feeds
./scripts/feeds install -a

# --- Custom Bootloader ---
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
  elif [ -n "${BPI_R4_GPT_LAYOUT:-}" ]; then
    echo "[GPT] Skipping: ATF not applied or layout not found"
  else
    echo "[GPT] No GPT layout requested"
  fi

  if [ "$atf_custom_applied" -eq 1 ]; then
    patch_custom_atf_sdmmc_flags "../bl-mt798x-dhcpd/atf-20260123/plat/mediatek/mt7988/bl2/bl2.mk" || true
  fi
else
  echo "[BOOT] Custom bootloader not found"
fi

# WiFi TX power
rm -rf ./package/firmware/wireless-regdb/patches/*
cp ../patches/kernel/mtk_wifi/500-tx_power.patch ./package/firmware/wireless-regdb/patches/ 2>/dev/null || true
if [ -f "../patches/kernel/mtk_wifi/regdb.Makefile" ]; then
  cp ../patches/kernel/mtk_wifi/regdb.Makefile ./package/firmware/wireless-regdb/Makefile
fi

# Build system cleanup
sed_in_place 's,-SNAPSHOT,,g' include/version.mk
sed_in_place 's,-SNAPSHOT,,g' package/base-files/image-config.in
sed_in_place '/CONFIG_BUILDBOT/d' include/feeds.mk
sed_in_place 's,CONFIG_WERROR=y,# CONFIG_WERROR is not set,g' target/linux/generic/config-6.6 || true

# Rootfs overlay
cp -rf ../patches/files ./files

# Cleanup
find ./ -name '*.orig' -delete
find ./ -name '*.rej' -delete

echo "[PREP] Minimal package preparation complete."
