# CLAUDE.md — BPI-R4 Firmware

OpenWrt 24.10 firmware for Banana Pi BPI-R4 (MT7988 / Filogic 880).

## The Build

```
make full        # clone → prepare → target → defconfig → download → compile
make minimal     # same but minimal variant (WiFi 7 + bootloader only)
make validate    # bash syntax + seed checks
```

Scripts: `build/01_clone.sh`, `build/02_prepare.sh`, `build/03_target.sh`
All accept `--variant full|minimal`.

## Rules

- OpenWrt 24.10 only. Strict pin: `grep 'v24.10'`, no loose regex.
- Kernel 6.6 only. Do NOT upgrade. MTK WiFi drivers are locked to 6.6.
- MTK feed is DEAD (git01.mediatek.com 404). Do NOT re-add without verifying a cloneable URL.
- Use `CONFIG_NET_MEDIATEK_SOC_WED=y` for hardware offload. NOT `CONFIG_MTK_NET_PPE` (legacy, 废案).
- ASPM off: `CONFIG_PCIEASPM_DEFAULT_OFF=y`. WiFi 7 on PCIe disconnects under 10G load.
- CPU governor: `schedutil`, NOT `performance`.
- Never paste line-numbered content into .sh or .seed files. Pattern `^\s*\d+\|` must never exist.
- DTS patches for `target/linux/mediatek/files-6.6/` go in scripts as direct edits, NOT in `patches/kernel/`.
- Run `bash -n build/*.sh` after any script change.
- Run `make validate` before pushing.

## Structure

```
build/           — 01_clone, 02_prepare, 03_target (--variant full|minimal)
files/           — rootfs overlay (etc/)
patches/kernel/  — tcp, fq, bbr3, perf-cc, perf-netfast, lrng, sfe, bcmfullcone, mtk-wifi, arm, btf, wg
patches/packages/— firewall, miniupnpd, odhcp6c, cgroupfs-mount
patches/gpt/     — ab.json, emmc-8g-ab.json, sd-ab.json
seed/            — full, minimal, nand, pro
tools/           — validate/analyze python scripts
tests/           — pytest files
```

## Seeds

| seed | purpose |
|------|---------|
| full.seed | Daily driver, all packages (DAE, passwall, ZT, TS, etc.) |
| minimal.seed | MTK/bootloader validation only |
| nand.seed | SPI-NAND optimized |
| pro.seed | BPI-R4-PRO variant |

All seeds must have `CONFIG_LINUX_6_6=y` and `CONFIG_TARGET_ARCH_PACKAGES="aarch64_cortex-a53"`.

## CI

- `validate.yml` — runs on push/PR, ubuntu-latest
- `build-minimal.yml` — manual dispatch, self-hosted Podman (ubuntu:24.04)
- Use heredoc-to-file pattern in YAML: `cat > script.sh <<'EOF'` then `podman run ... bash script.sh`
- If apt fails with "No space left": clear dotnet/android/ghc, use `--no-install-recommends`

## Bootloader

Custom: `Yuzhii0718/bl-mt798x-dhcpd` (master)
- ATF → `package/boot/arm-trusted-firmware-mediatek`
- U-Boot → `package/boot/uboot-mediatek`
- ATF sdmmc needs `DEFINES` → `BL2_CPPFLAGS` patch (in 02_prepare.sh)
- GPT injected into `../bl-mt798x-dhcpd/atf-20260123/src/gpt/`
