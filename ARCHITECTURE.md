# DCMOCPSO 与 UAVPathPlanning 架构说明

> 本文档根据项目核心代码整理，不把 `example*` 实验脚本、`results` 缓存和 `one_time_adjust*` 结果修正脚本作为架构主体。实验主题仅用于说明开发工作覆盖范围。

## 代码边界

核心实现分布在三个位置：

- `PlatEMO/Algorithms/Multi-objective optimization/DCMOCPSO/DCMOCPSO.m`：DCMOCPSO 的外层分治调度算法。
- `PlatEMO/Algorithms/Multi-objective optimization/DCMOCPSO/UAVPathPlanningSegment.m`：把完整 UAVPathPlanning 包装成分段子问题。
- `PlatEMO/Algorithms/Multi-objective optimization/MOCPSO/*.m`：MOCPSO、MOCPSO_Ek、MOCPSO_Ek_Flexible 及其算子、环境选择和辅助函数。
- `PlatEMO/Problems/Multi-objective optimization/Real-world MOPs/UAVPathPlanning.m`：无人机路径规划问题、通信模型、约束、目标函数和切换算法。

DCMOCPSO 不是独立的问题类，而是面向 `UAVPathPlanning` 的分治式算法。它在每个路径段内复用 `MOCPSO_Ek_Flexible`，最终把各段结果拼接回完整路径并交给原问题计算完整目标和约束。

## MOCPSO 到 DCMOCPSO 的算法层结构

项目里保留了三层 MOCPSO 形态：

- `MOCPSO`：基线算法。初始引入版本使用 `UniformPoint(Problem.N, Problem.M)`、固定 1:1:1 的 Winner/Loser 分组、普通 APD 环境选择和固定概率多项式变异。
- `MOCPSO_Ek`：在基线算法上加入维度探索贡献度 E_k、E_k 修正 APD、E_k 引导粒子、动态变异率和动态分组开关。
- `MOCPSO_Ek_Flexible`：把 E_k、动态分组、动态变异和参考向量倍率都参数化，既可退化为接近基线的 OneSeg 模式，也可作为 DCMOCPSO 每段子问题的内部优化器。

关键增强点如下：

- 维度探索贡献度：`calculateDimensionExploration` 根据每个维度的探索范围 `Range_j` 得到归一化权重 `W_j`，再计算粒子在探索不足维度上偏离种群中心的贡献 `E_k`。E_k 越高，表示该粒子对稀疏维度探索越有价值。
- E_k 环境选择：`EnvironmentalSelectionWithEk` 将原 APD 改为 `APD_k = (1 + tau_k) * d_k / (1 + lambda * E_k)`，用 E_k 作为奖励项保护探索贡献高的粒子。
- E_k 引导粒子：`calculateDimensionExploration` 会从可行解或低约束违反度候选中按 E_k 概率抽取引导粒子；`Operator_WithGuide` 在 CSS/DSS 速度更新中加入 `c_guide * r * (GuideDec - LoserDec)`。
- 动态引导权重：`MOCPSO_Ek_Flexible` 使用 `c_guide_dynamic = c_guide * (1 - t)`，前期引导强，后期逐步减弱。
- 动态变异率：`getMutationRateMultiplier(t)` 将基础变异概率 `1/D` 乘以阶段倍率，前 20% 为 2.0，随后依次降为 1.5、1.0、0.75、0.5。
- 动态分组比例：`groupParticlesByRatio` 支持按适应度批内排序分组。当前策略为前期 `[2,1,1]`、中期 `[1,1,1]`、后期 `[1,1,2]`。
- 参考向量倍率：`uniformPointMultiplier` 控制 `UniformPoint(Problem.N * multiplier, Problem.M)`，用于增加参考向量密度。

## DCMOCPSO 分治求解架构

`DCMOCPSO` 的入口是 `main(Algorithm, Problem)`。它只接受 `UAVPathPlanning` 问题，参数包括：

- `numSegments`：路径分段数。
- `segmentOverlap`：相邻段重叠航点数。
- `lambda`、`c_guide`：传给内部 MOCPSO_Ek_Flexible 的 E_k 和引导权重参数。
- `useDynamicGrouping`、`useDynamicMutation`、`useEk`：开关化启用 DCMOCPSO 增强机制。
- `uniformPointMultiplier`：内部优化器参考向量倍率。

主流程如下：

1. 检查问题类型并读取完整路径航点数 `Problem.D / 3`。
2. 通过 `calculateSegmentRanges` 计算每段 `[startIdx, endIdx]`，相邻段按 `segmentOverlap` 回退重叠。
3. 初始化完整路径，优先使用 `Problem.presetWaypoints`，否则调用 `Problem.generateUniformWaypoints()`。
4. 顺序求解每段：第一段只固定预设路径起点；后续段对上一段保留下来的每条路径分别创建子问题，固定重叠处前两个航点，运行内部优化器，再把子段解拼回完整路径。
5. 每段结束后调用 `filterParetoFront`，只基于已优化到当前段的航点计算平均信号、切换次数和覆盖率，并保留第一前沿路径。
6. 全部段完成后，把路径矩阵 reshape 为完整决策向量，用 `SOLUTION` 触发原始 `UAVPathPlanning` 的完整目标和约束计算。

这种架构的要点是：外层 DCMOCPSO 管路径分解、拼接和阶段性帕累托筛选；内层 MOCPSO_Ek_Flexible 管每个子问题的粒子群搜索。

## UAVPathPlanningSegment 子问题架构

`UAVPathPlanningSegment` 是 `PROBLEM` 的包装类，用来把完整 UAVPathPlanning 的一段航点转成可被 PlatEMO 算法求解的小问题。

它的职责包括：

- 保存原始问题对象、完整路径、当前段索引和固定航点。
- 第一段固定第一个航点；非第一段固定前两个航点，以维持段间连续性和方向约束。
- 根据段大小重设子问题维度：第一段优化 `(segmentSize - 1) * 3` 维，后续段优化 `(segmentSize - 2) * 3` 维。
- 复用原问题的目标数、编码、边界、种群规模和最大评估次数。
- `Initialization` 基于当前段的预设航点生成初始种群。
- `CalDec` 调用原问题的 `repairWaypointOutsideObstacle`，修复建筑物内航点并裁剪到边界内。
- `CalObj` 只计算当前段相关目标：负平均信号强度、切换次数、负路径覆盖率。覆盖率通过原问题的 `calculatePathCoverageRatio` 保持一致。
- `CalCon` 返回与完整问题同维度的约束数组，但只在当前段相关位置填入违反度，其余位置为 0。
- `CalFullPathObj` 和 `CalFullPathCon` 可把子问题解嵌回完整路径后调用原问题完整评估。

因此，`UAVPathPlanningSegment` 更准确地说是 DCMOCPSO 的“分段问题适配层”。它不是 MOCPSO 本身的算子改进，但属于 DCMOCPSO 分治架构不可分割的一部分。

## UAVPathPlanning 问题架构

`UAVPathPlanning` 是三目标真实场景问题，继承 PlatEMO 的 `PROBLEM`。

### 参数与场景生成

问题参数通过 `ParameterSet` 读取，主要包括：

- `bsPerKm2`：每平方公里基站数量。
- `velocity`：无人机最大速度。
- `TTT`：航点采样间隔，也用于切换时间粒度。
- `switchThreshold`：切换阈值。
- `obstacleMethod`：障碍物与预设路径生成方法，目前固定支持 0。
- `P_tx`：无人机发射功率。
- `switchMethod`：切换算法，0 阈值、1 CASH、2 前瞻性、3 A3。
- `lookaheadDistance`、`lookaheadHysteresisRange`、`lookaheadSafetyMargin`：前瞻切换算法参数。
- `presetAltitude`、`altitudeBounds`：可选高度复现实验参数。

场景数据会按 `UAVPathPlanning-<obstacleMethod>-<bsPerKm2>.mat` 加载或生成，包括预设路径、基站、障碍物、网格信息和路径段边界。路径总长度由预设路径计算，航点数自动设为 `ceil(pathLength / (velocity * 0.5 * TTT))`，每个航点包含 `x,y,z` 三维坐标。

### 目标函数

`CalObj` 对每个解计算三个最小化目标：

1. `-calculateAverageSignal(waypoints)`：最大化全程平均最强基站信号。
2. `calculateSwitchCount(waypoints)`：最小化切换次数。
3. `-calculatePathCoverageRatio(waypoints)`：最大化路径覆盖率。

当前 `switchMethod=2` 时，`CalObj` 会懒加载 `lookaheadScores` 缓存，避免重复计算前瞻评分。

### 约束函数

`CalCon` 计算四类约束违反度：

- 航点方向约束：相邻航点向量需要与其所属预设路径段方向保持非负投影；跨段时与任一相关段方向非负即可。
- 航点不在建筑物中：调用 `checkWaypointInObstacle`。
- 航点连线不穿过建筑物：调用 `checkSegmentIntersectsObstacle`。
- XY 平面边界约束：按 `waypointSegmentMapping` 对每个航点应用对应路径段的 `xyBound` 上下界。

代码中临时移除了连续三航点夹角约束。线段与障碍物的检测通过 `checkLineIntersectionInternal` 统一实现，`checkLineOfSight` 和 `checkSegmentIntersectsObstacle` 都复用该核心逻辑。

## 内嵌切换算法架构

切换算法统一由 `calculateSwitchDetails(waypoints)` 实现，`calculateSwitchCount` 只读取其 `switchCount`。该方法同时返回连接基站序列、信号矩阵、切换点和算法编号，便于目标函数和可视化复用同一逻辑。

### 信号模型

`computeSignalStrengths(waypoint)` 对所有基站计算信号强度：

- 有视距时路径损耗为 `20*log10(distance) + 61.4`。
- 无视距时路径损耗为 `40*log10(distance) + 72`。
- 信号强度为 `P_tx - pathLoss`。

视距由 `checkLineOfSight` 判断，底层复用障碍物相交检测。

### switchMethod=0：阈值切换

首航点连接最强基站。后续航点若当前服务基站信号低于 `switchThreshold`，则切换到当前最强基站，否则保持原连接。

### switchMethod=1：CASH

CASH 基于路径起点到终点方向预计算每个基站在路径方向上的投影距离和垂直距离。每个航点筛选“位于前方且信号可用”的候选基站，用 `distance_to_A / (1 + perpendicular_distance)` 评分，再结合固定迟滞余量和低信号安全条件决定是否切换。

### switchMethod=2：前瞻性切换

前瞻算法面向预设路径做信号预测和缓存：

1. `precomputeAllLookaheadScores` 对所有预设航点和所有基站预计算信号矩阵。
2. 对每个预设航点，找出 `lookaheadDistance` 范围内的预设航点。
3. 使用 `1 / (distance + epsilon)` 权重聚合未来窗口内各基站信号，得到该航点的基站前瞻评分。
4. 实际路径运行时，先找到当前实际航点最近的预设航点，再从缓存中取得前瞻评分最高的目标基站。
5. 切换触发前提是当前服务基站信号低于 `switchThreshold`。
6. 触发后仍需满足以下任一条件：目标信号高于当前信号加动态迟滞余量，或当前信号低于 `switchThreshold + lookaheadSafetyMargin`。
7. 动态迟滞余量由速度和当前信号强度共同决定：速度越快越灵敏，当前信号越强越抑制频繁切换。

这个算法把“当前最强”扩展为“沿预设路径未来窗口内综合表现最好”，并用动态迟滞与安全裕度抑制乒乓切换和弱信号拖延。

### switchMethod=3：A3

A3 使用固定迟滞余量和 TTT 确认。候选基站必须持续满足 `candidateSignal > currentSignal + hysteresisMargin`，再由 `shouldTriggerA3Handover` 统一判断是否切换。当前模型每个航点间隔已经等于 TTT，因此确认步数设为 1。

## UAVPathPlanningSegments 是否归入 DCMOCPSO

可以归入 DCMOCPSO 的“分治求解架构”，但不应归入 MOCPSO_Ek 的“粒子群核心算子改进”。

理由是：

- `UAVPathPlanningSegment` 的目的不是改变粒子速度、变异或环境选择，而是把完整路径问题拆成可顺序优化的子问题。
- 它直接服务于 `DCMOCPSO.main` 的分段、固定重叠航点、子问题求解和路径拼接流程。
- 它对目标与约束做了局部化计算，解决分段优化中“当前段粒子差异被完整路径未优化部分稀释”的问题。

因此在论文或项目说明中，建议表述为：`UAVPathPlanningSegment` 是 DCMOCPSO 用于 UAVPathPlanning 的问题分解与子问题建模模块；E_k、动态变异、动态分组、引导粒子和参考向量倍率属于 DCMOCPSO 内部优化器的 MOCPSO 改进模块。
