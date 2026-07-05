export type JobStatus =
  | "queued"
  | "preparing"
  | "running"
  | "exporting"
  | "succeeded"
  | "failed"
  | "cancelled";

export interface ProblemConfig {
  bs_per_km2: number;
  velocity: number;
  ttt_seconds: number;
  switch_threshold_dbm: number;
  obstacle_method: 0;
  transmit_power_dbm: number;
  switch_method: 0 | 1 | 2 | 3;
  lookahead_distance_m: number;
  lookahead_hysteresis_range_db: number;
  lookahead_safety_margin_db: number;
  preset_altitude_m: number | null;
  altitude_bounds_m: [number, number] | null;
}

export interface AlgorithmConfig {
  population_size: number;
  max_fe: number;
  num_segments: number;
  segment_overlap: number;
  lambda_weight: number;
  c_guide: number;
  use_dynamic_grouping: boolean;
  use_dynamic_mutation: boolean;
  use_ek: boolean;
  uniform_point_multiplier: number;
}

export interface PlanningScenarioConfig {
  scenarioId: string | null;
  snapshotFile?: string | null;
  matlabScenarioFile?: string | null;
}

export interface PlanningConfig {
  scenario: PlanningScenarioConfig;
  algorithmKey: "DCMOCPSO";
  problem: ProblemConfig;
  algorithm: AlgorithmConfig;
}

export interface TaskRecord {
  job_id: string;
  status: JobStatus;
  scenario_id?: string | null;
  algorithm_key?: string;
  created_at?: string;
  updated_at?: string;
  artifact_dir?: string | null;
  progress_json?: string | null;
  error_message?: string | null;
}

export interface TaskProgress {
  stage: string;
  percent: number;
  message: string;
  updatedAt?: string;
}

export interface TaskLogs {
  stdout: string;
  stderr: string;
}

export type Waypoint = [number, number, number];

export interface SwitchPoint {
  waypointIndex: number;
  fromBaseStation: number;
  toBaseStation: number;
}

export interface SolutionPath {
  solutionIndex: number;
  waypoints: Waypoint[];
  switchPoints: SwitchPoint[];
  servingBaseStations: number[];
}

export interface ObjectivePoint {
  solutionIndex: number;
  negativeSignal: number;
  switchCount: number;
  negativeCoverage: number;
}

export interface ObstacleFootprint {
  xMin: number;
  yMin: number;
  xMax: number;
  yMax: number;
  height: number;
}

export interface ScenarioPayload {
  presetPath: Waypoint[];
  baseStations: Waypoint[];
  obstacles: ObstacleFootprint[];
}

export interface ResultMetrics {
  runtimeSeconds: number | null;
  actualFe: number | null;
  solutionCount: number;
  meanSignalDbm: number | null;
  meanSwitchCount: number | null;
  meanCoverageRatio: number | null;
}

export interface PlanningResult {
  jobId: string;
  status: JobStatus;
  metrics: ResultMetrics;
  objectives: ObjectivePoint[];
  solutions: SolutionPath[];
  scenario: ScenarioPayload;
}

export interface Bounds {
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
}

export interface Building {
  id: string;
  footprint: [number, number][];
  height: number;
  xMin: number;
  yMin: number;
  xMax: number;
  yMax: number;
  gridX?: number;
  gridY?: number;
}

export interface CityGeometry {
  id: string;
  name: string;
  bounds: Bounds;
  grid?: Record<string, unknown>;
  buildings: Building[];
}

export interface BaseStation {
  id: string;
  x: number;
  y: number;
  z: number;
  powerDbm?: number;
  buildingId?: string;
}

export interface BaseStationPayload {
  id: string;
  name: string;
  cityModelId: string;
  baseStations: BaseStation[];
}

export interface PresetPoint {
  index: number;
  x: number;
  y: number;
  z: number;
}

export interface PresetPathPayload {
  id: string;
  name: string;
  cityModelId: string;
  points: PresetPoint[];
}

export interface ResourceRecord {
  id: string;
  name: string;
  description?: string | null;
  city_model_id?: string;
  base_station_set_id?: string;
  preset_path_id?: string;
  source_type?: string;
  source_format?: string | null;
  generation_algorithm_key?: string | null;
  station_count?: number;
  point_count?: number;
  snapshot_file_path?: string;
  matlab_scenario_file_path?: string;
  created_at?: string;
  updated_at?: string;
}

export interface ScenarioSnapshot {
  id: string;
  name: string;
  cityModel: CityGeometry;
  baseStationSet: BaseStationPayload;
  presetPath: PresetPathPayload;
}

export interface ImportSpec {
  format: string;
  title: string;
  requiredFields: string[];
  optionalFields: string[];
  exampleText: string;
}

export interface GenerationAlgorithm {
  key: string;
  targetType: string;
  name: string;
  description: string;
  requires?: string[];
  parameters: Array<{ key: string; type: string; required?: boolean; default?: unknown }>;
}

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? "";

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE}${path}`, {
    headers: {
      "Content-Type": "application/json",
      ...init?.headers
    },
    ...init
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(detail || `请求失败：${response.status}`);
  }

  return response.json() as Promise<T>;
}

function pick<T>(source: Record<string, unknown>, snake: string, camel: string, fallback: T): T {
  const value = source[snake] ?? source[camel];
  return (value ?? fallback) as T;
}

function toArray(value: unknown): unknown[] {
  if (value === null || value === undefined) {
    return [];
  }
  return Array.isArray(value) ? value : [value];
}

function normalizeWaypoint(value: unknown): Waypoint {
  if (!Array.isArray(value)) {
    return [0, 0, 0];
  }

  return [Number(value[0] ?? 0), Number(value[1] ?? 0), Number(value[2] ?? 0)];
}

function normalizeObstacle(value: unknown): ObstacleFootprint {
  const source = (value ?? {}) as Record<string, unknown>;
  return {
    xMin: Number(pick(source, "x_min", "xMin", 0)),
    yMin: Number(pick(source, "y_min", "yMin", 0)),
    xMax: Number(pick(source, "x_max", "xMax", 0)),
    yMax: Number(pick(source, "y_max", "yMax", 0)),
    height: Number(pick(source, "height", "height", 0))
  };
}

function normalizeSwitchPoint(value: unknown): SwitchPoint {
  const source = (value ?? {}) as Record<string, unknown>;
  return {
    waypointIndex: Number(pick(source, "waypoint_index", "waypointIndex", 0)),
    fromBaseStation: Number(pick(source, "from_base_station", "fromBaseStation", 0)),
    toBaseStation: Number(pick(source, "to_base_station", "toBaseStation", 0))
  };
}

function hasObstacleArea(obstacle: ObstacleFootprint): boolean {
  return obstacle.xMin !== obstacle.xMax || obstacle.yMin !== obstacle.yMax || obstacle.height !== 0;
}

export function normalizeResult(raw: Record<string, unknown>): PlanningResult {
  const metricsSource = (raw.metrics ?? {}) as Record<string, unknown>;
  const scenarioSource = (raw.scenario ?? {}) as Record<string, unknown>;
  const rawObjectives = toArray(raw.objectives);
  const rawSolutions = toArray(raw.solutions);

  return {
    jobId: String(pick(raw, "job_id", "jobId", "sample")),
    status: pick(raw, "status", "status", "succeeded") as JobStatus,
    metrics: {
      runtimeSeconds: pick(metricsSource, "runtime_seconds", "runtimeSeconds", null),
      actualFe: pick(metricsSource, "actual_fe", "actualFe", null),
      solutionCount: Number(pick(metricsSource, "solution_count", "solutionCount", rawSolutions.length)),
      meanSignalDbm: pick(metricsSource, "mean_signal_dbm", "meanSignalDbm", null),
      meanSwitchCount: pick(metricsSource, "mean_switch_count", "meanSwitchCount", null),
      meanCoverageRatio: pick(metricsSource, "mean_coverage_ratio", "meanCoverageRatio", null)
    },
    objectives: rawObjectives.map((entry) => {
      const source = (entry ?? {}) as Record<string, unknown>;
      return {
        solutionIndex: Number(pick(source, "solution_index", "solutionIndex", 0)),
        negativeSignal: Number(pick(source, "negative_signal", "negativeSignal", 0)),
        switchCount: Number(pick(source, "switch_count", "switchCount", 0)),
        negativeCoverage: Number(pick(source, "negative_coverage", "negativeCoverage", 0))
      };
    }),
    solutions: rawSolutions.map((entry) => {
      const source = (entry ?? {}) as Record<string, unknown>;
      return {
        solutionIndex: Number(pick(source, "solution_index", "solutionIndex", 0)),
        waypoints: toArray(source.waypoints).map(normalizeWaypoint),
        switchPoints: toArray(pick(source, "switch_points", "switchPoints", [])).map(normalizeSwitchPoint),
        servingBaseStations: toArray(pick(source, "serving_base_stations", "servingBaseStations", [])).map(Number)
      };
    }),
    scenario: {
      presetPath: toArray(pick(scenarioSource, "preset_path", "presetPath", [])).map(normalizeWaypoint),
      baseStations: toArray(pick(scenarioSource, "base_stations", "baseStations", [])).map(normalizeWaypoint),
      obstacles: toArray(scenarioSource.obstacles).map(normalizeObstacle).filter(hasObstacleArea)
    }
  };
}

export function createTask(config: PlanningConfig): Promise<TaskRecord> {
  return request<TaskRecord>("/api/tasks", {
    method: "POST",
    body: JSON.stringify(config)
  });
}

export function getTask(jobId: string): Promise<TaskRecord> {
  return request<TaskRecord>(`/api/tasks/${jobId}`);
}

export function listTasks(): Promise<TaskRecord[]> {
  return request<TaskRecord[]>("/api/tasks");
}

export function getTaskProgress(jobId: string): Promise<TaskProgress> {
  return request<TaskProgress>(`/api/tasks/${jobId}/progress`);
}

export function getTaskLogs(jobId: string): Promise<TaskLogs> {
  return request<TaskLogs>(`/api/tasks/${jobId}/logs`);
}

export async function getResult(jobId: string): Promise<PlanningResult> {
  const raw = await request<Record<string, unknown>>(`/api/tasks/${jobId}/result`);
  return normalizeResult(raw);
}

export function resultUrl(jobId: string): string {
  return `${API_BASE}/api/tasks/${jobId}/result`;
}

export function getCityImportSpecs(): Promise<ImportSpec[]> {
  return request<ImportSpec[]>("/api/city-models/import-specs");
}

export function getBaseStationImportSpecs(): Promise<ImportSpec[]> {
  return request<ImportSpec[]>("/api/base-station-sets/import-specs");
}

export function getPresetPathImportSpecs(): Promise<ImportSpec[]> {
  return request<ImportSpec[]>("/api/preset-paths/import-specs");
}

export function getResourceGenerationAlgorithms(): Promise<GenerationAlgorithm[]> {
  return request<GenerationAlgorithm[]>("/api/resource-generation-algorithms");
}

export function listCityModels(): Promise<ResourceRecord[]> {
  return request<ResourceRecord[]>("/api/city-models");
}

export function getCityGeometry(cityId: string): Promise<CityGeometry> {
  return request<CityGeometry>(`/api/city-models/${cityId}/geometry`);
}

export function generateCityModel(body: {
  name: string;
  algorithmKey: string;
  parameters: Record<string, unknown>;
}): Promise<ResourceRecord> {
  return request<ResourceRecord>("/api/city-models/generate", {
    method: "POST",
    body: JSON.stringify(body)
  });
}

export function importCityModel(body: {
  name: string;
  sourceFormat: string;
  content: string;
}): Promise<ResourceRecord> {
  return request<ResourceRecord>("/api/city-models/import", {
    method: "POST",
    body: JSON.stringify(body)
  });
}

export function listBaseStationSets(cityModelId?: string): Promise<ResourceRecord[]> {
  const query = cityModelId ? `?cityModelId=${encodeURIComponent(cityModelId)}` : "";
  return request<ResourceRecord[]>(`/api/base-station-sets${query}`);
}

export function getBaseStationPayload(setId: string): Promise<BaseStationPayload> {
  return request<BaseStationPayload>(`/api/base-station-sets/${setId}/stations`);
}

export function generateBaseStationSet(body: {
  cityModelId: string;
  name: string;
  algorithmKey: string;
  parameters: Record<string, unknown>;
}): Promise<ResourceRecord> {
  return request<ResourceRecord>("/api/base-station-sets/generate", {
    method: "POST",
    body: JSON.stringify(body)
  });
}

export function importBaseStationSet(body: {
  cityModelId: string;
  name: string;
  sourceFormat: string;
  content: string;
}): Promise<ResourceRecord> {
  return request<ResourceRecord>("/api/base-station-sets/import", {
    method: "POST",
    body: JSON.stringify(body)
  });
}

export function listPresetPaths(): Promise<ResourceRecord[]> {
  return request<ResourceRecord[]>("/api/preset-paths");
}

export function getPresetPath(pathId: string): Promise<PresetPathPayload> {
  return request<PresetPathPayload>(`/api/preset-paths/${pathId}`);
}

export function createPresetPath(body: {
  cityModelId: string;
  name: string;
  points: Array<{ x: number; y: number; z: number }>;
}): Promise<ResourceRecord> {
  return request<ResourceRecord>("/api/preset-paths", {
    method: "POST",
    body: JSON.stringify(body)
  });
}

export function importPresetPath(body: {
  cityModelId: string;
  name: string;
  sourceFormat: string;
  content: string;
}): Promise<ResourceRecord> {
  return request<ResourceRecord>("/api/preset-paths/import", {
    method: "POST",
    body: JSON.stringify(body)
  });
}

export function listScenarios(): Promise<ResourceRecord[]> {
  return request<ResourceRecord[]>("/api/scenarios");
}

export function createScenario(body: {
  name: string;
  cityModelId: string;
  baseStationSetId: string;
  presetPathId: string;
}): Promise<ResourceRecord> {
  return request<ResourceRecord>("/api/scenarios", {
    method: "POST",
    body: JSON.stringify(body)
  });
}

export function getScenarioSnapshot(scenarioId: string): Promise<ScenarioSnapshot> {
  return request<ScenarioSnapshot>(`/api/scenarios/${scenarioId}/snapshot`);
}
