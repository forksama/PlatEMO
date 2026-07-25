from pathlib import Path
from datetime import datetime, timedelta
import unittest

from backend.app.core.config import Settings
from backend.app.core.time import beijing_now_iso


class SettingsTests(unittest.TestCase):
    def test_settings_defaults_point_to_existing_platemo_root(self) -> None:
        settings = Settings()

        self.assertEqual(settings.project_root.name, "uav_path_planning_system")
        self.assertEqual(settings.repository_root, Path("C:/Repositories/PlatEMO"))
        self.assertEqual(settings.platemo_root, Path("C:/Repositories/PlatEMO/PlatEMO"))
        self.assertTrue(settings.platemo_root.exists())
        self.assertEqual(settings.artifact_root, settings.project_root / ".runtime" / "artifacts")
        self.assertEqual(
            settings.database_path,
            settings.project_root / ".runtime" / "uav_path_planning.sqlite3",
        )

    def test_beijing_now_uses_china_standard_time_offset(self) -> None:
        timestamp = datetime.fromisoformat(beijing_now_iso())

        self.assertEqual(timestamp.utcoffset(), timedelta(hours=8))


if __name__ == "__main__":
    unittest.main()
