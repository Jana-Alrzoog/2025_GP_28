# sim_core.py
# ============================================================
# Core simulator: loads data + provides snapshot functions
# ============================================================

import os
import json
import yaml
import csv
from datetime import datetime, timezone, timedelta

import numpy as np
import pandas as pd

# ------------------------------------------------------------
# Project paths (relative to this file, NOT /content)
# ------------------------------------------------------------
ROOT = os.path.dirname(os.path.abspath(__file__))
SEED = os.path.join(ROOT, "data", "seeds")
CONF = os.path.join(ROOT, "sims", "00_config.yaml")
OUT_DIR = os.path.join(ROOT, "data", "generated")
os.makedirs(OUT_DIR, exist_ok=True)

# ------------------------------------------------------------
# Load global configuration (headway patterns, multipliers, etc.)
# ------------------------------------------------------------
config = {}
if os.path.exists(CONF):
    with open(CONF, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f) or {}

print("Loaded config keys:", list(config.keys()))

# ============================================================
# 1) Load base-day template (station_id, minute_of_day, base_demand)
# ============================================================

candidates = [
    os.path.join(OUT_DIR, "day_base.csv"),
    os.path.join(OUT_DIR, "base_day.csv"),
    os.path.join(ROOT, "data", "base", "day_base.csv"),
    os.path.join(ROOT, "data", "base", "base_day.csv"),
]
src = next((p for p in candidates if os.path.exists(p)), None)
if src is None:
    raise FileNotFoundError("No base-day CSV found.")

base_day = pd.read_csv(src)
print("Loaded base-day from:", src, "| rows:", len(base_day))

# Normalize header names
base_day.columns = [str(c).strip().lower() for c in base_day.columns]

rename_map = {
    "station": "station_id",
    "station_code": "station_id",
    "sid": "station_id",
    "base": "base_demand",
    "base_day": "base_demand",
    "demand_base": "base_demand",
    "minute": "minute_of_day",
    "min": "minute_of_day",
}
base_day = base_day.rename(columns=rename_map)

# Build minute_of_day if missing
if "minute_of_day" not in base_day.columns:
    if {"hour", "minute"}.issubset(base_day.columns):
        base_day["minute_of_day"] = (
            pd.to_numeric(base_day["hour"], errors="coerce").fillna(0).astype(int) * 60
            + pd.to_numeric(base_day["minute"], errors="coerce").fillna(0).astype(int)
        )
    elif "time" in base_day.columns:
        t = pd.to_datetime(base_day["time"], errors="coerce")
        base_day["minute_of_day"] = (t.dt.hour * 60 + t.dt.minute).astype(int)
    elif "timestamp" in base_day.columns:
        ts = pd.to_datetime(base_day["timestamp"], errors="coerce")
        base_day["minute_of_day"] = (ts.dt.hour * 60 + ts.dt.minute).astype(int)
    else:
        base_day = base_day.reset_index().rename(columns={"index": "minute_of_day"})
        base_day["minute_of_day"] = base_day["minute_of_day"].clip(0, 1439).astype(int)

# Validate required columns
required_cols = ["station_id", "base_demand", "minute_of_day"]
for c in required_cols:
    if c not in base_day.columns:
        raise KeyError(f"Missing required column '{c}'.")

# Clean final columns
base_day["station_id"] = base_day["station_id"].astype(str).str.strip()
base_day["base_demand"] = pd.to_numeric(base_day["base_demand"], errors="coerce").fillna(0.0)
base_day["minute_of_day"] = (
    pd.to_numeric(base_day["minute_of_day"], errors="coerce").fillna(0).astype(int)
)

print("base_day ready with:", base_day.columns.tolist())

# ------------------------------------------------------------
# Riyadh timezone (UTC+3)
# ------------------------------------------------------------
RIYADH_TZ = timezone(timedelta(hours=3))

# ============================================================
# 2) Load stations & basic capacity metadata
# ============================================================

STATIONS_PATH = os.path.join(SEED, "stations.json")

if not os.path.exists(STATIONS_PATH):
    raise FileNotFoundError(f"stations.json not found at: {STATIONS_PATH}")

with open(STATIONS_PATH, "r", encoding="utf-8") as f:
    stations_list = json.load(f)

print(f"Loaded {len(stations_list)} stations")

stations_df = pd.json_normalize(stations_list)

# Ensure required capacity fields
if "capacity_station" not in stations_df.columns:
    stations_df["capacity_station"] = 2000

capacity_df = stations_df[["station_id", "capacity_station"]].copy()
print("capacity_df ready:", capacity_df.shape)

station_ids = capacity_df["station_id"].astype(str).unique().tolist()
print("Station IDs loaded:", station_ids)

# ============================================================
# 3) Load Events + Holiday + Multipliers
# ============================================================

EVENTS_CSV = os.path.join(SEED, "calendar_events.csv")
HOLIDAYS_CSV = os.path.join(SEED, "holidays.csv")


def norm_date(x: str) -> str:
    """Normalize date to 'YYYY-MM-DD' string or '' if invalid."""
    if x is None:
        return ""
    s = str(x).strip()
    if not s:
        return ""
    d = pd.to_datetime(s, errors="coerce", dayfirst=False)
    if pd.isna(d):
        d = pd.to_datetime(s, errors="coerce", dayfirst=True)
    return "" if pd.isna(d) else d.strftime("%Y-%m-%d")


# Load Holidays
holiday_dates = set()
if os.path.exists(HOLIDAYS_CSV):
    df_h = pd.read_csv(HOLIDAYS_CSV)
    for x in df_h[df_h.columns[0]].tolist():
        holiday_dates.add(norm_date(x))

print("Holiday dates loaded:", len(holiday_dates))

# Load Calendar Events
event_rows = []
if os.path.exists(EVENTS_CSV):
    with open(EVENTS_CSV, "r", encoding="utf-8") as f:
        rdr = csv.DictReader(f)
        for r in rdr:
            event_rows.append(
                {
                    "date": norm_date(r.get("date", "")),
                    "event_type": (r.get("event_type") or r.get("type") or "Other").strip(),
                    "stations_impacted": (r.get("stations_impacted") or "*").strip(),
                    "demand_modifier": float((r.get("demand_modifier") or 1.0)),
                }
            )

print("Loaded events:", len(event_rows))

GLOBAL_EVENT_TYPES = {"SaudiNationalDay"}  # example

event_types_map = {}  # (date, station_id) -> set(types)
event_mult_override = {}  # (date, station_id) -> multiplier
global_event_types_by_date = {}  # date -> set(types)
global_event_mult_by_date = {}  # date -> multiplier


def _norm(x):
    return str(x).strip().upper()


for e in event_rows:
    d = e["date"]
    if not d:
        continue

    etype = e["event_type"]
    dm = float(e["demand_modifier"])
    tokens = [t.strip() for t in e["stations_impacted"].split(";")]

    is_global = (etype in GLOBAL_EVENT_TYPES) or any(
        _norm(t) in {"*", "ALL", "ALL STATIONS"} for t in tokens
    )

    if is_global:
        global_event_types_by_date.setdefault(d, set()).add(etype)
        global_event_mult_by_date[d] = global_event_mult_by_date.get(d, 1.0) * dm

    for tok in tokens:
        if _norm(tok) in {"*", "ALL", "ALL STATIONS"}:
            continue

        sid = tok.strip()
        key = (d, sid)

        event_types_map.setdefault(key, set()).add(etype)
        event_mult_override[key] = event_mult_override.get(key, 1.0) * dm


def list_event_types(date_str, station_id):
    """Return list of event types for a given date & station."""
    types = set()
    key = (date_str, station_id)

    if key in event_types_map:
        types |= event_types_map[key]

    if date_str in global_event_types_by_date:
        types |= global_event_types_by_date[date_str]

    return sorted(types)


def event_csv_multiplier(date_str, station_id):
    """Return final event multiplier after combining local + global."""
    m = 1.0
    key = (date_str, station_id)

    if key in event_mult_override:
        m *= event_mult_override[key]

    if date_str in global_event_mult_by_date:
        m *= global_event_mult_by_date[date_str]

    return float(m)

# ============================================================
# 4) On-Demand Snapshot Generator (Capacity-Based)
# ============================================================

BASE_COL = "base_demand_norm" if "base_demand_norm" in base_day.columns else "base_demand"


def get_base_ratio(station_id, minute_of_day):
    """Look up the base demand ratio (0..1) for a given station & minute."""
    row = base_day[
        (base_day["station_id"] == station_id)
        & (base_day["minute_of_day"] == minute_of_day)
    ]
    if len(row) == 0:
        return 0.0
    return float(row[BASE_COL].iloc[0])


def get_capacity(station_id):
    """Return total station capacity for a given station."""
    row = capacity_df[capacity_df["station_id"] == station_id]
    if len(row) == 0:
        return 0.0
    return float(row["capacity_station"].iloc[0] or 0.0)


def demand_noise(mult=0.05):
    """Small multiplicative noise in [1-mult, 1+mult]."""
    return 1.0 + np.random.uniform(-mult, mult)


def classify_from_cap(station_total, capacity_station):
    """
    Classify crowding level based on utilization ratio (passengers / capacity).
    """
    if capacity_station <= 0:
        return "Medium", 0.0

    r = station_total / capacity_station

    if r < 0.30:
        level = "Low"
    elif r < 0.60:
        level = "Medium"
    elif r < 1.00:
        level = "High"
    else:
        level = "Extreme"

    return level, r


NORMAL_PEAK_UTIL = 0.85
CAP_BOOST_EVENT = 1.25


def make_snapshot_for_station(station_id, dt):
    """
    Build an on-demand snapshot for a single station at a given datetime.
    """
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=RIYADH_TZ)

    date_str = dt.strftime("%Y-%m-%d")
    minute_of_day = dt.hour * 60 + dt.minute

    base_ratio = get_base_ratio(station_id, minute_of_day)
    event_mult = event_csv_multiplier(date_str, station_id)
    holiday_mult = 0.7 if date_str in holiday_dates else 1.0
    noise = demand_noise(0.05)

    effective_ratio = base_ratio * event_mult * holiday_mult * noise
    effective_ratio = max(effective_ratio, 0.0)

    cap = get_capacity(station_id)
    station_total_raw = effective_ratio * cap

    ev_types = list_event_types(date_str, station_id)
    has_event = len(ev_types) > 0

    if has_event:
        cap_limit = cap * CAP_BOOST_EVENT
    else:
        cap_limit = cap * NORMAL_PEAK_UTIL

    station_total = min(station_total_raw, cap_limit)
    crowd_level, load_ratio = classify_from_cap(station_total, cap)

    return {
        "timestamp": dt.isoformat(),
        "station_id": station_id,
        "station_total": int(round(station_total)),
        "capacity_station": int(cap),
        "load_ratio": round(load_ratio, 3),
        "crowd_level": crowd_level,
        "events": ev_types,
    }


def generate_all_stations_snapshot(dt=None):
    """
    Generates a snapshot for all stations at the same datetime.
    Useful when the user opens the app (initial load).
    """
    if dt is None:
        dt = datetime.now(RIYADH_TZ)

    snapshots = []
    for sid in capacity_df["station_id"].unique():
        snap = make_snapshot_for_station(sid, dt)
        snapshots.append(snap)

    return snapshots


if __name__ == "__main__":
    # Optional local test
    now_riyadh = datetime.now(RIYADH_TZ)
    print("Test snapshot S1:", make_snapshot_for_station("S1", now_riyadh))
    all_now = generate_all_stations_snapshot()
    print("Total stations snapshot:", len(all_now))
