from pathlib import Path
import json

from backend.app.domain.models import PlanningConfig
from backend.app.jobs.service import JobService
from backend.app.visualization.mapper import normalize_result_payload


def create_router(service: JobService, artifact_root: Path):
    try:
        from fastapi import APIRouter, BackgroundTasks, HTTPException
    except ModuleNotFoundError as exc:
        raise RuntimeError("FastAPI is not installed; install backend dependencies first.") from exc

    router = APIRouter(prefix="/api")

    @router.post("/tasks")
    def create_task(config: PlanningConfig, background_tasks: BackgroundTasks):
        created = service.create_job(config)
        background_tasks.add_task(service.run_job, created.job_id)
        return created

    @router.get("/tasks")
    def list_tasks():
        return service.store.list_jobs()

    @router.get("/tasks/{job_id}")
    def get_task(job_id: str):
        record = service.store.get_job(job_id)
        if record is None:
            raise HTTPException(status_code=404, detail="Job not found")
        return record

    @router.get("/tasks/{job_id}/result")
    def get_result(job_id: str):
        result_path = artifact_root / job_id / "result.json"
        if not result_path.exists():
            raise HTTPException(status_code=404, detail="Result not available")
        return normalize_result_payload(json.loads(result_path.read_text(encoding="utf-8")))

    return router
