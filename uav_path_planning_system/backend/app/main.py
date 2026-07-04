from pathlib import Path

from backend.app.api.routes import create_router
from backend.app.core.config import Settings
from backend.app.jobs.service import JobService, PlanningRunner
from backend.app.jobs.store import JobStore
from backend.app.matlab.cli_runner import MatlabCliRunner


def create_app(runtime_root: Path | None = None, runner: PlanningRunner | None = None):
    try:
        from fastapi import FastAPI
    except ModuleNotFoundError as exc:
        raise RuntimeError("FastAPI is not installed; install backend dependencies first.") from exc

    settings = Settings()
    if runtime_root is None:
        runtime_root = settings.runtime_root
    artifact_root = runtime_root / "artifacts"
    store = JobStore(runtime_root / "uav_path_planning.sqlite3")
    if runner is None:
        runner = MatlabCliRunner(settings=settings)
    service = JobService(store=store, runner=runner, artifact_root=artifact_root)

    app = FastAPI(title="UAV Path Planning System")
    app.include_router(create_router(service=service, artifact_root=artifact_root))
    return app


try:
    app = create_app()
except RuntimeError:
    app = None
