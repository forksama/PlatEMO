# 绘图规范

本文档记录后续从项目实验结果生成论文、专利交底书或汇报图片时需要遵循的固定规则。

## 数据顺序

若原始结果数据中的顺序与以下规则冲突，则忽略原始顺序，按以下规则重新排列。

### 不同算法对比

不同算法对比图中，横轴或图例顺序应为：

1. 其他对比算法。
2. baseline 算法紧接在其他对比算法之后。
3. 本项目提出的优化算法放在最右侧或最后。

例如，若对比算法包含 `DGEA`、`IMMOEAD`、`Base-MOCPSO` 和 `DCMOCPSO`，则推荐顺序为：

`IMMOEAD`、`DGEA`、`Base-MOCPSO`、`DCMOCPSO`

其中 `Base-MOCPSO` 是 baseline，`DCMOCPSO` 是本项目优化算法。

### 消融实验

消融实验图中，横轴或图例顺序应从左到右体现优化模块逐步增加：

1. baseline 放在最左侧。
2. 越往右，加入的优化模块越多。
3. 完整方法放在最右侧。

例如：

`OneSeg_Lookahead`、`Seg_Lookahead`、`Full_Lookahead`

其中 `OneSeg_Lookahead` 是 baseline，`Seg_Lookahead` 增加分段求解，`Full_Lookahead` 增加完整 DCMOCPSO 增强机制。

## 误差线

后续绘图不再绘制误差线。

若结果文件中包含标准差、方差、置信区间或其他误差数据，绘图时直接忽略。图中只展示主要均值或最终指标值。

## 指标出图范围

不同类型实验需要绘制的指标图不同，后续绘图时按实验目标区分：

1. 多目标优化算法相关实验：需要绘制 `HV` 和 `runtime` 两类图。
2. 切换算法相关实验：需要绘制全部关键指标图，包括 `HV`、`runtime`、切换次数、覆盖率、信号强度。
3. 环境参数相关实验：需要绘制全部关键指标图，包括 `HV`、`runtime`、切换次数、覆盖率、信号强度。

其中切换次数在图中优先写作 `Mean Handover Count`，覆盖率写作 `Path Coverage Ratio`，信号强度写作 `Mean Signal Strength (dBm)`。

## 图类型选择

不同实验不必强行统一为同一种图。优先根据“核心比较对象”选择图类型，而不是只看横轴是否是数值：

1. 若核心比较对象是不同算法、切换方法、消融阶段或离散配置档位，优先使用柱状图或分组柱状图。
2. 若核心比较对象是连续物理参数或控制参数的敏感性趋势，优先使用折线图。
3. 若实验同时包含预算/参数维度和方法维度，但主要目的是比较方法优劣，优先使用分组柱状图。
4. 若指标为 `Mean Signal Strength (dBm)` 这类负值量，纯分类对比中可使用点图，避免从 0 开始的柱状图造成视觉误读。

在本项目现有实验中，推荐如下：

- `compare_vs_baselines`、`compare_vs_mocpso_ek`、`switch_method_oneseg`：核心是方法比较，使用分组柱状图。
- `uniform_point_multiplier`、`num_segments_full_param`：核心是离散配置档位比较，使用柱状图或分组柱状图。
- `lambda_cguide`、`lookahead_distance`、`lookahead_margins`、`velocity`、`TTT`、`bs_density`、`altitude_layers`：核心是参数敏感性趋势，使用折线图。
- `lookahead_only_oneseg`：纯分类方法对比，正值指标使用柱状图，信号强度使用点图。

## 标题与标签

图片标题、子图标题、坐标轴标签和图例不必机械使用原始字段名。

若原始字段名或脚本标题不能准确描述数据内容，应根据实际指标含义自行修改，使标题准确、简洁、适合论文或专利交底书使用。

例如：

- `meanSignal` 可写作 `Mean Signal Strength (dBm)`。
- `meanSwitchCount` 可写作 `Mean Handover Count` 或 `Mean Switch Count`，根据全文术语统一选择。
- `meanCoverageRatio` 可写作 `Path Coverage Ratio`。
- `HV` 可写作 `HV Metric` 或 `Hypervolume (HV)`。

## 算法名称映射

结果文件或实验脚本中的算法名称未必适合直接出现在论文、专利交底书或汇报图中。绘图时应优先使用以下展示名称。

### 算法对比

| 原始名称 | 展示名称 |
| --- | --- |
| `Base-MOCPSO` | `MOCPSO` |
| `DCMOCPSO` | `DCMOCPSO` |
| `IMMOEAD` | `IMMOEAD` |
| `DGEA` | `DGEA` |

不同算法对比推荐展示顺序：

`IMMOEAD`、`DGEA`、`MOCPSO`、`DCMOCPSO`

### 分阶段消融

| 原始名称 | 展示名称 |
| --- | --- |
| `OneSeg_Lookahead` | `MOCPSO` |
| `Seg_Lookahead` | `Segmented MOCPSO` |
| `Full_Lookahead` | `DCMOCPSO` |

这类图的标题或图注中说明实验条件使用了上下文感知前瞻性切换即可，不建议把 `Lookahead` 写进每个横轴标签。

推荐标题示例：

`Ablation under Context-Aware Lookahead Handover`

### 切换方法消融

| 原始名称 | 展示名称 |
| --- | --- |
| `OneSeg` | `CASH` |
| `OneSeg_A3` | `A3 Handover` |
| `OneSeg_Lookahead` | `Lookahead Handover` |

切换方法对比的展示顺序为 `A3 Handover`、`CASH`、`Lookahead Handover`。

这类图的标题或图注中说明优化器固定为 MOCPSO 即可，不建议把 `OneSeg` 写进横轴标签。

## 参数实验名称映射

参数敏感性实验中，图上不建议直接使用脚本生成的内部 group name。优先把横轴设置为参数数值，并把参数含义写入坐标轴标题。

| 原始名称形态 | 推荐展示方式 |
| --- | --- |
| `lambda_0p5` | 横轴值 `0.5`，坐标轴写 `E_k Reward Weight λ` |
| `cGuide_0p3` | 横轴值 `0.3`，坐标轴写 `Guide Weight c_guide` |
| `lookahead_500m` | 横轴值 `500`，坐标轴写 `Lookahead Distance (m)` |
| `hyst_10dB` | 横轴值 `10`，坐标轴写 `Dynamic Hysteresis Range (dB)` |
| `safety_4dB` | 横轴值 `4`，坐标轴写 `Safety Margin (dB)` |
| `UPx3` | 横轴值 `3x` 或 `3`，坐标轴写 `Reference Vector Multiplier` |
| `v20` | 原始值表示最大速度 `20`，绘图横轴使用平均速度 `10`，坐标轴写 `Average Speed (m/s)` |
| `ttt_5s` | 横轴值 `5`，坐标轴写 `TTT (s)` |
| `ttt_320ms` | 横轴值 `320`，坐标轴写 `TTT (ms)` |
| `bs_20` | 横轴值 `20`，坐标轴写 `Base Station Density (BS/km²)` |
| `H70_B60_80` | 横轴值 `70` 或 `70 (60-80)`，坐标轴写 `Altitude Layer (m)` |

## 特殊实验建议

### 分段数量成对实验

`example_ablation_DCMOCPSO_numSegments_FullParam.m` 中的原始组名形如：

- `Seg3_Full`
- `OneSeg_for_Seg3`

不建议直接用这些名称出图。推荐改成按分段数量分组的图：

- 横轴：`Number of Segments`
- 图例：`MOCPSO` 与 `DCMOCPSO`
- 每个横轴值下展示两组结果，例如 `K=3`、`K=5`、`K=7`、`K=9`

若必须使用分类标签，则推荐：

- `MOCPSO (K=3)`
- `DCMOCPSO (K=3)`

但更推荐使用“横轴为 K，图例区分算法”的结构。

### 前瞻参数实验

`example_ablation_DCMOCPSO_lookaheadDistance.m`、`example_ablation_DCMOCPSO_lookaheadMargins.m` 的实验实际固定为 MOCPSO/OneSeg 风格算法，只改变前瞻性切换参数。

图标题不建议写 `OneSeg_Lookahead`，推荐：

- `Lookahead Distance Sensitivity under MOCPSO`
- `Dynamic Hysteresis Sensitivity under MOCPSO`
- `Safety Margin Sensitivity under MOCPSO`

`example_ablation_DCMOCPSO_lookaheadDistance.m` 生成图时仅展示 `0 m` 到 `1500 m` 的结果。若原始结果中包含更大的前瞻距离，绘图时直接过滤，不纳入坐标轴或图例。

### Full_Lookahead 场景参数实验

`Full_Lookahead` 在图上应展示为 `DCMOCPSO`，标题中不要出现 `Full_Lookahead`。

推荐标题示例：

- `Velocity Sensitivity under DCMOCPSO`
- `TTT Sensitivity under DCMOCPSO`
- `Base Station Density Sensitivity under DCMOCPSO`
- `Standard TTT Sensitivity under DCMOCPSO`
- `Altitude Layer Sensitivity under DCMOCPSO`

速度参数实验中，原始结果的 `v10`、`v15`、`v20` 等字段表示最大速度。正式绘图时横轴应使用平均速度，按 `average speed = maximum speed / 2` 换算，并在图注中说明该换算关系。

### 指标名称

通信切换相关图中，`Switch Count` 和 `Handover Count` 二者择一统一使用。若面向通信领域论文或专利，优先使用：

`Mean Handover Count`

若希望和代码/实验缓存字段保持直观对应，可使用：

`Mean Switch Count`

同一份文档内不要混用。

## 风格默认值

默认采用克制、清晰、适合论文/专利材料的图表风格：

- 不使用花哨背景。
- 保留浅色网格线辅助读数。
- 标题准确描述实验对象、参数或场景。
- 同一组图保持统一颜色和术语。
- 若指标方向不同，可用简短标注说明 `Higher is better` 或 `Lower is better`。
