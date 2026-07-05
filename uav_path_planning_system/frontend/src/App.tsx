import {
  Activity,
  BarChart3,
  Building2,
  ClipboardList,
  Database,
  FileText,
  Layers3,
  ListChecks,
  Move,
  Play,
  RadioTower,
  RefreshCw,
  Route,
  Save,
  Settings,
  Trash2,
  Upload
} from "lucide-react";
import { type ReactNode, useEffect, useMemo, useState } from "react";

import {
  createPresetPath,
  createScenario,
  createTask,
  generateBaseStationSet,
  generateCityModel,
  getBaseStationImportSpecs,
  getBaseStationPayload,
  getCityGeometry,
  getCityImportSpecs,
  getPresetPath,
  getPresetPathImportSpecs,
  getResourceGenerationAlgorithms,
  getResult,
  getScenarioSnapshot,
  getTaskLogs,
  getTaskProgress,
  importBaseStationSet,
  importCityModel,
  importPresetPath,
  listBaseStationSets,
  listCityModels,
  listPresetPaths,
  listScenarios,
  listTasks,
  normalizeResult,
  resultUrl,
  type BaseStationPayload,
  type CityGeometry,
  type GenerationAlgorithm,
  type ImportSpec,
  type PlanningConfig,
  type PlanningResult,
  type PresetPathPayload,
  type ResourceRecord,
  type ScenarioSnapshot,
  type TaskLogs,
  type TaskProgress,
  type TaskRecord
} from "./api/client";
import { ThreeScene } from "./components/ThreeScene";
import { getSelectedObjectiveMetrics } from "./resultMetrics";

type TabKey =
  | "overview"
  | "city"
  | "base"
  | "path"
  | "scenario"
  | "planning"
  | "queue"
  | "results"
  | "settings";

const tabs: Array<{ key: TabKey; label: string; icon: typeof Activity }> = [
  { key: "overview", label: "总览", icon: Activity },
  { key: "city", label: "城市建模", icon: Building2 },
  { key: "base", label: "基站管理", icon: RadioTower },
  { key: "path", label: "预设路径", icon: Route },
  { key: "scenario", label: "场景组合", icon: Layers3 },
  { key: "planning", label: "规划任务", icon: ClipboardList },
  { key: "queue", label: "任务队列", icon: ListChecks },
  { key: "results", label: "结果中心", icon: BarChart3 },
  { key: "settings", label: "系统设置", icon: Settings }
];

const defaultConfig: PlanningConfig = {
  scenario: { scenarioId: null },
  algorithmKey: "DCMOCPSO",
  problem: {
    bs_per_km2: 20,
    velocity: 20,
    ttt_seconds: 5,
    switch_threshold_dbm: -101.5,
    obstacle_method: 0,
    transmit_power_dbm: 30,
    switch_method: 2,
    lookahead_distance_m: 500,
    lookahead_hysteresis_range_db: 10,
    lookahead_safety_margin_db: 4,
    preset_altitude_m: null,
    altitude_bounds_m: null
  },
  algorithm: {
    population_size: 20,
    max_fe: 100,
    num_segments: 5,
    segment_overlap: 2,
    lambda_weight: 0.5,
    c_guide: 0.3,
    use_dynamic_grouping: true,
    use_dynamic_mutation: true,
    use_ek: true,
    uniform_point_multiplier: 3
  }
};

const previewResult = normalizeResult({
  jobId: "preview",
  status: "succeeded",
  metrics: { solutionCount: 0 },
  objectives: [],
  solutions: [],
  scenario: {}
});

function App() {
  const [activeTab, setActiveTab] = useState<TabKey>("overview");
  const [config, setConfig] = useState<PlanningConfig>(defaultConfig);
  const [cityModels, setCityModels] = useState<ResourceRecord[]>([]);
  const [baseSets, setBaseSets] = useState<ResourceRecord[]>([]);
  const [allBaseSets, setAllBaseSets] = useState<ResourceRecord[]>([]);
  const [presetPaths, setPresetPaths] = useState<ResourceRecord[]>([]);
  const [scenarios, setScenarios] = useState<ResourceRecord[]>([]);
  const [tasks, setTasks] = useState<TaskRecord[]>([]);
  const [selectedCityId, setSelectedCityId] = useState("");
  const [selectedBaseSetId, setSelectedBaseSetId] = useState("");
  const [selectedPathId, setSelectedPathId] = useState("");
  const [selectedScenarioId, setSelectedScenarioId] = useState("");
  const [selectedTaskId, setSelectedTaskId] = useState("");
  const [cityGeometry, setCityGeometry] = useState<CityGeometry | null>(null);
  const [basePayload, setBasePayload] = useState<BaseStationPayload | null>(null);
  const [pathPayload, setPathPayload] = useState<PresetPathPayload | null>(null);
  const [scenarioSnapshot, setScenarioSnapshot] = useState<ScenarioSnapshot | null>(null);
  const [citySpecs, setCitySpecs] = useState<ImportSpec[]>([]);
  const [baseSpecs, setBaseSpecs] = useState<ImportSpec[]>([]);
  const [pathSpecs, setPathSpecs] = useState<ImportSpec[]>([]);
  const [generationAlgorithms, setGenerationAlgorithms] = useState<GenerationAlgorithm[]>([]);
  const [taskProgress, setTaskProgress] = useState<TaskProgress | null>(null);
  const [taskLogs, setTaskLogs] = useState<TaskLogs | null>(null);
  const [result, setResult] = useState<PlanningResult | null>(null);
  const [selectedSolution, setSelectedSolution] = useState(0);
  const [sceneControlMode, setSceneControlMode] = useState<"rotate" | "pan">("rotate");
  const [notice, setNotice] = useState("正在连接后端...");
  const [error, setError] = useState<string | null>(null);
  const [draftPoints, setDraftPoints] = useState<Array<{ x: number; y: number; z: number }>>([
    { x: 140, y: 100, z: 50 },
    { x: 420, y: 360, z: 50 }
  ]);
  const [cityImport, setCityImport] = useState({ format: "json", content: "" });
  const [baseImport, setBaseImport] = useState({ format: "json", content: "" });
  const [pathImport, setPathImport] = useState({ format: "json", content: "" });
  const [cityParams, setCityParams] = useState({ alpha: 0.3265, beta: 204.08, gamma: 40, seed: 1 });
  const [baseParams, setBaseParams] = useState({ bs_per_km2: 20, roof_offset_m: 5, seed: 1 });
  const [isBusy, setIsBusy] = useState(false);

  const cityAlgorithm = generationAlgorithms.find((item) => item.targetType === "city_model");
  const baseAlgorithm = generationAlgorithms.find((item) => item.targetType === "base_station_set");
  const selectedTask = tasks.find((task) => task.job_id === selectedTaskId) ?? null;
  const selectedScenarioRecord = scenarios.find((item) => item.id === selectedScenarioId) ?? null;
  const runningTasks = tasks.filter((task) => ["queued", "preparing", "running", "exporting"].includes(task.status));
  const completedTasks = tasks.filter((task) => task.status === "succeeded");
  const cityPresetPaths = useMemo(
    () => presetPaths.filter((path) => !selectedCityId || path.city_model_id === selectedCityId),
    [presetPaths, selectedCityId]
  );

  const sceneCity = scenarioSnapshot?.cityModel ?? cityGeometry;
  const sceneBase = scenarioSnapshot?.baseStationSet ?? basePayload;
  const scenePath = scenarioSnapshot?.presetPath ?? pathPayload;
  const sceneResult = result ?? previewResult;
  const draftPath = useMemo<PresetPathPayload>(
    () => ({
      id: "draft",
      name: "draft",
      cityModelId: selectedCityId,
      points: draftPoints.map((point, index) => ({ index, ...point }))
    }),
    [draftPoints, selectedCityId]
  );
  const displayedScenePath = activeTab === "path" ? draftPath : scenePath;
  const displayedPathPointCount =
    displayedScenePath?.points.length ?? (activeTab === "results" ? sceneResult.scenario.presetPath.length : 0);
  const resourceLookup = useMemo(
    () => ({
      cityModels,
      baseSets: allBaseSets,
      paths: presetPaths,
      scenarios
    }),
    [allBaseSets, cityModels, presetPaths, scenarios]
  );

  useEffect(() => {
    void loadBootstrap();
  }, []);

  useEffect(() => {
    if (cityModels.length && !selectedCityId) {
      setSelectedCityId(cityModels[0].id);
    }
  }, [cityModels, selectedCityId]);

  useEffect(() => {
    if (!selectedCityId) {
      setCityGeometry(null);
      setBaseSets([]);
      return;
    }
    void loadCity(selectedCityId);
  }, [selectedCityId]);

  useEffect(() => {
    if (!selectedBaseSetId) {
      setBasePayload(null);
      return;
    }
    void loadBaseSet(selectedBaseSetId);
  }, [selectedBaseSetId]);

  useEffect(() => {
    if (!selectedPathId) {
      setPathPayload(null);
      return;
    }
    void loadPresetPath(selectedPathId);
  }, [selectedPathId]);

  useEffect(() => {
    if (selectedPathId && !cityPresetPaths.some((path) => path.id === selectedPathId)) {
      setSelectedPathId("");
    }
  }, [cityPresetPaths, selectedPathId]);

  useEffect(() => {
    if (!selectedScenarioId) {
      setScenarioSnapshot(null);
      setConfig((current) => ({ ...current, scenario: { scenarioId: null } }));
      return;
    }
    setConfig((current) => ({ ...current, scenario: { scenarioId: selectedScenarioId } }));
    void loadScenario(selectedScenarioId);
  }, [selectedScenarioId]);

  useEffect(() => {
    const timer = window.setInterval(() => {
      void refreshTasks(false);
      if (selectedTaskId) {
        void refreshTaskRuntime(selectedTaskId);
      }
    }, 3000);
    return () => window.clearInterval(timer);
  }, [selectedTaskId]);

  async function loadBootstrap() {
    setError(null);
    try {
      const [citySpecData, baseSpecData, pathSpecData, algorithms] = await Promise.all([
        getCityImportSpecs(),
        getBaseStationImportSpecs(),
        getPresetPathImportSpecs(),
        getResourceGenerationAlgorithms()
      ]);
      setCitySpecs(citySpecData);
      setBaseSpecs(baseSpecData);
      setPathSpecs(pathSpecData);
      setGenerationAlgorithms(algorithms);
      await refreshResources();
      await refreshTasks(false);
      setNotice("系统已就绪");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "后端连接失败");
      setNotice("等待后端服务");
    }
  }

  async function refreshResources() {
    const [cities, stationSets, paths, sceneRecords] = await Promise.all([
      listCityModels(),
      listBaseStationSets(),
      listPresetPaths(),
      listScenarios()
    ]);
    setCityModels(cities);
    setAllBaseSets(stationSets);
    setPresetPaths(paths);
    setScenarios(sceneRecords);
  }

  async function refreshTasks(showNotice = true) {
    const taskData = await listTasks();
    setTasks(taskData);
    if (!selectedTaskId && taskData.length) {
      setSelectedTaskId(taskData[0].job_id);
    }
    if (showNotice) {
      setNotice("任务列表已刷新");
    }
  }

  async function loadCity(cityId: string) {
    try {
      const [geometry, stationSets, allStationSets] = await Promise.all([
        getCityGeometry(cityId),
        listBaseStationSets(cityId),
        listBaseStationSets()
      ]);
      setCityGeometry(geometry);
      setBaseSets(stationSets);
      setAllBaseSets(allStationSets);
      if (stationSets.length && !stationSets.some((item) => item.id === selectedBaseSetId)) {
        setSelectedBaseSetId(stationSets[0].id);
      } else if (!stationSets.length) {
        setSelectedBaseSetId("");
      }
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "城市模型读取失败");
    }
  }

  async function loadBaseSet(setId: string) {
    try {
      setBasePayload(await getBaseStationPayload(setId));
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "基站集合读取失败");
    }
  }

  async function loadPresetPath(pathId: string) {
    try {
      const payload = await getPresetPath(pathId);
      setPathPayload(payload);
      setDraftPoints(payload.points.map((point) => ({ x: point.x, y: point.y, z: point.z })));
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "预设路径读取失败");
    }
  }

  async function loadScenario(scenarioId: string) {
    try {
      setScenarioSnapshot(await getScenarioSnapshot(scenarioId));
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "场景快照读取失败");
    }
  }

  async function refreshTaskRuntime(jobId: string) {
    try {
      const [progress, logs] = await Promise.all([getTaskProgress(jobId), getTaskLogs(jobId)]);
      setTaskProgress(progress);
      setTaskLogs(logs);
    } catch {
      setTaskProgress(null);
      setTaskLogs(null);
    }
  }

  async function runAction(action: () => Promise<void>, doneMessage: string) {
    setIsBusy(true);
    setError(null);
    try {
      await action();
      setNotice(doneMessage);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "操作失败");
    } finally {
      setIsBusy(false);
    }
  }

  async function handleGenerateCity() {
    await runAction(async () => {
      const created = await generateCityModel({
        name: `城市模型 ${new Date().toLocaleTimeString()}`,
        algorithmKey: cityAlgorithm?.key ?? "MatlabAlphaBetaGammaUniformBuildings",
        parameters: cityParams
      });
      await refreshResources();
      setSelectedCityId(created.id);
    }, "城市模型已生成");
  }

  async function handleImportCity() {
    await runAction(async () => {
      const created = await importCityModel({
        name: `导入城市 ${new Date().toLocaleTimeString()}`,
        sourceFormat: cityImport.format,
        content: cityImport.content
      });
      await refreshResources();
      setSelectedCityId(created.id);
    }, "城市模型已导入");
  }

  async function handleGenerateBaseSet() {
    if (!selectedCityId) {
      setError("请先选择城市模型");
      return;
    }
    await runAction(async () => {
      const created = await generateBaseStationSet({
        cityModelId: selectedCityId,
        name: `基站集合 ${new Date().toLocaleTimeString()}`,
        algorithmKey: baseAlgorithm?.key ?? "MatlabDensityKMeansBaseStations",
        parameters: baseParams
      });
      await loadCity(selectedCityId);
      setSelectedBaseSetId(created.id);
    }, "基站集合已生成");
  }

  async function handleImportBaseSet() {
    if (!selectedCityId) {
      setError("请先选择城市模型");
      return;
    }
    await runAction(async () => {
      const created = await importBaseStationSet({
        cityModelId: selectedCityId,
        name: `导入基站 ${new Date().toLocaleTimeString()}`,
        sourceFormat: baseImport.format,
        content: baseImport.content
      });
      await loadCity(selectedCityId);
      setSelectedBaseSetId(created.id);
    }, "基站集合已导入");
  }

  async function handleSavePath() {
    if (!selectedCityId) {
      setError("请先选择城市模型");
      return;
    }
    await runAction(async () => {
      const created = await createPresetPath({
        cityModelId: selectedCityId,
        name: `预设路径 ${new Date().toLocaleTimeString()}`,
        points: draftPoints
      });
      await refreshResources();
      setSelectedPathId(created.id);
    }, "预设路径已保存");
  }

  async function handleImportPath() {
    if (!selectedCityId) {
      setError("请先选择城市模型");
      return;
    }
    await runAction(async () => {
      const created = await importPresetPath({
        cityModelId: selectedCityId,
        name: `导入路径 ${new Date().toLocaleTimeString()}`,
        sourceFormat: pathImport.format,
        content: pathImport.content
      });
      await refreshResources();
      setSelectedPathId(created.id);
    }, "预设路径已导入");
  }

  async function handleCreateScenario() {
    if (!selectedCityId || !selectedBaseSetId || !selectedPathId) {
      setError("请选择城市、基站集合和预设路径");
      return;
    }
    await runAction(async () => {
      const created = await createScenario({
        name: `场景组合 ${new Date().toLocaleTimeString()}`,
        cityModelId: selectedCityId,
        baseStationSetId: selectedBaseSetId,
        presetPathId: selectedPathId
      });
      await refreshResources();
      setSelectedScenarioId(created.id);
    }, "场景组合已创建");
  }

  async function handleCreateTask() {
    if (!selectedScenarioId) {
      setError("请先选择场景组合");
      return;
    }
    await runAction(async () => {
      const task = await createTask({ ...config, scenario: { scenarioId: selectedScenarioId } });
      setSelectedTaskId(task.job_id);
      setActiveTab("queue");
      await refreshTasks(false);
      await refreshTaskRuntime(task.job_id);
    }, "规划任务已创建");
  }

  async function handleLoadResult(jobId: string) {
    await runAction(async () => {
      const nextResult = await getResult(jobId);
      setResult(nextResult);
      setSelectedSolution(nextResult.solutions[0]?.solutionIndex ?? 0);
      setSelectedTaskId(jobId);
      setActiveTab("results");
    }, "规划结果已载入");
  }

  const body = useMemo(() => {
    switch (activeTab) {
      case "overview":
        return (
          <OverviewView
            cityCount={cityModels.length}
            baseCount={baseSets.length}
            scenarioCount={scenarios.length}
            runningCount={runningTasks.length}
            completedCount={completedTasks.length}
            onRefresh={() => void loadBootstrap()}
          />
        );
      case "city":
        return (
          <CityView
            specs={citySpecs}
            records={cityModels}
            selectedId={selectedCityId}
            lookup={resourceLookup}
            params={cityParams}
            importState={cityImport}
            isBusy={isBusy}
            onParamsChange={setCityParams}
            onImportChange={setCityImport}
            onSelect={setSelectedCityId}
            onGenerate={() => void handleGenerateCity()}
            onImport={() => void handleImportCity()}
          />
        );
      case "base":
        return (
          <BaseStationView
            specs={baseSpecs}
            cityModels={cityModels}
            selectedCityId={selectedCityId}
            records={baseSets}
            selectedId={selectedBaseSetId}
            lookup={resourceLookup}
            params={baseParams}
            importState={baseImport}
            isBusy={isBusy}
            onCitySelect={setSelectedCityId}
            onSelect={setSelectedBaseSetId}
            onParamsChange={setBaseParams}
            onImportChange={setBaseImport}
            onGenerate={() => void handleGenerateBaseSet()}
            onImport={() => void handleImportBaseSet()}
          />
        );
      case "path":
        return (
          <PathView
            specs={pathSpecs}
            cityModels={cityModels}
            baseSets={baseSets}
            paths={cityPresetPaths}
            selectedCityId={selectedCityId}
            selectedBaseSetId={selectedBaseSetId}
            selectedPathId={selectedPathId}
            points={draftPoints}
            lookup={resourceLookup}
            importState={pathImport}
            isBusy={isBusy}
            onCitySelect={setSelectedCityId}
            onBaseSelect={setSelectedBaseSetId}
            onPathSelect={setSelectedPathId}
            onPointsChange={setDraftPoints}
            onImportChange={setPathImport}
            onSave={() => void handleSavePath()}
            onImport={() => void handleImportPath()}
          />
        );
      case "scenario":
        return (
          <ScenarioView
            cityModels={cityModels}
            baseSets={baseSets}
            allBaseSets={allBaseSets}
            paths={cityPresetPaths}
            scenarios={scenarios}
            lookup={resourceLookup}
            selectedCityId={selectedCityId}
            selectedBaseSetId={selectedBaseSetId}
            selectedPathId={selectedPathId}
            selectedScenarioId={selectedScenarioId}
            isBusy={isBusy}
            onCitySelect={setSelectedCityId}
            onBaseSelect={setSelectedBaseSetId}
            onPathSelect={setSelectedPathId}
            onScenarioSelect={setSelectedScenarioId}
            onCreate={() => void handleCreateScenario()}
          />
        );
      case "planning":
        return (
          <PlanningView
            scenarios={scenarios}
            selectedScenarioId={selectedScenarioId}
            config={config}
            isBusy={isBusy}
            onScenarioSelect={setSelectedScenarioId}
            onConfigChange={setConfig}
            onSubmit={() => void handleCreateTask()}
          />
        );
      case "queue":
        return (
          <QueueView
            tasks={tasks}
            selectedTaskId={selectedTaskId}
            progress={taskProgress}
            logs={taskLogs}
            lookup={resourceLookup}
            onSelect={(jobId) => {
              setSelectedTaskId(jobId);
              void refreshTaskRuntime(jobId);
            }}
            onRefresh={() => void refreshTasks()}
          />
        );
      case "results":
        return (
          <ResultsView
            tasks={completedTasks}
            result={result}
            selectedTaskId={selectedTaskId}
            selectedSolution={selectedSolution}
            lookup={resourceLookup}
            onLoadResult={(jobId) => void handleLoadResult(jobId)}
            onSelectSolution={setSelectedSolution}
          />
        );
      case "settings":
        return <SettingsView notice={notice} />;
      default:
        return null;
    }
  }, [
    activeTab,
    allBaseSets,
    baseImport,
    baseParams,
    baseSets,
    cityImport,
    cityModels,
    cityParams,
    citySpecs,
    completedTasks,
    config,
    draftPoints,
    error,
    isBusy,
    notice,
    pathImport,
    pathSpecs,
    presetPaths,
    result,
    resourceLookup,
    runningTasks.length,
    scenarios,
    selectedBaseSetId,
    selectedCityId,
    selectedPathId,
    selectedScenarioId,
    selectedSolution,
    selectedTaskId,
    taskLogs,
    taskProgress
  ]);

  return (
    <div className="app-shell">
      <aside className="side-tabs" aria-label="系统模块">
        <div className="brand-block">
          <Database size={22} />
          <strong>UAV Planner</strong>
        </div>
        <nav>
          {tabs.map((tab) => {
            const Icon = tab.icon;
            return (
              <button
                className={tab.key === activeTab ? "active" : ""}
                key={tab.key}
                title={tab.label}
                onClick={() => setActiveTab(tab.key)}
              >
                <Icon size={19} />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </nav>
      </aside>
      <main className="workbench">
        <header className="workbench-header">
          <div>
            <p className="eyebrow">DCMOCPSO / UAVPathPlanning</p>
            <h1>面向通信优化的城市巡逻 UAV 路径规划系统</h1>
          </div>
          <div className={`status-pill ${error ? "failed" : "ready"}`}>{error ?? notice}</div>
        </header>
        <section className="tab-layout">
          <div className="tab-content">{body}</div>
          <section className="scene-panel">
            <div className="scene-toolbar">
              <div>
                <p className="eyebrow">三维场景</p>
                <h2>{selectedScenarioRecord?.name ?? sceneCity?.name ?? "当前组合"}</h2>
              </div>
              <div className="scene-tools">
                <div className="scene-mode-toggle" role="group" aria-label="三维图操作模式">
                  <button
                    className={sceneControlMode === "rotate" ? "active" : ""}
                    title="左键旋转三维图"
                    type="button"
                    onClick={() => setSceneControlMode("rotate")}
                  >
                    <RefreshCw size={16} />
                    <span>旋转</span>
                  </button>
                  <button
                    className={sceneControlMode === "pan" ? "active" : ""}
                    title="左键拖拽三维图"
                    type="button"
                    onClick={() => setSceneControlMode("pan")}
                  >
                    <Move size={16} />
                    <span>拖拽</span>
                  </button>
                </div>
                <div className="scene-counts">
                  <span>{sceneCity?.buildings.length ?? 0} 建筑</span>
                  <span>{sceneBase?.baseStations.length ?? 0} 基站</span>
                  <span>{displayedPathPointCount} 路径点</span>
                </div>
              </div>
            </div>
            <ThreeScene
              city={sceneCity}
              baseStations={sceneBase}
              presetPath={displayedScenePath}
              result={activeTab === "results" ? sceneResult : null}
              selectedSolution={selectedSolution}
              controlMode={sceneControlMode}
            />
          </section>
        </section>
      </main>
    </div>
  );
}

interface OverviewViewProps {
  cityCount: number;
  baseCount: number;
  scenarioCount: number;
  runningCount: number;
  completedCount: number;
  onRefresh: () => void;
}

function OverviewView(props: OverviewViewProps) {
  return (
    <div className="panel-stack">
      <div className="section-heading">
        <h2>总览</h2>
        <button className="icon-button" title="刷新" onClick={props.onRefresh}>
          <RefreshCw size={18} />
        </button>
      </div>
      <div className="metric-grid wide">
        <Metric label="城市模型" value={props.cityCount} />
        <Metric label="当前城市基站集合" value={props.baseCount} />
        <Metric label="场景组合" value={props.scenarioCount} />
        <Metric label="运行/排队任务" value={props.runningCount} />
        <Metric label="完成任务" value={props.completedCount} />
      </div>
    </div>
  );
}

function CityView(props: {
  specs: ImportSpec[];
  records: ResourceRecord[];
  selectedId: string;
  lookup: ResourceLookup;
  params: { alpha: number; beta: number; gamma: number; seed: number };
  importState: { format: string; content: string };
  isBusy: boolean;
  onParamsChange: (value: { alpha: number; beta: number; gamma: number; seed: number }) => void;
  onImportChange: (value: { format: string; content: string }) => void;
  onSelect: (value: string) => void;
  onGenerate: () => void;
  onImport: () => void;
}) {
  return (
    <div className="panel-stack">
      <div className="section-heading">
        <h2>城市建模</h2>
        <button className="primary-button" disabled={props.isBusy} onClick={props.onGenerate}>
          <Building2 size={18} />
          生成
        </button>
      </div>
      <div className="field-grid">
        <NumberField label="alpha" value={props.params.alpha} step={0.01} onChange={(alpha) => props.onParamsChange({ ...props.params, alpha })} />
        <NumberField label="beta" value={props.params.beta} step={1} onChange={(beta) => props.onParamsChange({ ...props.params, beta })} />
        <NumberField label="gamma" value={props.params.gamma} step={1} onChange={(gamma) => props.onParamsChange({ ...props.params, gamma })} />
        <NumberField label="随机种子" value={props.params.seed} step={1} onChange={(seed) => props.onParamsChange({ ...props.params, seed })} />
      </div>
      <ResourcePicker label="城市模型" records={props.records} selectedId={props.selectedId} onSelect={props.onSelect} />
      <ResourceDetailPanel record={props.records.find((record) => record.id === props.selectedId) ?? null} lookup={props.lookup} />
      <ImportBox
        specs={props.specs}
        state={props.importState}
        onChange={props.onImportChange}
        onImport={props.onImport}
        disabled={props.isBusy}
      />
    </div>
  );
}

function BaseStationView(props: {
  specs: ImportSpec[];
  cityModels: ResourceRecord[];
  selectedCityId: string;
  records: ResourceRecord[];
  selectedId: string;
  lookup: ResourceLookup;
  params: { bs_per_km2: number; roof_offset_m: number; seed: number };
  importState: { format: string; content: string };
  isBusy: boolean;
  onCitySelect: (value: string) => void;
  onSelect: (value: string) => void;
  onParamsChange: (value: { bs_per_km2: number; roof_offset_m: number; seed: number }) => void;
  onImportChange: (value: { format: string; content: string }) => void;
  onGenerate: () => void;
  onImport: () => void;
}) {
  return (
    <div className="panel-stack">
      <div className="section-heading">
        <h2>基站管理</h2>
        <button className="primary-button" disabled={props.isBusy} onClick={props.onGenerate}>
          <RadioTower size={18} />
          生成
        </button>
      </div>
      <ResourcePicker label="所属城市" records={props.cityModels} selectedId={props.selectedCityId} onSelect={props.onCitySelect} />
      <div className="field-grid">
        <NumberField label="基站密度" value={props.params.bs_per_km2} step={1} onChange={(bs_per_km2) => props.onParamsChange({ ...props.params, bs_per_km2 })} />
        <NumberField label="楼顶加高" value={props.params.roof_offset_m} step={1} onChange={(roof_offset_m) => props.onParamsChange({ ...props.params, roof_offset_m })} />
        <NumberField label="随机种子" value={props.params.seed} step={1} onChange={(seed) => props.onParamsChange({ ...props.params, seed })} />
      </div>
      <ResourcePicker label="基站集合" records={props.records} selectedId={props.selectedId} onSelect={props.onSelect} />
      <ResourceDetailPanel record={props.records.find((record) => record.id === props.selectedId) ?? null} lookup={props.lookup} />
      <ImportBox
        specs={props.specs}
        state={props.importState}
        onChange={props.onImportChange}
        onImport={props.onImport}
        disabled={props.isBusy}
      />
    </div>
  );
}

function PathView(props: {
  specs: ImportSpec[];
  cityModels: ResourceRecord[];
  baseSets: ResourceRecord[];
  paths: ResourceRecord[];
  selectedCityId: string;
  selectedBaseSetId: string;
  selectedPathId: string;
  points: Array<{ x: number; y: number; z: number }>;
  lookup: ResourceLookup;
  importState: { format: string; content: string };
  isBusy: boolean;
  onCitySelect: (value: string) => void;
  onBaseSelect: (value: string) => void;
  onPathSelect: (value: string) => void;
  onPointsChange: (value: Array<{ x: number; y: number; z: number }>) => void;
  onImportChange: (value: { format: string; content: string }) => void;
  onSave: () => void;
  onImport: () => void;
}) {
  return (
    <div className="panel-stack">
      <div className="section-heading">
        <h2>预设路径</h2>
        <button className="primary-button" disabled={props.isBusy} onClick={props.onSave}>
          <Save size={18} />
          保存
        </button>
      </div>
      <ResourcePicker label="所属城市" records={props.cityModels} selectedId={props.selectedCityId} onSelect={props.onCitySelect} />
      <ResourcePicker label="预览基站集合" records={props.baseSets} selectedId={props.selectedBaseSetId} onSelect={props.onBaseSelect} />
      <ResourcePicker label="已保存路径" records={props.paths} selectedId={props.selectedPathId} onSelect={props.onPathSelect} />
      <ResourceDetailPanel record={props.paths.find((record) => record.id === props.selectedPathId) ?? null} lookup={props.lookup} />
      <div className="point-table">
        {props.points.map((point, index) => (
          <div className="point-row" key={index}>
            <span>{index + 1}</span>
            <input value={point.x} type="number" onChange={(event) => updatePoint(props, index, "x", event.target.value)} />
            <input value={point.y} type="number" onChange={(event) => updatePoint(props, index, "y", event.target.value)} />
            <input value={point.z} type="number" onChange={(event) => updatePoint(props, index, "z", event.target.value)} />
            <button className="icon-button" type="button" title="删除路径点" onClick={() => removePoint(props, index)}>
              <Trash2 size={16} />
            </button>
          </div>
        ))}
      </div>
      <button
        className="secondary-button"
        onClick={() => props.onPointsChange([...props.points, { x: 0, y: 0, z: 50 }])}
      >
        <Route size={18} />
        新增点
      </button>
      <ImportBox
        specs={props.specs}
        state={props.importState}
        onChange={props.onImportChange}
        onImport={props.onImport}
        disabled={props.isBusy}
      />
    </div>
  );
}

function updatePoint(
  props: { points: Array<{ x: number; y: number; z: number }>; onPointsChange: (value: Array<{ x: number; y: number; z: number }>) => void },
  index: number,
  field: "x" | "y" | "z",
  value: string
) {
  props.onPointsChange(props.points.map((point, itemIndex) => (itemIndex === index ? { ...point, [field]: Number(value) } : point)));
}

function removePoint(
  props: { points: Array<{ x: number; y: number; z: number }>; onPointsChange: (value: Array<{ x: number; y: number; z: number }>) => void },
  index: number
) {
  props.onPointsChange(props.points.filter((_, itemIndex) => itemIndex !== index));
}

function ScenarioView(props: {
  cityModels: ResourceRecord[];
  baseSets: ResourceRecord[];
  allBaseSets: ResourceRecord[];
  paths: ResourceRecord[];
  scenarios: ResourceRecord[];
  lookup: ResourceLookup;
  selectedCityId: string;
  selectedBaseSetId: string;
  selectedPathId: string;
  selectedScenarioId: string;
  isBusy: boolean;
  onCitySelect: (value: string) => void;
  onBaseSelect: (value: string) => void;
  onPathSelect: (value: string) => void;
  onScenarioSelect: (value: string) => void;
  onCreate: () => void;
}) {
  return (
    <div className="panel-stack">
      <div className="section-heading">
        <h2>场景组合</h2>
        <button className="primary-button" disabled={props.isBusy} onClick={props.onCreate}>
          <Layers3 size={18} />
          创建
        </button>
      </div>
      <ResourcePicker label="城市模型" records={props.cityModels} selectedId={props.selectedCityId} onSelect={props.onCitySelect} />
      <ResourcePicker label="基站集合" records={props.baseSets} selectedId={props.selectedBaseSetId} onSelect={props.onBaseSelect} />
      <ResourcePicker label="预设路径" records={props.paths} selectedId={props.selectedPathId} onSelect={props.onPathSelect} />
      <ResourcePicker label="场景组合" records={props.scenarios} selectedId={props.selectedScenarioId} onSelect={props.onScenarioSelect} />
      <ScenarioDetailPanel
        scenario={props.scenarios.find((record) => record.id === props.selectedScenarioId) ?? null}
        lookup={{ ...props.lookup, baseSets: props.allBaseSets }}
      />
    </div>
  );
}

function PlanningView(props: {
  scenarios: ResourceRecord[];
  selectedScenarioId: string;
  config: PlanningConfig;
  isBusy: boolean;
  onScenarioSelect: (value: string) => void;
  onConfigChange: (value: PlanningConfig) => void;
  onSubmit: () => void;
}) {
  const config = props.config;
  return (
    <div className="panel-stack">
      <div className="section-heading">
        <h2>规划任务</h2>
        <button className="primary-button" disabled={props.isBusy} onClick={props.onSubmit}>
          <Play size={18} />
          创建任务
        </button>
      </div>
      <ResourcePicker label="场景组合" records={props.scenarios} selectedId={props.selectedScenarioId} onSelect={props.onScenarioSelect} />
      <div className="field-grid">
        <NumberField label="种群规模" value={config.algorithm.population_size} step={1} onChange={(value) => props.onConfigChange({ ...config, algorithm: { ...config.algorithm, population_size: value } })} />
        <NumberField label="最大 FE" value={config.algorithm.max_fe} step={1} onChange={(value) => props.onConfigChange({ ...config, algorithm: { ...config.algorithm, max_fe: value } })} />
        <NumberField label="分段数量" value={config.algorithm.num_segments} step={1} onChange={(value) => props.onConfigChange({ ...config, algorithm: { ...config.algorithm, num_segments: value } })} />
        <NumberField label="段重叠" value={config.algorithm.segment_overlap} step={1} onChange={(value) => props.onConfigChange({ ...config, algorithm: { ...config.algorithm, segment_overlap: value } })} />
        <NumberField label="飞行速度" value={config.problem.velocity} step={1} onChange={(value) => props.onConfigChange({ ...config, problem: { ...config.problem, velocity: value } })} />
        <NumberField label="TTT" value={config.problem.ttt_seconds} step={1} onChange={(value) => props.onConfigChange({ ...config, problem: { ...config.problem, ttt_seconds: value } })} />
        <NumberField label="切换阈值" value={config.problem.switch_threshold_dbm} step={1} onChange={(value) => props.onConfigChange({ ...config, problem: { ...config.problem, switch_threshold_dbm: value } })} />
        <NumberField label="发射功率" value={config.problem.transmit_power_dbm} step={1} onChange={(value) => props.onConfigChange({ ...config, problem: { ...config.problem, transmit_power_dbm: value } })} />
      </div>
      <label>
        切换算法
        <select
          value={config.problem.switch_method}
          onChange={(event) =>
            props.onConfigChange({
              ...config,
              problem: { ...config.problem, switch_method: Number(event.target.value) as 0 | 1 | 2 | 3 }
            })
          }
        >
          <option value={0}>阈值</option>
          <option value={1}>CASH</option>
          <option value={2}>前瞻</option>
          <option value={3}>A3</option>
        </select>
      </label>
    </div>
  );
}

function QueueView(props: {
  tasks: TaskRecord[];
  selectedTaskId: string;
  progress: TaskProgress | null;
  logs: TaskLogs | null;
  lookup: ResourceLookup;
  onSelect: (jobId: string) => void;
  onRefresh: () => void;
}) {
  return (
    <div className="panel-stack">
      <div className="section-heading">
        <h2>任务队列</h2>
        <button className="icon-button" title="刷新" onClick={props.onRefresh}>
          <RefreshCw size={18} />
        </button>
      </div>
      <TaskList tasks={props.tasks} selectedTaskId={props.selectedTaskId} onSelect={props.onSelect} />
      <TaskDetailPanel task={props.tasks.find((task) => task.job_id === props.selectedTaskId) ?? null} lookup={props.lookup} />
      <div className="progress-panel">
        <strong>{props.progress?.stage ?? "未选择任务"}</strong>
        <div className="progress-track">
          <span style={{ width: `${props.progress?.percent ?? 0}%` }} />
        </div>
        <p>{props.progress?.message ?? ""}</p>
      </div>
      <pre className="log-view">{props.logs?.stdout || props.logs?.stderr || ""}</pre>
    </div>
  );
}

function ResultsView(props: {
  tasks: TaskRecord[];
  result: PlanningResult | null;
  selectedTaskId: string;
  selectedSolution: number;
  lookup: ResourceLookup;
  onLoadResult: (jobId: string) => void;
  onSelectSolution: (solutionIndex: number) => void;
}) {
  const selectedMetrics = props.result
    ? getSelectedObjectiveMetrics(props.result.objectives, props.selectedSolution)
    : null;
  return (
    <div className="panel-stack">
      <div className="section-heading">
        <h2>结果中心</h2>
        {props.selectedTaskId ? (
          <a className="icon-button" title="下载 JSON" href={resultUrl(props.selectedTaskId)}>
            <FileText size={18} />
          </a>
        ) : null}
      </div>
      <TaskList tasks={props.tasks} selectedTaskId={props.selectedTaskId} onSelect={props.onLoadResult} />
      <TaskDetailPanel task={props.tasks.find((task) => task.job_id === props.selectedTaskId) ?? null} lookup={props.lookup} />
      {props.result ? (
        <>
          <div className="metric-grid wide">
            <Metric label="解数量" value={props.result.metrics.solutionCount} />
            <Metric label="信号" value={formatMaybe(selectedMetrics?.signalDbm)} />
            <Metric label="切换次数" value={formatMaybe(selectedMetrics?.switchCount)} />
            <Metric label="覆盖率" value={formatMaybe(selectedMetrics?.coverageRatio)} />
            <Metric label="HV" value={formatMaybe(selectedMetrics?.hypervolume)} />
            <Metric label="前沿总 HV" value={formatMaybe(selectedMetrics?.totalHypervolume)} />
          </div>
          <label>
            候选解
            <select value={props.selectedSolution} onChange={(event) => props.onSelectSolution(Number(event.target.value))}>
              {props.result.solutions.map((solution) => (
                <option key={solution.solutionIndex} value={solution.solutionIndex}>
                  Solution {solution.solutionIndex}
                </option>
              ))}
            </select>
          </label>
        </>
      ) : null}
    </div>
  );
}

interface ResourceLookup {
  cityModels: ResourceRecord[];
  baseSets: ResourceRecord[];
  paths: ResourceRecord[];
  scenarios: ResourceRecord[];
}

function TaskDetailPanel(props: { task: TaskRecord | null; lookup: ResourceLookup }) {
  if (!props.task) {
    return <InfoPanel title="任务详情" emptyText="未选择任务" />;
  }
  const scenario = props.task.scenario_id
    ? props.lookup.scenarios.find((record) => record.id === props.task?.scenario_id) ?? null
    : null;
  return (
    <InfoPanel title="任务详情">
      <DetailRows
        rows={[
          ["任务 ID", props.task.job_id],
          ["状态", props.task.status],
          ["算法", props.task.algorithm_key ?? props.task.config?.algorithmKey ?? "-"],
          ["场景组合", scenario?.name ?? props.task.scenario_id ?? "-"],
          ["创建时间", props.task.created_at ?? "-"],
          ["更新时间", props.task.updated_at ?? "-"]
        ]}
      />
      {props.task.error_message ? <p className="detail-warning">{props.task.error_message}</p> : null}
      <DetailObject title="问题参数" value={props.task.config?.problem} />
      <DetailObject title="算法参数" value={props.task.config?.algorithm} />
      <ScenarioDetailPanel scenario={scenario} lookup={props.lookup} nested />
    </InfoPanel>
  );
}

function ScenarioDetailPanel(props: { scenario: ResourceRecord | null; lookup: ResourceLookup; nested?: boolean }) {
  if (!props.scenario) {
    return props.nested ? null : <InfoPanel title="场景组合详情" emptyText="未选择场景组合" />;
  }
  return <ResourceDetailPanel record={props.scenario} lookup={props.lookup} title="场景组合详情" nested={props.nested} />;
}

function ResourceDetailPanel(props: {
  record: ResourceRecord | null;
  lookup: ResourceLookup;
  title?: string;
  nested?: boolean;
  depth?: number;
}) {
  const depth = props.depth ?? 0;
  if (!props.record) {
    return props.nested ? null : <InfoPanel title={props.title ?? "资源详情"} emptyText="未选择资源" />;
  }

  const generationParams = parseJsonValue(props.record.generation_params_json);
  const metadata = parseJsonValue(props.record.metadata_json);
  const bounds = parseJsonValue(props.record.bounds_json);
  const city = props.record.city_model_id ? findResource(props.lookup.cityModels, props.record.city_model_id) : null;
  const baseSet = props.record.base_station_set_id ? findResource(props.lookup.baseSets, props.record.base_station_set_id) : null;
  const presetPath = props.record.preset_path_id ? findResource(props.lookup.paths, props.record.preset_path_id) : null;
  const canNest = depth < 3;

  return (
    <InfoPanel title={props.title ?? `${getResourceKind(props.record)}详情`} nested={props.nested}>
      <DetailRows
        rows={[
          ["名称", props.record.name],
          ["ID", props.record.id],
          ["类型", getResourceKind(props.record)],
          ["来源", getSourceLabel(props.record.source_type)],
          ["文件格式", props.record.source_format ?? "-"],
          ["生成算法", props.record.generation_algorithm_key ?? "-"],
          ["建筑数", getMetadataValue(metadata, "buildingCount") ?? "-"],
          ["基站数", props.record.station_count ?? getMetadataValue(metadata, "stationCount") ?? "-"],
          ["路径点数", props.record.point_count ?? getMetadataValue(metadata, "pointCount") ?? "-"],
          ["创建时间", props.record.created_at ?? "-"]
        ]}
      />
      <DetailObject title="生成参数" value={generationParams} />
      <DetailObject title="边界信息" value={bounds} />
      <DetailObject title="元数据" value={metadata} />
      {canNest && city ? <ResourceDetailPanel record={city} lookup={props.lookup} nested depth={depth + 1} /> : null}
      {canNest && baseSet ? <ResourceDetailPanel record={baseSet} lookup={props.lookup} nested depth={depth + 1} /> : null}
      {canNest && presetPath ? <ResourceDetailPanel record={presetPath} lookup={props.lookup} nested depth={depth + 1} /> : null}
    </InfoPanel>
  );
}

function InfoPanel(props: { title: string; emptyText?: string; nested?: boolean; children?: ReactNode }) {
  return (
    <section className={props.nested ? "detail-panel nested" : "detail-panel"}>
      <h3>{props.title}</h3>
      {props.children ?? <p className="detail-empty">{props.emptyText}</p>}
    </section>
  );
}

function DetailRows(props: { rows: Array<[string, string | number]> }) {
  return (
    <dl className="detail-rows">
      {props.rows.map(([label, value]) => (
        <div key={label}>
          <dt>{label}</dt>
          <dd>{formatDetailValue(value)}</dd>
        </div>
      ))}
    </dl>
  );
}

function DetailObject(props: { title: string; value: unknown }) {
  if (!props.value || (isRecord(props.value) && !Object.keys(props.value).length)) {
    return null;
  }
  return (
    <details className="detail-object">
      <summary>{props.title}</summary>
      <pre>{JSON.stringify(props.value, null, 2)}</pre>
    </details>
  );
}

function parseJsonValue(value: string | null | undefined): unknown {
  if (!value) {
    return null;
  }
  try {
    return JSON.parse(value);
  } catch {
    return value;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function getMetadataValue(metadata: unknown, key: string): string | number | null {
  if (!isRecord(metadata)) {
    return null;
  }
  const value = metadata[key];
  return typeof value === "string" || typeof value === "number" ? value : null;
}

function findResource(records: ResourceRecord[], id: string): ResourceRecord | null {
  return records.find((record) => record.id === id) ?? null;
}

function getResourceKind(record: ResourceRecord): string {
  if (record.snapshot_file_path || record.base_station_set_id || record.preset_path_id) {
    return "场景组合";
  }
  if (typeof record.station_count === "number") {
    return "基站集合";
  }
  if (typeof record.point_count === "number") {
    return "预设路径";
  }
  return "城市模型";
}

function getSourceLabel(sourceType: string | undefined): string {
  if (sourceType === "generated") {
    return "算法生成";
  }
  if (sourceType === "imported") {
    return "文件导入";
  }
  if (sourceType === "manual") {
    return "手工创建";
  }
  return sourceType ?? "-";
}

function formatDetailValue(value: string | number): string {
  if (typeof value === "number") {
    return Number.isInteger(value) ? String(value) : value.toFixed(3);
  }
  return value || "-";
}

function SettingsView({ notice }: { notice: string }) {
  return (
    <div className="panel-stack">
      <div className="section-heading">
        <h2>系统设置</h2>
      </div>
      <div className="settings-grid">
        <Metric label="后端状态" value={notice} />
        <Metric label="规划算法" value="DCMOCPSO" />
        <Metric label="问题模型" value="UAVPathPlanning" />
        <Metric label="Runner" value="Matlab CLI" />
      </div>
    </div>
  );
}

function ImportBox(props: {
  specs: ImportSpec[];
  state: { format: string; content: string };
  disabled: boolean;
  onChange: (value: { format: string; content: string }) => void;
  onImport: () => void;
}) {
  const activeSpec = props.specs.find((spec) => spec.format === props.state.format) ?? props.specs[0];
  return (
    <div className="import-panel">
      <div className="section-heading compact">
        <h3>文件导入</h3>
        <button className="secondary-button" disabled={props.disabled || !props.state.content.trim()} onClick={props.onImport}>
          <Upload size={17} />
          导入
        </button>
      </div>
      <label>
        文件格式
        <select value={props.state.format} onChange={(event) => props.onChange({ ...props.state, format: event.target.value })}>
          {props.specs.map((spec) => (
            <option key={spec.format} value={spec.format}>
              {spec.format.toUpperCase()}
            </option>
          ))}
        </select>
      </label>
      <textarea
        value={props.state.content}
        onChange={(event) => props.onChange({ ...props.state, content: event.target.value })}
        placeholder={activeSpec?.exampleText ?? ""}
      />
      {activeSpec ? (
        <div className="format-spec">
          <strong>{activeSpec.title}</strong>
          <span>必填：{activeSpec.requiredFields.join(", ")}</span>
          <pre>{activeSpec.exampleText}</pre>
        </div>
      ) : null}
    </div>
  );
}

function ResourcePicker(props: {
  label: string;
  records: ResourceRecord[];
  selectedId: string;
  onSelect: (value: string) => void;
}) {
  return (
    <label>
      {props.label}
      <select value={props.selectedId} onChange={(event) => props.onSelect(event.target.value)}>
        <option value="">未选择</option>
        {props.records.map((record) => (
          <option key={record.id} value={record.id}>
            {record.name}
          </option>
        ))}
      </select>
    </label>
  );
}

function NumberField(props: {
  label: string;
  value: number;
  step: number;
  onChange: (value: number) => void;
}) {
  return (
    <label>
      {props.label}
      <input type="number" step={props.step} value={props.value} onChange={(event) => props.onChange(Number(event.target.value))} />
    </label>
  );
}

function Metric(props: { label: string; value: string | number }) {
  return (
    <div>
      <span>{props.label}</span>
      <strong>{props.value}</strong>
    </div>
  );
}

function TaskList(props: {
  tasks: TaskRecord[];
  selectedTaskId: string;
  onSelect: (jobId: string) => void;
}) {
  return (
    <div className="task-list">
      {props.tasks.map((task) => (
        <button
          className={task.job_id === props.selectedTaskId ? "selected" : ""}
          key={task.job_id}
          onClick={() => props.onSelect(task.job_id)}
        >
          <span className={`status-dot ${task.status}`} />
          <span>{task.job_id.slice(0, 10)}</span>
          <strong>{task.status}</strong>
        </button>
      ))}
    </div>
  );
}

function formatMaybe(value: number | null | undefined): string {
  if (value === null || value === undefined || Number.isNaN(value)) {
    return "-";
  }
  return value.toFixed(3);
}

export default App;
