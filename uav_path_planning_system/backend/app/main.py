from pathlib import Path

from backend.app.api.routes import create_router
from backend.app.core.config import Settings
from backend.app.jobs.service import JobService, PlanningRunner
from backend.app.jobs.store import JobStore
from backend.app.matlab.cli_runner import MatlabCliRunner
from backend.app.resources.service import ResourceService
from backend.app.resources.store import ResourceStore


def create_app(runtime_root: Path | None = None, runner: PlanningRunner | None = None):
    try:
        from fastapi import FastAPI
        from fastapi.middleware.cors import CORSMiddleware
    except ModuleNotFoundError as exc:
        raise RuntimeError("FastAPI is not installed; install backend dependencies first.") from exc

    settings = Settings()
    if runtime_root is None:
        runtime_root = settings.runtime_root
    artifact_root = runtime_root / "artifacts"
    database_path = runtime_root / "uav_path_planning.sqlite3"
    store = JobStore(database_path)
    resource_service = ResourceService(
        store=ResourceStore(database_path),
        resource_root=runtime_root / "resources",
    )
    if runner is None:
        runner = MatlabCliRunner(settings=settings)
    service = JobService(
        store=store,
        runner=runner,
        artifact_root=artifact_root,
        resource_service=resource_service,
    )

    app = FastAPI(title="UAV Path Planning System")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[
            "http://127.0.0.1:5173",
            "http://127.0.0.1:5174",
            "http://127.0.0.1:5175",
            "http://localhost:5173",
            "http://localhost:5174",
            "http://localhost:5175",
        ],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(
        create_router(
            service=service,
            artifact_root=artifact_root,
            resource_service=resource_service,
        )
    )
    return app


try:
    app = create_app()
except RuntimeError:
    app = None
