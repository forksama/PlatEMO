from pathlib import Path
import unittest

from backend.app.domain.models import JobStatus, PlanningConfig
from backend.app.jobs.service import JobService
from backend.app.jobs.store import JobStore


class FakeRunner:
    def __init__(self, fail: bool = False) -> None:
        self.fail = fail
        self.seen_job_id: str | None = None

    def run(self, job_id: str, config: PlanningConfig, artifact_dir: Path) -> Path:
        self.seen_job_id = job_id
        artifact_dir.mkdir(parents=True, exist_ok=True)
        if self.fail:
            raise RuntimeError("runner failed")
        result_path = artifact_dir / "result.json"
        result_path.write_text(
            '{"metrics":{"solutionCount":0},"objectives":[],"solutions":[],"scenario":{}}',
            encoding="utf-8",
        )
        return result_path


class JobServiceTests(unittest.TestCase):
    def test_job_service_runs_job_to_success(self) -> None:
        with self.subTest("job succeeds"):
            tmp_path = Path("test-runtime/job-success")
            store = JobStore(tmp_path / "jobs.sqlite3")
            runner = FakeRunner()
            service = JobService(store=store, runner=runner, artifact_root=tmp_path / "artifacts")

            job = service.create_job(PlanningConfig())
            service.run_job(job.job_id)

            record = store.get_job(job.job_id)
            self.assertIsNotNone(record)
            assert record is not None
            self.assertEqual(record.status, JobStatus.succeeded)
            self.assertEqual(runner.seen_job_id, job.job_id)
            self.assertTrue((tmp_path / "artifacts" / job.job_id / "input.json").exists())
            self.assertTrue((tmp_path / "artifacts" / job.job_id / "result.json").exists())

    def test_job_service_marks_failed_when_runner_raises(self) -> None:
        tmp_path = Path("test-runtime/job-failure")
        store = JobStore(tmp_path / "jobs.sqlite3")
        service = JobService(
            store=store,
            runner=FakeRunner(fail=True),
            artifact_root=tmp_path / "artifacts",
        )

        job = service.create_job(PlanningConfig())
        with self.assertRaises(RuntimeError):
            service.run_job(job.job_id)

        record = store.get_job(job.job_id)
        self.assertIsNotNone(record)
        assert record is not None
        self.assertEqual(record.status, JobStatus.failed)
        self.assertEqual(record.error_message, "runner failed")


if __name__ == "__main__":
    unittest.main()
