"""Validate BPI-R4 GPT layout JSON files.

This validator provides a CI-safe gate for the media-specific GPT files used by
BPI-R4 builds. It checks structural correctness, contiguity, required
partitions, and an explicit 8 GB marketing-capacity safety rule for eMMC.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
from pathlib import Path
from typing import Iterable

SECTOR_SIZE = 512
MIN_MARKETING_8GB_SECTORS = 8_000_000_000 // SECTOR_SIZE  # conservative lower bound
EMMC_REQUIRED_PARTITIONS = [
    "u-boot-env",
    "factory",
    "fip",
    "kernel_a",
    "rootfs_a",
    "kernel_b",
    "rootfs_b",
    "rootfs_data",
    "data",
]
SD_REQUIRED_PARTITIONS = EMMC_REQUIRED_PARTITIONS


@dataclass
class LayoutValidationResult:
    path: str
    ok: bool
    layout_kind: str
    errors: list[str]
    final_sector: int | None
    total_bytes: int | None


@dataclass
class ValidationReport:
    ok: bool
    results: list[LayoutValidationResult]


def _load_layout(path: Path) -> dict:
    return json.loads(path.read_text())


def _sector_span(partition: dict) -> int:
    return partition["end"] - partition["start"] + 1


def _validate_common(layout: dict, *, required_partitions: list[str]) -> tuple[list[str], int | None]:
    errors: list[str] = []
    missing = [name for name in required_partitions if name not in layout]
    if missing:
        errors.append(f"missing required partitions: {', '.join(missing)}")
        return errors, None

    previous_end = None
    for name, partition in layout.items():
        start = partition["start"]
        end = partition["end"]
        if start > end:
            errors.append(f"partition {name} has start > end ({start} > {end})")
            continue
        if previous_end is not None and start != previous_end + 1:
            errors.append(
                f"partition {name} is not contiguous with previous partition "
                f"({start} != {previous_end + 1})"
            )
        previous_end = end

    if list(layout)[-1] != "data":
        errors.append("last partition must be data so expansion targets the final partition")

    return errors, previous_end


def validate_layout(path: Path | str, *, layout_kind: str) -> LayoutValidationResult:
    layout_path = Path(path)
    layout = _load_layout(layout_path)
    required = EMMC_REQUIRED_PARTITIONS if layout_kind == "emmc" else SD_REQUIRED_PARTITIONS
    errors, final_sector = _validate_common(layout, required_partitions=required)

    if final_sector is not None and layout_kind == "emmc" and final_sector >= MIN_MARKETING_8GB_SECTORS:
        errors.append(
            f"layout exceeds conservative 8GB eMMC marketing capacity: "
            f"end sector {final_sector} >= {MIN_MARKETING_8GB_SECTORS}"
        )

    total_bytes = None
    if final_sector is not None:
        total_bytes = (final_sector + 1) * SECTOR_SIZE

    return LayoutValidationResult(
        path=str(layout_path),
        ok=not errors,
        layout_kind=layout_kind,
        errors=errors,
        final_sector=final_sector,
        total_bytes=total_bytes,
    )


def validate_repo(root: Path | str) -> ValidationReport:
    repo_root = Path(root)
    results = [
        validate_layout(repo_root / "PATCH/gpt/bpi-r4-emmc-8g-ab.json", layout_kind="emmc"),
        validate_layout(repo_root / "PATCH/gpt/bpi-r4-sd-ab.json", layout_kind="sd"),
        validate_layout(repo_root / "PATCH/gpt/bpi-r4-ab.json", layout_kind="sd"),
    ]
    return ValidationReport(ok=all(result.ok for result in results), results=results)


def report_to_dict(report: ValidationReport) -> dict:
    return {"ok": report.ok, "results": [asdict(result) for result in report.results]}


def _format_bytes(size: int | None) -> str:
    if size is None:
        return "unknown"
    gib = size / (1024 ** 3)
    gb = size / 1_000_000_000
    return f"{size} bytes ({gib:.2f} GiB / {gb:.2f} GB)"


def _format_lines(report: ValidationReport) -> Iterable[str]:
    yield f"Overall status: {'OK' if report.ok else 'FAILED'}"
    for result in report.results:
        yield f"- {Path(result.path).name} [{result.layout_kind}]: {'OK' if result.ok else 'FAILED'}"
        if result.final_sector is not None:
            yield f"  final_sector: {result.final_sector}"
        if result.total_bytes is not None:
            yield f"  total_size: {_format_bytes(result.total_bytes)}"
        for error in result.errors:
            yield f"  error: {error}"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate YAOF BPI-R4 GPT layouts")
    parser.add_argument(
        "repo_root",
        nargs="?",
        default=".",
        help="Repository root containing PATCH/gpt (default: current directory)",
    )
    parser.add_argument("--json", action="store_true", help="Print JSON instead of human output")
    args = parser.parse_args(argv)

    report = validate_repo(Path(args.repo_root))
    if args.json:
        print(json.dumps(report_to_dict(report), indent=2, sort_keys=True))
    else:
        for line in _format_lines(report):
            print(line)
    return 0 if report.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
