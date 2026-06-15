# 模块 3：无人机速度 velocity 调研记录

调研日期：2026-06-08

## 调研目标

本模块围绕 UAVPathPlanning 中的场景/运动变量 `velocity` 展开调研，目标是给后续实验中的速度取值提供文献、产品规格和通信仿真依据。

当前代码中与速度相关的默认值和实验设置为：

```matlab
% UAVPathPlanning.m
% velocity --- 10 --- 无人机最大速度（m/s）
% TTT --- 1 --- 时间间隔（s）

actualVelocity = obj.velocity * 0.5;
distancePerWaypoint = actualVelocity * obj.TTT;
obj.numWaypoints = max(2, ceil(obj.pathLength / distancePerWaypoint));

maxDistance = obj.velocity * obj.TTT;
```

```matlab
% example_ablation_UAVPathPlanning_velocity_FullParam.m
velocityList = [10, 15, 20, 25, 30];
```

也就是说，代码里的 `velocity` 既影响单步最大移动距离，也通过 `actualVelocity = velocity * 0.5` 影响航点数量。速度越大，在同一路径长度和 TTT 下航点数通常越少，单步可移动距离越大，切换触发和覆盖评价也会受到影响。

## 初步结论

从已有资料看，`velocityList = [10, 15, 20, 25, 30]` 可以保留，但需要在论文中解释为覆盖不同场景强度的速度梯度：

| 速度 | 解释定位 | 依据 |
|---:|---|---|
| 10 m/s | 城市巡检、低速巡航、保守运行速度 | 接近多旋翼巡检和配送论文中常用低中速；当前代码默认值也是 10 m/s。 |
| 15 m/s | 常规高效率巡检/测绘速度 | DJI Mavic 3 Enterprise 官方页面给出普通模式 15 m/s，且商业任务页面示例使用 15 m/s 测绘速度。 |
| 20 m/s | 较高速物流/应急/行业作业 | 接近部分物流无人机和行业无人机的高效运行速度，也接近小型行业多旋翼的运动上界。 |
| 25 m/s | 高速任务或通信压力测试下界 | 略高于常见多旋翼官方水平最大速度 21-23 m/s，可作为高机动场景扩展值。 |
| 30 m/s | 蜂窝联网 UAV 高机动/切换压力测试 | 约等于 108 km/h，接近蜂窝联网 UAV handover 论文中 100-120 km/h 的高移动速度设定。 |

如果论文更强调“城市多旋翼巡检”，建议主实验速度范围偏保守，例如 `[5, 10, 15, 20]` 或 `[8, 10, 12, 15, 20]`。如果论文强调“蜂窝联网 UAV 切换鲁棒性”，当前 `[10, 15, 20, 25, 30]` 更合适，因为它能覆盖从常规巡检到高机动切换压力测试的变化趋势。

## 官方产品规格依据

| 来源 | 速度信息 | 对实验取值的启发 |
|---|---|---|
| DJI Matrice 350 RTK 官方规格 | 最大水平速度为 23 m/s；官方续航测试说明中也出现约 8 m/s 的飞行速度条件。 | 说明工业级多旋翼的物理上限可接近 23 m/s，实验中的 20 m/s 有现实依据，25 m/s 已属于略高于常见多旋翼上限的扩展值。 |
| DJI Mavic 3 Enterprise 官方规格 | 普通模式最大 15 m/s，运动模式前飞 21 m/s；感知系统有效速度也常在 12-15 m/s 附近。 | 支持把 15 m/s 作为常规高效率巡检/测绘速度，把 20 m/s 作为接近运动模式上界的高速组。 |
| DJI Mavic 3 Enterprise 商业任务页面 | 在 GSD 5 cm、前向重叠率 80%、旁向重叠率 60% 的测绘任务示例中使用 15 m/s。 | 支持 15 m/s 作为行业测绘/巡检类任务中的代表速度，而不是单纯的机械最大速度。 |

## 学术论文与仿真依据

| 来源 | 速度信息 | 对实验取值的启发 |
|---|---|---|
| Drone flight data reveal energy and greenhouse gas emissions savings for very small package delivery | 实测小型四旋翼配送飞行覆盖 4、6、8、10、12 m/s；文中以 12 m/s 作为最快测试巡航速度，并在 100 m 巡航高度下分析配送能耗。 | 支持 10-12 m/s 作为小型多旋翼配送/巡航的常用运行速度区间。 |
| Design and Control of an Ultra-Low-Cost Logistic Delivery Fixed-Wing UAV | 物流投递测试中速度限制在 11-12 m/s。 | 支持配送类任务中 10-12 m/s 的保守速度设置。 |
| An Improved Reinforcement Learning-Based 6G UAV Communication for Smart Cities | 智慧城市、智慧农业和搜救场景中 UAV 飞行速度设置约 12 m/s。 | 支持 10-15 m/s 作为城市/搜救/巡航通信仿真的低中速区间。 |
| A Predictive-Reactive Learning Framework for Cellular-Connected UAV Handover in Urban Heterogeneous Networks | 蜂窝联网 UAV handover 仿真使用 100 km/h 和 120 km/h 两个速度场景，约等于 27.78 m/s 和 33.33 m/s。 | 支持把 30 m/s 作为高机动蜂窝切换压力测试速度。 |
| Mobility Management for Cellular-Connected UAVs | 论文示例中使用线性 UAV 移动模型，并给出 `v = 120 km/h` 的示例。 | 支持在通信切换研究中引入 30 m/s 附近的高速度组。 |
| Mobility State Detection of Cellular-Connected UAVs Based on Handover Count Statistics | 研究 handover count 与 UAV 高度、速度、测量窗口和地面基站密度之间的关系。 | 支持把 `velocity` 视为影响平均切换次数和移动状态识别的重要变量。 |

## 原文引用定位表

以下位置基于 2026-06-08 调研时抓取到的原文页面/PDF 文本。网页类来源给出标题、规格项、正文行号或搜索抓取摘要；PDF 类来源给出 PDF 页码和抓取行号；论文类来源给出题名、章节/摘要位置。行号用于快速回查，不作为正式论文页码。

| 调研结论对应来源 | 原文位置 | 支撑点 |
|---|---|---|
| DJI Matrice 350 RTK 官方规格：23 m/s 上界 | DJI Enterprise 页面“Matrice 350 RTK - Specs”，Aircraft 规格，L295-L297；续航测试说明 L310-L313。 | L295-L297 给出 Max Horizontal Speed = 23 m/s；L310-L313 说明最大飞行时间测试中以约 8 m/s 飞行。支撑工业多旋翼物理上限可接近 23 m/s，同时实际续航测试速度可明显低于最大速度。 |
| DJI Mavic 3 Enterprise 官方规格：15/21 m/s | DJI Enterprise 页面“Specs - DJI Mavic 3 Enterprise”，Aircraft 规格，L57-L60；感知系统 L378-L394。 | L57-L60 给出 Normal Mode 15 m/s、Sport Mode forward 21 m/s；L382 和 L393 给出前向/侧向有效感知速度不超过 15 m/s。支撑 15 m/s 作为常规高效作业速度，20 m/s 接近运动模式高速上界。 |
| DJI Mavic 3 Enterprise 商业任务页面：15 m/s 测绘示例 | DJI Mavic 3 Enterprise 产品页搜索抓取摘要，章节“Survey with Speed”；脚注 5。 | 原文脚注 5 写明在 GSD 5 cm、前向重叠率 80%、旁向重叠率 60% 条件下，flight speed 为 15 m/s。支撑 15 m/s 可作为行业测绘/巡检任务代表速度。 |
| Drone flight data reveal energy and greenhouse gas emissions savings for very small package delivery：4-12 m/s | PMC 页面搜索抓取摘要；Introduction 段；Estimation of drone range 段。 | 原文说明测试样本覆盖 25-100 m 高度和 4-12 m/s 地速；range 示例使用 `Vcr = 12 m/s`、payload 500 g、h = 100 m。支撑 10-12 m/s 作为小型四旋翼配送/巡航常用低中速。 |
| Design and Control of an Ultra-Low-Cost Logistic Delivery Fixed-Wing UAV：11-12 m/s | MDPI 页面搜索抓取摘要；2.4.3 Wing Aerodynamics / throwing test 段；Figure 28 附近。 | 原文说明投送试验中 throwing height 限制为 8-12 m，speed 限制为 11-12 m/s；并在 10 m 投送高度、12 m/s 投送速度下满足误差要求。支撑配送类任务中 10-12 m/s 的保守速度设置。 |
| An Improved Reinforcement Learning-Based 6G UAV Communication for Smart Cities：约 12 m/s | TechScience 页面“An Improved Reinforcement Learning-Based 6G UAV Communication for Smart Cities”，4.1 Simulation Parameters，L252-L255。 | L252-L255 说明仿真使用 DRONET，UAV 数量 20-70、区域 1800 × 1800 m²，并假设智慧农业/智慧城市搜救场景中 UAV flight speed 约 12 m/s。支撑 10-15 m/s 作为城市/搜救/巡航通信仿真的低中速区间。 |
| A Predictive-Reactive Learning Framework for Cellular-Connected UAV Handover：100/120 km/h | MDPI/Electronics 页面搜索抓取摘要，3 System Layout、4 System Model and Methodology、5 Simulation Results；ResearchGate PDF 摘要表。 | 原文说明 UAV 在 10 km × 10 km 异构 LTE/5G 网络中沿正弦轨迹飞行，速度设置为 100 km/h 和 120 km/h；ResearchGate 抓取表明确换算为 27.78 m/s 和 33.33 m/s。支撑把 30 m/s 作为高机动蜂窝切换压力测试速度。 |
| Mobility Management for Cellular-Connected UAVs：120 km/h 示例 | NSF PDF《Mobility Management for Cellular-Connected UAVs: A Learning-Based Approach》，P1-P2，L176-L184。 | L176-L184 描述 UAV 线性移动模型，并给出 `v = 120 km/h`、4 × 4 km² 区域、M = 48 的示例。支撑通信切换研究中可引入 30 m/s 附近的高速移动组。 |
| Mobility Management for Cellular-Connected UAVs：速度与切换机制 | 同一 PDF，P0-P2，L55-L67、L276-L288。 | L55-L67 说明 UAV 移动会带来 HOF、RLF、ping-pong 等移动性问题；L276-L288 说明 handover procedure 中包含 HOM 和 TTT，并基于 A3 条件触发。支撑速度变化需要和切换稳定性一起讨论。 |
| Mobility State Detection of Cellular-Connected UAVs Based on Handover Count Statistics：速度、HOC、基站密度耦合 | arXiv 页面，题名 L31-L33，摘要 L37-L41。 | L37-L41 说明 3GPP LTE 用预定义时间内的 handover 数估计速度和移动状态，并将 HOC 建模为 UAV height、velocity、测量窗口和 GBS density 的函数。支撑 `velocity` 是影响切换次数和移动状态识别的重要变量。 |

## 对当前 velocityList 的解释

当前实验：

```matlab
velocityList = [10, 15, 20, 25, 30];
```

建议解释为：

1. `10 m/s`：保守城市巡检速度，接近代码默认值，也符合小型配送/巡航实验中的低中速。
2. `15 m/s`：行业巡检/测绘中较常见的高效率速度，DJI Mavic 3 Enterprise 普通模式上界和测绘任务示例均支持该量级。
3. `20 m/s`：接近小型行业多旋翼运动模式速度上界，也可代表应急、较高速物流或快速巡航。
4. `25 m/s`：略高于常见多旋翼产品规格上限，用于观察算法在更高机动性下的退化或鲁棒性。
5. `30 m/s`：约 108 km/h，对齐蜂窝联网 UAV handover 论文中的 100-120 km/h 高速场景。

## 对实验设计的建议

### 方案 A：保留当前速度组

```matlab
velocityList = [10, 15, 20, 25, 30];
```

适合论文强调：

- 蜂窝联网 UAV 切换鲁棒性；
- 速度升高对切换次数、信号强度、覆盖率和 HV 的综合影响；
- 从常规巡检到高机动通信压力测试的一体化评估。

这是当前最建议保留的方案。

### 方案 B：城市巡检保守速度组

```matlab
velocityList = [5, 10, 15, 20];
```

适合论文强调：

- 城市治理、园区巡检、道路巡查；
- 更贴近多旋翼常规运行速度；
- 避免 25-30 m/s 被审稿人认为超过多数多旋翼巡检任务的常规速度。

### 方案 C：配送/巡检细粒度速度组

```matlab
velocityList = [8, 10, 12, 15, 20];
```

适合论文强调：

- 小型多旋翼配送；
- 10-12 m/s 附近的能耗和通信性能变化；
- 更细致观察中低速区间。

## 与后续模块的关系

速度不是孤立变量，需要和 TTT、基站密度、高度共同解释：

- 速度越高，相同 TTT 下每个采样步对应的空间距离越大，可能更容易错过最佳切换点。
- 速度越高，单位时间穿越小区边界的概率越高，平均切换次数通常会上升。
- 基站密度越高，速度对切换次数的放大效应越明显。
- 高度越高，LoS 链路更多，候选基站更多，速度变化对切换稳定性的影响可能更复杂。

## 参考来源

- DJI Matrice 350 RTK 官方规格：https://enterprise.dji.com/zh-tw/matrice-350-rtk/specs
- DJI Mavic 3 Enterprise 官方规格：https://enterprise.dji.com/fr/mobile/mavic-3-enterprise/specs
- DJI Mavic 3 Enterprise 商业任务页面：https://enterprise.dji.com/es/mavic-3-enterprise
- Drone flight data reveal energy and greenhouse gas emissions savings for very small package delivery：https://pmc.ncbi.nlm.nih.gov/articles/PMC9403403/
- Design and Control of an Ultra-Low-Cost Logistic Delivery Fixed-Wing UAV：https://www.mdpi.com/2076-3417/14/11/4358
- An Improved Reinforcement Learning-Based 6G UAV Communication for Smart Cities：https://www.techscience.com/cmc/v86n1/64490/html
- A Predictive-Reactive Learning Framework for Cellular-Connected UAV Handover in Urban Heterogeneous Networks：https://www.mdpi.com/2079-9292/15/1/109
- Mobility Management for Cellular-Connected UAVs：https://par.nsf.gov/servlets/purl/10199026
- Mobility State Detection of Cellular-Connected UAVs Based on Handover Count Statistics：https://www.researchgate.net/publication/372437138_Mobility_State_Detection_of_Cellular-Connected_UAVs_Based_on_Handover_Count_Statistics
