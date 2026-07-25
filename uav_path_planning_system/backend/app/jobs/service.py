from pathlib import Path
import json
import shutil
from typing import Protocol
from uuid import uuid4

from backend.app.core.time import beijing_now_iso
from backend.app.domain.models import (
    JobCreated,
    JobStatus,
    PlanningConfig,
    PlanningScenarioConfig,
)
from backend.app.jobs.store import JobStore
from backend.app.resources.service import ResourceNotFoundError, ResourceService


class PlanningRunner(Protocol):
    def run(self, job_id: str, config: PlanningConfig, artifact_dir: Path) -> Path:
        ...


class JobService:
    def __init__(
        self,
        store: JobStore,
        runner: PlanningRunner,
        artifact_root: Path,
        resource_service: ResourceService | None = None,
    ) -> None:
        self.store = store
        self.runner = runner
        self.artifact_root = artifact_root
        self.resource_service = resource_service

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
        self.store.update_runtime_paths(job_id, artifact_dir=artifact_dir)

        self.store.update_status(job_id, JobStatus.preparing)
        self._write_progress(
            job_id,
            artifact_dir,
            stage="preparing",
            percent=5,
            message="Preparing task input",
        )

        try:
            effective_config = self._materialize_config(record.config, artifact_dir)
        except Exception as exc:
            self.store.update_status(job_id, JobStatus.failed, str(exc))
            self._write_progress(
                job_id,
                artifact_dir,
                stage="failed",
                percent=100,
                message=str(exc),
            )
            raise

        (artifact_dir / "input.json").write_text(
            effective_config.model_dump_json(indent=2, by_alias=True),
            encoding="utf-8",
        )

        self.store.update_status(job_id, JobStatus.running)
        self._write_progress(
            job_id,
            artifact_dir,
            stage="running",
            percent=10,
            message="Matlab runner started",
        )
        try:
            self.runner.run(job_id, effective_config, artifact_dir)
        except Exception as exc:
            self.store.update_status(job_id, JobStatus.failed, str(exc))
            self._write_progress(
                job_id,
                artifact_dir,
                stage="failed",
                percent=100,
                message=str(exc),
            )
            raise
        self.store.update_status(job_id, JobStatus.exporting)
        self._write_progress(
            job_id,
            artifact_dir,
            stage="exporting",
            percent=95,
            message="Exporting result artifacts",
        )
        self.store.update_status(job_id, JobStatus.succeeded)
        self._write_progress(
            job_id,
            artifact_dir,
            stage="finished",
            percent=100,
            message="Planning task completed",
        )

    def get_progress(self, job_id: str) -> dict:
        record = self.store.get_job(job_id)
        if record is None:
            raise KeyError(f"Unknown job_id: {job_id}")
        if record.artifact_dir:
            progress_path = Path(record.artifact_dir) / "progress.json"
            if progress_path.exists():
                return json.loads(progress_path.read_text(encoding="utf-8"))
        if record.progress_json:
            return json.loads(record.progress_json)
        return {"stage": record.status.value, "percent": 0, "message": record.status.value}

    def get_logs(self, job_id: str) -> dict:
        record = self.store.get_job(job_id)
        if record is None:
            raise KeyError(f"Unknown job_id: {job_id}")
        artifact_dir = Path(record.artifact_dir) if record.artifact_dir else self.artifact_root / job_id
        return {
            "stdout": self._read_text_if_exists(artifact_dir / "stdout.log"),
            "stderr": self._read_text_if_exists(artifact_dir / "stderr.log"),
        }

    def _materialize_config(self, config: PlanningConfig, artifact_dir: Path) -> PlanningConfig:
        scenario_id = config.scenario.scenario_id
        if not scenario_id:
            return config
        if self.resource_service is None:
            raise ResourceNotFoundError("Scenario support is not configured")
        scenario = self.resource_service.store.get_scenario(scenario_id)
        if scenario is None:
            raise ResourceNotFoundError(f"Unknown scenario: {scenario_id}")
        snapshot_dst = artifact_dir / "scenario_snapshot.json"
        matlab_dst = artifact_dir / "matlab_scenario.json"
        shutil.copyfile(scenario.snapshot_file_path, snapshot_dst)
        shutil.copyfile(scenario.matlab_scenario_file_path, matlab_dst)
        scenario_config = PlanningScenarioConfig(
            scenarioId=scenario_id,
            snapshotFile=str(snapshot_dst.resolve()),
            matlabScenarioFile=str(matlab_dst.resolve()),
        )
        return config.model_copy(update={"scenario": scenario_config})

    def _write_progress(
        self,
        job_id: str,
        artifact_dir: Path,
        *,
        stage: str,
        percent: int,
        message: str,
    ) -> None:
        payload = {
            "stage": stage,
            "percent": percent,
            "message": message,
            "updatedAt": beijing_now_iso(),
        }
        (artifact_dir / "progress.json").write_text(
            json.dumps(payload, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        self.store.update_runtime_paths(job_id, artifact_dir=artifact_dir, progress=payload)

    def _read_text_if_exists(self, path: Path) -> str:
        if not path.exists():
            return ""
        return path.read_text(encoding="utf-8")
