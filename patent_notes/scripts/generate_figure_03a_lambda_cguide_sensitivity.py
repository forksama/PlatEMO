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
    / "lambda_cguide"
    / "LambdaCGuide_sweep_summary.mat"
)
OUTPUT_FILE = (
    ROOT
    / "patent_notes"
    / "figures"
    / "final_mixed"
    / "lambda_cguide_sensitivity_hv_runtime.png"
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
        }
    )
    return plt


def load_summary():
    mat = loadmat(SUMMARY_FILE, squeeze_me=True, struct_as_record=False)
    lambda_result = np.atleast_1d(mat["lambdaResults"])[0]
    cguide_result = np.atleast_1d(mat["cGuideResults"])[0]
    return {
        "lambda_x": np.asarray(lambda_result.sweptValues, dtype=float),
        "lambda_hv": np.asarray(lambda_result.meanHV, dtype=float),
        "lambda_runtime": np.asarray(lambda_result.meanRuntime, dtype=float),
        "fixed_cguide": float(lambda_result.fixedValue),
        "cguide_x": np.asarray(cguide_result.sweptValues, dtype=float),
        "cguide_hv": np.asarray(cguide_result.meanHV, dtype=float),
        "cguide_runtime": np.asarray(cguide_result.meanRuntime, dtype=float),
        "fixed_lambda": float(cguide_result.fixedValue),
    }


def draw_line(ax, x, y, color, marker, xlabel, ylabel, subtitle, direction_text, note):
    ax.plot(x, y, color=color, marker=marker, linewidth=2.4, markersize=6, zorder=3)
    ax.set_title(subtitle, pad=8)
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_xticks(x)
    ax.grid(color="#D9D9D9", linewidth=0.8, alpha=0.8, zorder=0)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.text(0.02, 0.96, direction_text, transform=ax.transAxes, ha="left", va="top", color="#666666", fontsize=10)
    ax.text(0.98, 0.08, note, transform=ax.transAxes, ha="right", va="bottom", color="#666666", fontsize=10)


def main():
    plt = configure_matplotlib()
    data = load_summary()

    fig, axes = plt.subplots(2, 2, figsize=(11.8, 7.8), constrained_layout=False)
    fig.suptitle("实验三：DCMOCPSO 参数敏感性", fontsize=18, fontweight="bold", y=0.98)

    draw_line(
        axes[0, 0],
        data["lambda_x"],
        data["lambda_hv"],
        "#4C78A8",
        "o",
        "Ek 奖励权重 lambda",
        "平均 HV",
        "（一）lambda 对 HV 的影响",
        "越大越好",
        f"固定 c_guide = {data['fixed_cguide']:.1f}",
    )
    draw_line(
        axes[0, 1],
        data["lambda_x"],
        data["lambda_runtime"],
        "#F58518",
        "o",
        "Ek 奖励权重 lambda",
        "运行时间 (s)",
        "（二）lambda 对运行时间的影响",
        "越小越好",
        f"固定 c_guide = {data['fixed_cguide']:.1f}",
    )
    draw_line(
        axes[1, 0],
        data["cguide_x"],
        data["cguide_hv"],
        "#54A24B",
        "o",
        "引导权重 c_guide",
        "平均 HV",
        "（三）c_guide 对 HV 的影响",
        "越大越好",
        f"固定 lambda = {data['fixed_lambda']:.1f}",
    )
    draw_line(
        axes[1, 1],
        data["cguide_x"],
        data["cguide_runtime"],
        "#D62728",
        "o",
        "引导权重 c_guide",
        "运行时间 (s)",
        "（四）c_guide 对运行时间的影响",
        "越小越好",
        f"固定 lambda = {data['fixed_lambda']:.1f}",
    )

    fig.text(0.5, 0.025, "折线点表示各参数取值下独立实验的均值。", ha="center", color="#666666", fontsize=10)
    fig.subplots_adjust(left=0.08, right=0.98, top=0.88, bottom=0.11, hspace=0.38, wspace=0.2)
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUTPUT_FILE, bbox_inches="tight")
    print(f"saved: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
