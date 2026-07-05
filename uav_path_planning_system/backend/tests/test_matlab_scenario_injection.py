from pathlib import Path
import unittest


class MatlabScenarioInjectionTests(unittest.TestCase):
    def test_uav_path_planning_keeps_existing_altitude_parameters_and_adds_scenario_thirteenth(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        source = (
            repo_root / "PlatEMO/Problems/Multi-objective optimization/Real-world MOPs/UAVPathPlanning.m"
        ).read_text(encoding="utf-8")

        self.assertIn("presetAltitude = params{11}", source)
        self.assertIn("altitudeBounds = params{12}", source)
        self.assertIn("scenarioDataPath = params{13}", source)
        self.assertIn("loadExternalScenario", source)

    def test_planning_bridge_passes_matlab_scenario_file_after_altitude_parameters(self) -> None:
        project_root = Path(__file__).resolve().parents[2]
        source = (project_root / "backend/app/matlab/scripts/run_planning_job.m").read_text(
            encoding="utf-8"
        )

        self.assertIn("scenarioDataPath", source)
        self.assertIn("config.scenario.matlabScenarioFile", source)
        self.assertIn("writeProgress", source)


if __name__ == "__main__":
    unittest.main()
