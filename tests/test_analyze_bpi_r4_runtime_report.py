from pathlib import Path
import tempfile
import textwrap
import unittest

from tools.analyze_bpi_r4_runtime_report import analyze_report_dir


class AnalyzeBpiR4RuntimeReportTests(unittest.TestCase):
    def _write_capture(self, root: Path, name: str, body: str) -> None:
        (root / f"{name}.md").write_text(body)

    def test_detects_pcie_and_overlay_problems(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            report_dir = Path(tmp)
            self._write_capture(
                report_dir,
                "dmesg_tail",
                textwrap.dedent(
                    """
                    # dmesg_tail

                    ## output
                    ```
                    mt7996e 0000:01:00.0: Message 00020007 timeout
                    pcieport 0000:00:00.0: AER: Corrected error received
                    ```
                    """.strip()
                ),
            )
            self._write_capture(
                report_dir,
                "df_h",
                textwrap.dedent(
                    """
                    # df_h

                    ## output
                    ```
                    Filesystem                Size      Used Available Use% Mounted on
                    overlayfs:/overlay      500.0M    450.0M     50.0M  90% /
                    ```
                    """.strip()
                ),
            )
            self._write_capture(report_dir, "mount", "## output\n```\n/dev/mmcblk0p7 on /overlay type ext4 (rw)\n```")
            self._write_capture(report_dir, "mmcblk0_parted", "## output\n```\n9      3294208s 15499263s data\n```")
            self._write_capture(report_dir, "cmdline", "## output\n```\nconsole=ttyS0 root=/dev/mmcblk0p5\n```")
            self._write_capture(report_dir, "fw_printenv", "## output\n```\nbootcmd=test\n```")

            report = analyze_report_dir(report_dir)

            self.assertFalse(report.ok)
            titles = {finding.title for finding in report.findings}
            self.assertIn("Possible MT7996 / PCIe instability", titles)
            self.assertIn("Overlay space is running tight", titles)

    def test_clean_capture_is_ok(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            report_dir = Path(tmp)
            self._write_capture(report_dir, "dmesg_tail", "## output\n```\nnormal boot\n```")
            self._write_capture(report_dir, "logread_tail", "## output\n```\nservices started\n```")
            self._write_capture(report_dir, "df_h", "## output\n```\noverlayfs:/overlay      1.0G    200.0M    824.0M  20% /\n```")
            self._write_capture(report_dir, "mount", "## output\n```\n/dev/root on /rom type squashfs (ro)\n```")
            self._write_capture(report_dir, "mmcblk0_parted", "## output\n```\n9      3294208s 15499263s data\n```")
            self._write_capture(report_dir, "cmdline", "## output\n```\nconsole=ttyS0 root=/dev/mmcblk0p5\n```")
            self._write_capture(report_dir, "fw_printenv", "## output\n```\nbootcmd=test\n```")

            report = analyze_report_dir(report_dir)

            self.assertTrue(report.ok)
            self.assertEqual(report.findings, [])

    def test_missing_report_directory_is_flagged(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            report_dir = Path(tmp) / "missing"
            report = analyze_report_dir(report_dir)
            self.assertFalse(report.ok)
            self.assertTrue(any(finding.title == "No captured report files found" for finding in report.findings))


if __name__ == "__main__":
    unittest.main()
