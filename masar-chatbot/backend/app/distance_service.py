# app/distance_service.py
from typing import Dict, Any, Optional, Tuple
import os
import time
import requests

GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY", "")

DM_URL = "https://maps.googleapis.com/maps/api/distancematrix/json"


def _call_distance_matrix(
    origin: Tuple[float, float],
    destination: Tuple[float, float],
    mode: str,
    *,
    departure_time: Optional[int] = None,  # unix seconds (for driving traffic)
) -> Optional[Dict[str, Any]]:
    """
    Calls Google Distance Matrix and returns the first element (rows[0].elements[0]) if OK.
    mode: walking | driving
    """
    if not GOOGLE_MAPS_API_KEY:
        return None

    params: Dict[str, Any] = {
        "origins": f"{origin[0]},{origin[1]}",
        "destinations": f"{destination[0]},{destination[1]}",
        "mode": mode,  # walking | driving
        "key": GOOGLE_MAPS_API_KEY,
        "language": "ar",
        "region": "sa",
        "units": "metric",
    }

    # For driving: allow traffic-aware ETA (duration_in_traffic)
    if departure_time is not None:
        params["departure_time"] = int(departure_time)

    r = requests.get(DM_URL, params=params, timeout=10)
    r.raise_for_status()
    data = r.json()

    # Top-level status
    if data.get("status") != "OK":
        return None

    rows = data.get("rows") or []
    if not rows:
        return None

    elements = rows[0].get("elements") or []
    if not elements:
        return None

    el = elements[0]
    if el.get("status") != "OK":
        return None

    # Must have distance + duration at least
    if "distance" not in el or "duration" not in el:
        return None

    return el


def _pack_result(el: Dict[str, Any], *, prefer_traffic: bool = False) -> Dict[str, Any]:
    """
    Converts a DistanceMatrix element into a compact payload.
    prefer_traffic: if True and duration_in_traffic exists, use it as primary duration.
    """
    distance = el.get("distance") or {}
    duration = el.get("duration") or {}

    # Traffic duration is only expected for driving with departure_time
    dur_traffic = el.get("duration_in_traffic") if prefer_traffic else None
    dur_used = dur_traffic if (isinstance(dur_traffic, dict) and "value" in dur_traffic) else duration

    dist_m = int(distance.get("value") or 0)
    dur_s = int(dur_used.get("value") or 0)

    return {
        "duration_min": int(round(dur_s / 60.0)),
        "duration_sec": dur_s,
        "duration_text": str(dur_used.get("text") or "").strip(),
        "distance_m": dist_m,
        "distance_text": str(distance.get("text") or "").strip(),
    }


def get_walk_drive(
    origin: Tuple[float, float],
    destination: Tuple[float, float],
    *,
    include_traffic_for_drive: bool = True,
) -> Dict[str, Any]:
    """
    Returns:
      {
        "walk":  {"duration_min": int, "distance_m": int, "duration_text": str, "distance_text": str, "duration_sec": int} | None,
        "drive": {"duration_min": int, "distance_m": int, "duration_text": str, "distance_text": str, "duration_sec": int} | None
      }

    Notes:
    - Always attempts both walking and driving.
    - Driving will try to use traffic-aware ETA if include_traffic_for_drive=True.
    """
    out: Dict[str, Any] = {"walk": None, "drive": None}

    # Walking
    try:
        w = _call_distance_matrix(origin, destination, "walking")
        if w:
            out["walk"] = _pack_result(w, prefer_traffic=False)
    except Exception:
        pass

    # Driving (traffic-aware if enabled)
    try:
        dep = int(time.time()) if include_traffic_for_drive else None
        d = _call_distance_matrix(origin, destination, "driving", departure_time=dep)
        if d:
            # prefer traffic duration if exists
            out["drive"] = _pack_result(d, prefer_traffic=True)
    except Exception:
        pass

    return out