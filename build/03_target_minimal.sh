#!/bin/bash
set -euo pipefail

# =============================================================================
# 03_target_minimal.sh — Target-specific config (minimal build variant)
# =============================================================================
# MUST run from inside the openwrt/ directory.
# Same functionality as 03_target.sh — separated for clarity.
# =============================================================================

cd "$(dirname "$0")/../../openwrt" 2>/dev/null || {
  echo "[TARGET] ERROR: Must run from repo root as: cd openwrt && ../build/03_target_minimal.sh" >&2
  exit 1
}

sed_in_place() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# ARM crypto optimization
sed_in_place 's,-mcpu=generic,-march=armv8-a+crc+crypto,g' include/target.mk

# Vermagic
resolve_profiles_url() {
  local release_repo version_number
  release_repo="$(sed -n 's#^VERSION_REPO:=.*,\(https://downloads\.openwrt\.org/releases/[^)]*\)).*$#\1#p' include/version.mk | tail -n 1)"
  if [ -z "$release_repo" ]; then
    version_number="$(sed -n 's#^VERSION_NUMBER:=.*,\([^)]*\)).*$#\1#p' include/version.mk | tail -n 1)"
    [ -n "$version_number" ] && release_repo="https://downloads.openwrt.org/releases/$version_number"
  fi
  [ -z "$release_repo" ] && return 1
  printf '%s/targets/mediatek/filogic/profiles.json\n' "${release_repo%/}"
}

profiles_url="$(resolve_profiles_url)"
wget -q -O profiles.json "$profiles_url"
jq -er '.linux_kernel.vermagic' profiles.json > .vermagic
sed_in_place \
  -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' \
  include/kernel-defaults.mk

# Rootfs overlay
cp -rf ../patches/files ./files

# Cleanup
find ./ -name '*.orig' -delete
find ./ -name '*.rej' -delete

echo "[TARGET] Minimal target configuration complete."
