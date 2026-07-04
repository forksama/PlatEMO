import importlib.util
from pathlib import Path
import tempfile
import unittest

from backend.app.domain.models import PlanningConfig
from backend.app.main import create_app


FASTAPI_AVAILABLE = importlib.util.find_spec("fastapi") is not None


class FakeRunner:
    def run(self, job_id: str, config: PlanningConfig, artifact_dir: Path) -> Path:
        result_path = artifact_dir / "result.json"
        result_path.write_text(
            """
            {
              "job_id": "fake-job",
              "status": "succeeded",
              "metrics": {"solution_count": 1},
              "objectives": {"solutionIndex": 0, "negativeSignal": 80, "switchCount": 1, "negativeCoverage": -0.9},
              "solutions": {"solutionIndex": 0, "waypoints": [[0, 0, 40]], "switchPoints": {"waypointIndex": 0}},
              "scenario": {}
            }
            """,
            encoding="utf-8",
        )
        return result_path


class ApiTaskTests(unittest.TestCase):
    @unittest.skipIf(FASTAPI_AVAILABLE, "FastAPI is installed; run real API tests instead.")
    def test_create_app_reports_missing_fastapi(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "FastAPI is not installed"):
            create_app(runtime_root=Path("test-runtime/api-missing"))

    @unittest.skipUnless(FASTAPI_AVAILABLE, "FastAPI is not installed.")
    def test_create_and_get_job(self) -> None:
        from fastapi.testclient import TestClient

        with tempfile.TemporaryDirectory() as tmp_dir:
            app = create_app(runtime_root=Path(tmp_dir), runner=FakeRunner())
            client = TestClient(app)

            response = client.post("/api/tasks", json={"problem": {}, "algorithm": {}})

            self.assertEqual(response.status_code, 200)
            created = response.json()
            self.assertEqual(created["status"], "queued")
            job_id = created["job_id"]

            status_response = client.get(f"/api/tasks/{job_id}")
            self.assertEqual(status_response.status_code, 200)
            self.assertEqual(status_response.json()["job_id"], job_id)
            self.assertEqual(status_response.json()["status"], "succeeded")

            result_response = client.get(f"/api/tasks/{job_id}/result")
            self.assertEqual(result_response.status_code, 200)
            self.assertEqual(result_response.json()["metrics"]["solution_count"], 1)
            self.assertIsInstance(result_response.json()["objectives"], list)
            self.assertIsInstance(result_response.json()["solutions"], list)
            self.assertIsInstance(result_response.json()["solutions"][0]["switchPoints"], list)

    @unittest.skipUnless(FASTAPI_AVAILABLE, "FastAPI is not installed.")
    def test_unknown_job_returns_404(self) -> None:
        from fastapi.testclient import TestClient

        with tempfile.TemporaryDirectory() as tmp_dir:
            app = create_app(runtime_root=Path(tmp_dir), runner=FakeRunner())
            client = TestClient(app)

            response = client.get("/api/tasks/missing")

            self.assertEqual(response.status_code, 404)


if __name__ == "__main__":
    unittest.main()
