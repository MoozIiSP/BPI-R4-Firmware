# BPI-R4 Test Report Template

Copy this file to `docs/bpi-r4-test-report-<tag>.md` after each hardware validation run.

---

## Test metadata

- **Release/tag:** `<tag>`
- **Commit SHA:** `<sha>`
- **Board:** `Banana Pi BPI-R4`
- **RAM:** `<4GB / 8GB>`
- **Bootloader:** `<version>`
- **Tester:** `<name>`
- **Date:** `<YYYY-MM-DD>`

## 1. SD validation

### Result
- Status: `<pass/fail/pending>`
- Card used: `<size/vendor>`

### Notes
- First boot: `<notes>`
- Auto-expand: `<notes>`
- A/B behavior: `<notes>`
- Reboot behavior: `<notes>`

### Evidence
- Runtime capture directory: `<path or attachment>`
- Important logs: `<summary>`

## 2. eMMC validation

### Result
- Status: `<pass/fail/pending>`
- eMMC size: `<e.g. 8GB>`

### Notes
- GPT fit: `<notes>`
- Boot result: `<notes>`
- Sysupgrade / slot switch: `<notes>`
- Rollback: `<notes>`

### Evidence
- Runtime capture directory: `<path or attachment>`
- Important logs: `<summary>`

## 3. SPI-NAND validation

### Result
- Status: `<pass/fail/pending>`

### Notes
- Standalone boot: `<notes>`
- Minimal recovery usability: `<notes>`
- Factory partition preservation: `<notes>`

### Evidence
- Runtime capture directory: `<path or attachment>`
- Important logs: `<summary>`

## 4. Cross-media regression checks

- SD-only expansion does not affect eMMC: `<pass/fail/pending>`
- eMMC GPT does not leak into NAND: `<pass/fail/pending>`
- Release bundles distinguish SD/eMMC/SNAND clearly: `<pass/fail/pending>`
- Release notes match artifacts: `<pass/fail/pending>`

## 5. Final verdict

- Release-safe for SD: `<yes/no>`
- Release-safe for eMMC: `<yes/no>`
- Release-safe for SPI-NAND: `<yes/no>`
- Follow-up required: `<list or none>`
