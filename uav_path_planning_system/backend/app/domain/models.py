from enum import Enum
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class JobStatus(str, Enum):
    queued = "queued"
    preparing = "preparing"
    running = "running"
    exporting = "exporting"
    succeeded = "succeeded"
    failed = "failed"
    cancelled = "cancelled"


class ProblemConfig(BaseModel):
    bs_per_km2: int = Field(default=20, ge=1, le=100)
    velocity: float = Field(default=20, gt=0)
    ttt_seconds: float = Field(default=5, gt=0)
    switch_threshold_dbm: float = -101.5
    obstacle_method: Literal[0] = 0
    transmit_power_dbm: float = 30
    switch_method: Literal[0, 1, 2, 3] = 2
    lookahead_distance_m: float = Field(default=500, ge=0)
    lookahead_hysteresis_range_db: float = Field(default=10, ge=0)
    lookahead_safety_margin_db: float = Field(default=4, ge=0)
    preset_altitude_m: float | None = None
    altitude_bounds_m: tuple[float, float] | None = None


class AlgorithmConfig(BaseModel):
    population_size: int = Field(default=20, ge=1, le=500)
    max_fe: int = Field(default=100, ge=1)
    num_segments: int = Field(default=5, ge=1)
    segment_overlap: int = Field(default=2, ge=0)
    lambda_weight: float = Field(default=0.5, ge=0, le=1)
    c_guide: float = Field(default=0.3, ge=0)
    use_dynamic_grouping: bool = True
    use_dynamic_mutation: bool = True
    use_ek: bool = True
    uniform_point_multiplier: int = Field(default=3, ge=1)


class PlanningScenarioConfig(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    scenario_id: str | None = Field(default=None, alias="scenarioId")
    snapshot_file: str | None = Field(default=None, alias="snapshotFile")
    matlab_scenario_file: str | None = Field(default=None, alias="matlabScenarioFile")


class PlanningConfig(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    scenario: PlanningScenarioConfig = Field(default_factory=PlanningScenarioConfig)
    algorithm_key: str = Field(default="DCMOCPSO", alias="algorithmKey")
    problem: ProblemConfig = Field(default_factory=ProblemConfig)
    algorithm: AlgorithmConfig = Field(default_factory=AlgorithmConfig)


class JobCreated(BaseModel):
    job_id: str
    status: JobStatus


class ObjectivePoint(BaseModel):
    solution_index: int
    negative_signal: float
    switch_count: float
    negative_coverage: float


class SwitchPoint(BaseModel):
    waypoint_index: int
    from_base_station: int
    to_base_station: int


class SolutionPath(BaseModel):
    solution_index: int
    waypoints: list[tuple[float, float, float]]
    switch_points: list[SwitchPoint] = Field(default_factory=list)
    serving_base_stations: list[int] = Field(default_factory=list)


class ObstacleFootprint(BaseModel):
    x_min: float
    y_min: float
    x_max: float
    y_max: float
    height: float


class ScenarioPayload(BaseModel):
    preset_path: list[tuple[float, float, float]] = Field(default_factory=list)
    base_stations: list[tuple[float, float, float]] = Field(default_factory=list)
    obstacles: list[ObstacleFootprint] = Field(default_factory=list)


class ResultMetrics(BaseModel):
    runtime_seconds: float | None = None
    actual_fe: int | None = None
    solution_count: int = 0
    mean_signal_dbm: float | None = None
    mean_switch_count: float | None = None
    mean_coverage_ratio: float | None = None


class PlanningResult(BaseModel):
    job_id: str
    status: JobStatus
    metrics: ResultMetrics
    objectives: list[ObjectivePoint]
    solutions: list[SolutionPath]
    scenario: ScenarioPayload
