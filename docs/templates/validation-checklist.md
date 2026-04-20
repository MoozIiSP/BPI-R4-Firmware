# BPI-R4 Media Validation Checklist

This checklist is meant for **real hardware verification** after a release or a local build.

Use it to validate the three media-specific BPI-R4 targets in this repo:

- `BPI-R4-SD`
- `BPI-R4-EMMC`
- `BPI-R4-SNAND`

---

## 0. Common pre-checks (all media)

Before testing a specific medium, confirm the following:

- Board really is **Banana Pi BPI-R4**
- Bootloader chain matches the intended flashing path
- You know which image you are testing:
  - `BPI-R4-SD`
  - `BPI-R4-EMMC`
  - `BPI-R4-SNAND`
- Release bundle and SHA256 are both present
- Serial console is available if possible
- A known-good recovery path exists:
  - UART console
  - another boot medium
  - previously working image

Recommended to record during each test:

- release tag / commit SHA
- tested medium
- board RAM size
- bootloader version
- whether first boot succeeded without manual recovery
- any kernel / mount / partition anomalies

---

## 1. SD target checklist (`BPI-R4-SD`)

### Flash / boot
- [ ] `sdcard.img.gz` decompresses cleanly
- [ ] Image writes to SD card without errors
- [ ] Board boots from SD without fallback to other medium
- [ ] Serial log shows normal kernel boot
- [ ] LuCI / SSH becomes reachable on first boot

### A/B layout expectations
- [ ] A/B partitions exist as expected after first boot
- [ ] Active boot slot is identifiable
- [ ] `sysupgrade.itb` can be staged without obvious partition mismatch
- [ ] No unexpected overwrite of boot-critical partitions

### First-boot auto-expand
- [ ] Auto-expand runs only when booted from **SD**
- [ ] Last partition on `/dev/mmcblk0` is expanded
- [ ] `data` grows to expected card capacity
- [ ] Filesystem check/resize completes successfully
- [ ] Marker file `/etc/.sd-data-expanded` is created
- [ ] Reboot after expansion is clean
- [ ] Second boot does **not** repeat destructive resize work

### Capacity edge cases
Test at least one smaller and one larger card if available:
- [ ] Small card still fits baseline A/B image
- [ ] Large card expands only the final `data` partition
- [ ] Partition numbering remains stable after expansion

### Service sanity
- [ ] Overlay is writable after expansion
- [ ] opkg works
- [ ] Network defaults are usable
- [ ] WiFi / switch / WAN do not regress due to SD-only logic

---

## 2. eMMC target checklist (`BPI-R4-EMMC`)

### Flash / boot
- [ ] eMMC preloader and FIP files match the expected flashing flow
- [ ] `sysupgrade.itb` is present in the bundle
- [ ] eMMC flashing completes without partition write errors
- [ ] Board boots from eMMC reliably
- [ ] No accidental dependency on SD/NAND presence

### 8GB-safe GPT validation
- [ ] Layout fits stock/common **8GB eMMC** safely
- [ ] `kernel_a` / `kernel_b` exist as expected
- [ ] `rootfs_a` / `rootfs_b` exist as expected
- [ ] `rootfs_data` exists and is writable
- [ ] `data` partition exists and mounts correctly
- [ ] No partition spills past expected device capacity

### Upgrade / rollback behavior
- [ ] `sysupgrade.itb` writes without partition mismatch
- [ ] Slot switching behaves as expected
- [ ] Config retention is sane
- [ ] Rollback path is understood and testable
- [ ] Existing bootloader flow remains compatible with this GPT

### Persistence / workload checks
- [ ] Reboot preserves configs and installed packages
- [ ] Overlay free space is acceptable for your normal package set
- [ ] Heavy plugin set still fits your intended usage model
- [ ] Logs do not show ext4 / mount / GPT repair issues

---

## 3. SPI-NAND target checklist (`BPI-R4-SNAND`)

### Boot chain / recovery role
- [ ] NAND bundle contains the expected preloader + FIP artifacts
- [ ] NAND flashing path is documented and reproducible
- [ ] Board can boot from SPI-NAND alone
- [ ] System is usable as a **minimal main system / recovery system**

### Minimal-system expectations
- [ ] Image size stays appropriate for 128MB-class NAND constraints
- [ ] Boot succeeds without large-package assumptions
- [ ] LuCI / SSH is available if intended
- [ ] Core network management works
- [ ] Overlay space remains available after first boot

### Partition / filesystem sanity
- [ ] NAND-specific layout is used, not block-device GPT assumptions
- [ ] No signs that SD/eMMC GPT logic was incorrectly applied
- [ ] Kernel/rootfs/overlay mount sequence is clean
- [ ] Factory / calibration-critical areas remain intact

### Recovery usefulness
- [ ] NAND image can flash or recover another medium when needed
- [ ] Basic package install still works within space constraints
- [ ] Device remains manageable even with eMMC/SD removed or broken

---

## 4. Cross-media regression checks

After validating each target individually, also confirm:

- [ ] SD-specific auto-expand does not affect eMMC boot
- [ ] eMMC GPT selection does not leak into NAND build
- [ ] NAND minimal seed does not accidentally become the default for SD/eMMC
- [ ] Release bundles are clearly distinguishable by filename
- [ ] Release notes match the actual bundle contents

---

## 5. Suggested commands during validation

These are useful to collect evidence while testing:

```sh
cat /proc/cmdline
cat /etc/board.json
block info
mount
df -h
lsblk
logread | tail -n 200
dmesg | tail -n 200
fw_printenv 2>/dev/null || true
```

If available on the image, also check:

```sh
parted -s /dev/mmcblk0 print
cat /sys/class/block/mmcblk0/device/type
ls -l /etc/.sd-data-expanded
```

To capture a reusable evidence pack on-device, run:

```sh
sh tools/collect_bpi_r4_runtime_report.sh ./bpi-r4-validation-report
```

Then analyze it on your workstation:

```bash
python3 tools/analyze_bpi_r4_runtime_report.py ./bpi-r4-validation-report
```

Then copy the result into a release/test report based on:

- `docs/bpi-r4-test-report-template.md`
- `docs/bpi-r4-release-notes-template.md`
- `docs/bpi-r4-dev-test-loop.md`

---

## 6. Recommended pass criteria

A target should be considered basically ready only if:

- it boots on real hardware without rescue intervention,
- its partition strategy matches the intended medium,
- it survives at least one reboot,
- its writable storage behaves as expected,
- and its update/recovery story is understood.

If any of those fail, treat the build as **not yet release-safe** for that medium.
