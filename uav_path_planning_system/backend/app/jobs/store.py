import json
import sqlite3
from dataclasses import dataclass
from pathlib import Path

from backend.app.core.time import beijing_now_iso
from backend.app.domain.models import JobStatus, PlanningConfig


@dataclass(frozen=True)
class JobRecord:
    job_id: str
    status: JobStatus
    config: PlanningConfig
    scenario_id: str | None
    algorithm_key: str
    artifact_dir: str | None
    progress_json: str | None
    created_at: str
    updated_at: str
    error_message: str | None


class JobStore:
    def __init__(self, database_path: Path) -> None:
        self.database_path = database_path
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        self._ensure_schema()

    def _connect(self) -> sqlite3.Connection:
        return sqlite3.connect(self.database_path)

    def _ensure_schema(self) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS jobs (
                    job_id TEXT PRIMARY KEY,
                    status TEXT NOT NULL,
                    config_json TEXT NOT NULL,
                    scenario_id TEXT,
                    algorithm_key TEXT,
                    artifact_dir TEXT,
                    progress_json TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    error_message TEXT
                )
                """
            )
            for name, ddl in {
                "scenario_id": "ALTER TABLE jobs ADD COLUMN scenario_id TEXT",
                "algorithm_key": "ALTER TABLE jobs ADD COLUMN algorithm_key TEXT",
                "artifact_dir": "ALTER TABLE jobs ADD COLUMN artifact_dir TEXT",
                "progress_json": "ALTER TABLE jobs ADD COLUMN progress_json TEXT",
            }.items():
                columns = [row[1] for row in conn.execute("PRAGMA table_info(jobs)").fetchall()]
                if name not in columns:
                    conn.execute(ddl)

    def create_job(self, job_id: str, config: PlanningConfig) -> JobRecord:
        now = beijing_now_iso()
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO jobs(
                    job_id, status, config_json, scenario_id, algorithm_key, artifact_dir,
                    progress_json, created_at, updated_at, error_message
                )
                VALUES (?, ?, ?, ?, ?, NULL, NULL, ?, ?, NULL)
                """,
                (
                    job_id,
                    JobStatus.queued.value,
                    config.model_dump_json(by_alias=True),
                    config.scenario.scenario_id,
                    config.algorithm_key,
                    now,
                    now,
                ),
            )
        return JobRecord(
            job_id,
            JobStatus.queued,
            config,
            config.scenario.scenario_id,
            config.algorithm_key,
            None,
            None,
            now,
            now,
            None,
        )

    def update_status(
        self,
        job_id: str,
        status: JobStatus,
        error_message: str | None = None,
    ) -> None:
        now = beijing_now_iso()
        with self._connect() as conn:
            conn.execute(
                "UPDATE jobs SET status = ?, updated_at = ?, error_message = ? WHERE job_id = ?",
                (status.value, now, error_message, job_id),
            )

    def update_runtime_paths(
        self,
        job_id: str,
        *,
        artifact_dir: Path | None = None,
        progress: dict | None = None,
    ) -> None:
        now = beijing_now_iso()
        progress_json = json.dumps(progress, ensure_ascii=False) if progress is not None else None
        with self._connect() as conn:
            conn.execute(
                """
                UPDATE jobs
                SET artifact_dir = COALESCE(?, artifact_dir),
                    progress_json = COALESCE(?, progress_json),
                    updated_at = ?
                WHERE job_id = ?
                """,
                (str(artifact_dir) if artifact_dir else None, progress_json, now, job_id),
            )

    def get_job(self, job_id: str) -> JobRecord | None:
        with self._connect() as conn:
            row = conn.execute(
                """
                SELECT job_id, status, config_json, scenario_id, algorithm_key, artifact_dir,
                       progress_json, created_at, updated_at, error_message
                FROM jobs WHERE job_id = ?
                """,
                (job_id,),
            ).fetchone()
        if row is None:
            return None
        return JobRecord(
            job_id=row[0],
            status=JobStatus(row[1]),
            config=PlanningConfig.model_validate(json.loads(row[2])),
            scenario_id=row[3],
            algorithm_key=row[4] or "DCMOCPSO",
            artifact_dir=row[5],
            progress_json=row[6],
            created_at=row[7],
            updated_at=row[8],
            error_message=row[9],
        )

    def list_jobs(self) -> list[JobRecord]:
        with self._connect() as conn:
            rows = conn.execute(
                """
                SELECT job_id, status, config_json, scenario_id, algorithm_key, artifact_dir,
                       progress_json, created_at, updated_at, error_message
                FROM jobs ORDER BY created_at DESC
                """
            ).fetchall()
        return [
            JobRecord(
                job_id=row[0],
                status=JobStatus(row[1]),
                config=PlanningConfig.model_validate(json.loads(row[2])),
                scenario_id=row[3],
                algorithm_key=row[4] or "DCMOCPSO",
                artifact_dir=row[5],
                progress_json=row[6],
                created_at=row[7],
                updated_at=row[8],
                error_message=row[9],
            )
            for row in rows
        ]
