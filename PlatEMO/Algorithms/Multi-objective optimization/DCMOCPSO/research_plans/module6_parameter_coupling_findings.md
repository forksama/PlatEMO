# 模块 6：环境参数耦合关系调研记录

调研日期：2026-06-08

## 调研目标

本模块分析 UAVPathPlanning 中几个环境/场景参数之间的耦合关系：

- `bsPerKm2`：目标基站密度
- `velocity`：无人机速度
- `TTT`：路径采样/切换决策时间间隔
- `altitudeCenter`：预设飞行高度中心
- `altitudeBounds`：高度可优化范围

前面模块 2-5 已经分别给出了单参数取值依据。本模块重点回答：

1. 哪些参数之间存在强耦合；
2. 哪些耦合会直接影响信号强度、切换次数、覆盖率和 HV；
3. 后续实验应该继续做单因素消融，还是构造联合场景组合。

## 代码侧耦合关系

当前代码中，环境参数不是完全独立的。

### velocity 与 TTT

```matlab
actualVelocity = obj.velocity * 0.5;
distancePerWaypoint = actualVelocity * obj.TTT;
obj.numWaypoints = max(2, ceil(obj.pathLength / distancePerWaypoint));

maxDistance = obj.velocity * obj.TTT;
currentSpeed = distPrev / obj.TTT;
```

因此：

- `velocity` 越大，航点数量通常越少；
- `TTT` 越大，航点数量也通常越少；
- `velocity * TTT` 决定相邻航点允许的最大空间位移；
- 前瞻性算法中 `currentSpeed = distPrev / TTT`，因此 TTT 会影响动态迟滞余量。

### bsPerKm2 与 altitude

基站部署在建筑物顶部：

```matlab
baseStations(bsIdx, :) = [x_min, y_min, height + 5];
baseStations(bsIdx, :) = [x_max, y_max, height + 5];
```

信号强度由 UAV 航点到所有基站的 3D 距离和 LoS/NLoS 决定：

```matlab
distances = sqrt(sum((obj.baseStations - repmat(waypoint, obj.numBS, 1)).^2, 2));
hasLOS = obj.checkLineOfSight(waypoint, obj.baseStations(k,:));
```

因此：

- `bsPerKm2` 决定候选基站数量和空间间距；
- `altitudeCenter/altitudeBounds` 决定 UAV 相对建筑物和基站的高度；
- 高度变化会改变 LoS/NLoS、3D 距离和可连接候选基站集合；
- 高密基站与高空 LoS 叠加时，可能同时带来覆盖增强和干扰/切换候选增多。

### 三个目标指标

当前目标为：

```matlab
rowObj(1) = -avgSignal;
rowObj(2) = switchCount;
rowObj(3) = -coverageRatio;
```

也就是说，算法倾向于：

- 平均信号强度越高越好；
- 切换次数越低越好；
- 覆盖率越高越好。

HV 最终会综合反映这三个目标，因此所有参数耦合最终都会通过这三个指标影响 HV。

## 文献侧耦合依据

| 来源 | 与耦合相关的结论 | 对本实验的启发 |
|---|---|---|
| Mobility State Detection of Cellular-Connected UAVs based on Handover Count Statistics | handover count 被建模为 UAV 高度、速度、测量时间窗口、GBS 密度和 TTT 的函数；速度估计还依赖 GBS 密度和 handover count 测量周期。 | 支持把 `velocity`、`bsPerKm2`、`TTT`、`altitude` 作为一组耦合变量，而不是完全独立变量。 |
| Handover Management for Drones in Future Mobile Networks | 无人机高速度、3D 移动、LoS 链路和高空飞行会导致更高 handover rate、ping-pong、RLF/HOF；150 m 高度无人机的平均切换频率可显著高于同速地面用户。 | 支持“高度 + 速度 + 基站候选数”共同影响切换频率。 |
| Machine Learning assisted Handover and Resource Management for Cellular Connected Drones | 蜂窝联网无人机受三维移动和 LoS 信道影响；高度升高会增加 handover 数；速度和高度共同塑造最优 H-RRM 策略。 | 支持在实验解释中把高度和速度作为影响切换策略边界的核心因素。 |
| Route-Aware Handover Enhancement for Drones in Cellular Networks | 利用预配置飞行路径信息可减少 handover、handover failure 和 ping-pong。 | 支持你当前前瞻性/路径感知算法的动机：路径信息对高机动切换有价值。 |
| 3GPP TR 38.901 | UMa/UMi 具有不同 ISD、基站高度、LoS/NLoS 和路径损耗模型；信道模型依赖 BS/UT 高度、距离和场景类型。 | 支持把 `bsPerKm2` 和 `altitude` 绑定到城市宏站/微站场景中解释。 |

## 参数耦合矩阵

| 参数 A | 参数 B | 耦合机制 | 对指标的预期影响 | 是否建议联合实验 |
|---|---|---|---|---|
| `velocity` | `TTT` | 二者共同决定航点间距、最大单步位移和采样频率。 | 速度高且 TTT 大时，容易错过及时切换，覆盖率/信号可能下降；速度高且 TTT 小时，切换更敏感，switchCount 可能上升。 | 高 |
| `velocity` | `bsPerKm2` | 高速度穿越小区更快，高密基站导致小区边界/候选基站更多。 | 高速高密通常增加切换次数；低密高速可能覆盖不足。 | 高 |
| `velocity` | `altitudeCenter` | 高度改变 LoS 和候选基站，速度决定穿越覆盖区的时间。 | 高速高空可能出现更多候选基站和更频繁切换；但适中高度可能提高覆盖稳定性。 | 中高 |
| `TTT` | `bsPerKm2` | 高密环境中短时最优基站变化更多，TTT 控制是否响应这些变化。 | 高密 + 小 TTT 容易频繁切换；高密 + 大 TTT 可降低切换但可能滞后。 | 高 |
| `TTT` | `altitudeCenter` | 高度越高，信号变化和候选基站集合更复杂；TTT 决定是否抑制短时变化。 | 适中 TTT 可能最优；过大 TTT 在高空复杂候选环境下可能降低覆盖。 | 中 |
| `bsPerKm2` | `altitudeCenter` | 基站密度决定候选数量，高度决定 LoS、3D 距离和建筑物遮挡。 | 覆盖率和信号强度通常随密度升高改善，但高空高密可能增加切换或干扰。 | 高 |
| `altitudeCenter` | `altitudeBounds` | 中心高度决定运行层，高度范围决定算法可调整空间。 | 范围过窄优化空间不足；范围过宽可能偏离预设高度或引入复杂约束。 | 中 |
| `altitudeBounds` | `bsPerKm2` | 高度可调范围改变 UAV 能否利用更优 LoS 或避开遮挡；密度影响可选基站收益。 | 高密环境下高度微调收益可能更明显；低密环境下高度调整未必能补偿覆盖不足。 | 中 |

## 最值得重点解释的三组耦合

### 1. velocity × TTT

这是代码中最直接的耦合。

```text
空间采样间隔约与 velocity × TTT 成正相关
```

因此不能只说“速度影响切换”，还应说明：

- 当 TTT 固定时，速度升高会压缩切换决策时间；
- 当速度固定时，TTT 增大会使路径离散更粗；
- 高速 + 大 TTT 是最容易出现切换滞后和覆盖断裂风险的组合；
- 高速 + 小 TTT 则可能带来更多切换和更高信令开销。

### 2. bsPerKm2 × velocity

这组决定“单位时间穿越多少个候选覆盖区”。

- `bsPerKm2` 低：候选基站少，切换次数低，但可能信号弱、覆盖不足。
- `bsPerKm2` 高：候选基站多，信号和覆盖通常更好，但切换次数更高。
- 速度越高，这种密度导致的切换增长越明显。

因此，高密基站不一定让 HV 单调变大。若 HV 同时惩罚切换次数，可能出现中高密最优、超高密反而下降。

### 3. altitude × bsPerKm2

高度改变 LoS/NLoS 和可见基站集合，密度改变候选基站数量。

- 低高度：建筑物遮挡更强，密度提升对覆盖帮助明显。
- 中高度：可能获得较好的 LoS 和较低干扰/切换折中。
- 高高度：LoS 候选增多，信号可改善，但也可能出现更多非服务基站干扰和更复杂切换。

因此，前面高度实验中的最优高度不应脱离基站密度解释。若基站密度变了，最优高度也可能变化。

## 是否需要笛卡尔积联合实验

不建议对五个参数做完整笛卡尔积。原因：

- 组合数量过大；
- 很多组合缺乏真实场景意义；
- 当前算法运行成本较高；
- 论文中难以解释高维组合结果。

更建议采用两类实验：

### A. 单因素消融继续保留

已有实验适合回答：

- 单独改变速度，指标如何变化；
- 单独改变 TTT，指标如何变化；
- 单独改变基站密度，指标如何变化；
- 单独改变高度/高度范围，指标如何变化。

这些实验用于说明敏感性。

### B. 场景组合实验

比笛卡尔积更适合论文主线。建议构造 5 个真实/典型场景：

| 场景 | bsPerKm2 | velocity | TTT | altitudeCenter | altitudeBounds | 解释 |
|---|---:|---:|---:|---:|---|---|
| 郊区/稀疏巡检 | 5 | 10 | 5 | 80 | 60-100 | 低密宏站、速度适中、高度略高以增强覆盖。 |
| 普通城区巡航 | 10 | 15 | 5 | 65 | 45-85 | 常规城市巡检/测绘。 |
| 高密城区低空巡检 | 20 | 15 | 3 | 50 | 30-70 | 建筑密集、基站较密、需要较灵活切换。 |
| 中心城区高速任务 | 30 | 20 | 3 | 80 | 60-100 | 高密基站 + 较高速 UAV，重点观察切换开销。 |
| 超高密热点/应急 | 40 | 25 | 1 | 95 | 75-115 | 低空经济重点区或应急高速场景，强调高覆盖与高切换压力。 |

这 5 组比完整组合更容易解释，也更符合“真实场景参数绑定”的论文叙事。

## 对 HV 的综合预期

若 HV 基于 `-avgSignal`、`switchCount`、`-coverageRatio` 三目标计算，则参数耦合下的趋势通常不是单调的。

| 参数变化 | 信号强度 | 切换次数 | 覆盖率 | HV 预期 |
|---|---|---|---|---|
| 速度升高 | 可能下降或波动 | 通常上升 | 可能下降 | 多数情况下下降或中速最优 |
| TTT 增大 | 可能先稳后降 | 通常下降 | 过大可能下降 | 适中 TTT 可能最优 |
| 基站密度升高 | 通常上升 | 通常上升 | 通常上升后饱和 | 中高密可能最优，超高密不一定更好 |
| 高度升高 | 可能先升后受干扰影响 | 通常更复杂，可能上升 | 可能先升后饱和 | 中等或中高高度可能最优 |
| 高度范围增大 | 优化空间增大 | 不确定 | 可能提升 | 适度范围较优，过宽未必更好 |

核心判断：

```text
HV 大概率出现在“信号/覆盖足够好，但切换次数没有爆炸”的折中区域。
```

因此，中等速度、中等 TTT、中高基站密度、中等或中高高度，往往比极端参数更可能取得较优 HV。

## 建议论文写法

建议将参数讨论分成两段：

1. 单参数依据：分别给出高度、速度、TTT、基站密度的文献/标准/城市数据来源。
2. 耦合解释：说明 UAV 蜂窝连接不是单参数问题，速度、高度、基站密度和 TTT 会共同影响 handover count、RSRP/信号强度、覆盖连续性和 HV。

可以使用如下表述：

> Since cellular-connected UAVs operate in 3D space with high mobility, the effects of velocity, altitude, base-station density, and handover decision interval are intrinsically coupled. Therefore, in addition to one-factor ablation studies, we further discuss scenario-level parameter combinations to reflect sparse macro-cell, dense urban, and hotspot/emergency deployments.

## 参考来源

- Mobility State Detection of Cellular-Connected UAVs based on Handover Count Statistics：https://arxiv.org/abs/2206.13007
- Handover Management for Drones in Future Mobile Networks：https://www.mdpi.com/1424-8220/22/17/6424
- Machine Learning assisted Handover and Resource Management for Cellular Connected Drones：https://arxiv.org/abs/2001.07937
- Route-Aware Handover Enhancement for Drones in Cellular Networks：https://eurekamag.com/research/102/712/102712848.php
- A Predictive-Reactive Learning Framework for Cellular-Connected UAV Handover in Urban Heterogeneous Networks：https://www.mdpi.com/2079-9292/15/1/109
- 3GPP TR 38.901 / ETSI TR 138 901 V19.3.0：https://www.etsi.org/deliver/etsi_tr/138900_138999/138901/19.03.00_60/tr_138901v190300p.pdf

