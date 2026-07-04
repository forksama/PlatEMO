# 开发工作梳理

> 本文档根据核心代码、提交历史中的 MOCPSO 引入版本，以及 `DCMOCPSO/example*.m` 实验脚本的文件名和头部说明整理。

## 1. DCMOCPSO 多目标优化算法

主要工作是在 MOCPSO 基线算法上做可开关、可消融的增强，并把增强算法嵌入 DCMOCPSO 分治框架。

相对最初引入的 MOCPSO，当前项目新增或强化了：

- 维度探索贡献度 E_k：衡量粒子在探索不足维度上的贡献。
- E_k 修正 APD：在环境选择中保护探索贡献较高的粒子。
- E_k 引导粒子：把高探索贡献粒子作为 CSS/DSS 速度更新的额外引导方向。
- 动态引导权重：`c_guide` 随迭代进度递减。
- 动态变异概率：多项式变异的基础概率 `1/D` 乘以阶段倍率，前期探索、后期收敛。
- 动态分组比例：前期增加 Winner 比例，中期均衡，后期增加 Loser2 比例强化收敛学习。
- 参考向量倍率：用 `uniformPointMultiplier` 调整 `UniformPoint` 规模。
- 可选 E_k：`MOCPSO_Ek_Flexible` 可通过 `useEk=false` 回退，用于消融对比。
- 面向约束问题的重试、空种群保护和终止前帕累托前沿筛选。

DCMOCPSO 本身的核心工作是：按航点序列把 UAVPathPlanning 拆为多个重叠段；每段调用 `MOCPSO_Ek_Flexible` 求解；后续段从前一段的多条候选路径继续展开；每段后基于已优化前缀做帕累托筛选；最终拼接完整路径并按原问题目标/约束评估。

## 2. UAVPathPlanning 问题复现

`UAVPathPlanning` 复现并扩展了无人机场景下的路径规划多目标问题，包含：

- 三维航点编码，每个航点为 `x,y,z`。
- 预设折线路径与均匀航点生成。
- 基于路径长度、速度和 TTT 自动推导航点数量。
- 城市建筑障碍物、基站部署和缓存 `.mat` 场景数据。
- LOS/NLOS 信号强度模型。
- 三目标评估：最大化平均信号强度、最小化切换次数、最大化路径覆盖率。
- 多类约束：路径方向、建筑物内航点、连线穿越建筑物、路径段 XY 边界。
- 航点修复逻辑：边界裁剪、首航点固定、建筑物内航点外移。
- 面向实验的高度中心和高度范围参数。

## 3. UAVPathPlanning 内嵌切换算法

切换算法被统一放在 `calculateSwitchDetails` 中，`calculateSwitchCount` 和实验可视化都可复用其结果。

已实现和对比的切换算法包括：

- 阈值切换：当前服务基站低于阈值时切换到最强基站。
- CASH：基于路径几何投影、候选基站评分、迟滞和安全条件切换。
- 前瞻性切换：沿预设路径向前看一段距离，使用未来窗口的加权信号评分选择目标基站，并结合动态迟滞余量与安全裕度触发切换。
- A3：使用固定迟滞余量和 TTT 确认作为对比算法。

前瞻性切换算法是本项目的核心设计之一。它通过 `precomputeAllLookaheadScores` 缓存每个预设航点的未来窗口基站评分，把切换目标从“当前最强”改为“未来窗口综合最优”，同时用速度和当前信号强度调节迟滞余量。

## 4. UAVPathPlanningSegments 分段求解

`UAVPathPlanningSegment` 是为了 DCMOCPSO 分段求解设计的子问题包装类。

它可以归入 DCMOCPSO 的分治架构，理由是：

- 它负责把完整路径问题切成段，而不是修改 MOCPSO 的粒子更新或环境选择。
- 它定义每段的优化变量、固定航点、局部目标和局部约束。
- 它与 `DCMOCPSO.main` 的段范围计算、路径拼接、帕累托筛选直接耦合。

因此建议在成果归类中写作：`UAVPathPlanningSegments` 是 DCMOCPSO 面向 UAVPathPlanning 的问题分解模块；它属于 DCMOCPSO 的应用架构和分治策略，不属于 E_k/动态变异/动态分组这类 MOCPSO 核心算子改进。

## 5. 实验与消融覆盖范围

`DCMOCPSO/example*.m` 文件展示了开发过程中的主要实验主题，归纳如下：

- 算法级对比：DCMOCPSO、OneSeg/Base-MOCPSO、IMMOEAD、DGEA。
- 三阶段消融：OneSeg_Lookahead、Seg_Lookahead、Full_Lookahead。
- MOCPSO 改进参数：`lambda`、`c_guide`、`uniformPointMultiplier`、`numSegments`。
- 前瞻切换参数：`lookaheadDistance`、`lookaheadHysteresisRange`、`lookaheadSafetyMargin`。
- 切换算法对比：阈值、前瞻性、A3。
- UAV 场景参数：速度、TTT、基站密度、高度层、高度范围。
- 预算敏感性：多个 maxFE 预算下的对比与缓存复用。
- 实验校验：`tests/test_example*.m` 针对实验脚本输出、指标保存和缓存修正提供回归检查。

这些实验文件不是核心架构的一部分，但它们说明了项目围绕“算法改进”和“UAV 场景参数”两条线做了系统消融。

## 6. 可作为个人开发工作的表述

可以把本项目工作概括为四类：

1. 基于 MOCPSO 设计并实现 DCMOCPSO，包括 E_k 维度探索贡献、动态变异、动态分组、引导粒子、参考向量倍率和可消融配置。
2. 复现并工程化 UAVPathPlanning 多目标问题，包括场景生成、信号模型、目标函数、约束、航点修复和实验参数化。
3. 设计并实现 UAVPathPlanning 的前瞻性切换算法，并与阈值、CASH、A3 等切换策略统一到同一接口下。
4. 设计 UAVPathPlanningSegment 分段子问题和 DCMOCPSO 外层分治求解流程，使完整路径优化可以按航点段顺序推进并逐段筛选帕累托候选。
