# BPI-R4-PRO Status

`BPI-R4-PRO` remains **experimental** in this repository.

## Current status

- Workflow exists: `.github/workflows/BPI-R4-PRO-OpenWrt.yml`
- Seed exists: `SEED/BPI-R4-PRO/config.seed`
- Validation parity with the main `BPI-R4` line: **not yet claimed**

## Maintenance policy

Until a dedicated hardware validation report exists, treat `BPI-R4-PRO` as:

- buildable when CI succeeds,
- useful for experimentation,
- but **not release-validated to the same level as BPI-R4 mainline**.

## Promotion criteria

Promote `BPI-R4-PRO` to first-class maintained status only after:

1. boot validation on real hardware,
2. storage / upgrade validation for its actual boot media,
3. a published `docs/bpi-r4-pro-test-report-<tag>.md`,
4. release notes that explicitly list supported flashing and rollback paths.
