"""
Statistical analysis and chart generation for benchmark results.

Usage:
    python tools/analyze_benchmark.py benchmark_results_<timestamp>.json
    python tools/analyze_benchmark.py benchmark_results_*.json  # compare multiple runs

Outputs charts next to the JSON file:
    benchmark_results_<timestamp>_latency_boxplot.png
    benchmark_results_<timestamp>_latency_per_batch.png
    benchmark_results_<timestamp>_cpu_power_stacked.png
    benchmark_results_<timestamp>_total_power.png
    benchmark_results_<timestamp>_stats.md   (statistical summary table)
"""

import json
import sys
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
from scipy import stats as scipy_stats


# ── Style ───────────────────────────────────────────────────────────────────

COLORS = {
    'CPU 1T':     '#4e79a7',
    'CPU 2T':     '#f28e2b',
    'CPU 3T':     '#e15759',
    'CPU 4T':     '#76b7b2',
    'XNNPACK':    '#59a14f',
    'Accelerated':'#edc948',
    'NPU-only':   '#b07aa1',
}
DEFAULT_COLOR = '#999999'

CPU_RAIL_COLORS = {
    'CPU BIG (X4)':    '#d62728',
    'CPU MID (A720)':  '#ff7f0e',
    'CPU MID-M':       '#ffbb78',
    'CPU LITTLE (A520)':'#aec7e8',
}


# ── Data loading ─────────────────────────────────────────────────────────────

def load(path: str) -> dict:
    return json.loads(Path(path).read_text(encoding='utf-8'))


def get_latencies(data: dict, label: str) -> list[float]:
    """All per-batch avg latencies for a config label."""
    result = []
    for key, v in data['latency'].items():
        batch_str, lbl = key.split(':', 1)
        if lbl == label and batch_str != '0' and 'avg_ms' in v:
            result.append(float(v['avg_ms']))
    return result


def get_rails(data: dict, label: str) -> dict[str, list[float]]:
    """Per-batch rail energy for a config label."""
    rail_lists: dict[str, list[float]] = {}
    for key, v in data['rails'].items():
        batch_str, lbl = key.split(':', 1)
        if lbl == label and batch_str != '0':
            for rail, mws in v.items():
                if not rail.startswith('_'):
                    rail_lists.setdefault(rail, []).append(float(mws))
    return rail_lists


def get_total_power(data: dict, label: str) -> list[float]:
    result = []
    for key, v in data['rails'].items():
        batch_str, lbl = key.split(':', 1)
        if lbl == label and batch_str != '0' and '_total_power_mw' in v:
            result.append(float(v['_total_power_mw']))
    return result


def config_labels(data: dict) -> list[str]:
    return [c['label'] for c in data['matrix']]


# ── Stats ────────────────────────────────────────────────────────────────────

def describe(xs: list[float]) -> dict:
    if not xs:
        return {}
    a = np.array(xs)
    return {
        'n':      len(a),
        'mean':   float(np.mean(a)),
        'median': float(np.median(a)),
        'std':    float(np.std(a, ddof=1)) if len(a) > 1 else 0.0,
        'min':    float(np.min(a)),
        'max':    float(np.max(a)),
        'p5':     float(np.percentile(a, 5)),
        'p95':    float(np.percentile(a, 95)),
        'cv_pct': float(np.std(a, ddof=1) / np.mean(a) * 100) if np.mean(a) else 0.0,
    }


# ── Charts ───────────────────────────────────────────────────────────────────

def plot_latency_boxplot(data: dict, out: Path):
    labels = config_labels(data)
    all_lats = [get_latencies(data, l) for l in labels]

    fig, ax = plt.subplots(figsize=(max(8, len(labels) * 1.2), 5))
    bp = ax.boxplot(all_lats, patch_artist=True, notch=False,
                    medianprops=dict(color='white', linewidth=2))

    for patch, label in zip(bp['boxes'], labels):
        patch.set_facecolor(COLORS.get(label, DEFAULT_COLOR))
        patch.set_alpha(0.85)

    ax.set_xticks(range(1, len(labels) + 1))
    ax.set_xticklabels(labels, rotation=15, ha='right')
    ax.set_ylabel('Latency (ms)')
    ax.set_title('Inference Latency Distribution per Config')
    ax.yaxis.set_minor_locator(ticker.AutoMinorLocator())
    ax.grid(axis='y', linestyle='--', alpha=0.5)
    fig.tight_layout()
    fig.savefig(str(out), dpi=150)
    plt.close(fig)
    print(f'  Chart: {out.name}')


def plot_latency_per_batch(data: dict, out: Path):
    labels = config_labels(data)
    batches = data['batches']
    if batches < 2:
        print('  Skipping per-batch line chart (only 1 batch)')
        return

    fig, ax = plt.subplots(figsize=(max(8, batches * 1.5), 5))
    batch_nums = list(range(1, batches + 1))

    for label in labels:
        lats_by_batch = {}
        for key, v in data['latency'].items():
            b_str, lbl = key.split(':', 1)
            if lbl == label and b_str != '0' and 'avg_ms' in v:
                lats_by_batch[int(b_str)] = float(v['avg_ms'])
        ys = [lats_by_batch.get(b) for b in batch_nums]
        valid = [(b, y) for b, y in zip(batch_nums, ys) if y is not None]
        if valid:
            xs, yvs = zip(*valid)
            ax.plot(xs, yvs, marker='o', label=label,
                    color=COLORS.get(label, DEFAULT_COLOR))

    ax.set_xlabel('Batch')
    ax.set_ylabel('Avg Latency (ms)')
    ax.set_title('Latency per Batch (thermal drift / variance)')
    ax.legend(loc='upper right', fontsize=8)
    ax.grid(linestyle='--', alpha=0.4)
    ax.xaxis.set_major_locator(ticker.MaxNLocator(integer=True))
    fig.tight_layout()
    fig.savefig(str(out), dpi=150)
    plt.close(fig)
    print(f'  Chart: {out.name}')


def plot_cpu_power_stacked(data: dict, out: Path):
    labels = config_labels(data)
    cpu_rails = list(CPU_RAIL_COLORS.keys())

    avgs = {rail: [] for rail in cpu_rails}
    errs = {rail: [] for rail in cpu_rails}

    for label in labels:
        rail_data = get_rails(data, label)
        for rail in cpu_rails:
            vals = rail_data.get(rail, [])
            avgs[rail].append(np.mean(vals) if vals else 0)
            errs[rail].append(np.std(vals, ddof=1) if len(vals) > 1 else 0)

    if not any(any(v > 0 for v in avgs[r]) for r in cpu_rails):
        print('  Skipping CPU power stacked chart (no Perfetto data)')
        return

    x = np.arange(len(labels))
    width = 0.6
    fig, ax = plt.subplots(figsize=(max(8, len(labels) * 1.2), 5))

    bottom = np.zeros(len(labels))
    for rail in cpu_rails:
        vals = np.array(avgs[rail])
        ax.bar(x, vals, width, bottom=bottom,
               label=rail, color=CPU_RAIL_COLORS[rail], alpha=0.9)
        bottom += vals

    # Error bar on total
    totals = bottom.copy()
    total_err = np.sqrt(sum(np.array(errs[r])**2 for r in cpu_rails))
    ax.errorbar(x, totals, yerr=total_err, fmt='none',
                ecolor='black', capsize=4, linewidth=1.5)

    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=15, ha='right')
    ax.set_ylabel('CPU Energy (mWs)')
    ax.set_title('CPU Power Rail Breakdown per Config')
    ax.legend(loc='upper right', fontsize=8)
    ax.grid(axis='y', linestyle='--', alpha=0.4)
    fig.tight_layout()
    fig.savefig(str(out), dpi=150)
    plt.close(fig)
    print(f'  Chart: {out.name}')


def plot_total_power(data: dict, out: Path):
    labels = config_labels(data)
    means, errs = [], []

    for label in labels:
        vals = get_total_power(data, label)
        means.append(np.mean(vals) if vals else 0)
        errs.append(np.std(vals, ddof=1) if len(vals) > 1 else 0)

    if not any(m > 0 for m in means):
        print('  Skipping total power chart (no battery current data)')
        return

    x = np.arange(len(labels))
    fig, ax = plt.subplots(figsize=(max(8, len(labels) * 1.2), 5))
    bars = ax.bar(x, means, yerr=errs, capsize=5,
                  color=[COLORS.get(l, DEFAULT_COLOR) for l in labels],
                  alpha=0.85)

    for bar, m in zip(bars, means):
        if m > 0:
            ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 50,
                    f'{m:.0f}', ha='center', va='bottom', fontsize=9)

    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=15, ha='right')
    ax.set_ylabel('Total Device Power (mW)')
    ax.set_title('Average Total Power Draw during Inference\n'
                 '(battery current × voltage — device must be unplugged)')
    ax.grid(axis='y', linestyle='--', alpha=0.4)
    fig.tight_layout()
    fig.savefig(str(out), dpi=150)
    plt.close(fig)
    print(f'  Chart: {out.name}')


def write_stats_md(data: dict, out: Path):
    labels = config_labels(data)
    lines = [
        '## Benchmark Statistical Summary',
        f'Batches: {data["batches"]}  ·  Runs/batch: {data["runs"]}',
        f'Config order randomised per batch: yes',
        '',
        '### Latency',
        '',
        '| Config | n | Mean (ms) | Median | Std | p5 | p95 | CV% |',
        '|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|',
    ]
    for label in labels:
        lats = get_latencies(data, label)
        d = describe(lats)
        if d:
            lines.append(
                f'| {label} | {d["n"]} | {d["mean"]:.1f} | {d["median"]:.1f} '
                f'| {d["std"]:.1f} | {d["p5"]:.1f} | {d["p95"]:.1f} | {d["cv_pct"]:.1f}% |'
            )

    lines += ['', '### Total Power (mW)', '',
              '| Config | n | Mean | Std | Min | Max |',
              '|:---|:---:|:---:|:---:|:---:|:---:|']
    for label in labels:
        vals = get_total_power(data, label)
        d = describe(vals)
        if d:
            lines.append(
                f'| {label} | {d["n"]} | {d["mean"]:.0f} | {d["std"]:.0f} '
                f'| {d["min"]:.0f} | {d["max"]:.0f} |'
            )

    # CPU BIG energy as NPU proxy
    lines += ['', '### CPU BIG Energy (mWs) — NPU offload proxy', '',
              '| Config | Mean | Std |',
              '|:---|:---:|:---:|']
    for label in labels:
        rails = get_rails(data, label)
        vals = rails.get('CPU BIG (X4)', [])
        d = describe(vals)
        if d:
            lines.append(f'| {label} | {d["mean"]:.0f} | {d["std"]:.0f} |')

    out.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'  Stats:  {out.name}')


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    paths = sys.argv[1:] or sorted(Path('.').glob('benchmark_results_*.json'))
    if not paths:
        print('Usage: python tools/analyze_benchmark.py <file.json>')
        sys.exit(1)

    for path in [Path(p) for p in paths]:
        if not path.exists():
            print(f'Not found: {path}')
            continue
        print(f'\nAnalysing {path}…')
        data = load(str(path))
        # Support both old flat layout and new benchmarks/<timestamp>/ layout.
        out_dir = path.parent

        plot_latency_boxplot(data,   out_dir / 'latency_boxplot.png')
        plot_latency_per_batch(data, out_dir / 'latency_per_batch.png')
        plot_cpu_power_stacked(data, out_dir / 'cpu_power_stacked.png')
        plot_total_power(data,       out_dir / 'total_power.png')
        write_stats_md(data,         out_dir / 'stats.md')
        print(f'  Output dir: {out_dir}')


if __name__ == '__main__':
    main()
