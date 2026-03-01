from fastapi import FastAPI, UploadFile, File, Form
from pydantic import BaseModel
from typing import Optional, Dict, Any, List, Tuple
from datetime import datetime, timezone
from dotenv import load_dotenv
import os
load_dotenv()
import json
import math
import heapq
import re

from app.firestore import fetch_all_faq
from app.places_service import geocode_place
from app.llm_client import ask_llm

# NEW (route walking/driving)
from app.distance_service import get_walk_drive

# Lost & Found
from app.lost_found_flow import handle_lost_found_flow
from app.session_store import get_session, save_session, reset_session

# Image upload
from app.upload import upload_lost_found_image

# Schedule (Firestore trips)  ✅ (kept, but schedule_flow will not rely on it)
from app.trips_store import fetch_trips_for_station_today

app = FastAPI()

# ----------------------------
# Config
# ----------------------------
METRO_STATIONS_PATH = os.getenv("METRO_STATIONS_PATH", "app/data/metro_stations.json")

# Station map (aliases + ordered default station suggestions)
STATION_ID_MAP_PATH = os.getenv("STATION_ID_MAP_PATH", "app/data/station_id_map.json")
STATION_DEFAULT_ORDER = ["S1", "S2", "S3", "S4", "S5", "S6"]

TRAIN_SPEED_KMH = float(os.getenv("TRAIN_SPEED_KMH", "35"))
DWELL_MIN = float(os.getenv("DWELL_MIN", "0.5"))          # minutes
MIN_SEGMENT_MIN = float(os.getenv("MIN_SEGMENT_MIN", "1.5"))
TRANSFER_MIN = float(os.getenv("TRANSFER_MIN", "5.0"))

TRANSFER_MAX_DIST_M = float(os.getenv("TRANSFER_MAX_DIST_M", "120"))  # meters
DEST_OPTIONS_COUNT = int(os.getenv("DEST_OPTIONS_COUNT", "6"))

# Station options count (for schedule suggestions)
STATION_OPTIONS_COUNT = int(os.getenv("STATION_OPTIONS_COUNT", "6"))

GENERAL_STATE = "general_qa"

# Schedule states (clean)
SCH_CHOOSE_STATION = "sch_choose_station"
SCH_SHOWING_TRIPS = "sch_showing_trips"

# Route states (NEW)
RT_ASK_DEST = "rt_ask_dest"
RT_SHOWING = "rt_showing"

# ----------------------------
# Route UI meta (icons/colors)
# (عدّلي مسميات الايقونات حسب Flutter assets)
# ----------------------------
LINE_META = {
    "Line1": {"name_ar": "المسار الأزرق",    "color": "#0077C8", "icon": "line_blue"},
    "Line2": {"name_ar": "المسار الأحمر",    "color": "#E10600", "icon": "line_red"},
    "Line3": {"name_ar": "المسار البرتقالي", "color": "#F57C00", "icon": "line_orange"},
    "Line4": {"name_ar": "المسار الأصفر",    "color": "#FBC02D", "icon": "line_yellow"},
    "Line5": {"name_ar": "المسار الأخضر",    "color": "#2E7D32", "icon": "line_green"},
    "Line6": {"name_ar": "المسار البنفسجي",  "color": "#6A1B9A", "icon": "line_purple"},
}

# ----------------------------
# Request model
# ----------------------------
class AskReq(BaseModel):
    question: str
    session_id: str
    passenger_id: str
    lat: Optional[float] = None
    lon: Optional[float] = None


# ----------------------------
# Small helpers
# ----------------------------
def _strip_opt_prefix(msg: str) -> str:
    """
    Allows the app to send "OPT:2" safely.
    """
    s = (msg or "").strip()
    if s.upper().startswith("OPT:"):
        return s.split(":", 1)[1].strip()
    return s


def _norm_ar(s: str) -> str:
    s = (s or "").strip().lower()
    s = " ".join(s.split())
    s = s.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
    s = s.replace("ى", "ي").replace("ة", "ه")
    return s


def _is_exit_to_menu(msg: str) -> bool:
    q = _norm_ar(msg)
    return q in {"menu", "القائمه", "القائمة", "رجوع", "عودة", "خروج", "back", "exit", "start"}


def _menu_choice_from_text(question: str) -> Optional[str]:
    """
    Fallback mapping if the client sends label text instead of a number.
    This must be conservative to avoid false routing.
    """
    q = _norm_ar(question)

    # General questions
    if "الاسئله" in q or "اسئله" in q or "عامه" in q:
        return "1"

    # Lost & found
    if "ابلاغ" in q or "مفقود" in q or "مفقودات" in q or "lost" in q:
        return "2"

    # Schedule
    if "مواعيد" in q or "الجدول" in q or "زمني" in q or "schedule" in q:
        return "3"

    # Route planning (be strict: do not trigger on the word "مسار" alone)
    if "تخطيط" in q or "route" in q or "اتجاه" in q or "كيف اروح" in q:
        return "4"

    # Also allow "from ... to ..." as a strong signal
    if ("من " in q and " الى " in q) or ("من " in q and "إلى " in question):
        return "4"

    return None


# ----------------------------
# Menu
# ----------------------------
MENU_TEXT = (
    "اهلا بك في مساعد مسار.\n"
    "كيف اقدر اساعدك اليوم؟\n\n"
    "1 - الاسئله العامه\n"
    "2 - الابلاغ عن مفقودات\n"
    "3 - مواعيد الرحلات (الجدول الزمني)\n"
    "4 - تخطيط المسار"
)

MENU_OPTIONS = [
    {"id": "1", "label": "الاسئله العامه"},
    {"id": "2", "label": "الابلاغ عن مفقودات"},
    {"id": "3", "label": "مواعيد الرحلات (الجدول الزمني)"},
    {"id": "4", "label": "تخطيط المسار"},
]

ALLOWED_MENU_CHOICES = {"1", "2", "3", "4"}


def menu_response():
    return {
        "matched_faq_id": None,
        "answer": MENU_TEXT,
        "confidence": 1.0,
        "type": "menu",
        "options": MENU_OPTIONS
    }


# ----------------------------
# Station map (aliases + ordered defaults) for ROUTE + SEARCH
# ----------------------------
_STATION_ID_MAP: Optional[Dict[str, str]] = None


def _load_station_id_map() -> Dict[str, str]:
    global _STATION_ID_MAP
    if _STATION_ID_MAP is not None:
        return _STATION_ID_MAP

    if not os.path.exists(STATION_ID_MAP_PATH):
        _STATION_ID_MAP = {}
        return _STATION_ID_MAP

    with open(STATION_ID_MAP_PATH, "r", encoding="utf-8") as f:
        _STATION_ID_MAP = json.load(f) or {}

    return _STATION_ID_MAP


def _aliases_from_map_value(raw: str) -> List[str]:
    """
    station_id_map.json uses "/" to separate aliases.
    Example:
      "المركز المالي/KAFD"
    """
    if not raw:
        return []
    return [p.strip() for p in str(raw).split("/") if p.strip()]


# ----------------------------
# Stations loading + helpers (for ROUTE / nearest / graph)
# ----------------------------
_STATIONS_CACHE: Optional[List[Dict[str, Any]]] = None
_GRAPH_CACHE: Optional[Dict[str, Any]] = None


def _safe_float(x) -> Optional[float]:
    try:
        if x is None:
            return None
        return float(x)
    except Exception:
        return None


def _haversine_km(lat1, lon1, lat2, lon2) -> float:
    R = 6371.0
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)

    a = math.sin(dlat / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlon / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


def _time_minutes_for_segment(lat1, lon1, lat2, lon2) -> float:
    dist_km = _haversine_km(lat1, lon1, lat2, lon2)
    travel = (dist_km / TRAIN_SPEED_KMH) * 60.0
    t = travel + DWELL_MIN
    return max(t, MIN_SEGMENT_MIN)


def _station_display(s: Dict[str, Any]) -> str:
    name = s.get("name_ar") or s.get("name_en") or s.get("code")
    return str(name).strip() or s.get("code", "")


def _find_station_by_text(
    text: str,
    stations: List[Dict[str, Any]],
    *,
    use_map_aliases: bool = True
) -> Optional[Dict[str, Any]]:
    """
    Match against multiple keys: ar/en/code (+ map aliases if enabled).
    Supports:
    - exact key match
    - contains match
    """
    q = _norm_ar(text)
    if not q:
        return None

    if use_map_aliases:
        m = _load_station_id_map()
        if m:
            for _, raw in m.items():
                aliases = _aliases_from_map_value(raw)
                if not aliases:
                    continue
                for a in aliases:
                    if _norm_ar(a) == q:
                        candidate_code = aliases[-1]
                        if candidate_code and (" " not in candidate_code):
                            for s in stations:
                                if s.get("id") == candidate_code:
                                    return s
                        break

    # Exact match
    for s in stations:
        keys = s.get("keys") or []
        if q in keys:
            return s

    # Contains match
    for s in stations:
        keys = s.get("keys") or []
        for k in keys:
            if q in k:
                return s

    return None


def _augment_station_keys_with_map_aliases(stations: List[Dict[str, Any]]) -> None:
    m = _load_station_id_map()
    if not m:
        return

    by_id = {s.get("id"): s for s in stations if s.get("id")}

    for _, raw in m.items():
        aliases = _aliases_from_map_value(raw)
        if not aliases:
            continue

        candidate_code = aliases[-1]
        target = None
        if candidate_code and (" " not in candidate_code) and (candidate_code in by_id):
            target = by_id[candidate_code]

        if target is None:
            for a in aliases:
                found = _find_station_by_text(a, stations, use_map_aliases=False)
                if found:
                    target = found
                    break

        if target is None:
            continue

        keys = target.get("keys") or []
        for a in aliases:
            na = _norm_ar(a)
            if na and na not in keys:
                keys.append(na)
        target["keys"] = list(dict.fromkeys(keys))


def _load_stations() -> List[Dict[str, Any]]:
    global _STATIONS_CACHE
    if _STATIONS_CACHE is not None:
        return _STATIONS_CACHE

    if not os.path.exists(METRO_STATIONS_PATH):
        raise FileNotFoundError(
            f"metro stations file not found: {METRO_STATIONS_PATH}. "
            f"Set METRO_STATIONS_PATH or place file at app/data/metro_stations.json"
        )

    with open(METRO_STATIONS_PATH, "r", encoding="utf-8") as f:
        raw = json.load(f)

    items = raw if isinstance(raw, list) else (raw.get("stations") or [])
    stations: List[Dict[str, Any]] = []

    for it in items:
        if not isinstance(it, dict):
            continue

        code = str(it.get("metrostationcode") or "").strip()
        ar = str(it.get("metrostationnamear") or "").strip()
        en = str(it.get("metrostationname") or "").strip()
        line = str(it.get("metroline") or "").strip()

        seq = it.get("stationseq")
        try:
            seq = int(seq) if seq is not None else None
        except Exception:
            seq = None

        gp = it.get("geo_point_2d") or {}
        lat = _safe_float(gp.get("lat") if isinstance(gp, dict) else None)
        lon = _safe_float(gp.get("lon") if isinstance(gp, dict) else None)

        if not code or lat is None or lon is None:
            continue

        keys = []
        if ar:
            keys.append(_norm_ar(ar))
        if en:
            keys.append(_norm_ar(en))
        keys.append(_norm_ar(code))
        keys = [k for k in keys if k]
        keys = list(dict.fromkeys(keys))

        stations.append({
            "id": code,
            "code": code,
            "name_ar": ar or en or code,
            "name_en": en or ar or code,
            "keys": keys,
            "line": line,
            "seq": seq,
            "lat": lat,
            "lon": lon,
        })

    _augment_station_keys_with_map_aliases(stations)

    _STATIONS_CACHE = stations
    return stations


def _find_nearest_station(lat: float, lon: float, stations: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    best = None
    best_km = 1e18
    for s in stations:
        d = _haversine_km(lat, lon, s["lat"], s["lon"])
        if d < best_km:
            best_km = d
            best = s
    return best


# ----------------------------
# Build graph + Dijkstra (ROUTE)
# ----------------------------
def _build_graph() -> Dict[str, Any]:
    global _GRAPH_CACHE
    if _GRAPH_CACHE is not None:
        return _GRAPH_CACHE

    stations = _load_stations()
    by_id: Dict[str, Dict[str, Any]] = {s["id"]: s for s in stations}
    adj: Dict[str, List[Tuple[str, float]]] = {sid: [] for sid in by_id.keys()}

    # 1) Line adjacency by seq
    by_line: Dict[str, List[Dict[str, Any]]] = {}
    for s in stations:
        line = s.get("line") or ""
        if not line:
            continue
        by_line.setdefault(line, []).append(s)

    for _, arr in by_line.items():
        arr_sorted = sorted(arr, key=lambda x: (x["seq"] is None, x["seq"] if x["seq"] is not None else 10**9))
        for i in range(len(arr_sorted) - 1):
            a = arr_sorted[i]
            b = arr_sorted[i + 1]
            if a["id"] not in by_id or b["id"] not in by_id:
                continue
            w = _time_minutes_for_segment(a["lat"], a["lon"], b["lat"], b["lon"])
            adj[a["id"]].append((b["id"], w))
            adj[b["id"]].append((a["id"], w))

    # 2A) Explicit transfer codes like "1B3/2B2"
    for s in stations:
        code = s["code"]
        if "/" in code:
            parts = [p.strip() for p in code.split("/") if p.strip()]
            for p in parts:
                if p in by_id:
                    adj[s["id"]].append((p, TRANSFER_MIN))
                    adj[p].append((s["id"], TRANSFER_MIN))
            for i in range(len(parts)):
                for j in range(i + 1, len(parts)):
                    pi, pj = parts[i], parts[j]
                    if pi in by_id and pj in by_id:
                        adj[pi].append((pj, TRANSFER_MIN))
                        adj[pj].append((pi, TRANSFER_MIN))

    # 2B) Transfer by same name (use first key as primary)
    by_name: Dict[str, List[Dict[str, Any]]] = {}
    for s in stations:
        keys = s.get("keys") or []
        primary = keys[0] if keys else _norm_ar(_station_display(s))
        by_name.setdefault(primary, []).append(s)

    max_km = TRANSFER_MAX_DIST_M / 1000.0
    for _, arr in by_name.items():
        if len(arr) < 2:
            continue
        for i in range(len(arr)):
            for j in range(i + 1, len(arr)):
                a, b = arr[i], arr[j]
                d_km = _haversine_km(a["lat"], a["lon"], b["lat"], b["lon"])
                if d_km <= max_km:
                    adj[a["id"]].append((b["id"], TRANSFER_MIN))
                    adj[b["id"]].append((a["id"], TRANSFER_MIN))

    _GRAPH_CACHE = {"stations": stations, "by_id": by_id, "adj": adj}
    return _GRAPH_CACHE


def _dijkstra(adj: Dict[str, List[Tuple[str, float]]], start: str, goal: str):
    dist: Dict[str, float] = {start: 0.0}
    prev: Dict[str, Optional[str]] = {start: None}
    pq = [(0.0, start)]
    visited = set()

    while pq:
        d, u = heapq.heappop(pq)
        if u in visited:
            continue
        visited.add(u)

        if u == goal:
            break

        for v, w in adj.get(u, []):
            nd = d + w
            if v not in dist or nd < dist[v]:
                dist[v] = nd
                prev[v] = u
                heapq.heappush(pq, (nd, v))

    if goal not in dist:
        return None, None

    path = []
    cur = goal
    while cur is not None:
        path.append(cur)
        cur = prev.get(cur)
    path.reverse()
    return path, dist[goal]


# ----------------------------
# Route helpers (NEW)
# ----------------------------
def _line_meta(line_id: str) -> Dict[str, Any]:
    return LINE_META.get(line_id, {"name_ar": line_id or "المسار", "color": None, "icon": None})


def _make_route_steps(path_ids: List[str], by_id: Dict[str, Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Produces UI-friendly steps:
      - ride on a line from station A to B (N stops)
      - transfer (if line changes)
    """
    if not path_ids or len(path_ids) < 2:
        return []

    steps: List[Dict[str, Any]] = []

    def station_name(sid: str) -> str:
        return _station_display(by_id[sid])

    cur_line = by_id[path_ids[0]].get("line")
    seg_start = path_ids[0]
    stops = 0

    for i in range(1, len(path_ids)):
        prev_sid = path_ids[i - 1]
        sid = path_ids[i]
        prev_line = by_id[prev_sid].get("line")
        this_line = by_id[sid].get("line")

        # Same line => keep riding
        if this_line == prev_line:
            stops += 1
            continue

        # Line changed at sid => close previous ride segment
        if prev_line:
            meta = _line_meta(prev_line)
            steps.append({
                "type": "ride",
                "line_id": prev_line,
                "line_name": meta.get("name_ar"),
                "line_color": meta.get("color"),
                "line_icon": meta.get("icon"),
                "from": station_name(seg_start),
                "to": station_name(prev_sid),
                "stops": max(1, stops),
            })

        # Transfer step
        if this_line:
            meta_to = _line_meta(this_line)
            steps.append({
                "type": "transfer",
                "at": station_name(prev_sid),
                "to_line_id": this_line,
                "to_line_name": meta_to.get("name_ar"),
                "to_line_color": meta_to.get("color"),
                "to_line_icon": meta_to.get("icon"),
                "minutes": int(round(TRANSFER_MIN)),
            })

        # Start new segment from prev_sid (transfer station) to next stations
        seg_start = prev_sid
        cur_line = this_line
        stops = 1  # we already moved one edge into the new line

    # close last segment
    last_line = by_id[path_ids[-1]].get("line")
    if last_line:
        meta_last = _line_meta(last_line)
        steps.append({
            "type": "ride",
            "line_id": last_line,
            "line_name": meta_last.get("name_ar"),
            "line_color": meta_last.get("color"),
            "line_icon": meta_last.get("icon"),
            "from": station_name(seg_start),
            "to": station_name(path_ids[-1]),
            "stops": max(1, stops),
        })

    return steps


def _route_card_response(
    *,
    title: str,
    start_station: Dict[str, Any],
    end_station: Dict[str, Any],
    dest_label: str,
    metro_min: int,
    walk_to_start: Optional[int],
    drive_to_start: Optional[int],
    walk_from_end: Optional[int],
    drive_from_end: Optional[int],
    steps: List[Dict[str, Any]],
) -> Dict[str, Any]:
    """
    Flutter-friendly payload (cards/icons)
    """
    return {
        "matched_faq_id": None,
        "answer": title,
        "confidence": 1.0,
        "type": "route_card",
        "route": {
            "destination_label": dest_label,
            "start_station": {
                "id": start_station.get("id"),
                "name": _station_display(start_station),
                "line_id": start_station.get("line"),
                "line_meta": _line_meta(start_station.get("line")),
                "lat": start_station.get("lat"),
                "lon": start_station.get("lon"),
            },
            "end_station": {
                "id": end_station.get("id"),
                "name": _station_display(end_station),
                "line_id": end_station.get("line"),
                "line_meta": _line_meta(end_station.get("line")),
                "lat": end_station.get("lat"),
                "lon": end_station.get("lon"),
            },
            "times": {
                "metro_min": metro_min,
                "walk_to_start_min": walk_to_start,
                "drive_to_start_min": drive_to_start,
                "walk_from_end_min": walk_from_end,
                "drive_from_end_min": drive_from_end,
            },
            "steps": steps,
        },
        "options": [
            {"id": "1", "label": "تغيير الوجهة"},
            {"id": "2", "label": "رجوع للقائمة"},
        ],
    }


# ----------------------------
# Route flow (rt_*) REPLACED
# ----------------------------
def route_flow(
    passenger_id: str,
    session_id: str,
    user_message: str,
    lat: Optional[float],
    lon: Optional[float]
) -> Dict[str, Any]:
    session = get_session(passenger_id, session_id)
    state = session.get("state") or "menu"
    data = session.get("data", {}) or {}

    msg = (user_message or "").strip()
    msg = _strip_opt_prefix(msg)

    # If showing route, allow actions
    if state == RT_SHOWING:
        if msg == "1":
            save_session(passenger_id, session_id, RT_ASK_DEST, data)
            return {"matched_faq_id": None, "answer": "تمام. وين تبي تروح؟", "confidence": 1.0, "type": "text"}
        if msg == "2":
            reset_session(passenger_id, session_id)
            return menu_response()

        # if user typed a new destination directly while showing
        save_session(passenger_id, session_id, RT_ASK_DEST, data)
        state = RT_ASK_DEST

    # Ask destination
    if state == RT_ASK_DEST:
        if not msg:
            return {"matched_faq_id": None, "answer": "وين تبي تروح؟ (مثال: البوليفارد)", "confidence": 1.0, "type": "text"}

        # Need user location to choose nearest station
        if lat is None or lon is None:
            save_session(passenger_id, session_id, RT_ASK_DEST, data)
            return {
                "matched_faq_id": None,
                "answer": "عشان احدد اقرب محطة لك، فعّلي الموقع بالتطبيق ثم ارسلي اسم وجهتك مرة ثانية.",
                "confidence": 1.0,
                "type": "text"
            }

        # 1) Geocode destination (place -> lat/lon)
        try:
            place = geocode_place(msg)  # expected: dict with lat/lon/name/address
        except Exception:
            place = None

        if not place or place.get("lat") is None or place.get("lon") is None:
            save_session(passenger_id, session_id, RT_ASK_DEST, data)
            return {
                "matched_faq_id": None,
                "answer": "ما قدرت احدد مكان الوجهة. اكتبي اسم اوضح (مثال: البوليفارد سيتي).",
                "confidence": 1.0,
                "type": "text"
            }

        dest_lat = float(place["lat"])
        dest_lon = float(place["lon"])
        dest_label = (place.get("name") or place.get("formatted_address") or msg).strip()

        # 2) Nearest stations (start near user, end near destination)
        g = _build_graph()
        stations = g["stations"]
        by_id = g["by_id"]
        adj = g["adj"]

        start_station = _find_nearest_station(lat, lon, stations)
        end_station = _find_nearest_station(dest_lat, dest_lon, stations)

        if not start_station or not end_station:
            save_session(passenger_id, session_id, RT_ASK_DEST, data)
            return {"matched_faq_id": None, "answer": "ما قدرت احدد اقرب محطات حاليا.", "confidence": 1.0, "type": "text"}

        start_id = start_station["id"]
        end_id = end_station["id"]

        # 3) Metro route
        path_ids, metro_min_f = _dijkstra(adj, start_id, end_id)
        if not path_ids:
            save_session(passenger_id, session_id, RT_ASK_DEST, data)
            return {"matched_faq_id": None, "answer": "ما قدرت القى مسار مترو بين اقرب محطتين حاليا.", "confidence": 1.0, "type": "text"}

        metro_min = int(round(metro_min_f or 0.0))

        # 4) Walking + Driving times (both)
        walk_to_start = drive_to_start = None
        walk_from_end = drive_from_end = None

        try:
            a = get_walk_drive(
    origin=(float(lat), float(lon)),
    destination=(float(start_station["lat"]), float(start_station["lon"]))
)
            walk_to_start  = (a.get("walk")  or {}).get("duration_min")
            drive_to_start = (a.get("drive") or {}).get("duration_min")
        except Exception:
            pass

        try:
            b = get_walk_drive(
                origin=(float(end_station["lat"]), float(end_station["lon"])),
                destination=(float(dest_lat), float(dest_lon)),
            )
            walk_from_end  = (b.get("walk")  or {}).get("duration_min")
            drive_from_end = (b.get("drive") or {}).get("duration_min")
        except Exception:
            pass

        steps = _make_route_steps(path_ids, by_id)
        print("WALK/DRIVE TO START:", a)

        # Save result for "re-show" / change destination
        data["rt_last"] = {
            "dest_label": dest_label,
            "dest_lat": dest_lat,
            "dest_lon": dest_lon,
            "start_id": start_id,
            "end_id": end_id,
            "metro_min": metro_min,
            "walk_to_start": walk_to_start,
            "drive_to_start": drive_to_start,
            "walk_from_end": walk_from_end,
            "drive_from_end": drive_from_end,
            "path_ids": path_ids,
        }
        save_session(passenger_id, session_id, RT_SHOWING, data)

        title = f"هذا افضل مسار للوجهة: {dest_label}"
        return _route_card_response(
            title=title,
            start_station=start_station,
            end_station=end_station,
            dest_label=dest_label,
            metro_min=metro_min,
            walk_to_start=walk_to_start,
            drive_to_start=drive_to_start,
            walk_from_end=walk_from_end,
            drive_from_end=drive_from_end,
            steps=steps,
        )

    # Fallback: reset to menu
    save_session(passenger_id, session_id, "menu", {})
    return {"matched_faq_id": None, "answer": "اختاري تخطيط المسار من القائمة.", "confidence": 1.0, "type": "text"}


# ============================================================
# Schedule flow UPDATED (always returns schedule_inline)
# ============================================================

def _default_station_codes_from_map(stations: List[Dict[str, Any]]) -> List[str]:
    m = _load_station_id_map()
    if not m:
        return []

    by_id = {s.get("id"): s for s in stations if s.get("id")}
    out: List[str] = []

    for key in STATION_DEFAULT_ORDER:
        raw = (m.get(key) or "").strip()
        aliases = _aliases_from_map_value(raw)
        if not aliases:
            continue

        candidate_code = aliases[-1]
        if candidate_code and (" " not in candidate_code) and (candidate_code in by_id):
            out.append(candidate_code)
            continue

        found_code = None
        for a in aliases:
            found = _find_station_by_text(a, stations, use_map_aliases=False)
            if found:
                found_code = found.get("id")
                break
        if found_code:
            out.append(found_code)

    return list(dict.fromkeys([x for x in out if x]))


def _schedule_station_options(stations: List[Dict[str, Any]], limit: int = 6) -> Tuple[List[Dict[str, str]], Dict[str, str]]:
    by_id = {s.get("id"): s for s in stations if s.get("id")}
    codes = _default_station_codes_from_map(stations)

    picks: List[Dict[str, Any]] = [by_id[c] for c in codes if c in by_id]

    if len(picks) < limit:
        remaining = [s for s in stations if s.get("id") not in set(codes)]
        remaining = sorted(remaining, key=lambda s: (s.get("line", ""), s.get("seq") is None, s.get("seq") or 10**9))
        picks.extend(remaining[: (limit - len(picks))])

    picks = picks[:limit]

    options: List[Dict[str, str]] = []
    opt_map: Dict[str, str] = {}
    for i, s in enumerate(picks, start=1):
        sid = str(s.get("id") or "")
        label = _station_display(s)
        options.append({"id": str(i), "label": label})
        opt_map[str(i)] = sid

    return options, opt_map


# kept (not used directly now)
def _next_trips_today_for_station(station_id: str, now_utc: datetime, limit: int = 4) -> List[Dict[str, Any]]:
    trips = fetch_trips_for_station_today(
        station_id,
        dt=now_utc,
        limit=max(0, int(limit)),
    )
    return trips[: max(0, int(limit))]


# NEW: schedule_inline payload (Flutter expects station_id + station_name in raw)
def _schedule_inline_response(station_id: str, station_label: str, answer: str) -> Dict[str, Any]:
    return {
        "matched_faq_id": None,
        "answer": answer,
        "confidence": 1.0,
        "type": "schedule_inline",
        "station_id": station_id,         # important
        "station_name": station_label,    # important
        "options": [
            {"id": "1", "label": "تغيير المحطة"},
            {"id": "2", "label": "رجوع للقائمة"},
        ],
    }


def schedule_flow(passenger_id: str, session_id: str, user_message: str) -> Dict[str, Any]:
    msg_raw = (user_message or "").strip()
    msg = _strip_opt_prefix(msg_raw)

    session = get_session(passenger_id, session_id)
    state = session.get("state") or "menu"
    data = session.get("data", {}) or {}

    stations = _load_stations()
    by_id = {s["id"]: s for s in stations}

    # show station suggestions
    if _norm_ar(msg) in {"", "options", "opt", "محطات", "اختيارات"}:
        options, opt_map = _schedule_station_options(stations, limit=STATION_OPTIONS_COUNT)
        data["sch_station_opt_map"] = opt_map
        save_session(passenger_id, session_id, SCH_CHOOSE_STATION, data)
        return {
            "matched_faq_id": None,
            "answer": "تمام. اختاري/اكتبي اسم المحطة عشان اعرض لك اقرب الرحلات القادمة.",
            "confidence": 1.0,
            "type": "stations",
            "options": options,
        }

    # while showing trips
    if state == SCH_SHOWING_TRIPS:
        if msg == "1":
            options, opt_map = _schedule_station_options(stations, limit=STATION_OPTIONS_COUNT)
            data["sch_station_opt_map"] = opt_map
            save_session(passenger_id, session_id, SCH_CHOOSE_STATION, data)
            return {
                "matched_faq_id": None,
                "answer": "تمام. اختاري محطة جديدة.",
                "confidence": 1.0,
                "type": "stations",
                "options": options,
            }
        if msg == "2":
            save_session(passenger_id, session_id, "menu", {})
            return menu_response()

        state = SCH_CHOOSE_STATION

    # choose station
    if state == SCH_CHOOSE_STATION or state == "menu":
        opt_map = (data.get("sch_station_opt_map") or {})
        st_id = None
        if msg in opt_map:
            st_id = opt_map[msg]

        if not st_id:
            found = _find_station_by_text(msg, stations, use_map_aliases=True)
            st_id = found["id"] if found else None

        if not st_id or st_id not in by_id:
            options, new_map = _schedule_station_options(stations, limit=STATION_OPTIONS_COUNT)
            data["sch_station_opt_map"] = new_map
            save_session(passenger_id, session_id, SCH_CHOOSE_STATION, data)
            return {
                "matched_faq_id": None,
                "answer": "ما قدرت احدد المحطة. اختاري من الاقتراحات او اكتبي الاسم بشكل اوضح.",
                "confidence": 1.0,
                "type": "stations",
                "options": options,
            }

        data["sch_station_id"] = st_id
        station_label = _station_display(by_id[st_id])

        # IMPORTANT CHANGE:
        # Backend no longer decides 'today trips' or filters.
        # Flutter ChatScheduleInline will fetch next trips from Firestore within 10 minutes and limit 4.
        save_session(passenger_id, session_id, SCH_SHOWING_TRIPS, data)

        return _schedule_inline_response(
            station_id=st_id,
            station_label=station_label,
            answer=f"تمام، هذي أقرب الرحلات للمحطة: {station_label}",
        )

    # fallback
    save_session(passenger_id, session_id, SCH_CHOOSE_STATION, data)
    options, opt_map = _schedule_station_options(stations, limit=STATION_OPTIONS_COUNT)
    data["sch_station_opt_map"] = opt_map
    return {
        "matched_faq_id": None,
        "answer": "اختاري محطة عشان اعرض لك اقرب الرحلات.",
        "confidence": 1.0,
        "type": "stations",
        "options": options,
    }


# ----------------------------
# /ask endpoint
# ----------------------------
@app.post("/ask")
def ask(req: AskReq):
    try:
        raw_question = (req.question or "").strip()
        question = _strip_opt_prefix(raw_question)

        session_id = req.session_id
        passenger_id = req.passenger_id
        lat = req.lat
        lon = req.lon

        session = get_session(passenger_id, session_id)
        state = (session.get("state") or "menu")

        if question.strip().lower() in ["", "menu", "start"]:
            reset_session(passenger_id, session_id)
            return menu_response()

        if _is_exit_to_menu(question):
            reset_session(passenger_id, session_id)
            return menu_response()

        if str(state).startswith("lf_"):
            reply_text = handle_lost_found_flow(
                session_id=session_id,
                user_message=question,
                passenger_id=passenger_id
            )
            return {"matched_faq_id": None, "answer": reply_text, "confidence": 1.0, "type": "text"}

        # NEW: route states handled by route_flow and returned as dict
        if str(state).startswith("rt_"):
            return route_flow(
                passenger_id=passenger_id,
                session_id=session_id,
                user_message=question,
                lat=lat,
                lon=lon
            )

        #  schedule states
        if state in {SCH_CHOOSE_STATION, SCH_SHOWING_TRIPS}:
            return schedule_flow(passenger_id=passenger_id, session_id=session_id, user_message=question)

        if state == GENERAL_STATE:
            faqs = fetch_all_faq()
            result = ask_llm(question, faqs)
            return {
                "matched_faq_id": result.get("matched_faq_id", None),
                "answer": result.get("answer", ""),
                "confidence": float(result.get("confidence", 0.0) or 0.0),
                "type": "text"
            }

        mapped_menu = _menu_choice_from_text(question) if state == "menu" else None
        if mapped_menu is not None:
            question = mapped_menu

        if state == "menu" and question not in ALLOWED_MENU_CHOICES:
            return menu_response()

        if question == "1":
            save_session(passenger_id, session_id, GENERAL_STATE, session.get("data", {}) or {})
            return {"matched_faq_id": None, "answer": "تم. ارسلي سؤالك العام وانا اجاوبك.", "confidence": 1.0, "type": "text"}

        if question == "2":
            reply_text = handle_lost_found_flow(session_id=session_id, user_message="menu", passenger_id=passenger_id)
            return {"matched_faq_id": None, "answer": reply_text, "confidence": 1.0, "type": "text"}

        if question == "3":
            data = session.get("data", {}) or {}
            stations = _load_stations()
            options, opt_map = _schedule_station_options(stations, limit=STATION_OPTIONS_COUNT)
            data["sch_station_opt_map"] = opt_map
            save_session(passenger_id, session_id, SCH_CHOOSE_STATION, data)
            return {
                "matched_faq_id": None,
                "answer": "تمام. اختاري/اكتبي اسم المحطة عشان اعرض لك اقرب الرحلات القادمة.",
                "confidence": 1.0,
                "type": "stations",
                "options": options,
            }

        # UPDATED: route entry = ask destination مباشرة (بدون خيارات)
        if question == "4":
            data = session.get("data", {}) or {}
            save_session(passenger_id, session_id, RT_ASK_DEST, data)
            return {"matched_faq_id": None, "answer": "وين تبي تروح؟", "confidence": 1.0, "type": "text"}

        faqs = fetch_all_faq()
        result = ask_llm(question, faqs)
        return {
            "matched_faq_id": result.get("matched_faq_id", None),
            "answer": result.get("answer", ""),
            "confidence": float(result.get("confidence", 0.0) or 0.0),
            "type": "text"
        }

    except Exception as e:
        return {
            "matched_faq_id": None,
            "answer": f"SERVER_ERROR: {type(e).__name__}: {str(e)}",
            "confidence": 0.0,
            "type": "error"
        }


# ----------------------------
# Upload endpoint
# ----------------------------
@app.post("/lost-found/upload-image")
async def upload_image(
    file: UploadFile = File(...),
    passenger_id: str = Form(...),
    session_id: str = Form(...),
    ticket_id: str | None = Form(None),
):
    photo_url = await upload_lost_found_image(
        file=file,
        passenger_id=passenger_id,
        ticket_id=ticket_id
    )

    session = get_session(passenger_id, session_id)
    data = session.get("data", {}) or {}
    data["photo_url"] = photo_url

    save_session(passenger_id, session_id, session.get("state", "menu"), data)

    return {"photo_url": photo_url}