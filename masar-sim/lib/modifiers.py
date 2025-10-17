# masar-sim/lib/modifiers.py

from typing import Any, Dict, List

# ---------- Helpers ----------

def _match_station(sta: Dict[str, Any], key: Any) -> bool:
    k = str(key).upper()
    return (
        str(sta.get("station_id", "")).upper() == k
        or str(sta.get("code", "")).upper() == k
    )

def _get_station(seeds: Dict[str, Any], key: Any) -> Dict[str, Any]:
    for s in seeds.get("stations", []):
        if _match_station(s, key):
            return s
    raise ValueError(f"Station not found: {key}")

def _first_number(*vals, default=None):
    """Return first value that is int/float from a list of candidates."""
    for v in vals:
        if isinstance(v, (int, float)):
            return v
        # strings that look like numbers
        try:
            return float(v)
        except Exception:
            pass
    return default

def _station_scale_from_capacity(stations: List[Dict[str, Any]], rec: Dict[str, Any]) -> float:
    """
    Compute relative station scale versus the mean capacity across stations.
    Supports multiple schema variants for capacity keys.
    """
    # possible capacity field names we may see
    cand_keys = ["capacity_platform", "peak_capacity", "platform_capacity", "peak_cap"]

    def cap_of(r):
        return _first_number(*[r.get(k) for k in cand_keys])

    caps = [cap_of(r) for r in stations]
    caps = [c for c in caps if isinstance(c, (int, float))]

    mean_cap = (sum(caps) / len(caps)) if caps else 1500.0
    station_cap = cap_of(rec)
    if not isinstance(station_cap, (int, float)):
        station_cap = mean_cap

    return (float(station_cap) / float(mean_cap)) if mean_cap > 0 else 1.0

# ---------- Core ----------

def compute_demand_modifier(ts, station_key, seeds: Dict[str, Any], config: Dict[str, Any]) -> Dict[str, Any]:
    """
    Return multiplicative modifier given timestamp, station, and seeds/config.
    Safe defaults are used if any sections are missing.
    """
    date_str = ts.date().isoformat()
    weekday  = ts.weekday()  # Monday=0 ... Sunday=6

    # Safe lookups
    stations = seeds.get("stations", [])
    weather_seed = seeds.get("weather", {}) or {}
    events_seed  = seeds.get("events", [])  or []
    holidays_seed= seeds.get("holidays", []) or []

    multipliers  = config.get("multipliers", {}) or {}
    weather_map  = multipliers.get("weather", {}) or {}
    events_map   = multipliers.get("events", {}) or {}

    # Station + relative scale
    st = _get_station(seeds, station_key)
    station_scale = _station_scale_from_capacity(stations, st)

    # Weekend (Fri=4, Sat=5) for KSA
    weekend_base = float(multipliers.get("weekend", 1.0))
    weekend_mult = weekend_base if weekday in [4, 5] else 1.0

    # Weather
    w = weather_seed.get(date_str, {"condition": "Sunny"})
    weather_cond = w.get("condition", "Sunny") if isinstance(w, dict) else str(w)
    weather_mult = float(weather_map.get(weather_cond, 1.0))

    # Events (match by station_id/code + date)
    sid   = str(st.get("station_id", "")).upper()
    scode = str(st.get("code", "")).upper()
    event_mult = 1.0

    for ev in events_seed:
        ev_station_raw = str(
            ev.get("station_id") or ev.get("station") or ev.get("station_code") or ""
        ).strip().upper()

        is_citywide = ev_station_raw in {"", "ALL", "CITY", "CITYWIDE"}

        if ev.get("date") == date_str and (is_citywide or ev_station_raw in {sid, scode}):
            et = ev.get("event_type", "Other")
            event_mult = max(event_mult, float(events_map.get(et, 1.0)))


    # Holiday
    holiday_mult = float(multipliers.get("holiday", 1.0))
    for hol in holidays_seed:
        if hol.get("date") == date_str:
            try:
                holiday_mult = float(hol.get("demand_modifier", holiday_mult))
            except Exception:
                pass

    final = station_scale * weekend_mult * weather_mult * event_mult * holiday_mult

    return {
        "station": scode or sid,
        "date": date_str,
        "weather": weather_cond,
        "station_scale": station_scale,
        "weekend_mult": weekend_mult,
        "weather_mult": weather_mult,
        "event_mult": event_mult,
        "holiday_mult": holiday_mult,
        "final_demand_modifier": final,
    }

