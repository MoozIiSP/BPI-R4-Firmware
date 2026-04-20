# BPI-R4 Firmware

OpenWrt 24.10 firmware for Banana Pi BPI-R4 (MT7988 / Filogic 880).

## Features

- **OpenWrt 24.10** with Kernel 6.6 (version-locked)
- **Custom U-Boot** (Yuzhii0718/bl-mt798x-dhcpd) with DHCPD/WebUI
- **WiFi 7** (MT7996) with TX power unlock and region-free regdb
- **10G networking** with WED hardware offload, SFE, BBRv3
- **A/B partition** support for SD, eMMC, and SPI-NAND
- **Full LuCI** web interface with Chinese/English languages
- **Fullcone NAT**, Shortcut-FE, WireGuard, ZeroTier, Tailscale
- **DAE** (Destination Aware Engine) with BPF acceleration

## Quick Start

```bash
# Clone the repository
git clone -b main https://github.com/MoozIiSP/BPI-R4-Firmware.git
cd BPI-R4-Firmware

# Run build scripts from inside the openwrt directory
# (See build/ directory for individual scripts)
```

## Directory Structure

```
├── build/                    # Build automation scripts
│   ├── 01_clone.sh           # Clone OpenWrt + third-party repos
│   ├── 01_clone_minimal.sh   # Minimal clone (OpenWrt + bootloader)
│   ├── 02_prepare.sh         # Full package preparation
│   ├── 02_prepare_minimal.sh # Minimal package preparation
│   ├── 03_target.sh          # Target-specific configuration
│   └── 03_target_minimal.sh  # Minimal target configuration
├── seed/                     # OpenWrt .config seed files
│   ├── bpi-r4-full.seed      # Full-featured router
│   ├── bpi-r4-minimal.seed   # Base + WiFi 7 validation
│   ├── bpi-r4-nand.seed      # SPI-NAND optimized
│   └── bpi-r4-pro.seed       # BPI-R4-PRO variant
├── patches/                  # Kernel & package patches
│   ├── kernel/               # Kernel patches (BBRv3, SFE, LRNG, etc.)
│   ├── packages/             # Package-level patches (firewall, miniupnpd)
│   ├── files/                # Rootfs overlay (etc/ configuration)
│   └── gpt/                  # A/B partition layouts
├── tools/                    # Validation & analysis tools
├── tests/                    # Test suite for validation tools
├── docs/                     # Documentation
└── .github/workflows/        # CI/CD pipelines
```

## Build Variants

| Seed | Use Case | Rootfs | Key Packages |
|------|----------|--------|-------------|
| `bpi-r4-full` | Daily driver router | 4096MB | DAE, passwall, openclash, ZT, TS, all LuCI |
| `bpi-r4-minimal` | MTK/bootloader validation | 512MB | WiFi 7 firmware, bootloader only |
| `bpi-r4-nand` | SPI-NAND boot | 4096MB | Reduced package set |
| `bpi-r4-pro` | BPI-R4-PRO hardware | 4096MB | Same as full, PRO device target |

## CI/CD

| Workflow | Trigger | Runner | Description |
|----------|---------|--------|-------------|
| **Validate** | push/PR | ubuntu-latest | Syntax check, seed validation, patch structure |
| **Build — Minimal** | manual | self-hosted (Podman) | MTK feed + bootloader validation build |

## Build Flow

```
01_clone → 02_prepare → 03_target → defconfig → seed → download → make
```

1. **Clone** — Fetch OpenWrt 24.10, third-party repos, custom bootloader
2. **Prepare** — Apply kernel patches, replace ATF/U-Boot, configure feeds
3. **Target** — Fetch vermagic, optimize ARM crypto, copy rootfs overlay
4. **Configure** — Apply seed file, run defconfig, narrow bootloader variants
5. **Build** — Download sources, compile firmware

## Kernel Optimizations

| Category | Patches | Effect |
|----------|---------|--------|
| TCP | 6.7 boost (4), 6.8 concurrent (4), 6.8 locality (2) | Better throughput under load |
| BBR | BBRv3 (18 patches) | Modern congestion control |
| FQ | 6.7 FQ scheduling (5 patches) | Better packet scheduling |
| SFE | Shortcut-FE (3 patches) | Software flow offload |
| LRNG | Random number generator (27 patches) | Better entropy |
| Crypto | Hardware crypto (MT7988 SAOT) | 10G Tailscale/Cloudflared |

## Network Tuning

- **WED**: Wireless Ethernet Dispatcher — bypasses CPU for WiFi→Ethernet
- **Flow Offload**: Hardware PPE acceleration
- **SFE**: Software fallback for complex rules
- **BBRv3**: Congestion control algorithm
- **FQ_CODEL + CAKE**: Queue management
- **Fullcone NAT**: Improved P2P compatibility

## Hardware Notes

| Component | Detail |
|-----------|--------|
| SoC | MediaTek MT7988 (Filogic 880) |
| RAM | 4GB / 8GB DDR4 |
| eMMC | 8GB (stock) |
| SPI-NAND | 128MB |
| WiFi 7 | MT7996 (PCIe) |
| 10G SFP+ | Yes |
| 4x GbE | Yes |

## License

GPL-2.0

## Credits

- OpenWrt Project
- Yuzhii0718 (custom bootloader)
- BBRv3 team
- LRNG project
- Shortcut-FE contributors
