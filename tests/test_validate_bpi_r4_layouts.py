from pathlib import Path
import tempfile
import unittest

from tools.validate_bpi_r4_layouts import MIN_MARKETING_8GB_SECTORS, validate_layout, validate_repo


class ValidateBpiR4LayoutsTests(unittest.TestCase):
    def test_repo_layouts_are_valid(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        report = validate_repo(repo_root)
        self.assertTrue(report.ok)
        self.assertTrue(all(result.ok for result in report.results))

    def test_emmc_layout_stays_within_conservative_8gb_marketing_capacity(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        result = validate_layout(repo_root / "PATCH/gpt/bpi-r4-emmc-8g-ab.json", layout_kind="emmc")
        self.assertTrue(result.ok)
        self.assertIsNotNone(result.final_sector)
        assert result.final_sector is not None
        self.assertLess(result.final_sector, MIN_MARKETING_8GB_SECTORS)

    def test_rejects_non_contiguous_layout(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad.json"
            path.write_text(
                """
                {
                  \"u-boot-env\": {\"start\": 8192, \"end\": 9215},
                  \"factory\": {\"start\": 9217, \"end\": 13311},
                  \"fip\": {\"start\": 13312, \"end\": 17407},
                  \"kernel_a\": {\"start\": 17408, \"end\": 82943},
                  \"rootfs_a\": {\"start\": 82944, \"end\": 607231},
                  \"kernel_b\": {\"start\": 607232, \"end\": 672767},
                  \"rootfs_b\": {\"start\": 672768, \"end\": 1197055},
                  \"rootfs_data\": {\"start\": 1197056, \"end\": 3294207},
                  \"data\": {\"start\": 3294208, \"end\": 15499263}
                }
                """.strip()
            )
            result = validate_layout(path, layout_kind="emmc")
            self.assertFalse(result.ok)
            self.assertTrue(any("not contiguous" in error for error in result.errors))


if __name__ == "__main__":
    unittest.main()
