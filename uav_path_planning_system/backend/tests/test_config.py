from pathlib import Path
import unittest

from backend.app.core.config import Settings


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


if __name__ == "__main__":
    unittest.main()
