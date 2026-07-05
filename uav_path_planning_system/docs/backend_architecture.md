# UAV 路径规划系统后端架构知识

本文档用于固化当前后端架构知识，便于后续继续开发前端、长任务管理和 Matlab 联调。当前文档只描述后端与 Matlab 接入层；前端仍处于可调整阶段，不在本文中固化为最终形态。

## 1. 后端定位

后端位于：

```text
C:/Repositories/PlatEMO/uav_path_planning_system/backend
```

后端的职责不是重写 `DCMOCPSO` 或 `UAVPathPlanning`，而是作为系统层封装：

- 接收前端提交的路径规划参数。
- 校验并标准化问题参数、算法参数。
- 创建规划任务并保存任务元数据。
- 为每个任务生成独立 artifact 目录。
- 调用 Matlab 中既有 `DCMOCPSO + UAVPathPlanning`。
- 保存 Matlab 输入、输出、日志和原始 `.mat` 结果。
- 向前端提供任务状态和标准 JSON 结果。

后端第一版采用：

```text
FastAPI + Pydantic + SQLite + 本地文件 artifact + Matlab CLI Runner
```

## 2. 设计边界

第一阶段坚持以下边界：

- 不修改 PlatEMO 现有核心算法文件。
- 不在 Python 中复刻 DCMOCPSO 或 UAVPathPlanning 算法。
- Matlab 继续作为优化计算核心。
- Python 只负责工程调度、参数模型、任务状态、文件落盘、结果规范化和 API。
- 前后端不直接读取 `.mat`，前端只消费 `result.json`。

当前新增的 Matlab 桥接脚本是：

```text
backend/app/matlab/scripts/run_planning_job.m
```

该脚本位于 Python 工程内，避免污染：

```text
PlatEMO/Algorithms
PlatEMO/Problems
```

## 3. 目录结构

```text
backend/
  __init__.py
  app/
    main.py
    api/
      routes.py
    core/
      config.py
    domain/
      models.py
    jobs/
      store.py
      service.py
    matlab/
      adapter.py
      cli_runner.py
      engine_runner.py
      scripts/
        run_planning_job.m
    visualization/
      mapper.py
  tests/
    test_api_tasks.py
    test_config.py
    test_domain_models.py
    test_job_service.py
    test_matlab_cli_runner.py
    test_visualization_mapper.py
```

各目录职责：

- `api/`：FastAPI 路由层，对外暴露任务 API。
- `core/`：运行配置，包含仓库根目录、Matlab 命令、runtime 路径。
- `domain/`：Pydantic 领域模型，统一前端、后端、Matlab 之间的参数/结果语义。
- `jobs/`：任务创建、状态更新、SQLite 任务元数据存储。
- `matlab/`：Matlab runner 抽象、CLI runner、未来 Engine runner 占位。
- `visualization/`：结果规范化和前端友好数据映射。
- `tests/`：后端单元和轻量集成测试。

## 4. 应用装配

入口文件：

```text
backend/app/main.py
```

核心装配逻辑：

```text
Settings
  -> JobStore
  -> MatlabCliRunner
  -> JobService
  -> FastAPI Router
```

`create_app(runtime_root=None, runner=None)` 支持注入自定义 runner：

- 生产运行：不传 runner，默认使用 `MatlabCliRunner`。
- 测试运行：传入 fake runner，避免 API 测试误触发真实 Matlab。

该注入点非常重要，因为真实 Matlab 任务可能运行数分钟、数十分钟甚至数小时，单元测试不能依赖真实算法进程。

## 5. 配置模型

配置文件：

```text
backend/app/core/config.py
```

当前支持的环境变量：

```text
UAV_SYSTEM_REPOSITORY_ROOT=C:/Repositories/PlatEMO
UAV_SYSTEM_MATLAB_EXECUTABLE=matlab
UAV_SYSTEM_MATLAB_RUNNER=cli
```

派生路径：

```text
repository_root = C:/Repositories/PlatEMO
project_root    = C:/Repositories/PlatEMO/uav_path_planning_system
platemo_root    = C:/Repositories/PlatEMO/PlatEMO
runtime_root    = C:/Repositories/PlatEMO/uav_path_planning_system/.runtime
artifact_root   = .runtime/artifacts
database_path   = .runtime/uav_path_planning.sqlite3
```

## 6. 领域模型

领域模型位于：

```text
backend/app/domain/models.py
```

核心模型：

- `ProblemConfig`：UAVPathPlanning 问题参数。
- `AlgorithmConfig`：DCMOCPSO 算法参数。
- `PlanningConfig`：一次任务的完整输入。
- `JobStatus`：任务状态枚举。
- `JobCreated`：任务创建响应。
- `PlanningResult`：规划结果结构。
- `ResultMetrics`：结果指标摘要。
- `ScenarioPayload`：场景图层数据。
- `SolutionPath`：候选路径。
- `ObjectivePoint`：Pareto 目标值。

当前默认参数与第一版验证场景保持一致：

```text
bs_per_km2 = 20
velocity = 20
ttt_seconds = 5
switch_threshold_dbm = -101.5
transmit_power_dbm = 30
switch_method = 2
population_size = 20
max_fe = 100
num_segments = 5
segment_overlap = 2
lambda_weight = 0.5
c_guide = 0.3
use_dynamic_grouping = true
use_dynamic_mutation = true
use_ek = true
uniform_point_multiplier = 3
```

`switch_method` 与 Matlab 中 `UAVPathPlanning` 的语义对应：

```text
0 = 阈值切换
1 = CASH
2 = 前瞻切换
3 = A3
```

## 7. API 设计

路由文件：

```text
backend/app/api/routes.py
```

当前 API：

```text
POST /api/tasks
GET  /api/tasks
GET  /api/tasks/{job_id}
GET  /api/tasks/{job_id}/result
```

### 7.1 创建任务

```text
POST /api/tasks
```

输入：`PlanningConfig`

后端行为：

1. 创建任务 ID。
2. 写入 SQLite 任务记录，初始状态为 `queued`。
3. 添加 FastAPI `BackgroundTasks`。
4. 后台执行 `JobService.run_job(job_id)`。
5. 立即返回 `job_id` 和 `queued` 状态。

注意：当前使用 FastAPI 内置后台任务，适合第一版原型。长期运行和多任务并发时，应升级为独立 worker/队列。

### 7.2 查询任务列表

```text
GET /api/tasks
```

返回 SQLite 中全部任务记录，按创建时间倒序。

### 7.3 查询单个任务

```text
GET /api/tasks/{job_id}
```

返回任务状态、配置、创建/更新时间和错误信息。

### 7.4 查询结果

```text
GET /api/tasks/{job_id}/result
```

读取：

```text
.runtime/artifacts/<job_id>/result.json
```

并通过 `normalize_result_payload()` 做结果规范化。

如果结果文件不存在，返回 404。

## 8. 任务状态机

当前任务状态：

```text
queued
running
succeeded
failed
cancelled
```

当前实际状态流：

```text
queued -> running -> succeeded
queued -> running -> failed
```

`cancelled` 已预留，但第一版还没有取消接口。

任务服务：

```text
backend/app/jobs/service.py
```

执行流程：

1. 根据 `job_id` 从 `JobStore` 读取任务。
2. 创建 artifact 目录。
3. 写入 `input.json`。
4. 更新状态为 `running`。
5. 调用 runner。
6. 成功则状态置为 `succeeded`。
7. 异常则状态置为 `failed` 并保存错误信息。

## 9. 持久化结构

第一版采用 SQLite + 本地文件。

SQLite 文件：

```text
.runtime/uav_path_planning.sqlite3
```

任务表：

```text
jobs
  job_id TEXT PRIMARY KEY
  status TEXT NOT NULL
  config_json TEXT NOT NULL
  created_at TEXT NOT NULL
  updated_at TEXT NOT NULL
  error_message TEXT
```

Artifact 目录：

```text
.runtime/artifacts/<job_id>/
  input.json
  result.json
  result.mat
  stdout.log
  stderr.log
```

文件含义：

- `input.json`：传给 Matlab 的标准任务输入。
- `result.json`：前端/API 消费的标准结果。
- `result.mat`：Matlab 原始结果，便于复现实验和后续分析。
- `stdout.log`：Matlab 标准输出。
- `stderr.log`：Matlab 标准错误。

## 10. Matlab 调用层

Runner 协议：

```text
PlanningRunner.run(job_id, config, artifact_dir) -> Path
```

当前实现：

```text
backend/app/matlab/cli_runner.py
```

调用方式：

```text
matlab -batch "addpath('<script_dir>'); run_planning_job('<platemo_root>', '<input_json>', '<artifact_dir>')"
```

重要实现细节：

- `artifact_dir` 会先 `resolve()` 成绝对路径。
- `input_path`、`artifact_dir`、`script_dir`、`platemo_root` 都以绝对路径传给 Matlab。
- 这是为了解决 Matlab 工作目录与 Python 工作目录不一致导致 `fileread(input.json)` 找不到文件的问题。

第一版使用 CLI runner 的原因：

- 不依赖 Python `matlab.engine`。
- 每个任务隔离性较好。
- 出错后可通过日志排查。

缺点：

- Matlab 启动成本高。
- 长任务运行期间 stdout/stderr 通过 `subprocess.Popen()` 边运行边写入日志文件。
- 不适合高频交互或大量并发。

预留实现：

```text
backend/app/matlab/engine_runner.py
```

后续可升级为常驻 Matlab Engine worker 或独立 worker 池。

## 11. Matlab 桥接脚本

脚本：

```text
backend/app/matlab/scripts/run_planning_job.m
```

职责：

1. 创建 artifact 目录。
2. `addpath(genpath(platemoRoot))`。
3. 读取 `input.json`。
4. 构造 `problemParameter`。
5. 构造 `algorithmParameter`。
6. 创建 `UAVPathPlanning`。
7. 创建 `DCMOCPSO`。
8. 执行 `Algorithm.Solve(Problem)`。
9. 提取最终种群。
10. 导出目标值、路径、切换点、场景。
11. 写入 `result.json`。
12. 保存 `result.mat`。

桥接脚本当前不修改任何 PlatEMO 算法源文件。

## 12. 结果规范化

规范化模块：

```text
backend/app/visualization/mapper.py
```

当前两个职责：

1. `normalize_result_payload(result)`  
   稳定 API 输出结构。

2. `build_plot_payload(result)`  
   生成更适合前端绘图的数据。

为什么需要规范化：

Matlab `jsonencode` 在只有一个元素时，可能把数组编码成单个对象。例如：

```text
objectives: {...}
solutions: {...}
switchPoints: {...}
```

而多元素时才是：

```text
objectives: [...]
solutions: [...]
switchPoints: [...]
```

因此后端 API 出口统一把这些字段变成 list，避免前端根据单解/多解写两套逻辑。

当前规范化字段：

- `objectives`
- `solutions`
- `solutions[*].switchPoints`
- `solutions[*].switch_points`
- `scenario.obstacles`

## 13. 已验证链路

已完成的验证：

```text
python -m unittest discover -s backend/tests -v
```

结果：

```text
22 tests
21 passed
1 skipped
```

跳过的测试是 FastAPI 未安装时的兜底测试；当前环境已安装 FastAPI，所以该测试按预期跳过。

真实 Matlab 冒烟任务也已跑通。

最小冒烟配置：

```text
population_size = 1
max_fe = 1
num_segments = 1
segment_overlap = 0
switch_method = 0
use_dynamic_grouping = false
use_dynamic_mutation = false
uniform_point_multiplier = 1
```

验证结果：

```text
job_id = 81fe7a8b98904d269ceadbedc88c2fb8
status = succeeded
runtimeSeconds = 85.7005822
actualFE = 2
solutionCount = 1
meanSignalDbm = -74.04236138412891
meanSwitchCount = 11
meanCoverageRatio = 0.8702334051052291
```

说明：

- 即使最小参数，Matlab 启动、PlatEMO 初始化、算法执行、并行池处理仍可能接近 1 到 2 分钟。
- 正常任务运行数分钟、数十分钟甚至数小时是合理预期。

## 14. 当前已知限制

### 14.1 没有真实进度条

当前只能看到：

```text
queued / running / succeeded / failed
```

不能看到：

```text
当前段编号
当前 FE
总 FE
百分比
当前日志行
预计剩余时间
```

原因：

- `MatlabCliRunner` 使用 `subprocess.run()`。
- Matlab stdout/stderr 当前在进程结束后一次性写入日志文件。
- Matlab 桥接脚本还没有持续写入 `progress.json`。

### 14.2 没有取消任务接口

当前任务一旦进入 Matlab 进程，只能等待进程结束或人工停止进程。后续应增加：

```text
POST /api/tasks/{job_id}/cancel
```

### 14.3 没有队列和并发控制

当前 FastAPI BackgroundTasks 适合原型，不适合大量长任务。后续建议引入：

- 独立 worker 进程。
- 单机队列。
- Redis/Celery/RQ。
- Matlab worker 池。

### 14.4 Matlab CLI 启动成本高

CLI runner 稳定但启动慢。后续可以升级：

- Matlab Engine 常驻 worker。
- 预热 parpool。
- 长任务队列串行执行。
- 缓存相同输入任务结果。

## 15. 后续建议

后端下一阶段建议优先做：

1. 任务进度文件

   Matlab 每个关键阶段写入：

   ```text
   progress.json
   ```

   示例字段：

   ```json
   {
     "stage": "solving_segment",
     "segmentIndex": 2,
     "segmentCount": 5,
     "currentFE": 120,
     "maxFE": 500,
     "percent": 42.0,
     "message": "Solving segment 2/5",
     "updatedAt": "2026-07-04T14:00:00Z"
   }
   ```

2. 进度 API

   ```text
   GET /api/tasks/{job_id}/progress
   ```

3. 日志 API

   ```text
   GET /api/tasks/{job_id}/logs
   ```

4. 取消 API

   ```text
   POST /api/tasks/{job_id}/cancel
   ```

5. 任务历史与结果复用

   支持前端加载历史任务和已有结果，不必每次重新跑 Matlab。

6. 独立 worker

   将 Matlab 长任务从 FastAPI 进程中剥离出去，增强稳定性。

## 16. 当前提交状态

当前后端架构已提交：

```text
4292cbab Ignore UAV system artifacts
cd3f7f46 Add UAV planning backend
```

前端提交已按要求退回，当前前端目录保留为未提交状态，方便继续调整。

本文档用于补充后端架构知识，不改变当前后端运行逻辑。

## 17. 第二阶段当前实现增量

当前后端已从第一版“任务提交器”扩展为“资源管理 + 场景快照 + Matlab 场景注入 + 粗粒度进度日志”的系统骨架。

### 17.1 新增资源管理模块

新增模块：

```text
backend/app/resources/
  store.py
  service.py
```

新增 SQLite 表：

```text
city_models
base_station_sets
preset_paths
scenarios
```

资源文件统一落在：

```text
.runtime/resources/
  city_models/<id>/normalized.json
  base_station_sets/<id>/normalized.json
  preset_paths/<id>/normalized.json
  scenarios/<id>/snapshot.json
  scenarios/<id>/matlab_scenario.json
```

当前支持：

- 城市模型 JSON/CSV 导入。
- 城市模型基于 `alpha / beta / gamma` 生成。
- 基站集合 JSON/CSV 导入。
- 基站集合基于城市模型和 `bs_per_km2` 生成，自动生成时基站落在建筑物左下角/右上角，高度为 `building.height + roof_offset_m`，默认 `roof_offset_m = 5m`。
- 预设路径 JSON/CSV 导入。
- 预设路径手动点位保存。
- 场景组合快照生成。
- 文件导入格式说明 API。
- 资源生成算法注册 API。

资源归属关系当前固定为：

```text
CityModel 1 -> N BaseStationSet
CityModel 1 -> N PresetPath
Scenario 1 -> 1 CityModel + 1 BaseStationSet + 1 PresetPath
```

也就是说：

- 每个基站集合只属于一个城市模型。
- 每条预设路径只属于一个城市模型，不在资源层绑定基站集合。
- 创建场景组合时才同时指定城市模型、基站集合、预设路径，并校验基站集合和预设路径都属于所选城市模型。
- `preset_paths` 表不再包含 `base_station_set_id`；启动时会迁移旧表结构，保留已有路径资源的城市、文件和点数信息。

### 17.2 新增资源 API

新增接口：

```text
POST /api/city-models/import
POST /api/city-models/generate
GET  /api/city-models
GET  /api/city-models/{id}
GET  /api/city-models/{id}/geometry
GET  /api/city-models/import-specs
GET  /api/city-models/generation-algorithms

POST /api/base-station-sets/import
POST /api/base-station-sets/generate
GET  /api/base-station-sets
GET  /api/base-station-sets/{id}
GET  /api/base-station-sets/{id}/stations
GET  /api/base-station-sets/import-specs
GET  /api/base-station-sets/generation-algorithms

POST /api/preset-paths
POST /api/preset-paths/import
GET  /api/preset-paths
GET  /api/preset-paths/{id}
GET  /api/preset-paths/import-specs

POST /api/scenarios
GET  /api/scenarios
GET  /api/scenarios/{id}
GET  /api/scenarios/{id}/snapshot

GET /api/algorithms
GET /api/resource-generation-algorithms
```

### 17.3 任务模型扩展

`PlanningConfig` 新增：

```text
scenario.scenarioId
scenario.snapshotFile
scenario.matlabScenarioFile
algorithmKey
```

任务状态扩展为：

```text
queued
preparing
running
exporting
succeeded
failed
cancelled
```

新增任务接口：

```text
GET /api/tasks/{job_id}/progress
GET /api/tasks/{job_id}/logs
```

每个任务 artifact 当前可能包含：

```text
input.json
scenario_snapshot.json
matlab_scenario.json
progress.json
stdout.log
stderr.log
result.json
result.mat
```

### 17.4 Matlab 对接增量

`run_planning_job.m` 当前会写粗粒度阶段进度：

```text
loading_scenario
initializing_problem
initializing_algorithm
running_algorithm
exporting_result
finished
```

`MatlabCliRunner` 已从 `subprocess.run()` 改为 `subprocess.Popen()`，stdout/stderr 会边运行边写入日志文件，前端可在任务运行中读取已刷出的日志。

### 17.5 UAVPathPlanning 外部场景注入

当前对既有 Matlab 问题类做了一个向后兼容改动：

```text
PlatEMO/Problems/Multi-objective optimization/Real-world MOPs/UAVPathPlanning.m
```

新增第 13 个可选参数：

```text
scenarioDataPath
```

兼容关系：

- 第 11 个参数仍为 `presetAltitude`。
- 第 12 个参数仍为 `altitudeBounds`。
- 第 13 个参数才是 `scenarioDataPath`。
- 如果 `scenarioDataPath` 为空或文件不存在，保持旧的默认场景缓存/生成逻辑。

外部场景 JSON 当前读取：

```text
presetPath
baseStations
obstacles
bounds
grid
```

说明：Matlab 内部障碍物结构仍是 `gridX x gridY x 5` 矩形网格，因此前端/资源层传入的建筑物在 Matlab 侧先按矩形外接框参与避障和视距计算。

### 17.6 当前仍未完成的能力

以下能力尚未做完整工程化：

- `DCMOCPSO` 内部 FE 级进度。
- 运行中任务取消。
- 独立 worker 进程或多 Matlab worker 池。
- 多边形建筑在 Matlab 内部的精确几何求交。
- 大规模城市模型的前端 LOD/分块加载。
