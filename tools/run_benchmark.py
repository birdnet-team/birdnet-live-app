"""
On-device inference benchmark with per-rail Perfetto power measurement.

The Flutter integration test runs ONCE. Python reads its stdout live and
starts/stops a Perfetto trace around each config using BENCHMARK_START/END
markers printed by the test. No repeated build/deploy.

Usage:
    python tools/run_benchmark.py
    python tools/run_benchmark.py -r 20 --big-cores 6
    python tools/run_benchmark.py --device <id> --no-perfetto

Output: benchmark_results_<timestamp>.md  (or --output <path>)

Requirements (pip install in your env):
    perfetto pandas numpy
"""

import argparse
import os
import platform
import re
import shutil
import subprocess
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).parent.parent
ADB  = (shutil.which('adb') or
        str(Path.home() / 'AppData/Local/Android/Sdk/platform-tools/adb.exe'))

DEVICE_TRACE = '/data/misc/perfetto-traces/bm.pb'
DEVICE_CFG   = '/data/misc/perfetto-configs/bm.pbtxt'
LOCAL_TRACE  = Path(os.environ.get('TEMP', '/tmp')) / 'bm_trace.pb'

PERFETTO_CFG = """\
buffers { size_kb: 16384 }
data_sources {
  config {
    name: "android.power"
    android_power_config {
      battery_poll_ms: 100
      collect_power_rails: true
      battery_counters: BATTERY_COUNTER_CURRENT
      battery_counters: BATTERY_COUNTER_CHARGE
      battery_counters: BATTERY_COUNTER_VOLTAGE
    }
  }
}
"""

_perfetto_proc: subprocess.Popen | None = None

_CPU_RAILS = ['CPU BIG (X4)', 'CPU MID (A720)', 'CPU MID-M', 'CPU LITTLE (A520)']

# Note: power.rails.tpu (S7M_VDD_TPU = Darwinn Edge TPU) counter does not
# increment during inference on Pixel 9 Pro — PMIC driver limitation.
# TPU power is root-protected. CPU rail drops are the best available proxy.
RAILS = {
    'power.rails.cpu.big':          'CPU BIG (X4)',
    'power.rails.cpu.mid':          'CPU MID (A720)',
    'power.rails.cpu.mid.mem':      'CPU MID-M',
    'power.rails.cpu.little':       'CPU LITTLE (A520)',
    'power.rails.gpu':              'GPU',
    'power.rails.memory.interface': 'RAM (MIF)',
    'power.rails.system.fabric':    'System fabric',
    'power.rails.display':          'Display',
    'power.rails.wifi.bt':          'WiFi / BT',
    'power.rails.modem':            'Modem',
}

RAILS_ORDER = [
    'CPU BIG (X4)', 'CPU MID (A720)', 'CPU MID-M', 'CPU LITTLE (A520)',
    'GPU', 'RAM (MIF)', 'System fabric', 'Display', 'WiFi / BT', 'Modem',
]


# ── ADB / Perfetto ─────────────────────────────────────────────────────────

def adb(*args, capture=False):
    cmd = [ADB] + list(args)
    return subprocess.run(cmd, text=True, capture_output=capture)


def perfetto_start():
    """Push config and start Perfetto as a foreground blocking process in a thread."""
    global _perfetto_proc
    # Push config.
    subprocess.run([ADB, 'shell', f'cat > {DEVICE_CFG}'],
                   input=PERFETTO_CFG, text=True, capture_output=True)
    # Kill any leftover instance.
    subprocess.run([ADB, 'shell', 'pkill -f "perfetto -c"'],
                   capture_output=True)
    time.sleep(0.3)
    # Start as foreground blocking process — Python holds the handle.
    _perfetto_proc = subprocess.Popen(
        [ADB, 'shell', f'perfetto -c {DEVICE_CFG} -o {DEVICE_TRACE} --txt'],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True,
    )
    time.sleep(0.8)  # Let Perfetto connect to traced.


def perfetto_stop_and_parse() -> dict:
    global _perfetto_proc
    if _perfetto_proc is None:
        return {}
    # Send SIGINT via adb to flush the trace gracefully.
    subprocess.run([ADB, 'shell', 'pkill -SIGINT -f "perfetto -c"'],
                   capture_output=True)
    try:
        out, _ = _perfetto_proc.communicate(timeout=5)
        if out and 'error' in out.lower():
            print(f'    [perfetto: {out.strip()[:120]}]')
    except subprocess.TimeoutExpired:
        _perfetto_proc.kill()
    _perfetto_proc = None
    time.sleep(0.5)

    res = adb('pull', DEVICE_TRACE, str(LOCAL_TRACE), capture=True)
    if res.returncode != 0:
        print(f'    [trace pull failed: {res.stderr.strip()}]')
        return {}
    try:
        sys.path.insert(0, str(Path(__file__).parent))
        from parse_trace import parse
        return parse(str(LOCAL_TRACE))
    except ModuleNotFoundError as e:
        print(f'    [ERROR: {e}]')
        print('    Run with: mamba run -n birdnet-inspect python tools/run_benchmark.py')
        return {}
    except Exception as e:
        print(f'    [trace parse error: {e}]')
        return {}


# ── Matrix ─────────────────────────────────────────────────────────────────

def build_matrix(big_cores: int) -> list[dict]:
    configs = []
    for t in range(1, big_cores + 1):
        configs.append({'label': f'CPU {t}T', 'provider': 'cpu', 'threads': t})
    configs += [
        {'label': 'XNNPACK',     'provider': 'xnnpack',        'threads': 0},
        {'label': 'Accelerated', 'provider': 'accelerated',    'threads': 0},
        {'label': 'NPU-only',    'provider': 'nnapi_npu_only', 'threads': 0},
    ]
    return configs


# ── Main ───────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-r', '--runs',      type=int, default=10)
    parser.add_argument('--warmup',          type=int, default=2)
    parser.add_argument('--big-cores',       type=int, default=4)
    parser.add_argument('--device', '-d',    type=str, default=None)
    parser.add_argument('--output', '-o',    type=str, default=None)
    parser.add_argument('--batches', '-b',   type=int, default=1,
                        help='Number of full sweeps through all configs (default: 1)')
    parser.add_argument('--pause',           type=int, default=10,
                        help='Pause between batches in seconds (default: 10)')
    parser.add_argument('--no-perfetto',     action='store_true')
    args = parser.parse_args()

    matrix = build_matrix(args.big_cores)
    use_perfetto = not args.no_perfetto
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    if args.output:
        out_dir = Path(args.output)
    else:
        out_dir = ROOT / 'benchmarks' / timestamp
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / 'results.md'

    print(f'Benchmark  →  {out_path.name}')
    print(f'Runs: {args.runs}  Warm-up: {args.warmup}  Big cores: {args.big_cores}')
    print(f'Perfetto: {"enabled" if use_perfetto else "disabled"}')
    print()

    # Build env for the single test run.
    env = os.environ.copy()
    env['BENCHMARK_RUNS']      = str(args.runs)
    env['BENCHMARK_WARMUP']    = str(args.warmup)
    env['BENCHMARK_BIG_CORES'] = str(args.big_cores)
    env['BENCHMARK_BATCHES']   = str(args.batches)
    env['BENCHMARK_PAUSE_S']   = str(args.pause)
    env['BENCHMARK_RANDOMIZE'] = '1'

    # Platform.environment is empty inside Android sandbox.
    # Write a JSON config file to the device that the test reads instead.
    import json as _json
    cfg = _json.dumps({
        'runs':      args.runs,
        'warmup':    args.warmup,
        'bigCores':  args.big_cores,
        'batches':   args.batches,
        'pauseSeconds': args.pause,
        'randomize': True,
    })
    subprocess.run([ADB, 'shell', f'echo \'{cfg}\' > /data/local/tmp/benchmark_config.json'],
                   capture_output=True)
    print(f'Config written to device: {cfg}')

    flutter = shutil.which('flutter') or shutil.which('flutter.bat') or 'flutter'
    cmd = [flutter, 'test',
           'integration_test/inference_benchmark_test.dart', '--no-pub']
    if args.device:
        cmd += ['--device-id', args.device]

    # Per (batch, config) results.
    # key = (batch_num, label)
    rail_results: dict[tuple, dict] = {}
    latency_results: dict[tuple, dict] = {}
    current_label: str | None = None
    current_batch: int = 1
    all_lines: list[str] = []

    proc = subprocess.Popen(
        cmd, env=env, cwd=ROOT,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding='utf-8', errors='replace', bufsize=1,
        shell=(platform.system() == 'Windows'),
    )

    for line in proc.stdout:
        print(line, end='')
        all_lines.append(line)
        stripped = line.strip()

        if stripped.startswith('BATCH_START:'):
            current_batch = int(stripped.split(':')[1])
            print(f'\n[Batch {current_batch}]')

        elif stripped.startswith('BATCH_PAUSE:'):
            secs = stripped.split(':')[1]
            print(f'  [pausing {secs}s for thermals to settle…]')

        elif stripped.startswith('BENCHMARK_START:'):
            parts = stripped.split(':')
            current_label = parts[1]
            if use_perfetto:
                print(f'  [perfetto start → {current_label} batch={current_batch}]')
                perfetto_start()

        elif stripped.startswith('BENCHMARK_END:'):
            parts = stripped.split(':')
            label = parts[1]
            key = (current_batch, label)
            if use_perfetto and label == current_label:
                print(f'  [perfetto stop  → {label}]')
                rails = perfetto_stop_and_parse()
                rail_results[key] = rails
                if rails:
                    cpu   = sum(rails.get(r, 0) for r in _CPU_RAILS)
                    total = rails.get('_total_power_mw')
                    total_str = f'  |  Total ~{total:.0f} mW' if total else ''
                    print(f'  → CPU {cpu:.0f} mWs{total_str}  (TPU rail not measurable)')
            current_label = None

        elif '✓ avg=' in stripped:
            m = re.search(r'avg=(\d+)ms', stripped)
            if m and current_label:
                key = (current_batch, current_label)
                latency_results.setdefault(key, {})['avg_ms'] = int(m.group(1))

    proc.wait()

    # Parse min/max from each batch's table output.
    full_output = ''.join(all_lines)
    label_set = {c['label'] for c in matrix}
    # The test prints one table at the end covering all results.
    # We'll rely on per-batch avg captured above; min/max from overall table.
    for m in re.finditer(
        r'\|\s*([^\|]+?)\s*\|\s*([\d.]+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|',
        full_output,
    ):
        label = m.group(1).strip()
        if label in label_set:
            # Store under (0, label) as "all-batch" aggregate from test output.
            key = (0, label)
            latency_results.setdefault(key, {}).update(
                avg_ms=float(m.group(2)),
                min_ms=int(m.group(3)),
                max_ms=int(m.group(4)),
            )

    # Save raw data as JSON for statistical analysis.
    import json as _json
    raw_data = {
        'matrix': matrix,
        'batches': args.batches,
        'runs': args.runs,
        'latency': {f'{k[0]}:{k[1]}': v for k, v in latency_results.items()},
        'rails':   {f'{k[0]}:{k[1]}': v for k, v in rail_results.items()},
    }
    json_path = out_dir / 'results.json'
    json_path.write_text(_json.dumps(raw_data, indent=2), encoding='utf-8')

    table = build_table(matrix, latency_results, rail_results,
                        args.runs, args.warmup, args.batches)
    print('\n' + table)
    out_path.write_text(table, encoding='utf-8', newline='\n')

    # Auto-generate charts and stats into the same folder.
    try:
        sys.path.insert(0, str(Path(__file__).parent))
        from analyze_benchmark import (plot_latency_boxplot, plot_latency_per_batch,
                                        plot_cpu_power_stacked, plot_total_power,
                                        write_stats_md, load)
        data = load(str(json_path))
        stem = out_dir / 'results'
        print('\nGenerating charts…')
        plot_latency_boxplot(data,   out_dir / 'latency_boxplot.png')
        plot_latency_per_batch(data, out_dir / 'latency_per_batch.png')
        plot_cpu_power_stacked(data, out_dir / 'cpu_power_stacked.png')
        plot_total_power(data,       out_dir / 'total_power.png')
        write_stats_md(data,         out_dir / 'stats.md')
    except Exception as e:
        print(f'  [charts skipped: {e}]')

    print(f'\nAll output in: {out_dir}')


# ── Table ──────────────────────────────────────────────────────────────────

def _cpu_total(rails: dict) -> float | None:
    vals = [rails[r] for r in _CPU_RAILS if r in rails]
    return sum(vals) if vals else None


def _agg_latency(latencies: dict, label: str) -> dict:
    """Aggregate per-batch latency entries for a label."""
    avgs = [v['avg_ms'] for k, v in latencies.items()
            if isinstance(k, tuple) and k[1] == label and 'avg_ms' in v]
    mins = [v['min_ms'] for k, v in latencies.items()
            if isinstance(k, tuple) and k[1] == label and 'min_ms' in v]
    maxs = [v['max_ms'] for k, v in latencies.items()
            if isinstance(k, tuple) and k[1] == label and 'max_ms' in v]
    # Fallback: test's own summary stored under key (0, label)
    fallback = latencies.get((0, label), {})
    if not avgs and fallback:
        return fallback
    if not avgs:
        return {}
    return {
        'avg_ms': sum(avgs) / len(avgs),
        'min_ms': min(mins) if mins else min(avgs),
        'max_ms': max(maxs) if maxs else max(avgs),
    }


def _agg_rails(rails_by_label: dict, label: str) -> dict:
    """Average per-rail energy across all batches for a label."""
    from collections import defaultdict
    sums: dict = defaultdict(list)
    for k, v in rails_by_label.items():
        if isinstance(k, tuple) and k[1] == label:
            for rail, val in v.items():
                sums[rail].append(val)
    return {r: sum(vs) / len(vs) for r, vs in sums.items() if vs}


def build_table(matrix, latencies, rails_by_label, runs, warmup, batches=1) -> str:
    now = datetime.now()

    # Aggregate across batches for lookup.
    agg_rails = {cfg['label']: _agg_rails(rails_by_label, cfg['label']) for cfg in matrix}
    has_perfetto = any(agg_rails.values())

    active_cpu = [r for r in _CPU_RAILS
                  if any(agg_rails.get(cfg['label'], {}).get(r) for cfg in matrix)]
    extra = [r for r in RAILS_ORDER
             if r not in _CPU_RAILS
             and any(agg_rails.get(cfg['label'], {}).get(r) for cfg in matrix)]

    has_total_power = any(
        agg_rails.get(cfg['label'], {}).get('_total_power_mw')
        for cfg in matrix
    )
    cols = ['Configuration', 'Avg (ms)', 'Min', 'Max', 'RT ×']
    if has_perfetto:
        if has_total_power:
            cols += ['Total (mW)']
        cols += ['CPU total (mWs)'] + active_cpu + extra

    sep = [':-' + '-' * max(1, len(c) - 2) + '-' for c in cols]

    buf = [
        '## Inference Benchmark',
        (f'{now.year}-{now.month:02d}-{now.day:02d} {now.hour:02d}:{now.minute:02d}'
         f'  ·  {runs} runs + {warmup} warm-up'
         + (f'  ·  {batches} batches' if batches > 1 else '')),
        '',
        '| ' + ' | '.join(cols) + ' |',
        '|' + '|'.join(sep) + '|',
    ]

    for cfg in matrix:
        label = cfg['label']
        stats = _agg_latency(latencies, label)
        rails = agg_rails.get(label, {})

        if not stats:
            buf.append('| ' + ' | '.join([label, '❌', '—', '—', '—'] +
                                          ['—'] * (len(cols) - 5)) + ' |')
            continue

        avg = stats.get('avg_ms', 0)
        mn  = stats.get('min_ms', '—')
        mx  = stats.get('max_ms', '—')
        rt  = f'{3000 / avg:.1f}×' if avg else '—'
        row = [label, f'{avg:.0f}', str(mn), str(mx), rt]

        if has_perfetto:
            if has_total_power:
                total = rails.get('_total_power_mw')
                row.append(f'{total:.0f}' if total else '—')
            cpu = _cpu_total(rails)
            row.append(f'{cpu:.0f}' if cpu is not None else '—')
            for r in active_cpu:
                v = rails.get(r)
                row.append(f'{v:.0f}' if v else '—')
            for r in extra:
                v = rails.get(r)
                row.append(f'{v:.0f}' if v else '—')

        buf.append('| ' + ' | '.join(row) + ' |')

    if has_perfetto:
        buf.append('')
        buf.append('> **Note on TPU power**: The Tensor G4 Edge TPU (Darwinn / `S7M_VDD_TPU`) '
                   'handles NPU-only inference, but its power rail counter does not increment '
                   'during active inference on this device — a PMIC driver limitation. '
                   'CPU BIG energy drop (−80% in NPU-only) is the best available proxy for '
                   'TPU activity. TPU power data requires root access.')

    return '\n'.join(buf) + '\n'


if __name__ == '__main__':
    main()
