#!/bin/bash
set -euo pipefail

# Unified CI build entry point for GitHub Actions.
#
# Environment:
#   BUILD_VARIANT             minimal|full (default: minimal)
#   BUILD_MEDIA               sd|emmc|snand (default: sd)
#   BPI_R4_ENABLE_MTK_FEED    0|1 (default: 1)
#   BPI_R4_MTK_FEED_RELEASE   MTK feed release directory (default: 24.10)
#   ARTIFACT_DIR              output directory for bundled artifacts

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

BUILD_VARIANT="${BUILD_VARIANT:-minimal}"
BUILD_MEDIA="${BUILD_MEDIA:-sd}"
BPI_R4_ENABLE_MTK_FEED="${BPI_R4_ENABLE_MTK_FEED:-1}"
BPI_R4_MTK_FEED_RELEASE="${BPI_R4_MTK_FEED_RELEASE:-24.10}"
ARTIFACT_DIR="${ARTIFACT_DIR:-artifacts}"

case "$BUILD_VARIANT" in
  minimal|full) ;;
  *) echo "[CI] ERROR: BUILD_VARIANT must be minimal or full" >&2; exit 1 ;;
esac

case "$BUILD_MEDIA" in
  sd) BPI_R4_GPT_LAYOUT="${BPI_R4_GPT_LAYOUT:-sd-ab.json}" ;;
  emmc) BPI_R4_GPT_LAYOUT="${BPI_R4_GPT_LAYOUT:-emmc-8g-ab.json}" ;;
  snand) BPI_R4_GPT_LAYOUT="${BPI_R4_GPT_LAYOUT:-}" ;;
  *) echo "[CI] ERROR: BUILD_MEDIA must be sd, emmc, or snand" >&2; exit 1 ;;
esac

export BPI_R4_ENABLE_MTK_FEED
export BPI_R4_MTK_FEED_RELEASE
export BPI_R4_GPT_LAYOUT

configure_boot_media() {
  local media="$1"
  cd "$REPO_ROOT/openwrt"

  local symbols=(
    CONFIG_PACKAGE_trusted-firmware-a-mt7988-emmc-comb
    CONFIG_PACKAGE_trusted-firmware-a-mt7988-sdmmc-comb
    CONFIG_PACKAGE_trusted-firmware-a-mt7988-spim-nand-ubi-comb
    CONFIG_PACKAGE_u-boot-mt7988_bananapi_bpi-r4-emmc
    CONFIG_PACKAGE_u-boot-mt7988_bananapi_bpi-r4-sdmmc
    CONFIG_PACKAGE_u-boot-mt7988_bananapi_bpi-r4-snand
  )

  for symbol in "${symbols[@]}"; do
    sed -i \
      -e "/^${symbol}=/d" \
      -e "/^# ${symbol} is not set/d" \
      .config
  done

  case "$media" in
    emmc)
      printf '%s\n' \
        '# CONFIG_PACKAGE_trusted-firmware-a-mt7988-sdmmc-comb is not set' \
        '# CONFIG_PACKAGE_trusted-firmware-a-mt7988-spim-nand-ubi-comb is not set' \
        '# CONFIG_PACKAGE_u-boot-mt7988_bananapi_bpi-r4-sdmmc is not set' \
        '# CONFIG_PACKAGE_u-boot-mt7988_bananapi_bpi-r4-snand is not set' \
        'CONFIG_PACKAGE_trusted-firmware-a-mt7988-emmc-comb=y' \
        'CONFIG_PACKAGE_u-boot-mt7988_bananapi_bpi-r4-emmc=y' >> .config
      ;;
    snand)
      printf '%s\n' \
        '# CONFIG_PACKAGE_trusted-firmware-a-mt7988-emmc-comb is not set' \
        '# CONFIG_PACKAGE_trusted-firmware-a-mt7988-sdmmc-comb is not set' \
        '# CONFIG_PACKAGE_u-boot-mt7988_bananapi_bpi-r4-emmc is not set' \
        '# CONFIG_PACKAGE_u-boot-mt7988_bananapi_bpi-r4-sdmmc is not set' \
        'CONFIG_PACKAGE_trusted-firmware-a-mt7988-spim-nand-ubi-comb=y' \
        'CONFIG_PACKAGE_u-boot-mt7988_bananapi_bpi-r4-snand=y' >> .config
      ;;
    sd)
      printf '%s\n' \
        '# CONFIG_PACKAGE_trusted-firmware-a-mt7988-emmc-comb is not set' \
        '# CONFIG_PACKAGE_trusted-firmware-a-mt7988-spim-nand-ubi-comb is not set' \
        '# CONFIG_PACKAGE_u-boot-mt7988_bananapi_bpi-r4-emmc is not set' \
        '# CONFIG_PACKAGE_u-boot-mt7988_bananapi_bpi-r4-snand is not set' \
        'CONFIG_PACKAGE_trusted-firmware-a-mt7988-sdmmc-comb=y' \
        'CONFIG_PACKAGE_u-boot-mt7988_bananapi_bpi-r4-sdmmc=y' >> .config
      ;;
  esac

  make defconfig
}

bundle_artifacts() {
  local target_dir="$REPO_ROOT/openwrt/bin/targets/mediatek/filogic"
  local bundle_name="bpi-r4-${BUILD_VARIANT}-${BUILD_MEDIA}"
  local bundle_dir="$REPO_ROOT/$ARTIFACT_DIR/$bundle_name"
  local archive="$REPO_ROOT/$ARTIFACT_DIR/${bundle_name}.zip"

  rm -rf "$bundle_dir" "$archive" "$archive.sha256sum"
  mkdir -p "$bundle_dir"

  cp "$REPO_ROOT/openwrt/.config" "$bundle_dir/config.build-config"
  cp "$target_dir"/sha256sums "$bundle_dir/" 2>/dev/null || true
  cp "$target_dir"/profiles.json "$bundle_dir/" 2>/dev/null || true
  cp "$target_dir"/version.buildinfo "$bundle_dir/" 2>/dev/null || true
  cp "$target_dir"/feeds.buildinfo "$bundle_dir/" 2>/dev/null || true
  cp "$target_dir"/config.buildinfo "$bundle_dir/" 2>/dev/null || true
  find "$target_dir" -maxdepth 1 -type f -name 'openwrt-mediatek-filogic-bananapi_bpi-r4*' -exec cp {} "$bundle_dir/" \;

  (cd "$REPO_ROOT/$ARTIFACT_DIR" && zip -qr "$(basename "$archive")" "$bundle_name")
  (cd "$REPO_ROOT/$ARTIFACT_DIR" && sha256sum "$(basename "$archive")" > "$(basename "$archive").sha256sum")

  echo "[CI] Bundle created: $archive"
}

echo "[CI] Variant: $BUILD_VARIANT"
echo "[CI] Media: $BUILD_MEDIA"
echo "[CI] MTK feed: $BPI_R4_ENABLE_MTK_FEED"
echo "[CI] MTK release: $BPI_R4_MTK_FEED_RELEASE"
echo "[CI] GPT layout: ${BPI_R4_GPT_LAYOUT:-none}"

chmod +x build/*.sh

echo "[CI] Step 1: clone sources"
bash build/01_clone.sh --variant "$BUILD_VARIANT"

echo "[CI] Step 2: prepare packages"
cd "$REPO_ROOT/openwrt"
bash ../build/02_prepare.sh --variant "$BUILD_VARIANT"

echo "[CI] Step 3: target configuration"
bash ../build/03_target.sh --variant "$BUILD_VARIANT"

echo "[CI] Step 4: seed configuration"
cp "$REPO_ROOT/seed/${BUILD_VARIANT}.seed" .config
make defconfig

echo "[CI] Step 5: boot media configuration"
configure_boot_media "$BUILD_MEDIA"

echo "[CI] Step 6: download sources"
make download -j"$(nproc)"

echo "[CI] Step 7: compile"
set +e
make -j"$(nproc)"
build_status=$?
set -e

if [ "$build_status" -ne 0 ]; then
  echo "[CI] Build failed, retrying first failing target with verbose logs"
  make -j1 V=s || true
  exit "$build_status"
fi

echo "[CI] Step 8: bundle artifacts"
bundle_artifacts
