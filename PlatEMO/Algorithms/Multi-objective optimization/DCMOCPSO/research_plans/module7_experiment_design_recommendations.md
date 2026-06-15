# 模块 7：实验参数设计与推荐配置

调研日期：2026-06-08

## 设计目标

本模块把前面 1-6 的调研结果收束成最终实验参数设计，目标是形成一套可以直接写进论文、也能映射到 MATLAB 脚本的配置方案。

核心原则：

1. 单因素消融继续保留，用于说明 `velocity`、`TTT`、`bsPerKm2`、高度等变量的独立影响。
2. 不做完整笛卡尔积，避免组合数量过大且缺乏场景意义。
3. 增加少量“真实场景组合”，用于说明参数之间的耦合和现实解释。
4. 所有实验默认与当前 Full_Lookahead/full_param 对齐，除非实验本身是算法消融。

## 当前推荐主配置

建议把当前主配置定义为“高密城市低空巡航 + 前瞻性切换 + full_param 优化”：

```matlab
baseProblemParameter = {20, 20, 5, -101.5, 0, 30, 2, 500, 10, 4};
param_Full = {5, 2, 0.5, 0.3, true, true, true};
maxFE_Full = 100;
n = 20;
```

含义：

| 参数 | 当前值 | 推荐解释 |
|---|---:|---|
| `bsPerKm2` | 20 | 中高密城市蜂窝覆盖，介于 3GPP UMa 和 UMi 之间。 |
| `velocity` | 20 m/s | 较高速城市巡航/应急巡检，接近行业多旋翼高速运行上界。 |
| `TTT` | 5 s | 当前模型中的中等路径采样/切换决策间隔。 |
| `switchThreshold` | -101.5 dBm | 覆盖判断/切换触发阈值，沿用当前模型。 |
| `switchMethod` | 2 | 前瞻性切换算法。 |
| `lookaheadDistance` | 500 m | 中等前向展望距离。 |
| `lookaheadHysteresisRange` | 10 dB | 当前代码默认动态迟滞余量范围。 |
| `lookaheadSafetyMargin` | 4 dB | 当前代码默认安全裕度。 |

这个主配置适合作为所有环境参数消融的固定基线。

## 推荐保留的单因素实验

### 1. 速度消融

建议保留当前取值：

```matlab
velocityList = [10, 15, 20, 25, 30];
```

解释：

| 速度 | 场景定位 |
|---:|---|
| 10 m/s | 低速巡检/小型配送。 |
| 15 m/s | 常规行业巡检/测绘。 |
| 20 m/s | 较高速城市巡航或应急任务。 |
| 25 m/s | 高机动扩展场景。 |
| 30 m/s | 蜂窝联网 UAV 高速切换压力测试。 |

建议固定：

```matlab
baseProblemParameter = {20, velocity, 5, -101.5, 0, 30, 2, 500, 10, 4};
```

### 2. TTT 消融

建议保留当前取值：

```matlab
TTTList = [1, 3, 5, 7, 9];
```

解释：

| TTT | 场景定位 |
|---:|---|
| 1 s | 高频采样/快速切换决策。 |
| 3 s | 较灵活决策间隔。 |
| 5 s | 主配置基准值。 |
| 7 s | 较保守决策间隔。 |
| 9 s | 粗采样/强保守场景。 |

注意：这里的 TTT 应解释为路径采样/切换决策时间间隔，不能直接等同于 3GPP RRC 毫秒级 Time-To-Trigger。

建议固定：

```matlab
baseProblemParameter = {20, 20, TTT, -101.5, 0, 30, 2, 500, 10, 4};
```

### 3. 基站密度消融

建议保留当前取值：

```matlab
bsPerKm2List = [5, 10, 20, 30, 40];
```

解释：

| bsPerKm2 | 场景定位 |
|---:|---|
| 5 | 稀疏宏站，接近 3GPP UMa 500 m ISD。 |
| 10 | 普通城区宏站增强/宏微混合。 |
| 20 | 中高密城市覆盖。 |
| 30 | 高密微站，接近 3GPP UMi 200 m ISD。 |
| 40 | 超高密城市、园区、热点区域或低空经济重点区。 |

建议固定：

```matlab
baseProblemParameter = {bsPerKm2, 20, 5, -101.5, 0, 30, 2, 500, 10, 4};
```

### 4. 高度/高度范围消融

当前实验取值可以保留：

```matlab
altitudeCenterList = [35, 50, 65, 80, 95];
altitudeBoundOffset = 20;
altitudeBoundsList = [altitudeCenterList(:) - altitudeBoundOffset, ...
                      altitudeCenterList(:) + altitudeBoundOffset];
```

对应：

| altitudeCenter | altitudeBounds | 场景定位 |
|---:|---|---|
| 35 | 15-55 m | 低高度巡检，受建筑遮挡影响更强。 |
| 50 | 30-70 m | 城市低空巡航常见层。 |
| 65 | 45-85 m | 中间高度层。 |
| 80 | 60-100 m | 中高低空巡航层。 |
| 95 | 75-115 m | 接近 120 m 监管友好上限的高低空层。 |

若后续希望更规整、更容易写论文，也可以使用：

```matlab
altitudeCenterList = [40, 60, 80, 100];
altitudeBoundOffset = 20;
```

但从复用现有缓存和保持实验连续性的角度，优先保留 `[35, 50, 65, 80, 95] ± 20 m`。

## 不建议作为主实验的配置

### 不建议完整笛卡尔积

不建议做：

```matlab
velocityList × TTTList × bsPerKm2List × altitudeCenterList
```

原因：

- 组合数量至少 5 × 5 × 5 × 5 = 625 组；
- 当前每组还需要 n=20，多次运行成本很高；
- 很多组合没有真实场景意义；
- 论文中难以解释所有交互项。

### 不建议把秒级 TTT 写成 3GPP 标准 TTT

当前 `TTTList = [1, 3, 5, 7, 9]` 是代码中的路径采样/切换决策间隔。若论文要严格对齐 3GPP 标准 TTT，应另设一组毫秒级实验：

```matlab
TTTList_standardLike = [0.04, 0.16, 0.32, 0.64, 1.28];
```

但这会显著增加航点数量和算法维度，不建议替换当前主实验。

## 推荐增加的场景组合实验

建议在单因素消融之外，增加一组 5 个场景的组合实验。该实验不追求遍历所有参数，而是让每组参数对应一个真实或典型低空通信场景。

| 场景 | bsPerKm2 | velocity | TTT | altitudeCenter | altitudeBounds | 解释 |
|---|---:|---:|---:|---:|---|---|
| Sparse_Macro_Patrol | 5 | 10 | 5 | 80 | 60-100 | 郊区/稀疏宏站巡检，基站少，适当升高高度增强覆盖。 |
| Urban_Patrol | 10 | 15 | 5 | 65 | 45-85 | 普通城区巡航，速度和高度都取中等。 |
| Dense_LowAltitude | 20 | 15 | 3 | 50 | 30-70 | 高密城区低空巡检，基站较密，TTT 略小以提高响应。 |
| Dense_FastMission | 30 | 20 | 3 | 80 | 60-100 | 高密城区较高速任务，重点观察切换开销。 |
| UltraDense_Emergency | 40 | 25 | 1 | 95 | 75-115 | 超高密热点/应急任务，高覆盖但切换压力最大。 |

建议 MATLAB 配置格式：

```matlab
scenarioConfigs = {
    'Sparse_Macro_Patrol',  {5,  10, 5, -101.5, 0, 30, 2, 500, 10, 4, 80, [60, 100]};
    'Urban_Patrol',        {10, 15, 5, -101.5, 0, 30, 2, 500, 10, 4, 65, [45, 85]};
    'Dense_LowAltitude',   {20, 15, 3, -101.5, 0, 30, 2, 500, 10, 4, 50, [30, 70]};
    'Dense_FastMission',   {30, 20, 3, -101.5, 0, 30, 2, 500, 10, 4, 80, [60, 100]};
    'UltraDense_Emergency',{40, 25, 1, -101.5, 0, 30, 2, 500, 10, 4, 95, [75, 115]};
};
```

建议算法配置：

```matlab
n = 20;
N = 20;
maxFE_Full = 100;
param_Full = {5, 2, 0.5, 0.3, true, true, true};
```

## 推荐论文实验结构

建议最终论文中的实验结构如下：

1. 算法消融：验证分段、前瞻性算法、full_param 优化的贡献。
2. 前瞻性机制参数消融：验证 lookaheadDistance、hysteresis range、safety margin 等参数。
3. 环境单因素消融：分别验证速度、TTT、基站密度、高度/高度范围。
4. 场景组合实验：验证算法在不同真实低空通信场景下的综合表现。

其中模块 7 主要支撑第 3 和第 4 部分。

## 指标解释

所有环境参数实验建议统一报告：

- `HV`
- 平均信号强度
- 平均切换次数
- 平均覆盖率
- 运行时间
- 有效运行次数 validCount

论文解释逻辑建议：

```text
HV is maximized when the solution set achieves a good trade-off among stronger signal strength, fewer handovers, and higher path coverage.
```

参数变化的预期方向：

| 参数 | 信号强度 | 切换次数 | 覆盖率 | HV 预期 |
|---|---|---|---|---|
| 速度升高 | 可能下降或波动 | 通常上升 | 可能下降 | 中速更可能较优。 |
| TTT 增大 | 可能先稳后降 | 通常下降 | 过大可能下降 | 适中值更可能较优。 |
| 基站密度增大 | 通常上升 | 通常上升 | 上升后饱和 | 中高密可能较优，超高密不一定最好。 |
| 高度升高 | 可能先升后饱和/受干扰影响 | 可能上升 | 可能先升后饱和 | 中等或中高高度可能较优。 |

## 最终推荐配置汇总

建议论文最终采用：

```matlab
% Main baseline
baseProblemParameter = {20, 20, 5, -101.5, 0, 30, 2, 500, 10, 4};
param_Full = {5, 2, 0.5, 0.3, true, true, true};
maxFE_Full = 100;
n = 20;

% One-factor environmental ablations
velocityList = [10, 15, 20, 25, 30];
TTTList = [1, 3, 5, 7, 9];
bsPerKm2List = [5, 10, 20, 30, 40];
altitudeCenterList = [35, 50, 65, 80, 95];
altitudeBoundOffset = 20;

% Scenario-level combinations
scenarioConfigs = {
    'Sparse_Macro_Patrol',  {5,  10, 5, -101.5, 0, 30, 2, 500, 10, 4, 80, [60, 100]};
    'Urban_Patrol',        {10, 15, 5, -101.5, 0, 30, 2, 500, 10, 4, 65, [45, 85]};
    'Dense_LowAltitude',   {20, 15, 3, -101.5, 0, 30, 2, 500, 10, 4, 50, [30, 70]};
    'Dense_FastMission',   {30, 20, 3, -101.5, 0, 30, 2, 500, 10, 4, 80, [60, 100]};
    'UltraDense_Emergency',{40, 25, 1, -101.5, 0, 30, 2, 500, 10, 4, 95, [75, 115]};
};
```

## 参考来源

- 模块 1 场景背景调研：`module1_application_scenarios_findings.md`
- 模块 2 高度/高度范围调研：`module2_altitude_range_findings.md`
- 模块 3 速度调研：`module3_velocity_findings.md`
- 模块 4 TTT 调研：`module4_TTT_findings.md`
- 模块 5 基站密度调研：`module5_bs_density_findings.md`
- 模块 6 参数耦合调研：`module6_parameter_coupling_findings.md`
- 3GPP TR 38.901 / ETSI TR 138 901 V19.3.0：https://www.etsi.org/deliver/etsi_tr/138900_138999/138901/19.03.00_60/tr_138901v190300p.pdf
- Mobility State Detection of Cellular-Connected UAVs based on Handover Count Statistics：https://arxiv.org/abs/2206.13007
- Handover Management for Drones in Future Mobile Networks：https://www.mdpi.com/1424-8220/22/17/6424
- DJI Matrice 350 RTK 官方规格：https://enterprise.dji.com/zh-tw/matrice-350-rtk/specs
- 深圳市工信局 5G 基站数据：https://gxj.sz.gov.cn/gkmlpt/content/10/10329/post_10329286.html

