from __future__ import annotations

from pathlib import Path

import numpy as np
from scipy.io import loadmat


ROOT = Path(__file__).resolve().parents[2]
SUMMARY_FILE = (
    ROOT
    / "PlatEMO"
    / "Algorithms"
    / "Multi-objective optimization"
    / "DCMOCPSO"
    / "results"
    / "switch_method_oneseg"
    / "OneSegSwitchMethod_FE_sweep_summary.mat"
)
OUTPUT_FILE = (
    ROOT
    / "patent_notes"
    / "figures"
    / "final_mixed"
    / "switch_method_comparison_fe_sweep_grouped_bars.png"
)


METHOD_LABELS = {
    "OneSeg_A3": "A3切换",
    "OneSeg": "CASH",
    "OneSeg_Lookahead": "前瞻性切换",
}
METHOD_ORDER = ["A3切换", "CASH", "前瞻性切换"]
METHOD_COLORS = {
    "A3切换": "#4C78A8",
    "CASH": "#F58518",
    "前瞻性切换": "#D62728",
}
METRICS = [
    ("hv", "HV", "（一）HV", "越大越好", "bar", False),
    ("runtime", "运行时间 (s)", "（二）运行时间", "越小越好", "bar", True),
    ("handover", "平均切换次数", "（三）平均切换次数", "越小越好", "bar", True),
    ("coverage", "路径覆盖率", "（四）路径覆盖率", "越大越好", "bar", False),
    ("signal", "平均信号强度 (dBm)", "（五）平均信号强度", "越大越好", "point", False),
]


def configure_matplotlib():
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    plt.rcParams.update(
        {
            "font.sans-serif": [
                "Microsoft YaHei",
                "SimHei",
                "Noto Sans CJK SC",
                "Arial Unicode MS",
                "DejaVu Sans",
            ],
            "axes.unicode_minus": False,
            "figure.dpi": 160,
            "savefig.dpi": 300,
            "font.size": 11,
            "axes.titlesize": 13,
            "axes.labelsize": 12,
            "xtick.labelsize": 11,
            "ytick.labelsize": 11,
            "legend.fontsize": 10,
            "legend.title_fontsize": 10,
        }
    )
    return plt


def load_summary():
    results = loadmat(SUMMARY_FILE, squeeze_me=True, struct_as_record=False)["results"]
    fe_budgets = [int(str(s.setName).replace("FE", "")) for s in np.atleast_1d(results.setResults)]
    records = []
    for fe, set_result in zip(fe_budgets, np.atleast_1d(results.setResults)):
        raw_names = [str(x) for x in np.atleast_1d(set_result.groupNames)]
        names = [METHOD_LABELS.get(name, name) for name in raw_names]
        metric_values = {
            "hv": np.asarray(set_result.meanHV, dtype=float),
            "runtime": np.asarray(set_result.meanRuntime, dtype=float),
            "handover": np.asarray(set_result.meanSwitchCount, dtype=float),
            "coverage": np.asarray(set_result.meanCoverageRatio, dtype=float),
            "signal": np.asarray(set_result.meanSignal, dtype=float),
        }
        for idx, method in enumerate(names):
            row = {"fe": fe, "method": method}
            for metric, values in metric_values.items():
                row[metric] = float(values[idx])
            records.append(row)
    return fe_budgets, records


def metric_matrix(records, fe_budgets, metric):
    matrix = np.full((len(METHOD_ORDER), len(fe_budgets)), np.nan, dtype=float)
    by_key = {(row["method"], row["fe"]): row for row in records}
    for i, method in enumerate(METHOD_ORDER):
        for j, fe in enumerate(fe_budgets):
            matrix[i, j] = by_key[(method, fe)][metric]
    return matrix


def set_metric_ylim(ax, values, zero_based=False):
    finite_values = values[np.isfinite(values)]
    if not finite_values.size:
        return
    ymin = float(np.min(finite_values))
    ymax = float(np.max(finite_values))
    span = ymax - ymin
    if span <= 0:
        span = max(abs(ymax), 1.0) * 0.1
    if zero_based:
        lower = 0 if ymin >= 0 else ymin - 0.12 * span
        upper = ymax + 0.18 * span
    else:
        lower = ymin - 0.18 * span
        upper = ymax + 0.28 * span
    ax.set_ylim(lower, upper)


def draw_metric(ax, fe_budgets, values, ylabel, subtitle, direction, style, zero_based):
    x = np.arange(len(fe_budgets), dtype=float)
    width = 0.22
    offsets = (np.arange(len(METHOD_ORDER)) - (len(METHOD_ORDER) - 1) / 2) * width

    for method, offset, row in zip(METHOD_ORDER, offsets, values):
        if style == "point":
            ax.scatter(
                x + offset,
                row,
                label=method,
                color=METHOD_COLORS[method],
                s=42,
                zorder=3,
            )
        else:
            ax.bar(
                x + offset,
                row,
                width=width,
                label=method,
                color=METHOD_COLORS[method],
                edgecolor="#222222",
                linewidth=0.45,
                zorder=3,
            )

    ax.set_title(subtitle, pad=8)
    ax.set_xlabel("FE 预算")
    ax.set_ylabel(ylabel)
    ax.set_xticks(x)
    ax.set_xticklabels([str(fe) for fe in fe_budgets])
    set_metric_ylim(ax, values, zero_based=zero_based)
    ax.grid(axis="y", color="#D9D9D9", linewidth=0.8, alpha=0.8, zorder=0)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.text(0.02, 0.96, direction, transform=ax.transAxes, ha="left", va="top", color="#666666", fontsize=10)


def main():
    plt = configure_matplotlib()
    fe_budgets, records = load_summary()

    fig, axes = plt.subplots(3, 2, figsize=(12.2, 9.0), constrained_layout=False)
    axes_flat = axes.ravel()
    fig.suptitle("实验四：切换方法对比", fontsize=18, fontweight="bold", y=0.98)

    for ax, (metric, ylabel, subtitle, direction, style, zero_based) in zip(axes_flat, METRICS):
        draw_metric(ax, fe_budgets, metric_matrix(records, fe_budgets, metric), ylabel, subtitle, direction, style, zero_based)

    legend_ax = axes_flat[-1]
    legend_ax.axis("off")
    handles, labels = axes_flat[0].get_legend_handles_labels()
    legend_ax.legend(
        handles,
        labels,
        title="切换方法",
        loc="upper left",
        bbox_to_anchor=(0.04, 0.98),
        borderaxespad=0.0,
        frameon=True,
        framealpha=0.94,
        facecolor="white",
        edgecolor="#CCCCCC",
    )
    legend_ax.text(0.04, 0.24, "柱形和点表示各组独立实验的均值。", ha="left", va="center", color="#666666", fontsize=10)

    fig.subplots_adjust(left=0.08, right=0.98, top=0.9, bottom=0.08, hspace=0.55, wspace=0.28)
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUTPUT_FILE, bbox_inches="tight")
    print(f"saved: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
