from pathlib import Path
import importlib.util
import tempfile
import unittest

from backend.app.domain.models import PlanningConfig
from backend.app.main import create_app


FASTAPI_AVAILABLE = importlib.util.find_spec("fastapi") is not None


class FakeRunner:
    def run(self, job_id: str, config: PlanningConfig, artifact_dir: Path) -> Path:
        result_path = artifact_dir / "result.json"
        result_path.write_text(
            '{"metrics":{"solutionCount":0},"objectives":[],"solutions":[],"scenario":{}}',
            encoding="utf-8",
        )
        (artifact_dir / "stdout.log").write_text("runner log\n", encoding="utf-8")
        return result_path


class ApiResourceTests(unittest.TestCase):
    @unittest.skipUnless(FASTAPI_AVAILABLE, "FastAPI is not installed.")
    def test_resource_workflow_and_scenario_task_api(self) -> None:
        from fastapi.testclient import TestClient

        with tempfile.TemporaryDirectory() as tmp_dir:
            app = create_app(runtime_root=Path(tmp_dir), runner=FakeRunner())
            client = TestClient(app)

            specs_response = client.get("/api/city-models/import-specs")
            self.assertEqual(specs_response.status_code, 200)
            self.assertGreaterEqual(len(specs_response.json()), 1)

            city_response = client.post(
                "/api/city-models/generate",
                json={
                    "name": "city",
                    "algorithmKey": "MatlabAlphaBetaGammaUniformBuildings",
                    "parameters": {"alpha": 0.25, "beta": 8, "gamma": 30, "seed": 1},
                },
            )
            self.assertEqual(city_response.status_code, 200)
            city_id = city_response.json()["id"]

            station_response = client.post(
                "/api/base-station-sets/generate",
                json={
                    "cityModelId": city_id,
                    "name": "stations",
                    "algorithmKey": "MatlabDensityKMeansBaseStations",
                    "parameters": {"bs_per_km2": 4, "seed": 2},
                },
            )
            self.assertEqual(station_response.status_code, 200)
            station_id = station_response.json()["id"]

            path_response = client.post(
                "/api/preset-paths",
                json={
                    "cityModelId": city_id,
                    "baseStationSetId": station_id,
                    "name": "route",
                    "points": [{"x": 0, "y": 0, "z": 50}, {"x": 100, "y": 100, "z": 50}],
                },
            )
            self.assertEqual(path_response.status_code, 200)
            path_id = path_response.json()["id"]

            scenario_response = client.post(
                "/api/scenarios",
                json={
                    "name": "scenario",
                    "cityModelId": city_id,
                    "baseStationSetId": station_id,
                    "presetPathId": path_id,
                },
            )
            self.assertEqual(scenario_response.status_code, 200)
            scenario_id = scenario_response.json()["id"]

            task_response = client.post(
                "/api/tasks",
                json={"scenario": {"scenarioId": scenario_id}, "problem": {}, "algorithm": {}},
            )
            self.assertEqual(task_response.status_code, 200)
            job_id = task_response.json()["job_id"]

            progress_response = client.get(f"/api/tasks/{job_id}/progress")
            self.assertEqual(progress_response.status_code, 200)
            self.assertIn(progress_response.json()["stage"], {"queued", "preparing", "running", "finished"})

            logs_response = client.get(f"/api/tasks/{job_id}/logs")
            self.assertEqual(logs_response.status_code, 200)
            self.assertIn("stdout", logs_response.json())

            input_json = Path(tmp_dir) / "artifacts" / job_id / "input.json"
            self.assertTrue(input_json.exists())
            self.assertIn("matlabScenarioFile", input_json.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
