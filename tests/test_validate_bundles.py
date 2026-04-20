from pathlib import Path
import tempfile
import unittest
import zipfile

from tools.validate_bpi_r4_bundles import validate_bundle_zip, validate_release_dir


class ValidateBpiR4BundlesTests(unittest.TestCase):
    def _write_zip(self, path: Path, members: list[str]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(path, "w") as zf:
            for member in members:
                zf.writestr(member, "test")

    def test_validate_bundle_zip_accepts_sd_bundle(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bundle = Path(tmp) / "YAOF-BPI-R4-SD-2026-04-16-24.10.1.zip"
            self._write_zip(
                bundle,
                [
                    "openwrt-mediatek-filogic-bananapi_bpi-r4-sdcard.img.gz",
                    "openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb",
                    "openwrt-mediatek-filogic-bananapi_bpi-r4.manifest",
                ],
            )

            result = validate_bundle_zip(bundle)

            self.assertTrue(result.ok)
            self.assertEqual(result.bundle_kind, "sd")
            self.assertEqual(result.missing_members, [])

    def test_validate_bundle_zip_reports_missing_emmc_member(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bundle = Path(tmp) / "YAOF-BPI-R4-EMMC-2026-04-16-24.10.1.zip"
            self._write_zip(
                bundle,
                [
                    "openwrt-mediatek-filogic-bananapi_bpi-r4-emmc-preloader.bin",
                    "openwrt-mediatek-filogic-bananapi_bpi-r4.manifest",
                ],
            )

            result = validate_bundle_zip(bundle)

            self.assertFalse(result.ok)
            self.assertEqual(result.bundle_kind, "emmc")
            self.assertIn(
                "openwrt-mediatek-filogic-bananapi_bpi-r4-emmc-bl31-uboot.fip",
                result.missing_members,
            )
            self.assertIn(
                "openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb",
                result.missing_members,
            )

    def test_validate_release_dir_checks_sha_and_all_three_media(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            release_dir = Path(tmp) / "artifact"
            release_dir.mkdir(parents=True, exist_ok=True)

            self._write_zip(
                release_dir / "YAOF-BPI-R4-SD-2026-04-16-24.10.1.zip",
                [
                    "openwrt-mediatek-filogic-bananapi_bpi-r4-sdcard.img.gz",
                    "openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb",
                    "openwrt-mediatek-filogic-bananapi_bpi-r4.manifest",
                ],
            )
            self._write_zip(
                release_dir / "YAOF-BPI-R4-EMMC-2026-04-16-24.10.1.zip",
                [
                    "openwrt-mediatek-filogic-bananapi_bpi-r4-emmc-preloader.bin",
                    "openwrt-mediatek-filogic-bananapi_bpi-r4-emmc-bl31-uboot.fip",
                    "openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb",
                    "openwrt-mediatek-filogic-bananapi_bpi-r4.manifest",
                ],
            )
            self._write_zip(
                release_dir / "YAOF-BPI-R4-SNAND-2026-04-16-24.10.1.zip",
                [
                    "openwrt-mediatek-filogic-bananapi_bpi-r4-snand-preloader.bin",
                    "openwrt-mediatek-filogic-bananapi_bpi-r4-snand-bl31-uboot.fip",
                    "openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb",
                    "openwrt-mediatek-filogic-bananapi_bpi-r4.manifest",
                ],
            )
            (release_dir / "YAOF-BPI-R4-SD-2026-04-16-24.10.1.sha256sum").write_text("sha")
            (release_dir / "YAOF-BPI-R4-EMMC-2026-04-16-24.10.1.sha256sum").write_text("sha")
            (release_dir / "YAOF-BPI-R4-SNAND-2026-04-16-24.10.1.sha256sum").write_text("sha")

            report = validate_release_dir(release_dir)

            self.assertTrue(report.ok)
            self.assertEqual(
                {bundle.bundle_kind for bundle in report.bundle_results},
                {"sd", "emmc", "snand"},
            )
            self.assertEqual(report.missing_bundle_kinds, [])
            self.assertEqual(report.missing_sha_for, [])

    def test_validate_release_dir_reports_missing_snand_bundle(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            release_dir = Path(tmp) / "artifact"
            release_dir.mkdir(parents=True, exist_ok=True)

            self._write_zip(
                release_dir / "YAOF-BPI-R4-SD-2026-04-16-24.10.1.zip",
                [
                    "openwrt-mediatek-filogic-bananapi_bpi-r4-sdcard.img.gz",
                    "openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb",
                    "openwrt-mediatek-filogic-bananapi_bpi-r4.manifest",
                ],
            )
            self._write_zip(
                release_dir / "YAOF-BPI-R4-EMMC-2026-04-16-24.10.1.zip",
                [
                    "openwrt-mediatek-filogic-bananapi_bpi-r4-emmc-preloader.bin",
                    "openwrt-mediatek-filogic-bananapi_bpi-r4-emmc-bl31-uboot.fip",
                    "openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb",
                    "openwrt-mediatek-filogic-bananapi_bpi-r4.manifest",
                ],
            )
            (release_dir / "YAOF-BPI-R4-SD-2026-04-16-24.10.1.sha256sum").write_text("sha")
            (release_dir / "YAOF-BPI-R4-EMMC-2026-04-16-24.10.1.sha256sum").write_text("sha")

            report = validate_release_dir(release_dir)

            self.assertFalse(report.ok)
            self.assertEqual(report.missing_bundle_kinds, ["snand"])


if __name__ == "__main__":
    unittest.main()
