from typing import List, Dict, Any, Optional
from datetime import datetime

# google.cloud.firestore.Client 
from app.firestore import get_db


def _month_id(dt: datetime) -> str:
    return dt.strftime("%Y-%m")


def _day_prefix(dt: datetime) -> str:
    return dt.strftime("%Y%m%d")  # matches your docId prefix


def fetch_trips_for_station_today(
    station_id: str,
    *,
    dt: Optional[datetime] = None,
    limit: int = 8
) -> List[Dict[str, Any]]:
    """
    Reads trips for today's date from:
    trips_month/{YYYY-MM}/trips/{YYYYMMDD_*}
    Filters by station_id using station_ids field.

    Expected fields:
      - station_ids: list[str]
      - line: str (optional)
      - times: dict (optional)  e.g. {"2-1": "08:10"}
    """
    dt = dt or datetime.now()
    month_id = _month_id(dt)
    day_prefix = _day_prefix(dt)

    db = get_db()
    col = db.collection("trips_month").document(month_id).collection("trips")

    start = f"{day_prefix}_"
    end = f"{day_prefix}_\uf8ff"

    docs = (
        col.order_by("__name__")
        .start_at([start])
        .end_at([end])
        .limit(200)
        .stream()
    )

    results: List[Dict[str, Any]] = []
    for d in docs:
        data = d.to_dict() or {}
        data["id"] = d.id

        station_ids = data.get("station_ids") or []
        if station_id in station_ids:
            results.append(data)

    def _key(x: Dict[str, Any]):
        times = x.get("times") or {}
        t = times.get(station_id)
        return t or "99:99"

    results.sort(key=_key)
    return results[:limit]
