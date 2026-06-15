# 模块 4：TTT Time-To-Trigger 调研记录

调研日期：2026-06-08

## 调研目标

本模块围绕 UAVPathPlanning 中的 `TTT` 展开调研。这里需要特别区分两个层面的含义：

1. 通信标准中的 `Time-To-Trigger`：LTE/NR RRC 测量事件需要持续满足一定时间后，才触发测量报告或切换流程。
2. 当前代码中的 `TTT`：以秒为单位的航点时间间隔，同时影响航点数量、单步最大移动距离、当前速度估计和 A3 持续确认建模。

因此，后续论文中不宜直接把当前 `TTTList = [1, 3, 5, 7, 9]` 解释为 3GPP 原始标准枚举值；更准确的说法是：本实验研究 UAV 路径规划模型中“采样/切换决策时间间隔”的影响，并参考 Time-To-Trigger 的机制思想。

## 当前代码中的 TTT

`UAVPathPlanning.m` 中对 `TTT` 的说明和使用包括：

```matlab
% TTT --- 1 --- 时间间隔（s）
% 无人机速度自动计算：numWaypoints = pathLength / (velocity * 0.8 * TTT)

actualVelocity = obj.velocity * 0.5;
distancePerWaypoint = actualVelocity * obj.TTT;
obj.numWaypoints = max(2, ceil(obj.pathLength / distancePerWaypoint));

maxDistance = obj.velocity * obj.TTT;
currentSpeed = distPrev / obj.TTT;
```

A3 分支中还有如下建模假设：

```matlab
% 当前模型每个航点间隔已经等于TTT，因此A3持续确认对应一个采样步。
a3TttRequiredSteps = 1;
```

当前 TTT 与基站密度实验脚本中设置为：

```matlab
TTTList = [1, 3, 5, 7, 9];
baseProblemParameter = {20, 20, 5, -101.5, 0, 30, 2, 500, 10, 4};
```

这说明当前代码中的 `TTT` 不是纯粹的 RRC 参数，而是一个更粗粒度的路径离散时间间隔。它会影响：

- 航点数量：TTT 越大，同一路径下航点越少；
- 单步可移动距离：TTT 越大，`velocity * TTT` 越大；
- 前瞻性算法里的当前速度估计：`currentSpeed = distPrev / TTT`；
- 切换统计：采样点变少后，可能漏掉一些短时切换机会；
- HV：通过平均信号强度、切换次数、覆盖率等指标间接变化。

## 3GPP 标准中的 TTT 取值

LTE TS 36.331 和 5G NR TS 38.331 中，`TimeToTrigger` 是 RRC 测量事件的标准信息元素。其典型枚举值为：

```text
0, 40, 64, 80, 100, 128, 160, 256,
320, 480, 512, 640, 1024, 1280, 2560, 5120 ms
```

标准含义是：事件条件需要在 TTT 时间窗口内持续满足，才触发测量报告。以 A3 事件为例，可理解为“邻区优于服务小区达到偏置/迟滞条件后，还需要持续满足一段时间”。

这类毫秒级 TTT 的作用是平衡：

- TTT 太小：更敏感，更容易快速切换，但容易受瞬时衰落影响，增加 ping-pong 切换和信令开销；
- TTT 太大：更保守，可减少不必要切换，但可能导致切换过晚，增加 HOF/RLF 或覆盖中断风险；
- 高速 UAV 场景：速度越高，短时间内跨越的小区/覆盖碎片越多，因此 TTT 与速度、测量周期、基站密度必须共同考虑。

## UAV 蜂窝切换文献中的 TTT 设置

| 来源 | TTT 相关设置 | 对实验设计的启发 |
|---|---|---|
| Mobility Management for Cellular-Connected UAVs: A Learning-Based Approach | 仿真参数中使用 TTT = 160 ms、HOM = 3 dB，UAV 速度为 120 km/h。 | 160 ms 是蜂窝联网 UAV handover 文献中比较典型的 A3/基线切换参数。 |
| Mobility State Detection of Cellular-Connected UAVs based on Handover Count Statistics | 分析 handover count 与 UAV 高度、速度、GBS 密度、测量窗口、measurement gap 和 TTT 的关系；文中比较了 `tTTT = 0 ms` 与 `tTTT = 160 ms` 等情况。 | 支持把 TTT 作为影响切换次数和移动状态识别的重要变量；高 TTT 可能让 UAV 跳过一些短覆盖区，导致切换次数下降。 |
| DIHAT: Differential Integrator Handover Algorithm with TTT window for LTE-based systems | 说明 LTE hard handover 由 handover margin 和 TTT 共同决定；TTT window 用于减少 ping-pong，但过度保守会带来实时业务延迟。 | 支持在论文中解释 TTT 的经典权衡：小 TTT 更敏感，大 TTT 更稳定但可能更迟缓。 |
| Handover Management for Drones in Future Mobile Networks: A Survey | 综述指出蜂窝联网无人机面临高切换率、ping-pong、RLF/HOF 等问题，速度、三维移动和网络参数配置都会影响 handover。 | 支持把 UAV 场景下的 TTT 消融和切换稳定性、覆盖连续性联系起来。 |

## 原文引用定位表

以下位置基于 2026-06-08 调研时抓取到的原文页面/PDF 文本。网页类来源给出标题、章节和正文行号；PDF 类来源给出 PDF 页码和抓取行号；标准类来源给出规格号、信息元素和抓取行号。行号用于快速回查，不作为正式论文页码。

| 调研结论对应来源 | 原文位置 | 支撑点 |
|---|---|---|
| 本代码中的 TTT 含义 | `UAVPathPlanning.m`：文件头注释 L7、L19、L24；计算逻辑 L377-L379、L510、L640、L899、L997；`example_ablation_UAVPathPlanning_TTT_bsDensity_FullParam.m`：L21-L24、L40-L49。 | 代码注释将 TTT 作为“时间间隔（s）”；航点数量由 `velocity * 0.8 * TTT` 相关公式决定；最大位移使用 `velocity * TTT`；A3 分支说明每个航点间隔等于 TTT，因此一次采样步对应持续确认；实验脚本设置 `TTTList = [1,3,5,7,9]`。支撑“当前 TTT 是秒级路径采样/切换决策间隔，而非纯 RRC TTT”。 |
| 3GPP TS 36.331 / ETSI TS 136 331：LTE TimeToTrigger 枚举 | ETSI TS 136 331 V16.14.0，P733，L34874-L34883；3GPP 规格页 TS 36.331，L4-L14。 | P733 定义 TimeToTrigger IE，说明它表示事件条件需要持续满足的时间，并给出 `ms0, ms40, ms64, ..., ms5120` 枚举；3GPP 规格页确认 36.331 是 E-UTRA RRC 协议规范。支撑 LTE RRC 中 TTT 是毫秒级标准枚举。 |
| 3GPP TS 38.331 / ETSI TS 138 331：NR TimeToTrigger 枚举 | ETSI TS 138 331 V17.2.0，P892-P893，L19189-L19195；3GPP 规格页 TS 38.331。 | P892-P893 定义 NR RRC 的 TimeToTrigger IE，说明 `ms0` 对应 0 ms、`ms40` 对应 40 ms，并列出到 `ms5120` 的枚举。支撑 5G NR 中同样使用毫秒级 TTT 枚举。 |
| Mobility Management for Cellular-Connected UAVs：TTT/HOM 和 A3 机制 | arXiv PDF《Mobility Management for Cellular-Connected UAVs: A Learning-Based Approach》，P2，L276-L288；P3，L444-L450。 | P2 L276-L288 说明 handover procedure 涉及 HOM 和 TTT，TTT 是 A3 条件满足后启动的时间窗口，测量报告在 TTT 过期前不发送；P3 L444-L450 描述候选小区在 TTT 结束时仍满足 HOM 条件才发生切换。支撑 TTT 的“持续确认”机制解释。 |
| Mobility Management for Cellular-Connected UAVs：160 ms 基线参数 | 同一 PDF，Table I，P4，L468-L476；仿真说明 P4，L479-L483。 | Table I 给出 `v = 120 km/h`、`TTT, HOM = 160 ms, 3 dB`；仿真说明中 UAV 速度为 120 km/h。支撑 160 ms 是蜂窝联网 UAV handover 文献中可对齐的基线 TTT。 |
| Mobility State Detection of Cellular-Connected UAVs：TTT 与 HOC/速度估计 | arXiv 页面摘要 L37-L41；PDF Table II，P5，L584-L596；公式解释 P5，L618-L622。 | 摘要说明 HOC 是 UAV 高度、速度、测量窗口和 GBS 密度的函数，并讨论低 TTT；Table II 比较 `tTTT = 0, 40, 160 ms`；P5 L618-L622 说明相关参数依赖 measurement gap、TTT、UAV 高度和天线配置。支撑 TTT 与 handover count、速度估计和基站密度存在耦合。 |
| Mobility State Detection of Cellular-Connected UAVs：高 TTT 减少 HOC | 同一 PDF，P5-P6，L669-L680；P9-P10，L1210-L1226、L1244-L1247。 | L669-L675 说明较高 TTT 会让 UAV 跳过一些 handover triggering events，因此 HOC 更少；Fig. 10/11 比较不同 TTT 对速度估计误差和估计器的影响。支撑“TTT 增大会降低切换次数但可能跳过短时切换机会”。 |
| DIHAT：LTE hard handover 由 HOM 与 TTT 决定 | Springer 页面标题和摘要 L21-L30、L58-L61；Introduction L107-L115；LTE hard handover algorithm L157-L163。 | 摘要说明 hard handover 由 handover margin 和 TTT 决定，TTT 目的之一是减少 ping-pong；L157-L163 说明 LTE standard hard handover 使用 HOM 和 TTT，TTT timer 用于减少 unnecessary handovers，并要求条件在整个 TTT window 内满足。 |
| DIHAT：TTT 的权衡 | Springer 页面 L114-L118、L182-L190。 | L114-L115 说明 TTT window 可减少 ping-pong，但会使 handover 决策不够快；L188-L190 说明 DIHAT 在 TTT window 内持续满足条件才切换，若变化率过大可提前切换以支持实时业务。支撑“小 TTT 敏感、大 TTT 稳定但可能迟缓”的权衡。 |
| Handover Management for Drones in Future Mobile Networks：无人机切换挑战 | MDPI/Sensors 页面，Abstract 与 Introduction，搜索抓取摘要；4.2 Handover Decision Algorithms；5 Handover Challenges；7.2 Mobility Management。 | 原文指出 connected drones 会因高空传播、天线旁瓣、高速移动、覆盖区有限等因素出现 frequent handovers、ping-pong、RLF/HOF 等问题；4.2 讨论 handover decision algorithms，5 和 7.2 将高速、三维移动和网络参数配置与 handover 概率、ping-pong、RLF 联系起来。支撑 UAV 场景下 TTT 应和速度、三维移动、基站密度共同解释。 |

## 对当前 TTTList 的解释

当前实验：

```matlab
TTTList = [1, 3, 5, 7, 9];
```

建议解释为：

1. `1 s`：高频采样/快速决策，接近最敏感切换；可捕捉更多短时信号变化，但可能切换更多。
2. `3 s`：较短决策间隔，仍然较灵活，但比 1 s 更保守。
3. `5 s`：当前 baseProblemParameter 的默认实验值，可作为中间基准。
4. `7 s`：较长决策间隔，可能降低切换次数，但更容易错过短覆盖区。
5. `9 s`：强保守/粗采样场景，适合观察过大间隔对覆盖率和信号质量的负面影响。

更严谨的表述是：

> 本文中的 TTT 以秒为单位，表示路径离散和切换决策的采样时间间隔；它借鉴 3GPP Time-To-Trigger 的持续确认思想，但并不直接等同于 RRC 层毫秒级 TTT 枚举。

## 如果要做标准对齐实验

如果后续想做一组更贴近 3GPP 标准的 TTT 消融，可以考虑新增一个毫秒级实验，而不是替换当前秒级实验。例如：

```matlab
TTTList = [0.04, 0.16, 0.32, 0.64, 1.28];  % seconds
```

对应：

```text
40 ms, 160 ms, 320 ms, 640 ms, 1280 ms
```

这组值的优点是能直接和 LTE/NR 标准枚举对应，尤其 `160 ms` 可和蜂窝联网 UAV handover 文献中的常用基线对齐。缺点是：在当前代码里 TTT 还控制航点数量，毫秒级 TTT 会显著增加航点数，可能导致维度变大、运行时间大幅增加。因此是否采用这组值，需要结合算法运行成本重新评估。

## 对指标变化的预期

在当前代码建模下，随着 `TTT` 从 1 s 增加到 9 s，可能出现以下趋势：

- 平均切换次数：大概率下降。采样更粗，持续确认更保守，短时切换机会被跳过。
- 平均信号强度：可能先稳定或小幅提升，随后下降。适度 TTT 可避免劣质短时切换，但过大 TTT 可能滞后，导致停留在弱服务基站。
- 覆盖率：可能呈现中间较优。过小 TTT 容易频繁切换但未必降低覆盖；过大 TTT 则可能错过及时切换，覆盖率下降。
- HV：不一定单调。若 HV 同时偏好高信号、低切换和高覆盖，则通常会出现适中 TTT 较优，过小或过大都不理想。

因此，当前 `[1, 3, 5, 7, 9]` 更适合用来验证“时间间隔过小/过大都可能不优，存在折中值”的结论。

## 建议论文写法

建议在论文中把该参数命名或解释为：

- `TTT / sampling interval`
- `handover decision interval`
- `time interval inspired by Time-To-Trigger`

如果直接写 `3GPP TTT`，需要额外说明单位差异和模型抽象，否则审稿人可能会质疑为什么使用 1-9 秒而不是标准毫秒级枚举。

## 参考来源

- 3GPP TS 36.331 官方规格页：https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=2440
- ETSI TS 136 331 V16.14.0：https://www.etsi.org/deliver/etsi_ts/136300_136399/136331/16.14.00_60/ts_136331v161400p.pdf
- 3GPP TS 38.331 官方规格页：https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3197
- ETSI TS 138 331 V17.2.0：https://www.etsi.org/deliver/etsi_ts/138300_138399/138331/17.02.00_60/ts_138331v170200p.pdf
- Mobility Management for Cellular-Connected UAVs: A Learning-Based Approach：https://arxiv.org/abs/2002.01546
- Mobility State Detection of Cellular-Connected UAVs based on Handover Count Statistics：https://arxiv.org/abs/2206.13007
- DIHAT: Differential Integrator Handover Algorithm with TTT window for LTE-based systems：https://link.springer.com/article/10.1186/1687-1499-2014-162
- Handover Management for Drones in Future Mobile Networks：https://www.mdpi.com/1424-8220/22/17/6424
