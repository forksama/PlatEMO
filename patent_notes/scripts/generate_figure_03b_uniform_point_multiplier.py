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
    / "uniform_point_multiplier"
    / "UniformPointMultiplier_summary.mat"
)
OUTPUT_FILE = (
    ROOT
    / "patent_notes"
    / "figures"
    / "final_mixed"
    / "uniform_point_multiplier_dcmocpso_hv_runtime_bars.png"
)


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
    return {
        "x": np.asarray(results.uniformPointMultipliers, dtype=int),
        "hv": np.asarray(results.meanHV, dtype=float),
        "runtime": np.asarray(results.meanRuntime, dtype=float),
    }


def draw_bars(ax, x_labels, values, ylabel, subtitle, direction_text, ylim=None, show_label=False):
    x = np.arange(len(x_labels), dtype=float)
    ax.bar(
        x,
        values,
        width=0.46,
        label="DCMOCPSO" if show_label else None,
        color="#4C78A8",
        edgecolor="#222222",
        linewidth=0.45,
        zorder=3,
    )
    ax.set_title(subtitle, pad=10)
    ax.set_xlabel("参考向量倍增系数")
    ax.set_ylabel(ylabel)
    ax.set_xticks(x)
    ax.set_xticklabels([str(v) for v in x_labels])
    if ylim is not None:
        ax.set_ylim(*ylim)
    ax.grid(axis="y", color="#D9D9D9", linewidth=0.8, alpha=0.8, zorder=0)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.text(0.02, 0.96, direction_text, transform=ax.transAxes, ha="left", va="top", color="#666666", fontsize=10)


def main():
    plt = configure_matplotlib()
    data = load_summary()

    fig, axes = plt.subplots(1, 2, figsize=(12.0, 4.8), constrained_layout=False)
    fig.suptitle("实验三：参考向量倍增系数敏感性", fontsize=18, fontweight="bold", y=0.98)

    draw_bars(
        axes[0],
        data["x"],
        data["hv"],
        "平均 HV",
        "（一）平均 HV",
        "越大越好",
        ylim=(np.nanmin(data["hv"]) - 0.0003, np.nanmax(data["hv"]) + 0.0003),
    )
    draw_bars(
        axes[1],
        data["x"],
        data["runtime"],
        "运行时间 (s)",
        "（二）平均运行时间",
        "越小越好",
        show_label=True,
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

    fig.text(0.5, 0.02, "柱形高度表示各参数取值下独立实验的均值。", ha="center", color="#666666", fontsize=10)
    fig.subplots_adjust(left=0.08, right=0.88, top=0.78, bottom=0.18, wspace=0.24)
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUTPUT_FILE, bbox_inches="tight")
    print(f"saved: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
