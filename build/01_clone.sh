#!/bin/bash
set -euo pipefail

# =============================================================================
# 01_clone.sh — Clone OpenWrt 24.10 source and third-party repositories
# =============================================================================
# Usage: Run from the repository root (same directory as build/).
# Output: openwrt/, openwrt_snap/, bl-mt798x-dhcpd/, and various third-party
#         package repos cloned alongside the main tree.
# =============================================================================

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# --- Helper ------------------------------------------------------------------
clone_repo() {
  local repo_url="$1"
  local branch_name="$2"
  local target_dir="$3"

  if [ -d "$target_dir/.git" ]; then
    echo "[CLONE] $target_dir already exists, skipping."
    return 0
  fi

  echo "[CLONE] Cloning $repo_url ($branch_name) → $target_dir"
  git clone -b "$branch_name" --depth 1 "$repo_url" "$target_dir"
}

# --- Resolve OpenWrt 24.10 release tag ---------------------------------------
resolve_openwrt_tag() {
  local tag
  tag="$(curl -fsSL https://api.github.com/repos/openwrt/openwrt/tags \
    | jq -r '.[].name' \
    | grep -E '^v24\.10' \
    | head -n 1)"

  if [ -z "$tag" ]; then
    echo "[CLONE] ERROR: Could not resolve OpenWrt v24.10 tag" >&2
    exit 1
  fi

  echo "$tag"
}

OPENWRT_TAG="$(resolve_openwrt_tag)"
echo "[CLONE] Resolved OpenWrt release: $OPENWRT_TAG"

# --- Repository URLs ---------------------------------------------------------
OPENWRT_REPO="https://github.com/openwrt/openwrt.git"
BOOTLOADER_REPO="https://github.com/Yuzhii0718/bl-mt798x-dhcpd.git"

# Third-party package repos (used by 02_prepare.sh)
LEDE_REPO="https://github.com/coolsnowwolf/lede.git"
LEDE_PKG_REPO="https://github.com/coolsnowwolf/packages.git"
OPENWRT_PKG_REPO="https://github.com/openwrt/packages.git"
OPENWRT_ADD_REPO="https://github.com/QiuSimons/OpenWrt-Add.git"
DOCKERMAN_REPO="https://github.com/lisaac/luci-app-dockerman"
DOCKER_LIB_REPO="https://github.com/lisaac/luci-lib-docker"
LUCI_THEME_DESIGN_REPO="https://github.com/SAENE/luci-theme-design"

# --- Clone OpenWrt source ----------------------------------------------------
clone_repo "$OPENWRT_REPO" "$OPENWRT_TAG" openwrt

# Clone openwrt-24.10 snapshot for package replacement
clone_repo "$OPENWRT_REPO" "openwrt-24.10" openwrt_snap

# --- Clone custom bootloader -------------------------------------------------
clone_repo "$BOOTLOADER_REPO" "master" bl-mt798x-dhcpd

# --- Clone third-party repos (needed by 02_prepare.sh) -----------------------
clone_repo "$LEDE_REPO" "master" lede &
clone_repo "$LEDE_PKG_REPO" "master" lede_pkg_ma &
clone_repo "$OPENWRT_PKG_REPO" "master" openwrt_pkg_ma &
clone_repo "$OPENWRT_ADD_REPO" "master" OpenWrt-Add &
clone_repo "$DOCKERMAN_REPO" "master" dockerman &
clone_repo "$DOCKER_LIB_REPO" "master" docker_lib &
clone_repo "$LUCI_THEME_DESIGN_REPO" "master" luci_theme_design_repo &

wait

# --- Post-clone: merge snap packages into main tree --------------------------
echo "[CLONE] Merging openwrt_snap packages into openwrt tree"

# Remove default packages from main tree
find openwrt/package/* -maxdepth 0 \
  ! -name 'firmware' \
  ! -name 'kernel' \
  ! -name 'base-files' \
  ! -name 'Makefile' \
  -exec rm -rf {} +

# Copy snap packages (these contain the 24.10 feed definitions)
rm -rf ./openwrt_snap/package/firmware \
       ./openwrt_snap/package/kernel \
       ./openwrt_snap/package/base-files \
       ./openwrt_snap/package/Makefile

cp -rf ./openwrt_snap/package/* ./openwrt/package/
cp -rf ./openwrt_snap/feeds.conf.default ./openwrt/feeds.conf.default

echo "[CLONE] All repositories cloned and prepared."
