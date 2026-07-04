import json
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from backend.app.domain.models import JobStatus, PlanningConfig


@dataclass(frozen=True)
class JobRecord:
    job_id: str
    status: JobStatus
    config: PlanningConfig
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
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    error_message TEXT
                )
                """
            )

    def create_job(self, job_id: str, config: PlanningConfig) -> JobRecord:
        now = datetime.now(timezone.utc).isoformat()
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO jobs(job_id, status, config_json, created_at, updated_at, error_message)
                VALUES (?, ?, ?, ?, ?, NULL)
                """,
                (job_id, JobStatus.queued.value, config.model_dump_json(), now, now),
            )
        return JobRecord(job_id, JobStatus.queued, config, now, now, None)

    def update_status(
        self,
        job_id: str,
        status: JobStatus,
        error_message: str | None = None,
    ) -> None:
        now = datetime.now(timezone.utc).isoformat()
        with self._connect() as conn:
            conn.execute(
                "UPDATE jobs SET status = ?, updated_at = ?, error_message = ? WHERE job_id = ?",
                (status.value, now, error_message, job_id),
            )

    def get_job(self, job_id: str) -> JobRecord | None:
        with self._connect() as conn:
            row = conn.execute(
                """
                SELECT job_id, status, config_json, created_at, updated_at, error_message
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
            created_at=row[3],
            updated_at=row[4],
            error_message=row[5],
        )

    def list_jobs(self) -> list[JobRecord]:
        with self._connect() as conn:
            rows = conn.execute(
                """
                SELECT job_id, status, config_json, created_at, updated_at, error_message
                FROM jobs ORDER BY created_at DESC
                """
            ).fetchall()
        return [
            JobRecord(
                job_id=row[0],
                status=JobStatus(row[1]),
                config=PlanningConfig.model_validate(json.loads(row[2])),
                created_at=row[3],
                updated_at=row[4],
                error_message=row[5],
            )
            for row in rows
        ]
