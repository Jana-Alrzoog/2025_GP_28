from __future__ import annotations

from typing import List, Dict, Any, Optional
from datetime import datetime, timezone

from app.firestore import get_db

# ----------------------------
# Helpers
# ----------------------------
def _to_utc(dt: datetime) -> datetime:
    """
    Ensure datetime is timezone-aware in UTC.
    If a naive datetime is passed, it is assumed to be UTC.
    """
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _hhmm(s: Optional[str]) -> str:
    """Return HH:MM from strings like HH:MM:SS."""
    if not s:
        return "--:--"
    s = str(s).strip()
    return s[:5] if len(s) >= 5 else s


def _safe_str(x: Any, default: str = "") -> str:
    if x is None:
        return default
    return str(x)


# Simple line -> color map
LINE_COLORS = {
    "Blue":   "#0057FF",
    "Red":    "#FF2D2D",
    "Orange": "#FF8A00",
    "Green":  "#00A86B",
    "Purple": "#7C3AED",
}


def _line_color(line_id: Optional[str]) -> str:
    key = _safe_str(line_id).strip()
    return LINE_COLORS.get(key, "#3B82F6")


# ----------------------------
# New API (Recommended)
# ----------------------------
def fetch_next_trips_for_station(
    station_id: str,
    *,
    dt: Optional[datetime] = None,
    limit: int = 4,
) -> List[Dict[str, Any]]:
    """
    Collection Group:
      trips_month/{YYYY-MM}/trips/{tripDoc}/stops/{stopDoc}

    stop doc fields:
      - station_id ✅
      - arrival_timestamp (Firestore Timestamp)
      - arrival_time ("HH:MM:SS")
      - direction_id ("0"/"1")
      - line_id ("Blue"/...)
      - trip_id (...)
    """
    if not station_id or not isinstance(station_id, str):
        return []

    now = _to_utc(dt or datetime.now(timezone.utc))
    db = get_db()

    q = (
        db.collection_group("stops")
        .where("station_id", "==", station_id)
        .where("arrival_timestamp", ">=", now)
        .order_by("arrival_timestamp")
        .limit(max(0, int(limit)))
    )

    stop_snaps = list(q.stream())

    results: List[Dict[str, Any]] = []
    for sd in stop_snaps:
        stop = sd.to_dict() or {}

        # parent trip doc:
        # .../trips_month/{month}/trips/{tripDoc}/stops/{stopDoc}
        trip_ref = sd.reference.parent.parent
        trip = (trip_ref.get().to_dict() or {}) if trip_ref else {}

        line_id = stop.get("line_id") or trip.get("line_id") or ""
        direction_id = stop.get("direction_id") or trip.get("direction_id") or "0"

        # اسم الرحلة/الوجهة
        trip_headsign = (
            trip.get("end_station_code")
            or trip.get("end_station_id")
            or stop.get("trip_id")
            or trip.get("trip_id")
            or "Trip"
        )

        arrival_time = _hhmm(stop.get("arrival_time"))
        route_color = _line_color(line_id)

        results.append(
            {
                "trip_id": stop.get("trip_id") or trip.get("trip_id"),
                "trip_headsign": trip_headsign,
                "route_short_name": _safe_str(line_id),
                "route_color": route_color,
                "direction_id": _safe_str(direction_id),
                "arrival_time": arrival_time,
                "station_id": station_id,
            }
        )

    return results


# ----------------------------
# Backward compatible wrapper (keep old name)
# ----------------------------
def fetch_trips_for_station_today(
    station_id: str,
    *,
    dt: Optional[datetime] = None,
    limit: int = 8,
) -> List[Dict[str, Any]]:
    """
    Wrapper kept for compatibility with old call sites.
    Uses station_id only (NOT station_code).
    """
    return fetch_next_trips_for_station(
        station_id,
        dt=dt,
        limit=min(max(0, int(limit)), 20),
    )