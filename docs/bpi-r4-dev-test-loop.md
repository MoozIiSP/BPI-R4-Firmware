# BPI-R4 Dev → Test Loop

This is the shortest recommended loop for this repo when you want to:

1. compile locally or via CI,
2. flash to a board,
3. capture logs,
4. analyze what should be optimized next.

---

## 1. Build

Local build baseline:

```bash
bash SCRIPTS/01_get_ready.sh
bash SCRIPTS/02_prepare_package.sh
bash SCRIPTS/BPI-R4/02_target_only.sh

cd openwrt
make defconfig
make -j"$(nproc)"
```

Or trigger the GitHub Actions matrix build and download the media-specific bundle you need.

---

## 2. Pick a medium

- **SD**: fastest iteration path for first-boot and A/B behavior
- **eMMC**: primary persistent deployment validation
- **SPI-NAND**: minimal recovery / rescue validation

Recommended iteration order:

1. SD
2. eMMC
3. SPI-NAND

---

## 3. Flash and boot

Use the correct bundle for the target medium:

- `YAOF-BPI-R4-SD-*.zip`
- `YAOF-BPI-R4-EMMC-*.zip`
- `YAOF-BPI-R4-SNAND-*.zip`

Before flashing, verify the matching `*.sha256sum`.

Bring the board up with serial attached if possible.

---

## 4. Capture runtime evidence on-device

After the board boots and basic network access works:

```sh
sh tools/collect_bpi_r4_runtime_report.sh ./bpi-r4-validation-report
```

This captures the essentials for post-deploy debugging:

- kernel cmdline
- board.json
- block / mount / df / lsblk
- dmesg tail
- logread tail
- fw_printenv
- parted output for `/dev/mmcblk0` when available
- SD expansion marker when present

Copy the resulting directory back to your workstation.

---

## 5. Analyze logs on the workstation

Run:

```bash
python3 tools/analyze_bpi_r4_runtime_report.py ./bpi-r4-validation-report
```

JSON mode:

```bash
python3 tools/analyze_bpi_r4_runtime_report.py ./bpi-r4-validation-report --json
```

The analyzer currently looks for likely problem classes:

- MT7996 / PCIe / ASPM instability
- storage / GPT / resize / ext4 issues
- overlay pressure
- missing SD expansion marker
- network / offload instability
- thermal throttling signs
- missing boot environment visibility

---

## 6. Feed results back into the repo

Use the analyzer output plus the raw capture to decide the next optimization:

- **WiFi / PCIe instability**
  - re-check ASPM disable path
  - confirm MTK feed packages override `mt76`
  - inspect calibration / firmware loading

- **Storage / resize issues**
  - review GPT selection
  - verify the actual flashed medium
  - confirm `data` is last partition and only SD expands it

- **Overlay pressure**
  - trim plugin set
  - move mutable data elsewhere
  - revisit `rootfs_data` / `data` sizing

- **Network/offload instability**
  - test WED / flow offload combinations
  - reduce one acceleration option at a time
  - compare under the same traffic profile

- **Thermal issues**
  - improve cooling before tuning for more throughput

Then document the result in:

- `docs/bpi-r4-test-report-<tag>.md`
- release notes based on `docs/bpi-r4-release-notes-template.md`

---

## 7. Minimal closed loop

The intended loop is:

```text
change config/patch
-> build
-> flash one medium
-> boot + smoke test
-> collect runtime report
-> analyze report
-> adjust one variable
-> rebuild
```

Do not change multiple performance knobs at once if the logs show instability.

For debugging, prefer:

- one medium,
- one hypothesis,
- one rebuild.
