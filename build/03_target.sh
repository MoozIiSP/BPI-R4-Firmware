#!/bin/bash
set -euo pipefail

# =============================================================================
# 03_target.sh — Target-specific configuration for BPI-R4
# =============================================================================
# MUST run from inside the openwrt/ directory: cd openwrt && ../build/03_target.sh
# Usage: cd openwrt && bash ../build/03_target.sh [--variant full|minimal]
# (Both variants use the same target config logic)
# =============================================================================

cd "$(dirname "$0")/../openwrt" 2>/dev/null || {
  echo "[TARGET] ERROR: Must run from repo root as: cd openwrt && bash ../build/03_target.sh" >&2
  exit 1
}

# --- Argument parsing (accepted but logic is the same for both) ----------------
VARIANT="full"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --variant|-v) VARIANT="$2"; shift 2 ;;
    --help|-h) echo "Usage: $0 [--variant full|minimal]"; exit 0 ;;
    *) ;; # ignore
  esac
done

sed_in_place() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# --- ARM crypto optimization ---
echo "[TARGET] Applying ARM crypto optimization"
sed_in_place 's,-mcpu=generic,-march=armv8-a+crc+crypto,g' include/target.mk

# --- Vermagic: fetch from mediatek/filogic profiles.json ---
echo "[TARGET] Resolving vermagic from mediatek/filogic profiles.json"

resolve_profiles_url() {
  local release_repo version_number
  release_repo="$(sed -n 's#^VERSION_REPO:=.*,\(https://downloads\.openwrt\.org/releases/[^)]*\)).*$#\1#p' include/version.mk | tail -n 1)"

  if [ -z "$release_repo" ]; then
    version_number="$(sed -n 's#^VERSION_NUMBER:=.*,\([^)]*\)).*$#\1#p' include/version.mk | tail -n 1)"
    if [ -n "$version_number" ]; then
      release_repo="https://downloads.openwrt.org/releases/$version_number"
    fi
  fi

  if [ -z "$release_repo" ]; then
    echo "[TARGET] ERROR: Failed to resolve OpenWrt release repo" >&2
    return 1
  fi

  printf '%s/targets/mediatek/filogic/profiles.json\n' "${release_repo%/}"
}

profiles_url="$(resolve_profiles_url)"
echo "[TARGET] Downloading from: $profiles_url"
wget -q -O profiles.json "$profiles_url"
jq -er '.linux_kernel.vermagic' profiles.json > .vermagic

echo "[TARGET] Vermagic: $(cat .vermagic)"

# Patch kernel-defaults.mk to copy .vermagic during build
sed_in_place \
  -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' \
  include/kernel-defaults.mk

# --- Rootfs overlay ---
echo "[TARGET] Copying rootfs overlay"
cp -rf ../patches/files ./files

# --- Cleanup ---
find ./ -name '*.orig' -delete
find ./ -name '*.rej' -delete

echo "[TARGET] Target configuration complete."
