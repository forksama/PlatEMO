from pathlib import Path
import json
from typing import Any

from backend.app.domain.models import PlanningConfig
from backend.app.jobs.service import JobService
from backend.app.resources.service import ResourceNotFoundError, ResourceService, ResourceValidationError
from backend.app.visualization.mapper import normalize_result_payload


def create_router(service: JobService, artifact_root: Path, resource_service: ResourceService):
    try:
        from fastapi import APIRouter, BackgroundTasks, HTTPException
        from pydantic import BaseModel, ConfigDict, Field
    except ModuleNotFoundError as exc:
        raise RuntimeError("FastAPI is not installed; install backend dependencies first.") from exc

    router = APIRouter(prefix="/api")

    class ImportRequest(BaseModel):
        name: str
        description: str | None = None
        source_format: str = Field(alias="sourceFormat")
        content: str

        model_config = ConfigDict(populate_by_name=True)

    class CityGenerateRequest(BaseModel):
        name: str
        description: str | None = None
        algorithm_key: str = Field(alias="algorithmKey")
        parameters: dict[str, Any] = Field(default_factory=dict)

        model_config = ConfigDict(populate_by_name=True)

    class BaseStationImportRequest(ImportRequest):
        city_model_id: str = Field(alias="cityModelId")

    class BaseStationGenerateRequest(BaseModel):
        city_model_id: str = Field(alias="cityModelId")
        name: str
        algorithm_key: str = Field(alias="algorithmKey")
        parameters: dict[str, Any] = Field(default_factory=dict)

        model_config = ConfigDict(populate_by_name=True)

    class PresetPathCreateRequest(BaseModel):
        city_model_id: str = Field(alias="cityModelId")
        base_station_set_id: str = Field(alias="baseStationSetId")
        name: str
        points: list[dict[str, Any]]

        model_config = ConfigDict(populate_by_name=True)

    class PresetPathImportRequest(ImportRequest):
        city_model_id: str = Field(alias="cityModelId")
        base_station_set_id: str = Field(alias="baseStationSetId")

    class ScenarioCreateRequest(BaseModel):
        name: str
        city_model_id: str = Field(alias="cityModelId")
        base_station_set_id: str = Field(alias="baseStationSetId")
        preset_path_id: str = Field(alias="presetPathId")

        model_config = ConfigDict(populate_by_name=True)

    def translate_resource_error(exc: Exception) -> HTTPException:
        if isinstance(exc, ResourceNotFoundError):
            return HTTPException(status_code=404, detail=str(exc))
        if isinstance(exc, ResourceValidationError):
            return HTTPException(status_code=400, detail=str(exc))
        return HTTPException(status_code=500, detail=str(exc))

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

    @router.get("/tasks/{job_id}/progress")
    def get_progress(job_id: str):
        try:
            return service.get_progress(job_id)
        except KeyError:
            raise HTTPException(status_code=404, detail="Job not found")

    @router.get("/tasks/{job_id}/logs")
    def get_logs(job_id: str):
        try:
            return service.get_logs(job_id)
        except KeyError:
            raise HTTPException(status_code=404, detail="Job not found")

    @router.get("/city-models/import-specs")
    def city_import_specs():
        return resource_service.get_import_specs("city_model")

    @router.get("/city-models/generation-algorithms")
    def city_generation_algorithms():
        return resource_service.get_generation_algorithms("city_model")

    @router.post("/city-models/import")
    def import_city_model(request: ImportRequest):
        try:
            return resource_service.import_city_model(
                name=request.name,
                description=request.description,
                source_format=request.source_format,
                content=request.content,
            )
        except Exception as exc:
            raise translate_resource_error(exc)

    @router.post("/city-models/generate")
    def generate_city_model(request: CityGenerateRequest):
        try:
            return resource_service.generate_city_model(
                name=request.name,
                description=request.description,
                algorithm_key=request.algorithm_key,
                parameters=request.parameters,
            )
        except Exception as exc:
            raise translate_resource_error(exc)

    @router.get("/city-models")
    def list_city_models():
        return resource_service.store.list_city_models()

    @router.get("/city-models/{city_model_id}")
    def get_city_model(city_model_id: str):
        record = resource_service.store.get_city_model(city_model_id)
        if record is None:
            raise HTTPException(status_code=404, detail="City model not found")
        return record

    @router.get("/city-models/{city_model_id}/geometry")
    def get_city_geometry(city_model_id: str):
        try:
            return resource_service.get_city_geometry(city_model_id)
        except Exception as exc:
            raise translate_resource_error(exc)

    @router.get("/base-station-sets/import-specs")
    def base_station_import_specs():
        return resource_service.get_import_specs("base_station_set")

    @router.get("/base-station-sets/generation-algorithms")
    def base_station_generation_algorithms():
        return resource_service.get_generation_algorithms("base_station_set")

    @router.post("/base-station-sets/import")
    def import_base_station_set(request: BaseStationImportRequest):
        try:
            return resource_service.import_base_station_set(
                city_model_id=request.city_model_id,
                name=request.name,
                source_format=request.source_format,
                content=request.content,
            )
        except Exception as exc:
            raise translate_resource_error(exc)

    @router.post("/base-station-sets/generate")
    def generate_base_station_set(request: BaseStationGenerateRequest):
        try:
            return resource_service.generate_base_station_set(
                city_model_id=request.city_model_id,
                name=request.name,
                algorithm_key=request.algorithm_key,
                parameters=request.parameters,
            )
        except Exception as exc:
            raise translate_resource_error(exc)

    @router.get("/base-station-sets")
    def list_base_station_sets(cityModelId: str | None = None):
        return resource_service.store.list_base_station_sets(cityModelId)

    @router.get("/base-station-sets/{set_id}")
    def get_base_station_set(set_id: str):
        record = resource_service.store.get_base_station_set(set_id)
        if record is None:
            raise HTTPException(status_code=404, detail="Base station set not found")
        return record

    @router.get("/base-station-sets/{set_id}/stations")
    def get_base_station_payload(set_id: str):
        try:
            return resource_service.get_base_station_payload(set_id)
        except Exception as exc:
            raise translate_resource_error(exc)

    @router.get("/preset-paths/import-specs")
    def preset_path_import_specs():
        return resource_service.get_import_specs("preset_path")

    @router.post("/preset-paths")
    def create_preset_path(request: PresetPathCreateRequest):
        try:
            return resource_service.create_preset_path(
                city_model_id=request.city_model_id,
                base_station_set_id=request.base_station_set_id,
                name=request.name,
                points=request.points,
            )
        except Exception as exc:
            raise translate_resource_error(exc)

    @router.post("/preset-paths/import")
    def import_preset_path(request: PresetPathImportRequest):
        try:
            return resource_service.import_preset_path(
                city_model_id=request.city_model_id,
                base_station_set_id=request.base_station_set_id,
                name=request.name,
                source_format=request.source_format,
                content=request.content,
            )
        except Exception as exc:
            raise translate_resource_error(exc)

    @router.get("/preset-paths")
    def list_preset_paths():
        return resource_service.store.list_preset_paths()

    @router.get("/preset-paths/{path_id}")
    def get_preset_path(path_id: str):
        try:
            return resource_service.get_preset_path_payload(path_id)
        except Exception as exc:
            raise translate_resource_error(exc)

    @router.post("/scenarios")
    def create_scenario(request: ScenarioCreateRequest):
        try:
            return resource_service.create_scenario(
                name=request.name,
                city_model_id=request.city_model_id,
                base_station_set_id=request.base_station_set_id,
                preset_path_id=request.preset_path_id,
            )
        except Exception as exc:
            raise translate_resource_error(exc)

    @router.get("/scenarios")
    def list_scenarios():
        return resource_service.store.list_scenarios()

    @router.get("/scenarios/{scenario_id}")
    def get_scenario(scenario_id: str):
        record = resource_service.store.get_scenario(scenario_id)
        if record is None:
            raise HTTPException(status_code=404, detail="Scenario not found")
        return record

    @router.get("/scenarios/{scenario_id}/snapshot")
    def get_scenario_snapshot(scenario_id: str):
        try:
            return resource_service.get_scenario_snapshot(scenario_id)
        except Exception as exc:
            raise translate_resource_error(exc)

    @router.get("/algorithms")
    def list_planning_algorithms():
        return [
            {
                "key": "DCMOCPSO",
                "name": "DCMOCPSO",
                "problem": "UAVPathPlanning",
                "parameters": [],
            }
        ]

    @router.get("/resource-generation-algorithms")
    def list_resource_generation_algorithms():
        return resource_service.get_generation_algorithms()

    return router
