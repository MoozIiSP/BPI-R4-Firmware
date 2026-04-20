# BPI-R4 Release Notes Template

Use this template for every published tag.

---

## Scope

- **Release:** `<tag>`
- **Commit:** `<sha>`
- **Target line:** `OpenWrt 24.10 / Kernel 6.6`
- **Board:** `Banana Pi BPI-R4`

## Included bundles

- `YAOF-BPI-R4-SD-<date>-<tag>.zip`
- `YAOF-BPI-R4-EMMC-<date>-<tag>.zip`
- `YAOF-BPI-R4-SNAND-<date>-<tag>.zip`
- matching `*.sha256sum`
- CI validation reports:
  - `YAOF-BPI-R4-bundle-validation-<tag>.json`
  - `YAOF-BPI-R4-layout-validation-<tag>.json`

## Medium guidance

### SD

**Use for:** A/B testing and low-friction bring-up.

**Flash path:** write `sdcard.img.gz` to the SD card, boot from SD, then verify `data` auto-expansion.

**Rollback:** power off, remove SD card, boot from your previous medium.

### eMMC

**Use for:** main persistent deployment on common 8GB eMMC modules.

**Flash path:** use the bundled preloader/FIP pair plus `sysupgrade.itb` according to your current bootloader flow.

**Rollback:** keep the previous slot/recovery path available and verify slot switching before production rollout.

### SPI-NAND

**Use for:** minimal self-bootable recovery / rescue system.

**Flash path:** flash the bundled NAND preloader/FIP artifacts and validate standalone boot.

**Rollback:** recover through UART / alternate boot medium if NAND flashing fails.

## Known issues

- `<issue or none>`
- `<issue or none>`

## Validation status

- SD boot: `<pass/fail/pending>`
- SD auto-expand: `<pass/fail/pending>`
- eMMC 8GB GPT: `<pass/fail/pending>`
- eMMC upgrade / rollback: `<pass/fail/pending>`
- SPI-NAND standalone boot: `<pass/fail/pending>`
- Cross-media regression check: `<pass/fail/pending>`

Link the full report:
- `docs/bpi-r4-test-report-<tag>.md`

## Checksums

Verify the matching `*.sha256sum` file before flashing.
