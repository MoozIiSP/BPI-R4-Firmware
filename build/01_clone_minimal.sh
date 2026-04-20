#!/bin/bash
set -euo pipefail

# =============================================================================
# 01_clone_minimal.sh — Clone OpenWrt 24.10 + bootloader only (no third-party)
# =============================================================================
# Cache-aware: preserves dl/, staging_dir/, build_dir/ across workspace wipes.
# Usage: Run from the repository root (same directory as build/).
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

OPENWRT_REPO="https://github.com/openwrt/openwrt.git"
BOOTLOADER_REPO="https://github.com/Yuzhii0718/bl-mt798x-dhcpd.git"

# --- Cache-aware clone logic -------------------------------------------------
# When GitHub Actions restores caches then checks out, openwrt/.git may be gone
# but dl/staging_dir/build_dir are restored from cache. Preserve them.

if [ ! -d "openwrt/.git" ]; then
  echo "[CLONE] OpenWrt source missing or incomplete. Re-cloning..."

  # 1. Back up cached directories
  for dir in dl staging_dir build_dir; do
    if [ -d "openwrt/$dir" ]; then
      echo "[CLONE] Backing up openwrt/$dir → _saved_$dir"
      mv "openwrt/$dir" "./_saved_$dir"
    fi
  done

  # 2. Clean and clone
  rm -rf openwrt
  clone_repo "$OPENWRT_REPO" "$OPENWRT_TAG" openwrt &
  clone_repo "$OPENWRT_REPO" "openwrt-24.10" openwrt_snap &
  clone_repo "$BOOTLOADER_REPO" "master" bl-mt798x-dhcpd &

  wait

  # 3. Restore caches
  for dir in dl staging_dir build_dir; do
    if [ -d "./_saved_$dir" ]; then
      echo "[CLONE] Restoring _saved_$dir → openwrt/$dir"
      mv "./_saved_$dir" "openwrt/$dir"
    fi
  done

  # 4. Setup base package structure
  if [ -d "openwrt" ]; then
    find openwrt/package/* -maxdepth 0 \
      ! -name 'firmware' \
      ! -name 'kernel' \
      ! -name 'base-files' \
      ! -name 'Makefile' \
      -exec rm -rf {} +

    if [ -d "openwrt_snap" ]; then
      rm -rf ./openwrt_snap/package/firmware \
             ./openwrt_snap/package/kernel \
             ./openwrt_snap/package/base-files \
             ./openwrt_snap/package/Makefile
      cp -rf ./openwrt_snap/package/* ./openwrt/package/
      cp -rf ./openwrt_snap/feeds.conf.default ./openwrt/feeds.conf.default
    fi
  fi
else
  echo "[CLONE] OpenWrt source already present."
  # Ensure sub-repos exist
  clone_repo "$OPENWRT_REPO" "openwrt-24.10" openwrt_snap
  clone_repo "$BOOTLOADER_REPO" "master" bl-mt798x-dhcpd
fi

echo "[CLONE] OpenWrt base and custom bootloader sources are ready."
