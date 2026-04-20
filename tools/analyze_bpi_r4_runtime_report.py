"""Analyze captured BPI-R4 runtime validation reports.

Input is the directory produced by `tools/collect_bpi_r4_runtime_report.sh`.
The analyzer scans captured command outputs and highlights likely issues plus
optimization candidates relevant to BPI-R4 deployments.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
from pathlib import Path
import re
from typing import Iterable


@dataclass
class Finding:
    severity: str
    category: str
    title: str
    evidence: list[str]
    recommendation: str


@dataclass
class AnalysisReport:
    path: str
    ok: bool
    findings: list[Finding]
    checked_files: list[str]


def _read_capture_text(report_dir: Path, name: str) -> str:
    path = report_dir / f"{name}.md"
    if not path.exists():
        return ""
    return path.read_text()


def _extract_code_block(text: str) -> str:
    matches = re.findall(r"```(?:[a-z]+)?\n(.*?)```", text, flags=re.S)
    return "\n\n".join(matches)


def _add_finding(findings: list[Finding], *, severity: str, category: str, title: str, evidence: list[str], recommendation: str) -> None:
    findings.append(
        Finding(
            severity=severity,
            category=category,
            title=title,
            evidence=evidence,
            recommendation=recommendation,
        )
    )


def _match_lines(text: str, patterns: list[str]) -> list[str]:
    matched: list[str] = []
    for line in text.splitlines():
        lower = line.lower()
        if any(pattern in lower for pattern in patterns):
            matched.append(line.strip())
    return matched


def analyze_report_dir(path: Path | str) -> AnalysisReport:
    report_dir = Path(path)
    dmesg_text = _extract_code_block(_read_capture_text(report_dir, "dmesg_tail"))
    logread_text = _extract_code_block(_read_capture_text(report_dir, "logread_tail"))
    df_text = _extract_code_block(_read_capture_text(report_dir, "df_h"))
    mount_text = _extract_code_block(_read_capture_text(report_dir, "mount"))
    parted_text = _extract_code_block(_read_capture_text(report_dir, "mmcblk0_parted"))
    fwenv_text = _extract_code_block(_read_capture_text(report_dir, "fw_printenv"))
    cmdline_text = _extract_code_block(_read_capture_text(report_dir, "cmdline"))
    marker_text = _extract_code_block(_read_capture_text(report_dir, "sd_expand_marker"))
    checked_files = sorted(path.name for path in report_dir.glob("*.md"))

    findings: list[Finding] = []
    if not checked_files:
        _add_finding(
            findings,
            severity="medium",
            category="capture",
            title="No captured report files found",
            evidence=[f"Directory checked: {report_dir}"],
            recommendation="Run tools/collect_bpi_r4_runtime_report.sh on the device first, then analyze the resulting directory.",
        )
        return AnalysisReport(path=str(report_dir), ok=False, findings=findings, checked_files=checked_files)

    combined = "\n".join(part for part in [dmesg_text, logread_text] if part)

    pcie_lines = _match_lines(combined, ["pcie", "aspm", "mt7996", "wo0", "reset", "firmware crashed", "timeout"])
    suspicious_pcie = [
        line for line in pcie_lines if any(token in line.lower() for token in ["error", "fail", "timeout", "reset", "crash", "down"]) 
    ]
    if suspicious_pcie:
        _add_finding(
            findings,
            severity="high",
            category="wifi-pcie",
            title="Possible MT7996 / PCIe instability",
            evidence=suspicious_pcie[:8],
            recommendation=(
                "Check PCIe ASPM remains disabled, verify MTK feed priority overrides mt76, "
                "and inspect antenna / calibration / firmware load stability before tuning performance."
            ),
        )

    storage_lines = _match_lines(combined + "\n" + parted_text, ["ext4", "mmc", "blk_update_request", "i/o error", "buffer i/o", "gpt", "partition", "resize2fs", "fsck"])
    suspicious_storage = [
        line for line in storage_lines if any(token in line.lower() for token in ["error", "fail", "corrupt", "gpt", "resize", "i/o", "recovering journal"])
    ]
    if suspicious_storage:
        _add_finding(
            findings,
            severity="high",
            category="storage",
            title="Possible storage / partition / filesystem issue",
            evidence=suspicious_storage[:8],
            recommendation=(
                "Re-check the flashed medium, partition table, and resize flow. For SD, confirm only the final data partition expands. "
                "For eMMC, verify slot layout and sysupgrade target selection."
            ),
        )

    overlay_match = re.search(r"overlayfs:/overlay\s+(\d+(?:\.\d+)?[KMGTP]?)\s+(\d+(?:\.\d+)?[KMGTP]?)\s+(\d+(?:\.\d+)?[KMGTP]?)\s+(\d+%)", df_text)
    if overlay_match:
        used_pct = overlay_match.group(4)
        if int(used_pct.rstrip('%')) >= 85:
            _add_finding(
                findings,
                severity="medium",
                category="overlay-space",
                title="Overlay space is running tight",
                evidence=[overlay_match.group(0)],
                recommendation=(
                    "Trim heavy packages, move mutable data out of overlay, or reconsider rootfs_data / data sizing for your normal plugin set."
                ),
            )

    if parted_text and "data" not in parted_text.lower():
        _add_finding(
            findings,
            severity="medium",
            category="partition-layout",
            title="Captured partition table does not obviously show a data partition",
            evidence=parted_text.splitlines()[:12],
            recommendation="Confirm the running image actually used the intended BPI-R4 SD/eMMC layout and not another fallback layout.",
        )

    if marker_text == "" and "/dev/mmcblk0" in mount_text and "rootfs_data" in parted_text.lower():
        _add_finding(
            findings,
            severity="medium",
            category="sd-expand",
            title="SD expansion marker not captured",
            evidence=["/etc/.sd-data-expanded not present in capture"],
            recommendation="If this was an SD boot, confirm the first-boot expand script ran and did not silently fail.",
        )

    if cmdline_text and "root=" not in cmdline_text:
        _add_finding(
            findings,
            severity="low",
            category="boot-args",
            title="Kernel cmdline missing obvious root= argument",
            evidence=cmdline_text.splitlines()[:4],
            recommendation="Review the boot chain and keep a serial capture for slot-selection debugging.",
        )

    if fwenv_text.strip() == "":
        _add_finding(
            findings,
            severity="low",
            category="boot-env",
            title="fw_printenv produced no captured environment",
            evidence=["fw_printenv output empty or unavailable"],
            recommendation="If A/B rollback debugging is needed, make sure fw_printenv is installed and environment access is configured on the running image.",
        )

    thermal_lines = _match_lines(combined, ["thermal", "throttle", "overheat"])
    thermal_bad = [line for line in thermal_lines if any(token in line.lower() for token in ["throttle", "critical", "overheat"])]
    if thermal_bad:
        _add_finding(
            findings,
            severity="medium",
            category="thermal",
            title="Thermal throttling or overheating signs detected",
            evidence=thermal_bad[:6],
            recommendation="Check cooling, case airflow, and sustained 10G/WiFi load before pushing more aggressive performance tuning.",
        )

    network_lines = _match_lines(combined, ["mtk", "wed", "nft", "flow offload", "napi", "netdev watchdog", "link is down"])
    suspicious_network = [
        line for line in network_lines if any(token in line.lower() for token in ["watchdog", "error", "down", "stopped", "timeout"])
    ]
    if suspicious_network:
        _add_finding(
            findings,
            severity="medium",
            category="network",
            title="Possible network/offload instability",
            evidence=suspicious_network[:8],
            recommendation="Check WED/offload settings, link partner stability, and whether a specific acceleration option should be disabled for this workload.",
        )

    checked_files = sorted(path.name for path in report_dir.glob("*.md"))
    return AnalysisReport(
        path=str(report_dir),
        ok=not any(f.severity == "high" for f in findings),
        findings=findings,
        checked_files=checked_files,
    )


def report_to_dict(report: AnalysisReport) -> dict:
    return {
        "path": report.path,
        "ok": report.ok,
        "checked_files": report.checked_files,
        "findings": [asdict(finding) for finding in report.findings],
    }


def _format_lines(report: AnalysisReport) -> Iterable[str]:
    yield f"Report dir: {report.path}"
    yield f"Overall status: {'OK' if report.ok else 'ATTENTION NEEDED'}"
    yield f"Checked files: {', '.join(report.checked_files) if report.checked_files else 'none'}"
    if not report.findings:
        yield "No obvious issues detected in captured logs."
        return
    for finding in report.findings:
        yield f"- [{finding.severity}] {finding.category}: {finding.title}"
        for line in finding.evidence:
            yield f"    evidence: {line}"
        yield f"    recommendation: {finding.recommendation}"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Analyze a captured BPI-R4 runtime validation report")
    parser.add_argument("report_dir", nargs="?", default="./bpi-r4-validation-report")
    parser.add_argument("--json", action="store_true", help="Print JSON instead of human-readable output")
    args = parser.parse_args(argv)

    report = analyze_report_dir(Path(args.report_dir))
    if args.json:
        print(json.dumps(report_to_dict(report), indent=2, sort_keys=True))
    else:
        for line in _format_lines(report):
            print(line)
    return 0 if report.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
