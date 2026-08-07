# Firewall4 Fullcone Patch Restoration Design

## Objective

Restore the two deliberately disabled firewall4 fullcone patches on the current OpenWrt 24.10 baseline with the smallest source-compatible change, then prove the complete package repository still builds on GitHub Actions.

All patch application checks, validation jobs, and builds run on GitHub-hosted Linux runners. The local macOS checkout is used only for source inspection, editing, and Git operations.

## Current Evidence

- Commit `6f88877` excluded `999-01-firewall4-add-fullcone-support.patch` and `999-02-firewall4-add-bcm-fullconenat-support.patch` to restore the base build.
- GitHub Actions run `26240675942` is the red baseline. It used firewall4 commit `18fc0ead19faf06b8ce7ec5be84957278e942dfa` and failed while applying `999-01`.
- The first and only rejected hunk was the WAN-zone hunk in `root/etc/config/firewall`.
- The patch expects `option forward DROP` as context, while firewall4 `18fc0ead` contains `option forward REJECT`.
- All other `999-01` hunks applied before the package preparation stopped. `999-02` was not attempted because `999-01` failed first.
- The supporting kernel, libnftnl, nftables, LuCI, and non-fullcone firewall4 patches remain enabled in the current passing build.

## Scope

### Included

1. Rebase the failed `999-01` configuration hunk onto the current firewall4 source without changing its intended fullcone defaults.
2. Restore both `999-01` and `999-02` to the firewall4 package patch series in their existing order.
3. Run repository validation and a complete `full / sd / MTK feed 24.10` package repository build on GitHub Actions.
4. Stop at the first new substantive error if `999-02` or a dependent component exposes additional drift.

### Excluded

- Rewriting firewall4 directly from `build/02_prepare.sh`.
- Restoring LRNG or changing any kernel patch family in the same batch.
- Changing fullcone defaults, nftables syntax, or BCM fullcone behavior without new failure evidence.
- Running patch dry-runs, builds, or tests on macOS.
- Publishing a new package Release before the restored series passes the build workflow.

## Approaches Considered

### 1. Minimal patch rebase and series restoration — selected

Update only the stale context line in `999-01`, then remove the two filename exclusions in `build/02_prepare.sh`. This preserves the original feature semantics and keeps the diff attributable to the observed failure.

### 2. Restore only nft fullcone

Enable `999-01` but continue excluding `999-02`. This reduces immediate risk but does not restore the complete intentionally disabled series and leaves BCM fullcone unavailable.

### 3. Replace the patches with build-script mutations

Modify unpacked firewall4 files directly during preparation. This avoids patch context matching but is harder to audit, obscures ordering, and would be more fragile across OpenWrt updates.

## Design

The patch series remains the source of truth. `999-01` continues to introduce nft fullcone support and `999-02` continues to layer BCM fullcone selection on top of it.

The only planned patch-content edit is the failed WAN-zone hunk context:

- old expected context: `option forward DROP`
- current source context: `option forward REJECT`

The hunk adds `fullcone4` and `fullcone6`; it must not change the current forwarding policy. The build script will copy all firewall4 patch files again, preserving lexical order after `001`, `100`, and `990`.

No blanket `|| true`, reject deletion, fuzzy fallback, or automatic patch rewriting is added. A new failure remains fatal and visible in the GitHub Actions log.

## Remote Validation

1. Treat run `26240675942` as the RED evidence for the stale context.
2. Push the minimal patch and build-script changes.
3. Run `.github/workflows/validate.yml` on the feature branch.
4. Run `.github/workflows/build-packages.yml` with MTK feed release `24.10`.
5. Require the `Build package repository` step to succeed and the `bpi-r4-full-packages` artifact to exist, be unexpired, and have nonzero size.

If the build fails, inspect the complete failed job log and identify the first substantive error. Only a directly evidenced drift in `999-02` or its dependencies may expand this batch.

## Success Criteria

- `999-01` and `999-02` are no longer filtered from the firewall4 patch series.
- The current firewall4 forwarding policy remains `REJECT`; restoration does not silently revert it to `DROP`.
- GitHub validation succeeds.
- The complete package repository build succeeds with all firewall4 patches enabled.
- The expected nonempty package artifact is uploaded.
- No local macOS validation or build command is executed.
