from __future__ import annotations

import os
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
    / "compare_vs_baselines"
    / "DCMOCPSO_vs_baselines_FE_sweep_summary.mat"
)
OUTPUT_FILE = (
    ROOT
    / "patent_notes"
    / "figures"
    / "final_mixed"
    / "dcmocpso_vs_baselines_fe_sweep_hv_runtime_grouped_bars.png"
)


METHOD_LABELS = {
    "Base-MOCPSO": "MOCPSO",
    "DCMOCPSO": "DCMOCPSO",
    "IMMOEAD": "IMMOEAD",
    "DGEA": "DGEA",
}

METHOD_ORDER = ["IMMOEAD", "DGEA", "MOCPSO", "DCMOCPSO"]
METHOD_COLORS = {
    "IMMOEAD": "#4C78A8",
    "DGEA": "#F58518",
    "MOCPSO": "#54A24B",
    "DCMOCPSO": "#D62728",
}


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


def as_1d(value):
    return np.atleast_1d(value).astype(object)


def load_summary():
    mat = loadmat(SUMMARY_FILE, squeeze_me=True, struct_as_record=False)
    results = mat["results"]
    fe_budgets = [int(x) for x in np.atleast_1d(results.maxFE_DCMOCPSOList)]

    records = []
    for fe, set_result in zip(fe_budgets, as_1d(results.setResults)):
        raw_names = [str(x) for x in np.atleast_1d(set_result.groupNames)]
        display_names = [METHOD_LABELS.get(name, name) for name in raw_names]
        hv = np.asarray(set_result.meanHV, dtype=float)
        runtime = np.asarray(set_result.meanRuntime, dtype=float)
        for name, hv_value, runtime_value in zip(display_names, hv, runtime):
            records.append(
                {
                    "fe": fe,
                    "method": name,
                    "hv": float(hv_value),
                    "runtime": float(runtime_value),
                }
            )
    return fe_budgets, records


def metric_matrix(records, fe_budgets, metric):
    matrix = np.full((len(METHOD_ORDER), len(fe_budgets)), np.nan, dtype=float)
    index = {(row["method"], row["fe"]): row for row in records}
    for i, method in enumerate(METHOD_ORDER):
        for j, fe in enumerate(fe_budgets):
            matrix[i, j] = index[(method, fe)][metric]
    return matrix


def draw_grouped_bars(ax, values, fe_budgets, ylabel, subtitle, direction_text, ylim=None):
    x = np.arange(len(fe_budgets), dtype=float)
    width = 0.18
    offsets = (np.arange(len(METHOD_ORDER)) - (len(METHOD_ORDER) - 1) / 2) * width

    for method, offset, row in zip(METHOD_ORDER, offsets, values):
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

    ax.set_title(subtitle, pad=10)
    ax.set_xlabel("FE 预算")
    ax.set_ylabel(ylabel)
    ax.set_xticks(x)
    ax.set_xticklabels([str(fe) for fe in fe_budgets])
    if ylim is not None:
        ax.set_ylim(*ylim)
    ax.grid(axis="y", color="#D9D9D9", linewidth=0.8, alpha=0.8, zorder=0)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.text(
        0.02,
        0.96,
        direction_text,
        transform=ax.transAxes,
        ha="left",
        va="top",
        color="#666666",
        fontsize=10,
    )


def main():
    plt = configure_matplotlib()
    fe_budgets, records = load_summary()
    hv_values = metric_matrix(records, fe_budgets, "hv")
    runtime_values = metric_matrix(records, fe_budgets, "runtime")

    fig, axes = plt.subplots(1, 2, figsize=(12.0, 4.8), constrained_layout=False)
    fig.suptitle("实验一：多目标优化算法基线对比", fontsize=18, fontweight="bold", y=0.98)

    draw_grouped_bars(
        axes[0],
        hv_values,
        fe_budgets,
        "平均 HV",
        "（一）平均 HV",
        "越大越好",
        ylim=(np.nanmin(hv_values) - 0.003, np.nanmax(hv_values) + 0.003),
    )
    draw_grouped_bars(
        axes[1],
        runtime_values,
        fe_budgets,
        "运行时间 (s)",
        "（二）平均运行时间",
        "越小越好",
    )

    axes[1].legend(
        title="算法",
        loc="upper left",
        bbox_to_anchor=(1.01, 1.0),
        borderaxespad=0.0,
        frameon=True,
        framealpha=0.94,
        facecolor="white",
        edgecolor="#CCCCCC",
    )

    fig.text(0.5, 0.02, "柱形高度表示 20 次独立实验的均值。", ha="center", color="#666666", fontsize=10)
    fig.subplots_adjust(left=0.08, right=0.88, top=0.78, bottom=0.18, wspace=0.24)

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUTPUT_FILE, bbox_inches="tight")
    print(f"saved: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
