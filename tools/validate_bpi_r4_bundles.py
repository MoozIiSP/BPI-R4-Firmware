"""Validate BPI-R4 media-specific release bundles.

This module checks that release bundles for:
- SD
- EMMC
- SNAND

contain the expected files and that a matching sha256sum file exists.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import re
from typing import Iterable
import zipfile


EXPECTED_BUNDLE_MEMBERS = {
    "sd": [
        "openwrt-mediatek-filogic-bananapi_bpi-r4-sdcard.img.gz",
        "openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb",
        "openwrt-mediatek-filogic-bananapi_bpi-r4.manifest",
    ],
    "emmc": [
        "openwrt-mediatek-filogic-bananapi_bpi-r4-emmc-preloader.bin",
        "openwrt-mediatek-filogic-bananapi_bpi-r4-emmc-bl31-uboot.fip",
        "openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb",
        "openwrt-mediatek-filogic-bananapi_bpi-r4.manifest",
    ],
    "snand": [
        "openwrt-mediatek-filogic-bananapi_bpi-r4-snand-preloader.bin",
        "openwrt-mediatek-filogic-bananapi_bpi-r4-snand-bl31-uboot.fip",
        "openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb",
        "openwrt-mediatek-filogic-bananapi_bpi-r4.manifest",
    ],
}

BUNDLE_FILENAME_RE = re.compile(r"^YAOF-BPI-R4-(SD|EMMC|SNAND)-.+\.zip$")
REQUIRED_BUNDLE_KINDS = ["sd", "emmc", "snand"]


@dataclass
class BundleValidationResult:
    path: Path
    bundle_kind: str
    ok: bool
    missing_members: list[str]
    extra_members: list[str]


@dataclass
class ReleaseValidationReport:
    path: Path
    ok: bool
    bundle_results: list[BundleValidationResult]
    missing_bundle_kinds: list[str]
    missing_sha_for: list[str]


def detect_bundle_kind(path: Path) -> str:
    match = BUNDLE_FILENAME_RE.match(path.name)
    if not match:
        raise ValueError(f"Unsupported BPI-R4 bundle filename: {path.name}")
    return match.group(1).lower()


def _zip_members(path: Path) -> list[str]:
    with zipfile.ZipFile(path) as zf:
        return sorted(info.filename for info in zf.infolist() if not info.is_dir())


def validate_bundle_zip(path: Path | str) -> BundleValidationResult:
    bundle_path = Path(path)
    bundle_kind = detect_bundle_kind(bundle_path)
    members = _zip_members(bundle_path)
    expected_members = EXPECTED_BUNDLE_MEMBERS[bundle_kind]
    missing_members = [member for member in expected_members if member not in members]
    extra_members = [member for member in members if member not in expected_members]
    return BundleValidationResult(
        path=bundle_path,
        bundle_kind=bundle_kind,
        ok=not missing_members,
        missing_members=missing_members,
        extra_members=extra_members,
    )


def _find_bundle_paths(release_dir: Path) -> list[Path]:
    return sorted(
        path
        for path in release_dir.glob("YAOF-BPI-R4-*.zip")
        if BUNDLE_FILENAME_RE.match(path.name)
    )


def _has_matching_sha(bundle_path: Path) -> bool:
    return bundle_path.with_suffix(".sha256sum").exists()


def validate_release_dir(path: Path | str) -> ReleaseValidationReport:
    release_dir = Path(path)
    bundle_paths = _find_bundle_paths(release_dir)
    bundle_results = [validate_bundle_zip(bundle_path) for bundle_path in bundle_paths]
    seen_bundle_kinds = {result.bundle_kind for result in bundle_results}
    missing_bundle_kinds = [kind for kind in REQUIRED_BUNDLE_KINDS if kind not in seen_bundle_kinds]
    missing_sha_for = [bundle.path.name for bundle in bundle_results if not _has_matching_sha(bundle.path)]
    ok = (
        not missing_bundle_kinds
        and not missing_sha_for
        and all(bundle.ok for bundle in bundle_results)
    )
    return ReleaseValidationReport(
        path=release_dir,
        ok=ok,
        bundle_results=bundle_results,
        missing_bundle_kinds=missing_bundle_kinds,
        missing_sha_for=missing_sha_for,
    )


def _bundle_result_to_dict(result: BundleValidationResult) -> dict:
    return {
        "path": str(result.path),
        "bundle_kind": result.bundle_kind,
        "ok": result.ok,
        "missing_members": result.missing_members,
        "extra_members": result.extra_members,
    }


def report_to_dict(report: ReleaseValidationReport) -> dict:
    return {
        "path": str(report.path),
        "ok": report.ok,
        "missing_bundle_kinds": report.missing_bundle_kinds,
        "missing_sha_for": report.missing_sha_for,
        "bundle_results": [_bundle_result_to_dict(result) for result in report.bundle_results],
    }


def _format_lines(report: ReleaseValidationReport) -> Iterable[str]:
    yield f"Release dir: {report.path}"
    yield f"Overall status: {'OK' if report.ok else 'FAILED'}"
    if report.missing_bundle_kinds:
        yield f"Missing bundle kinds: {', '.join(report.missing_bundle_kinds)}"
    if report.missing_sha_for:
        yield f"Bundles missing sha256sum: {', '.join(report.missing_sha_for)}"
    for bundle in report.bundle_results:
        yield f"- {bundle.path.name}: {'OK' if bundle.ok else 'FAILED'}"
        if bundle.missing_members:
            yield f"  missing: {', '.join(bundle.missing_members)}"
        if bundle.extra_members:
            yield f"  extra: {', '.join(bundle.extra_members)}"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate YAOF BPI-R4 media release bundles")
    parser.add_argument(
        "path",
        nargs="?",
        default="artifact",
        help="Bundle zip or directory containing YAOF-BPI-R4-*.zip artifacts (default: artifact)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print JSON report instead of human-readable text",
    )
    args = parser.parse_args(argv)

    target_path = Path(args.path)
    if target_path.is_file():
        result = validate_bundle_zip(target_path)
        if args.json:
            print(json.dumps(_bundle_result_to_dict(result), indent=2, sort_keys=True))
        else:
            print(f"Bundle: {result.path}")
            print(f"Status: {'OK' if result.ok else 'FAILED'}")
            if result.missing_members:
                print(f"Missing: {', '.join(result.missing_members)}")
            if result.extra_members:
                print(f"Extra: {', '.join(result.extra_members)}")
        return 0 if result.ok else 1

    report = validate_release_dir(target_path)
    if args.json:
        print(json.dumps(report_to_dict(report), indent=2, sort_keys=True))
    else:
        for line in _format_lines(report):
            print(line)
    return 0 if report.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
