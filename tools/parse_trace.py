"""
Parse a Perfetto power trace and return per-rail energy deltas + total power.

Call parse(trace_path) → dict with:
  - per-rail labels → energy in mWs
  - '_total_power_mw'  → average total device power draw in mW (from battery current)
  - '_duration_s'      → measurement window duration in seconds
"""
from perfetto.trace_processor import TraceProcessor

# Rails to include in benchmark output, with display labels.
# Values are cumulative µWs (microWatt-seconds) — delta = energy consumed.
RAILS = {
    'power.rails.cpu.big':          'CPU BIG (X4)',
    'power.rails.cpu.mid':          'CPU MID (A720)',
    'power.rails.cpu.mid.mem':      'CPU MID-M',
    'power.rails.cpu.little':       'CPU LITTLE (A520)',
    # power.rails.tpu (S7M_VDD_TPU = Darwinn Edge TPU) counter does not
    # increment during inference on Pixel 9 Pro — omitted from output.
    'power.rails.gpu':              'GPU',
    'power.rails.memory.interface': 'RAM (MIF)',
    'power.rails.system.fabric':    'System fabric',
    'power.rails.display':          'Display',
    'power.rails.wifi.bt':          'WiFi / BT',
    'power.rails.modem':            'Modem',
}


def parse(trace_path: str) -> dict:
    """Return {label: delta_mWs, '_total_power_mw': float, '_duration_s': float}."""
    tp = TraceProcessor(trace=trace_path)
    try:
        # Per-rail energy deltas (cumulative µWs counters).
        rows = tp.query("""
            SELECT
                ct.name AS track,
                MAX(c.value) - MIN(c.value) AS delta_uws
            FROM counter_track AS ct
            JOIN counter AS c ON ct.id = c.track_id
            GROUP BY ct.name
        """).as_pandas_dataframe()

        # Battery current (µA) and voltage (µV or mV depending on device).
        # batt.current_ua is instantaneous; we average all samples.
        batt = tp.query("""
            SELECT
                ct.name AS track,
                AVG(ABS(c.value)) AS avg_val,
                COUNT(*) AS n,
                (MAX(ts) - MIN(ts)) / 1e9 AS duration_s
            FROM counter_track AS ct
            JOIN counter AS c ON ct.id = c.track_id
            WHERE ct.name IN ('batt.current_ua', 'batt.voltage_uv',
                              'batt.charge_uah')
            GROUP BY ct.name
        """).as_pandas_dataframe()

    finally:
        tp.close()

    result = {}
    for _, row in rows.iterrows():
        label = RAILS.get(row['track'])
        if label:
            result[label] = row['delta_uws'] / 1000.0  # µWs → mWs

    # Compute total average power from battery current × voltage.
    duration_s = 0.0
    avg_current_ua = None
    avg_voltage_uv = None

    for _, row in batt.iterrows():
        if row['track'] == 'batt.current_ua':
            avg_current_ua = row['avg_val']
            duration_s = row['duration_s']
        elif row['track'] == 'batt.voltage_uv':
            avg_voltage_uv = row['avg_val']

    if avg_current_ua is not None and avg_voltage_uv is not None and avg_voltage_uv > 0:
        # µA × µV / 1e12 = W  →  × 1000 = mW
        result['_total_power_mw'] = (avg_current_ua * avg_voltage_uv) / 1e9
    elif avg_current_ua is not None:
        # Fallback: assume ~3.8V nominal if voltage not available
        result['_total_power_mw'] = avg_current_ua * 3800 / 1e6

    result['_duration_s'] = duration_s
    return result


def print_table(rails: dict):
    total = rails.get('_total_power_mw')
    dur   = rails.get('_duration_s', 0)
    if total:
        print(f"\n  Total avg power: {total:.0f} mW  (over {dur:.1f}s)")
    print(f"\n  {'Rail':<22} {'Energy (mWs)':>14}")
    print(f"  {'─'*22}  {'─'*14}")
    for label, mws in sorted(
        ((k, v) for k, v in rails.items() if not k.startswith('_')),
        key=lambda x: -x[1]
    ):
        print(f"  {label:<22}  {mws:>14.1f}")


if __name__ == '__main__':
    import sys
    path = sys.argv[1] if len(sys.argv) > 1 else r'C:/Users/JB/AppData/Local/Temp/pwr.pb'
    rails = parse(path)
    print_table(rails)
