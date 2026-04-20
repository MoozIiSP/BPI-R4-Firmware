# =============================================================================
# BPI-R4 Firmware — Build entry point
# =============================================================================
# Usage:
#   make full              — Full build (all packages, LuCI, third-party)
#   make minimal           — Minimal build (base + WiFi 7 + bootloader)
#   make validate          — Run local validation checks
#   make clean             — Remove cloned source trees
#   make help              — Show this help
# =============================================================================

SHELL := /bin/bash
REPO_ROOT := $(shell pwd)
BUILD := $(REPO_ROOT)/build

VARIANT ?= full

.PHONY: full minimal validate clean help \
        clone prepare target defconfig download compile build-all

help:
	@echo "BPI-R4 Firmware Build System"
	@echo ""
	@echo "Targets:"
	@echo "  make full       Full build (clone → compile)"
	@echo "  make minimal    Minimal build (clone → compile)"
	@echo "  make validate   Run local validation (syntax, seeds, patches)"
	@echo "  make clean      Remove cloned source trees (keeps dl/cache)"
	@echo "  make help       Show this help"
	@echo ""
	@echo "Individual steps:"
	@echo "  make clone      Clone OpenWrt and dependencies"
	@echo "  make prepare    Apply patches and configure feeds"
	@echo "  make target     Target-specific configuration"
	@echo "  make defconfig  Generate .config from seed"
	@echo "  make download   Download source packages"
	@echo "  make compile    Compile firmware (parallel)"
	@echo "  make compile-verbose  Compile with full verbose output"
	@echo ""
	@echo "Example:"
	@echo "  make minimal"

full: VARIANT = full
full: build-all

minimal: VARIANT = minimal
minimal: build-all

build-all: clone prepare target defconfig download compile

compile:
	@echo "=== Compiling ($(VARIANT)) ==="
	@echo "Running make -j\$$(nproc) in openwrt/..."
	@echo "  For verbose output: make compile-verbose"
	cd openwrt && make -j$$(nproc)

compile-verbose:
	@echo "=== Compiling verbose ($(VARIANT)) ==="
	cd openwrt && make -j1 V=s

download:
	@echo "=== Downloading sources ($(VARIANT)) ==="
	cd openwrt && make download -j$$(nproc)

clone:
	@echo "=== Cloning (variant: $(VARIANT)) ==="
	bash $(BUILD)/01_clone.sh --variant $(VARIANT)

prepare:
	@echo "=== Preparing packages (variant: $(VARIANT)) ==="
	cd openwrt && bash ../build/02_prepare.sh --variant $(VARIANT)

target:
	@echo "=== Target configuration ==="
	cd openwrt && bash ../build/03_target.sh --variant $(VARIANT)

defconfig:
	@echo "=== Applying seed configuration ==="
	cp -rf seed/$(VARIANT).seed openwrt/.config
	cd openwrt && make defconfig

validate:
	@echo "=== Running validation ==="
	@failed=0; \
	for script in $(BUILD)/*.sh; do \
		echo "Checking $$script..."; \
		if ! bash -n "$$script"; then \
			echo "FAIL: $$script has syntax errors"; \
			failed=1; \
		fi; \
	done; \
	if [ "$$failed" -ne 0 ]; then exit 1; fi
	@echo ""
	@echo "=== Validating seed files ==="
	python3 - <<'PYEOF'
from pathlib import Path
import re, sys

for seed in sorted(Path('seed').glob('*.seed')):
    text = seed.read_text()
    bad = re.findall(r'^\s*\d+\|', text, flags=re.MULTILINE)
    if bad:
        print(f"  ERROR: {seed.name} has line number pollution")
        sys.exit(1)
    if 'CONFIG_LINUX_6_6=y' not in text:
        print(f"  ERROR: {seed.name} missing kernel lock")
        sys.exit(1)
    print(f"  {seed.name}: OK")

print("\nAll validations passed.")
PYEOF

clean:
	@echo "=== Cleaning source trees ==="
	rm -rf openwrt openwrt_snap bl-mt798x-dhcpd \
	       lede lede_pkg_ma openwrt_pkg_ma OpenWrt-Add \
	       dockerman docker_lib luci_theme_design_repo \
	       _saved_dl _saved_staging_dir _saved_build_dir
	@echo "Cleaned. Cache directories (dl/, staging_dir/, build_dir/) preserved if present."
