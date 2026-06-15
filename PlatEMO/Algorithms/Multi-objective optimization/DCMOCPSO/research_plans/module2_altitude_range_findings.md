# 模块 2：飞行高度与高度范围调研记录

调研日期：2026-06-08

## 调研目标

本模块围绕 UAVPathPlanning 中的高度相关参数开展调研：

- `altitudeCenter`：预设飞行高度中心
- `altitudeBounds`：高度上下界范围

当前实验脚本中已有设置为：

```matlab
altitudeCenterList = [35, 50, 65, 80, 95];
altitudeBoundOffset = 20;
altitudeBoundsList = [altitudeCenterList(:) - altitudeBoundOffset, ...
                      altitudeCenterList(:) + altitudeBoundOffset];
```

本模块目标是判断这些高度是否具有现实或文献依据，并为后续更正式的实验取值设计提供来源支撑。

## 初步结论

从国内监管、城市低空路径规划文献、物流配送文献和蜂窝联网 UAV 文献来看，低空无人机高度设置大致可以分为三类：

1. **监管友好的城市低空运行层**：通常应重点关注真高 120 m 以下，尤其是 20-120 m 区间。
2. **城市路径规划/风险评估高度层**：常将 20-80 m 或 20-120 m 划分为若干高度层，用于考虑建筑物、风险和航路分层。
3. **蜂窝联网 UAV 通信仿真高度**：常见高度包括 50 m、100 m、120 m、150 m、250 m、300 m 等，用于分析覆盖、干扰和 LoS/NLoS 变化。

因此，当前 `[35, 50, 65, 80, 95]` 加 `±20 m` 的设计可以覆盖 15-115 m，高度范围基本落在中国低空监管和城市低空运行的主区间内。但如果用于论文实验，需要把它解释为“城市低空 120 m 以下巡航高度层附近的细粒度对比”，而不是任意取值。

## 监管与标准依据

| 来源 | 关键内容 | 对实验高度设计的启发 |
|---|---|---|
| 《无人驾驶航空器飞行管理暂行条例》 | 真高 120 m 以上空域属于应当划设为管制空域的重要边界之一；警察、海关、应急管理部门在特定场地上方不超过真高 120 m 的训练/飞行活动有专门规定。 | 120 m 可作为城市低空轻小型无人机实验高度设计的重要上限参考。 |
| 《民用无人驾驶航空器运行安全管理规则》 | 对民用无人驾驶航空器运行安全、运行限制、风险控制、重点地区和机场净空区等提出管理要求。 | 高度不能只由路径优化决定，还应受运行限制、空域和安全能力约束。 |
| 3GPP TR 36.777 / TR 38.901 相关资料 | Aerial UE / UAV 高度用于蜂窝通信建模，常涉及从地面用户高度到 300 m 以内的空中用户高度范围。 | 蜂窝联网 UAV 仿真可考虑 120 m 以上高度，但若强调城市低空巡航和国内监管友好，宜重点放在 120 m 以下。 |

## 学术文献依据

| 来源 | 高度相关内容 | 对实验高度设计的启发 |
|---|---|---|
| 城市复杂环境下多目标无人机路径规划研究 | 文献指出城市空域内 eVTOL/UAV 运行高度不高于 120 m，并对 120 m 以下空域做高度层划分；以 20 m 为最低运行高度，划分为 20 m、40 m、60 m、80 m 等高度层。 | 支持将城市低空路径规划高度设置在 20-120 m，并用离散高度层做对比。 |
| 城市低空场景下无人机运行对地风险量化评估 | 城市低空风险与人口密度、地表遮蔽、障碍物高度、禁飞区划设和 UAV 飞行高度密切相关。 | 高度变化不仅影响通信，也影响安全风险；`altitudeBounds` 需要体现城市障碍物和风险约束。 |
| 基于低空风险场的三维航迹规划 | 城市低空环境常指 1000 m 以下空域，但建筑物、电线杆、树木、高架设施、气象扰动等使低空飞行复杂。 | 说明“低空”概念很宽，但本文若聚焦小型城市巡航，应进一步限制在更低的 20-120 m。 |
| Drone delivery problem with multi-flight level | 物流配送研究将不同飞行高度层作为决策因素，案例中使用 50 m、100 m、150 m 三个高度层；文中还提到美国 FAA 最大高度约 133 m，以及 Amazon、Wing 等配送高度实践差异。 | 支持用 50 m、100 m、150 m 等离散高度层做物流/配送场景分析；但 150 m 对国内城市低空监管可能需要说明为扩展场景。 |
| Cellular-connected UAV patrol and MEC system | 城市蜂窝联网 UAV 巡检仿真中，考虑节能和飞行规则，将 UAV 固定飞行高度设置为 100 m。 | 100 m 是蜂窝联网城市巡检仿真中较有代表性的高度中心。 |
| Aerial Coverage Analysis of Cellular Systems at LTE and mmWave Frequencies Using 3D City Models | 仿真关注 UAV 在城市中飞行至 250 m AGL 的覆盖表现，并指出不同高度会影响 LTE/mmWave 覆盖与干扰。 | 如果研究通信覆盖极限，可扩展到 250 m；但本文城市巡航场景可先聚焦 120 m 以下。 |
| Cellular Connectivity for UAVs: Network Modeling, Performance Analysis and Design Guidelines | 分析指出 UAV 在 100 m 高度时，相比地面用户可能出现覆盖和吞吐变化，说明高度显著影响蜂窝连接性能。 | 支持把 100 m 作为通信性能分析的重要参考高度。 |

## 原文引用定位表

以下位置基于 2026-06-08 调研时抓取到的原文页面/PDF 文本。网页类来源给出标题、发布日期、正文行号或章节；PDF 类来源给出 PDF 页码和抓取行号；标准类来源给出规格号、表格/章节和抓取行号。行号用于快速回查，不作为正式论文页码。

| 调研结论对应来源 | 原文位置 | 支撑点 |
|---|---|---|
| 《无人驾驶航空器飞行管理暂行条例》：120 m 监管边界 | 中国政府网《无人驾驶航空器飞行管理暂行条例》，搜索抓取摘要定位到第十九条、第三十一条；国务院公报版本同源。 | 第十九条将“真高 120 米以上空域”列为应划设为管制空域的重要边界之一；第三十一条提到警察、海关、应急管理部门特定场地上方“不超过真高 120 米”的飞行活动。支撑 120 m 作为国内城市低空监管友好边界。 |
| 《民用无人驾驶航空器运行安全管理规则》：运行安全约束 | CAAC 网页标题“民用无人驾驶航空器运行安全管理规则”，发文日期 2024-01-01，网页 L50-L68；附件 PDF P1-P2，L13-L23、L33-L47。 | 网页 L50-L68 给出主题分类、文号、规章名称和 CCAR-92；PDF P1-P2 说明规则适用于民用无人驾驶航空器运行安全管理，并将运行按场景风险分为开放类、特定类、审定类。支撑“高度设计应受运行限制和风险控制约束”。 |
| 3GPP TR 36.777：Aerial UE 标准背景 | 3GPP 规格页，Reference 36.777，Title “Enhanced LTE support for aerial vehicles”，L4-L15、L105-L115。 | 规格页明确 TR 36.777 是面向 aerial vehicles 的 LTE 支持研究，相关工作项为“Study on enhanced LTE Support for Aerial Vehicles”。支撑蜂窝联网 UAV 高度建模应参考 aerial UE 场景。 |
| 3GPP TR 38.901 / ETSI TR 138 901：城市蜂窝信道场景 | ETSI PDF《TR 138 901 V19.3.0》，P15-P16，L609-L615、L629-L632。 | P15-P16 给出 UMi、UMa、SMa 场景示例，包含基站高度、用户高度、ISD 等参数，支撑蜂窝信道模型中高度和场景强相关。 |
| 3GPP TR 38.901 / TR 36.777：Aerial UE 高度范围 | ETSI PDF P125，L9193-L9206；P113，L8279-L8282。 | P125 的 LOS condition table 引用 TR 36.777 的 UMi-AV/UMa-AV/RMa-AV，并给出 aerial UE height 到 300 m 的适用范围；P113 给出垂直平面 1.5-300 m 和固定高度 {25,50,100,200,300} m。支撑通信仿真可覆盖 120 m 以上扩展高度。 |
| 城市复杂环境下多目标无人机路径规划研究：高度层划分 | 南航学报摘要页，题名 L20，DOI L22-L24，摘要 L73-L80，引用信息 L86-L88；HTML 阅读 3.2“路径规划”段落。 | 摘要 L73-L80 说明对城市 UAV 空域进行高度层划分，并指出算例最优运行高度为 40 m；HTML 3.2 段落明确城市 120 m 以下空域划分为 20 m、40 m、60 m、80 m 等高度层。支撑 20-120 m 低空分层和 40/60/80 m 等离散高度。 |
| 城市低空场景下无人机运行对地风险量化评估：高度与风险 | 北航学报页面，题名 L72，出处 L78-L80，摘要 L193-L194，英文摘要 L204-L210。 | 摘要 L193-L194 说明风险地图结合人口密度、遮蔽效应、障碍物、禁飞区等；英文摘要 L209 明确风险程度与障碍物高度、禁飞区和 UAV flight height 相关。支撑高度不仅影响通信，也影响城市低空安全风险。 |
| 基于低空风险场的三维航迹规划：低空复杂环境 | 北京理工大学学报页面，题名 L44-L51，摘要 L71-L74。 | 摘要 L71-L74 针对城市低空复杂环境，提出三维风险场和实时航迹规划方法，并强调多层次威胁动态感知与规避。支撑城市低空飞行受到建筑物、障碍和动态风险约束。 |
| Drone delivery problem with multi-flight level：物流高度层 | ScienceDirect 页面，题名 L36-L48，Highlights L51-L61，摘要 L70-L72，Introduction L80-L85。 | L70-L72 说明将垂直空间划分为多个 flight levels；L80-L81 记录 FAA 133 m、Amazon 61-152 m、Wing 45 m 等高度背景；L84-L85 说明算例使用 50 m、100 m、150 m 三个高度层并讨论高层绕行与爬升/下降权衡。 |
| Cellular-connected UAV patrol and MEC system：100 m 城市巡检仿真 | ScienceDirect 页面，题名 L36-L48，摘要 L49-L52，Simulation settings L82-L83。 | L82-L83 明确城市环境仿真中 UAV flight altitude 固定为 100 m，单步时间 0.5 s、单步最大距离 25 m。支撑把 100 m 作为蜂窝联网城市巡检仿真高度中心。 |
| Aerial Coverage Analysis of Cellular Systems：250 m AGL 覆盖分析 | MDPI 页面标题和摘要；System Model 段落；搜索抓取摘要定位到“up to an altitude of 250 m AGL”。 | 原文说明仿真关注 BS-to-UAV downlink，UAV 飞至 250 m AGL，并指出高空 inter-cell interference 是主要限制因素。支撑通信覆盖研究可扩展到 250 m，但城市常规巡航仍可聚焦 120 m 以下。 |
| Cellular Connectivity for UAVs：100 m 高度性能变化 | arXiv 页面，题名 L31-L33，摘要 L38-L42。 | 摘要 L39-L41 指出 UAV 因高度带来的有利传播条件会因邻近地面基站同频干扰而“反噬”，并给出 100 m UAV 相比地面用户覆盖率下降的分析结果。支撑高度会显著影响蜂窝连接性能，100 m 是通信分析重要参考高度。 |

## 对 `altitudeCenter` 的启发

当前代码中：

```matlab
altitudeCenterList = [35, 50, 65, 80, 95];
```

其覆盖范围对应较低到中等城市低空高度：

- 35 m：低高度巡查，接近建筑/道路/园区低空作业，但更容易受建筑遮挡和避障约束影响。
- 50 m：城市低空巡检和物流文献中常见的低层高度。
- 65 m：中间高度层，可作为 50-80 m 之间的过渡。
- 80 m：城市路径规划文献中常见高度层附近。
- 95 m：接近 100 m，和蜂窝联网 UAV 巡检仿真中的 100 m 高度接近。

初步判断：

- 如果论文强调国内城市低空巡航，`35-95 m` 是合理的低空主区间。
- 如果希望与文献中 100 m、120 m、150 m 高度层对齐，可以考虑把中心高度调整为更容易解释的 `[40, 60, 80, 100, 120]` 或 `[50, 75, 100, 125, 150]`。
- 若严格约束在 120 m 以下，则 `altitudeCenter + upper offset` 不宜超过 120 m。

## 对 `altitudeBounds` 的启发

当前代码中：

```matlab
altitudeBoundOffset = 20;
altitudeBounds = altitudeCenter ± 20 m;
```

对应范围：

| altitudeCenter | altitudeBounds |
|---:|---:|
| 35 | 15-55 |
| 50 | 30-70 |
| 65 | 45-85 |
| 80 | 60-100 |
| 95 | 75-115 |

初步判断：

- 这个设计整体保持在 120 m 以下，符合城市低空监管友好的高度区间。
- `±20 m` 可以解释为允许优化算法在中心高度附近进行局部高度调整，而不是完全自由飞行。
- 对于低高度中心 35 m，15 m 下界可能偏低，城市建筑、树木、电线杆和安全风险更敏感；如果面向城市巡检，后续可能需要把最低下界设为 20 m 或 30 m。
- 对于 95 m 中心，115 m 上界仍低于 120 m，比较适合作为“接近监管上限但未越界”的高层对比。

## 建议后续实验高度设计方向

后续可以考虑两套设计，不急于立即改脚本。

### 方案 A：保留当前细粒度低空方案

```matlab
altitudeCenterList = [35, 50, 65, 80, 95];
altitudeBoundOffset = 20;
```

适用解释：

- 城市低空 120 m 以下巡航
- 每 15 m 一个中心高度变化
- 每组允许上下 20 m 局部优化
- 最高上界 115 m，避开 120 m 管制边界

需要补充说明：

- 最低下界 15 m 是否过低，需要结合具体城市障碍物和安全约束说明。

### 方案 B：改为文献/监管更易解释的高度层

```matlab
altitudeCenterList = [40, 60, 80, 100];
altitudeBoundOffset = 20;
```

对应范围：

```text
20-60, 40-80, 60-100, 80-120
```

适用解释：

- 与 20 m 分层思想更一致
- 完整覆盖 20-120 m
- 100 m 对齐蜂窝联网 UAV 巡检仿真常用高度
- 120 m 对齐国内监管边界

### 方案 C：扩展通信/物流高度层

```matlab
altitudeCenterList = [50, 100, 150];
```

适用解释：

- 对齐物流配送多飞行高度层文献
- 对齐通信仿真中 100 m、150 m 等高度

限制：

- 150 m 超过国内 120 m 低空监管友好边界，若采用需要明确说明为扩展仿真场景，不宜作为城市常规巡航主场景。

## 当前建议

如果本文主场景是“国内城市低空巡航 + 蜂窝联网 UAV 通信优化”，更推荐后续优先考虑：

```matlab
altitudeCenterList = [40, 60, 80, 100];
altitudeBoundOffset = 20;
```

或者保留当前：

```matlab
altitudeCenterList = [35, 50, 65, 80, 95];
altitudeBoundOffset = 20;
```

但需要在论文中解释它对应：

```text
15-115 m 的城市低空巡航可行高度范围，整体低于 120 m 监管边界。
```

## 后续需要补查的问题

- 具体城市巡检案例是否公开飞行高度，如深圳地铁、上海奉贤、北京延庆等。
- 低空航路分层是否有更正式的国内标准或地方规范。
- 多旋翼巡检任务的最低安全飞行高度是否通常高于 15 m。
- 本代码中建筑物高度最高可达 200 m，若严格模拟高层建筑城区，120 m 以下高度可能无法越过部分建筑，需说明路径绕行与避障机制。

## 已记录来源

- 中国政府网：《无人驾驶航空器飞行管理暂行条例》  
  https://www.gov.cn/zhengce/content/202306/content_6888799.htm
- 中国民用航空局：《民用无人驾驶航空器运行安全管理规则》  
  https://www.caac.gov.cn/XXGK/XXGK/MHGZ/202401/t20240103_222566.html
- 3GPP TR 36.777：Enhanced LTE Support for Aerial Vehicles  
  https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3231
- 3GPP TR 38.901 / ETSI：Channel model for frequencies from 0.5 to 100 GHz  
  https://www.etsi.org/deliver/etsi_tr/138900_138999/138901/19.03.00_60/tr_138901v190300p.pdf
- 城市复杂环境下多目标无人机路径规划研究  
  https://jnuaa.nuaa.edu.cn/njhkht/article/html/202406003
- 城市低空场景下无人机运行对地风险量化评估  
  https://bhxb.buaa.edu.cn/bhzk/article/doi/10.13700/j.bh.1001-5965.2024.0244
- 基于低空风险场的三维航迹规划  
  https://journal.bit.edu.cn/zr/cn/article/id/6d059ae8-17a7-4de9-8fed-cd79b89ab5e5
- Drone delivery problem with multi-flight level: Machine learning based solution approach  
  https://www.sciencedirect.com/science/article/pii/S0360835224006867
- Trajectory design of cellular-connected UAV patrol and mobile edge computing system  
  https://www.sciencedirect.com/science/article/pii/S1389128625003512
- Aerial Coverage Analysis of Cellular Systems at LTE and mmWave Frequencies Using 3D City Models  
  https://pmc.ncbi.nlm.nih.gov/articles/PMC6308414/
- Cellular Connectivity for UAVs: Network Modeling, Performance Analysis and Design Guidelines  
  https://arxiv.org/abs/1804.08121
