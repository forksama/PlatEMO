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
    / "lookahead_margins_oneseg"
    / "LookaheadHysteresisOneSegSweep_summary.mat"
)
OUTPUT_FILE = (
    ROOT
    / "patent_notes"
    / "figures"
    / "final_mixed"
    / "lookahead_hysteresis_mocpso_metrics_lines.png"
)


METRICS = [
    ("meanHV", "HV", "（一）HV", "越大越好", "#4C78A8"),
    ("meanRuntime", "运行时间 (s)", "（二）运行时间", "越小越好", "#F58518"),
    ("meanSwitchCount", "平均切换次数", "（三）平均切换次数", "越小越好", "#54A24B"),
    ("meanCoverageRatio", "路径覆盖率", "（四）路径覆盖率", "越大越好", "#D62728"),
    ("meanSignal", "平均信号强度 (dBm)", "（五）平均信号强度", "越大越好", "#7B61B9"),
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
        }
    )
    return plt


def load_summary():
    results = loadmat(SUMMARY_FILE, squeeze_me=True, struct_as_record=False)["results"]
    data = {"x": np.asarray(results.sweptValues, dtype=float).astype(int)}
    for metric, *_ in METRICS:
        data[metric] = np.asarray(getattr(results, metric), dtype=float)
    data["fixed_safety"] = float(results.fixedValue)
    return data


def draw_line(ax, x, y, ylabel, subtitle, direction, color):
    ax.plot(x, y, color=color, marker="o", linewidth=2.4, markersize=5.8, zorder=3)
    ax.set_title(subtitle, pad=8)
    ax.set_xlabel("动态滞后范围 (dB)")
    ax.set_ylabel(ylabel)
    ax.set_xticks(x)
    finite_y = y[np.isfinite(y)]
    if finite_y.size:
        ymin = float(np.min(finite_y))
        ymax = float(np.max(finite_y))
        span = ymax - ymin
        if span <= 0:
            span = max(abs(ymax), 1.0) * 0.1
        ax.set_ylim(ymin - 0.18 * span, ymax + 0.28 * span)
    ax.grid(color="#D9D9D9", linewidth=0.8, alpha=0.8, zorder=0)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.text(0.02, 0.96, direction, transform=ax.transAxes, ha="left", va="top", color="#666666", fontsize=10)


def main():
    plt = configure_matplotlib()
    data = load_summary()

    fig, axes = plt.subplots(3, 2, figsize=(12.2, 9.0), constrained_layout=False)
    axes_flat = axes.ravel()
    fig.suptitle("实验四：动态滞后范围敏感性", fontsize=18, fontweight="bold", y=0.98)

    for ax, (metric, ylabel, subtitle, direction, color) in zip(axes_flat, METRICS):
        draw_line(ax, data["x"], data[metric], ylabel, subtitle, direction, color)

    note_ax = axes_flat[-1]
    note_ax.axis("off")
    note_ax.text(
        0.04,
        0.62,
        f"固定安全裕量：{data['fixed_safety']:.0f} dB\n折线点表示各参数取值下独立实验的均值。",
        ha="left",
        va="center",
        color="#666666",
        fontsize=11,
        linespacing=1.6,
    )

    fig.subplots_adjust(left=0.08, right=0.98, top=0.9, bottom=0.08, hspace=0.55, wspace=0.28)
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUTPUT_FILE, bbox_inches="tight")
    print(f"saved: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
