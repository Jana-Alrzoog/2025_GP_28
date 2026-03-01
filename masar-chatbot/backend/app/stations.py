import json
import math
import os
from typing import Any, Dict, List, Optional, Tuple

LINE_META = {
    "Line1": {"name_en": "Blue line",   "name_ar": "المسار الأزرق",   "color": "#0077C8", "icon": "line_blue"},
    "Line2": {"name_en": "Red line",    "name_ar": "المسار الأحمر",   "color": "#E10600", "icon": "line_red"},
    "Line3": {"name_en": "Orange line", "name_ar": "المسار البرتقالي","color": "#F57C00", "icon": "line_orange"},
    "Line4": {"name_en": "Yellow line", "name_ar": "المسار الأصفر",   "color": "#FBC02D", "icon": "line_yellow"},
    "Line5": {"name_en": "Green line",  "name_ar": "المسار الأخضر",   "color": "#2E7D32", "icon": "line_green"},
    "Line6": {"name_en": "Purple line", "name_ar": "المسار البنفسجي", "color": "#6A1B9A", "icon": "line_purple"},
}

def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Distance (km) between two lat/lon points."""
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlmb/2)**2
    return 2 * R * math.asin(math.sqrt(a))

def load_stations(path: str) -> List[Dict[str, Any]]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def _station_lat_lon(st: Dict[str, Any]) -> Optional[Tuple[float, float]]:
    # Prefer geo_point_2d if present
    gp = st.get("geo_point_2d")
    if isinstance(gp, dict) and "lat" in gp and "lon" in gp:
        return float(gp["lat"]), float(gp["lon"])

    # Fallback to geoshape.geometry.coordinates [lon, lat]
    geo = st.get("geoshape", {}).get("geometry", {})
    coords = geo.get("coordinates")
    if isinstance(coords, list) and len(coords) >= 2:
        lon, lat = coords[0], coords[1]
        return float(lat), float(lon)

    return None

def find_nearest_station(
    user_lat: float,
    user_lon: float,
    stations: List[Dict[str, Any]],
    same_line_only: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    """
    Returns the nearest station record (+distance_km).
    same_line_only: e.g. "Line1" to restrict search (optional)
    """
    best = None
    best_d = float("inf")

    for st in stations:
        if same_line_only and st.get("metroline") != same_line_only:
            continue

        latlon = _station_lat_lon(st)
        if not latlon:
            continue

        lat, lon = latlon
        d = _haversine_km(user_lat, user_lon, lat, lon)
        if d < best_d:
            best_d = d
            best = st

    if not best:
        return None

    # attach distance + line meta
    line_id = best.get("metroline")
    meta = LINE_META.get(line_id, {})
    return {
        "metrostationcode": best.get("metrostationcode"),
        "name_en": best.get("metrostationname"),
        "name_ar": best.get("metrostationnamear"),
        "line_id": line_id,
        "line_name_en": best.get("metrolinename") or meta.get("name_en"),
        "line_name_ar": best.get("metrolinenamear") or meta.get("name_ar"),
        "line_color": meta.get("color"),
        "line_icon": meta.get("icon"),
        "stationseq": best.get("stationseq"),
        "distance_km": round(best_d, 3),
        "lat": _station_lat_lon(best)[0],
        "lon": _station_lat_lon(best)[1],
    }