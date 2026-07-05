# 面向通信优化的城市巡逻 UAV 路径规划系统

该目录是 PlatEMO 外层仓库下新增的 Python/Web 工程，用于把现有 Matlab 算法模块工程化接入到路径规划系统中。

当前目标是打通：

- React 前端工作台：左侧多 Tab 管理城市建模、基站、预设路径、场景组合、规划任务、任务队列和结果中心。
- Three.js 三维场景：展示建筑物、基站、预设路径、规划路径和切换点，支持旋转、平移、缩放。
- FastAPI 后端：提供资源管理、场景快照、任务创建、任务查询、进度日志和结果查询接口。
- Matlab CLI 适配层：通过 `matlab -batch` 调用 PlatEMO 中的 `DCMOCPSO + UAVPathPlanning`。
- SQLite 与本地文件持久化：保存资源元数据、任务元数据、输入参数、Matlab 日志、`result.json` 和 `result.mat`。

## 目录结构

```text
uav_path_planning_system/
  backend/
    app/
      api/             # FastAPI 路由
      core/            # 系统配置
      domain/          # 参数、任务、结果模型
      jobs/            # SQLite 任务存储与任务服务
      matlab/          # Matlab 调用适配层与桥接脚本
      resources/       # 城市/基站/路径/场景资源管理
      visualization/   # 前端友好的结果映射
    tests/             # 后端单元测试
  frontend/
    src/
      api/             # 前端 API 客户端与结果归一化
      components/      # 工作台组件
      styles/          # 页面样式
  .runtime/            # 本地运行产物，默认不入库
```

## 后端运行

```powershell
cd C:\Repositories\PlatEMO\uav_path_planning_system
python -m pip install -e ".[dev]"
python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000
```

如果暂时无法安装 `matlab.engine`，第一版默认使用 `matlab -batch`。可通过 `.env` 或环境变量调整：

```powershell
$env:UAV_SYSTEM_REPOSITORY_ROOT="C:/Repositories/PlatEMO"
$env:UAV_SYSTEM_MATLAB_EXECUTABLE="matlab"
$env:UAV_SYSTEM_MATLAB_RUNNER="cli"
```

## 前端运行

```powershell
cd C:\Repositories\PlatEMO\uav_path_planning_system\frontend
npm install
npm run dev
```

前端默认通过 Vite 代理访问 `http://127.0.0.1:8000/api`。也可以设置 `VITE_API_BASE_URL` 指向其他后端地址。

## 验证

在后端依赖可用时运行：

```powershell
cd C:\Repositories\PlatEMO\uav_path_planning_system
python -m unittest discover -s backend/tests -v
```

在前端依赖可用时运行：

```powershell
cd C:\Repositories\PlatEMO\uav_path_planning_system\frontend
npm run build
```

## Matlab 接入边界

Python 侧新增桥接脚本：

```text
backend/app/matlab/scripts/run_planning_job.m
```

桥接脚本负责读取任务输入、添加 PlatEMO 路径、创建 `UAVPathPlanning` 问题对象、创建 `DCMOCPSO` 算法对象、执行优化并输出标准化结果文件。

当前对 `UAVPathPlanning.m` 增加了向后兼容的第 13 个可选参数 `scenarioDataPath`，用于让系统导入或生成的城市、基站、预设路径场景真实进入 Matlab 计算。未传入该参数时，原有默认场景逻辑保持不变。
