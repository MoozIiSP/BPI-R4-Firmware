# MTK Feed + Custom Bootloader Build Notes

This note records the validated path for building BPI-R4 firmware with:

- OpenWrt 24.10
- MediaTek's `mtk-openwrt-feeds`
- the custom `bl-mt798x-dhcpd` bootloader tree

The clean builder validation completed successfully with the minimal BPI-R4
target and produced the SD image, recovery/sysupgrade ITBs, and eMMC/SPI-NAND
bootloader artifacts.

## Validated command

Run `02_prepare.sh` from a clean OpenWrt tree with MTK feed support enabled:

```bash
BPI_R4_ENABLE_MTK_FEED=1 \
BPI_R4_MTK_FEED_RELEASE=24.10 \
BPI_R4_GPT_LAYOUT=sd-ab.json \
bash ../build/02_prepare.sh --variant minimal
```

Then build OpenWrt normally:

```bash
make defconfig
make -j"$(nproc)"
```

The clean verification selected:

```text
CONFIG_TARGET_mediatek_filogic_DEVICE_bananapi_bpi-r4=y
```

and generated these key artifacts under `bin/targets/mediatek/filogic/`:

```text
openwrt-mediatek-filogic-bananapi_bpi-r4-sdcard.img.gz
openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb
openwrt-mediatek-filogic-bananapi_bpi-r4-initramfs-recovery.itb
openwrt-mediatek-filogic-bananapi_bpi-r4-emmc-preloader.bin
openwrt-mediatek-filogic-bananapi_bpi-r4-emmc-bl31-uboot.fip
openwrt-mediatek-filogic-bananapi_bpi-r4-snand-preloader.bin
openwrt-mediatek-filogic-bananapi_bpi-r4-snand-bl31-uboot.fip
```

## What changed

`build/02_prepare.sh` now keeps the default path conservative: MTK feed support
is disabled unless `BPI_R4_ENABLE_MTK_FEED=1` is set. When enabled, the script:

- adds `https://git01.mediatek.com/openwrt/feeds/mtk-openwrt-feeds` as
  `mtk_openwrt_feed`
- applies the selected release payload from `24.10/files`
- copies the selected release tools into `tools/`
- applies `24.10/patches-base` and `24.10/patches-feeds`
- copies missing unified filogic DTS sources from the MTK autobuild payload
- prunes one non-BPI-R4 MT7988A reference image target for the minimal variant
- adapts the custom ATF and U-Boot source trees for the current OpenWrt package
  wrappers
- injects the requested GPT layout into the custom ATF tree when
  `BPI_R4_GPT_LAYOUT` is set

## Why the previous build failed

The earlier failure was not one single problem. It was a combination of upstream
version drift and custom source-tree integration gaps.

First, the MTK feed release payload is not applied by `scripts/feeds install`
alone. The feed carries extra `files`, `tools`, `patches-base`, and
`patches-feeds` content under the release directory. Without applying that
payload, the build can fetch feed packages but still miss the target/kernel
changes expected by MTK's package set.

Second, two MTK patches no longer applied cleanly to the current OpenWrt 24.10
tree:

- `1000-arch-arm64-dts-add-fitblk-support-for-MediaTek-RFB.patch` tried to
  apply an `mt7988a-rfb.dts` bootargs hunk that was already present.
- `3200-package-dnsmasq-v2_91-upgrade.patch` expected older `dnsmasq`
  Makefile context; OpenWrt 24.10 had drifted around `PKG_RELEASE`, so the
  metadata update needed to be applied directly.

`02_prepare.sh` now treats these two cases as known, narrow compatibility
adjustments instead of ignoring arbitrary patch failures.

Third, the MTK filogic payload references DTS and DTBO files that are present
in the feed's autobuild tree, but not in the base OpenWrt target tree. Missing
files such as `mt7988a-rfb-eth0-gsw.dtso` and related overlays caused the
kernel/image build to fail. The prepare step now copies `.dts`, `.dtsi`, and
`.dtso` files from the MTK autobuild filogic payload before the target build.

Fourth, the minimal BPI-R4 validation does not need every MTK reference image
target. One reference target, `mediatek_mt7988a-rfb-mxl86252`, requires DTS
support that is not present in the current minimal 6.6 payload. The script
removes that non-BPI-R4 image target only for `--variant minimal`, keeping the
validation focused on `bananapi_bpi-r4`.

Finally, the custom bootloader source tree needed compatibility fixes:

- ATF now uses `BL2_CPPFLAGS += -DMSDC_INDEX=1` instead of passing the SD/MMC
  define through the old `DEFINES` line.
- U-Boot needs the BPI-R4 DTS files extracted from OpenWrt's
  `450-add-bpi-r4.patch` into the custom source tree, plus Makefile entries for
  the BPI-R4 DTBs.
- The BPI-R4 U-Boot defconfigs disable `CONFIG_BOARD_LATE_INIT`, avoiding a
  build-time symbol mismatch in the custom U-Boot tree.

With those fixes in place, the clean builder path can build
`OpenWrt + MTK feed + custom bootloader` without manual edits inside the
OpenWrt tree.
