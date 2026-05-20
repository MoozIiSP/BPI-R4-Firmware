# CI and Release Flow

This repository keeps GitHub Actions intentionally small and explicit:

1. `Validate` checks repository structure and script/config sanity.
2. `Build Firmware` performs a manual firmware build for one variant and one
   boot medium.
3. `Release Firmware` builds release bundles and publishes them to GitHub
   Releases.

Temporary patch-test workflows should not be kept after the validated change is
merged. Add build behavior to `build/ci-build.sh` first, then call it from a
workflow.

## Validate

Workflow: `.github/workflows/validate.yml`

Triggers:

- push to any branch, except documentation-only changes
- pull requests targeting `main`
- manual dispatch

Checks:

- bash syntax for `build/*.sh`
- seed file invariants
- expected patch directory population

## Manual build

Workflow: `.github/workflows/build.yml`

Trigger: manual dispatch only.

Inputs:

- `variant`: `minimal` or `full`
- `media`: `sd`, `emmc`, or `snand`
- `enable_mtk_feed`: defaults to enabled
- `mtk_feed_release`: defaults to `24.10`

The workflow runs on `ubuntu-24.04`, installs OpenWrt dependencies through
`build/ci-install-deps.sh`, and executes `build/ci-build.sh`.

The build script performs:

```text
clone sources
-> prepare OpenWrt feeds, MTK payload, patches, and custom bootloader
-> apply target configuration
-> apply seed
-> select boot medium
-> download sources
-> compile
-> bundle artifacts
```

Build outputs are uploaded as workflow artifacts:

```text
bpi-r4-<variant>-<media>.zip
bpi-r4-<variant>-<media>.zip.sha256sum
```

## Release

Workflow: `.github/workflows/release.yml`

Triggers:

- push a tag matching `v*`
- manual dispatch with `tag_name`

The release workflow builds the minimal MTK-feed-enabled profile for:

- SD
- eMMC
- SPI-NAND

After all media builds pass, the publish job creates or updates the GitHub
Release and uploads the generated bundles.

Manual releases default to draft mode. Tag-triggered releases are published
directly.

## Release safety

A successful release workflow means the firmware bundles compiled. It does not
replace hardware validation. Before treating a release as field-ready, run the
hardware checklist in:

```text
docs/templates/validation-checklist.md
```

and record results in a test report based on:

```text
docs/templates/test-report-template.md
```
