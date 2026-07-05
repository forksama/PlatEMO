# UAV 路径规划系统第二阶段实施记录

本文档记录本轮已经按设计文档落地的内容，以及后续仍需要继续拆分实现的方向。

## 1. 已落地能力

### 1.1 后端资源管理

已新增城市模型、基站集合、预设路径、场景组合四类资源。

当前支持：

- 城市模型导入：JSON / CSV。
- 城市模型生成：`MatlabAlphaBetaGammaUniformBuildings`。
- 基站集合导入：JSON / CSV。
- 基站集合生成：`MatlabDensityKMeansBaseStations`。
- 预设路径导入：JSON / CSV。
- 预设路径手动点位保存。
- 场景组合快照。
- 文件导入格式说明。
- 资源生成算法注册。

说明：当前 Python 侧实现了与 Matlab 公式一致的轻量生成逻辑，用于系统闭环和前端展示；Matlab 桥接脚本接口已预留，后续可把生成过程切换为真实 Matlab 资源生成脚本。

### 1.2 任务模型和进度日志

已新增：

- `scenarioId` 任务输入。
- 任务 artifact 中的 `scenario_snapshot.json`。
- 任务 artifact 中的 `matlab_scenario.json`。
- `progress.json`。
- `/api/tasks/{job_id}/progress`。
- `/api/tasks/{job_id}/logs`。
- Matlab stdout/stderr 运行中落盘。

任务状态扩展为：

```text
queued / preparing / running / exporting / succeeded / failed / cancelled
```

### 1.3 Matlab 场景注入

`UAVPathPlanning.m` 已支持第 13 个可选参数 `scenarioDataPath`。

兼容关系：

```text
第 11 参数：presetAltitude
第 12 参数：altitudeBounds
第 13 参数：scenarioDataPath
```

如果传入外部场景，Matlab 会读取：

```text
presetPath
baseStations
obstacles
bounds
grid
```

如果未传入外部场景，则继续使用原有默认场景生成或缓存文件。

### 1.4 前端多 Tab 工作台

前端已重构为左侧 Tab 工作台：

```text
总览
城市建模
基站管理
预设路径
场景组合
规划任务
任务队列
结果中心
系统设置
```

### 1.5 三维场景工作台

前端已新增 Three.js 三维视图，当前支持：

- 城市建筑物三维显示。
- 基站显示。
- 预设路径显示。
- 规划结果路径显示。
- 切换点显示。
- OrbitControls 旋转、平移、缩放。
- 预设路径 Tab 中点击地面新增路径点。

## 2. 当前验证结果

后端：

```text
python -m unittest discover -s backend/tests -v
20 tests OK, 1 skipped
```

前端：

```text
npm run build
npm audit
```

结果：

```text
build passed
0 vulnerabilities
```

浏览器验证：

- 桌面视口：左侧 Tab、后端状态、三维 canvas、城市生成流程正常。
- 移动视口：布局可用，三维 canvas 可渲染。
- 桌面和移动 canvas 区域像素采样均非空白。

## 3. 后续建议

下一轮建议优先做：

1. 把城市/基站生成从 Python 轻量实现切到 Matlab 生成脚本。
2. 为 `DCMOCPSO` 内部增加 FE/segment 级进度输出。
3. 增加运行中取消任务能力。
4. 增加资源删除/归档与名称编辑。
5. 增加真实文件上传控件或拖放导入。
6. 对大型城市模型做 Three.js InstancedMesh / LOD 优化。
