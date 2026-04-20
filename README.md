# BPI-R4 Firmware

OpenWrt 24.10 firmware for Banana Pi BPI-R4 (MT7988 / Filogic 880).

## Build Targets

| Target | Description |
|--------|-------------|
| BPI-R4 (Full) | Full-featured router firmware with all packages |
| BPI-R4 (Minimal) | Base system for MTK/bootloader validation |
| BPI-R4 (NAND) | SPI-NAND optimized build |
| BPI-R4-PRO | PRO variant firmware |

## Directory Structure

```
├── build/              # Build scripts (clone, prepare, target)
├── seed/               # OpenWrt .config seed files
├── patches/            # Kernel patches, rootfs overlay, GPT layouts
│   ├── kernel/         # Kernel patches (BBRv3, SFE, LRNG, etc.)
│   ├── packages/       # Package-level patches
│   ├── files/          # Rootfs overlay (etc/)
│   └── gpt/            # A/B partition layouts
├── tools/              # Validation and analysis tools
├── docs/               # Documentation
└── .github/workflows/  # CI/CD pipelines
```

## Quick Start

```bash
git clone -b main https://github.com/MoozIiSP/BPI-R4-Firmware.git
cd BPI-R4-Firmware
# Run build scripts from the build/ directory
```

## License

GPL-2.0
