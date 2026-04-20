# BPI-R4 Storage / Boot Media Strategy

This repo should treat **SPI-NAND**, **eMMC**, and **SD** as different boot media with different goals.

## 1. SPI-NAND (128MB)

### Goal
- Keep a **self-bootable minimal system** on NAND
- Must include **bootloader / U-Boot chain**
- Must be able to recover, flash, and manage the board without relying on eMMC/SD

### Expected contents
- BL2 / preloader
- U-Boot env
- factory
- FIP (ATF + U-Boot)
- kernel
- rootfs
- rootfs_data / overlay (small)

### Design notes
- NAND should **not** share the same large GPT/A-B layout used for block devices
- NAND layout is boot-medium specific (typically NMBM or full UBI style)
- Keep rootfs lean; extra plugins should live on overlay only if space allows, or preferably on eMMC/SD/external storage

### Current build policy
- Use `SEED/BPI-R4-NAND/config.seed` for the SPI-NAND bundle
- Keep NAND image bootable with U-Boot / FIP / kernel / rootfs
- Treat SPI-NAND as a **minimal main system / recovery system**, not the full plugin-heavy profile

## 2. eMMC (officially common 8GB)

### Goal
- Primary persistent system
- Stable A/B upgrades
- Enough writable space for configs, opkg installs, and service state

### Current repo policy
- Use an **8GB-safe GPT**
- Keep A/B fixed-size
- Keep `rootfs_data` larger than minimal OpenWrt defaults
- Preserve a separate `data` partition

### Layout intent
- kernel_a/rootfs_a
- kernel_b/rootfs_b
- rootfs_data
- data

## 3. SD Card

### Goal
- Convenient A/B testing media
- Reduce repeated reflash / back-and-forth test friction
- Expand user storage automatically on first boot

### Current repo policy
- Use an A/B GPT baseline compatible with small cards
- Keep slot sizes fixed
- Reserve the final `data` partition for **first-boot auto expansion** to the full card size

### Expected build outputs
- `YAOF-BPI-R4-SD-*.zip`
- `YAOF-BPI-R4-EMMC-*.zip`
- `YAOF-BPI-R4-SNAND-*.zip`

The SD image should remain A/B-capable while expanding the final `data` partition on first boot.

## 4. GPT files in this repo

### Block-device GPTs
- `PATCH/gpt/bpi-r4-ab.json`
  - current default injected GPT for block-device A/B use
  - now sized to be compatible with common 8GB-class media
- `PATCH/gpt/bpi-r4-emmc-8g-ab.json`
  - explicit 8GB eMMC A/B layout
- `PATCH/gpt/bpi-r4-sd-ab.json`
  - SD A/B baseline layout intended for later first-boot expansion of `data`

### Important
These GPT files are for **block devices** (eMMC / SD). They are **not** the NAND partition definition.

## 5. Current status / next follow-up work

Already implemented in repo:
1. Media-specific BPI-R4 build targets (`BPI-R4-EMMC`, `BPI-R4-SD`, `BPI-R4-SNAND`)
2. SD first-boot auto-expand logic for the final `data` partition
3. NAND-specific minimal seed profile (`SEED/BPI-R4-NAND/config.seed`)
4. CI bundle/layout validators plus release/test report templates
5. Explicit `BPI-R4-PRO` experimental-status note

Still worth refining later:
1. Execute the real hardware validation run and publish `docs/bpi-r4-test-report-<tag>.md`
2. Decide whether SD and eMMC should diverge further in GPT sizing after field testing
3. Promote `BPI-R4-PRO` only after dedicated hardware validation

## 6. Validation checklist

For hands-on testing after a build or release, use:

- `docs/bpi-r4-validation-checklist.md`

That checklist covers:
- SD first-boot expansion behavior
- eMMC 8GB-safe GPT validation
- SPI-NAND minimal-system / recovery validation
- cross-media regression checks
