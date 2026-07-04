from pathlib import Path
from typing import Protocol
from uuid import uuid4

from backend.app.domain.models import JobCreated, JobStatus, PlanningConfig
from backend.app.jobs.store import JobStore


class PlanningRunner(Protocol):
    def run(self, job_id: str, config: PlanningConfig, artifact_dir: Path) -> Path:
        ...


class JobService:
    def __init__(self, store: JobStore, runner: PlanningRunner, artifact_root: Path) -> None:
        self.store = store
        self.runner = runner
        self.artifact_root = artifact_root

    def create_job(self, config: PlanningConfig) -> JobCreated:
        job_id = uuid4().hex
        self.store.create_job(job_id, config)
        return JobCreated(job_id=job_id, status=JobStatus.queued)

    def run_job(self, job_id: str) -> None:
        record = self.store.get_job(job_id)
        if record is None:
            raise KeyError(f"Unknown job_id: {job_id}")

        artifact_dir = self.artifact_root / job_id
        artifact_dir.mkdir(parents=True, exist_ok=True)
        (artifact_dir / "input.json").write_text(
            record.config.model_dump_json(indent=2),
            encoding="utf-8",
        )

        self.store.update_status(job_id, JobStatus.running)
        try:
            self.runner.run(job_id, record.config, artifact_dir)
        except Exception as exc:
            self.store.update_status(job_id, JobStatus.failed, str(exc))
            raise
        self.store.update_status(job_id, JobStatus.succeeded)
