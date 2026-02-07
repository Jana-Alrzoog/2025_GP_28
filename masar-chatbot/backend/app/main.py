from fastapi import FastAPI, UploadFile, File, Form
from pydantic import BaseModel
from typing import Optional, Dict, Any, List, Tuple
import os
import json
import math
import heapq

from app.firestore import fetch_all_faq
from app.llm_client import ask_llm

# Lost & Found imports
from app.lost_found_flow import handle_lost_found_flow
from app.session_store import get_session, save_session, reset_session  # ✅ UPDATED

# Image upload
from app.upload import upload_lost_found_image

app = FastAPI()

# ----------------------------
# Config
# ----------------------------
METRO_STATIONS_PATH = os.getenv("METRO_STATIONS_PATH", "app/data/metro_stations.json")

TRAIN_SPEED_KMH = float(os.getenv("TRAIN_SPEED_KMH", "35"))
DWELL_MIN = float(os.getenv("DWELL_MIN", "0.5"))          # minutes
MIN_SEGMENT_MIN = float(os.getenv("MIN_SEGMENT_MIN", "1.5"))
TRANSFER_MIN = float(os.getenv("TRANSFER_MIN", "5.0"))

TRANSFER_MAX_DIST_M = float(os.getenv("TRANSFER_MAX_DIST_M", "120"))  # meters
DEST_OPTIONS_COUNT = int(os.getenv("DEST_OPTIONS_COUNT", "6"))


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
# Menu
# ----------------------------
MENU_TEXT = (
    "أهلاً بك في مساعدك مسار 🤖🚇\n"
    "كيف أقدر أساعدك اليوم؟\n\n"
    "1️⃣ الأسئلة العامة\n"
    "2️⃣ الإبلاغ عن مفقودات\n"
    "3️⃣ مواعيد الرحلات (الجدول الزمني)\n"
    "4️⃣ تخطيط المسار"
)

MENU_OPTIONS = [
    {"id": "1", "label": "الأسئلة العامة"},
    {"id": "2", "label": "الإبلاغ عن مفقودات"},
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
# Stations loading + helpers
# ----------------------------
_STATIONS_CACHE: Optional[List[Dict[str, Any]]] = None
_GRAPH_CACHE: Optional[Dict[str, Any]] = None


def _safe_float(x) -> Optional[float]:
    try:
        if x is None:
            return None
        return float(x)
    except:
        return None


def _norm_ar(s: str) -> str:
    s = (s or "").strip().lower()
    s = " ".join(s.split())
    s = s.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
    s = s.replace("ى", "ي").replace("ة", "ه")
    return s


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
        except:
            seq = None

        gp = it.get("geo_point_2d") or {}
        lat = _safe_float(gp.get("lat") if isinstance(gp, dict) else None)
        lon = _safe_float(gp.get("lon") if isinstance(gp, dict) else None)

        if not code or lat is None or lon is None:
            continue

        stations.append({
            "id": code,
            "code": code,
            "name_ar": ar or en or code,
            "name_en": en or ar or code,
            "name_key": _norm_ar(ar or en or code),
            "line": line,
            "seq": seq,
            "lat": lat,
            "lon": lon,
        })

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


def _station_display(s: Dict[str, Any]) -> str:
    name = s.get("name_ar") or s.get("name_en") or s.get("code")
    return str(name).strip() or s.get("code", "")


# ----------------------------
# Build graph + Dijkstra
# ----------------------------
def _build_graph() -> Dict[str, Any]:
    global _GRAPH_CACHE
    if _GRAPH_CACHE is not None:
        return _GRAPH_CACHE

    stations = _load_stations()
    by_id: Dict[str, Dict[str, Any]] = {s["id"]: s for s in stations}
    adj: Dict[str, List[Tuple[str, float]]] = {sid: [] for sid in by_id.keys()}

    # 1) line adjacency by seq
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

    # 2A) explicit transfer codes like "1B3/2B2"
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

    # 2B) transfer by same name_key and close distance
    by_name: Dict[str, List[Dict[str, Any]]] = {}
    for s in stations:
        by_name.setdefault(s["name_key"], []).append(s)

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


def _find_station_by_text(text: str, stations: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    q = _norm_ar(text)
    if not q:
        return None

    exact = [s for s in stations if s["name_key"] == q]
    if exact:
        return exact[0]

    contains = [s for s in stations if q in s["name_key"]]
    if contains:
        return contains[0]

    return None


def _make_destination_options(start_station_id: str, user_lat: float, user_lon: float, stations: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    arr = []
    for s in stations:
        if s["id"] == start_station_id:
            continue
        d = _haversine_km(user_lat, user_lon, s["lat"], s["lon"])
        arr.append((d, s))
    arr.sort(key=lambda x: x[0])
    return [s for _, s in arr[:DEST_OPTIONS_COUNT]]


# ----------------------------
# Route flow (rt_*)
# ----------------------------
def route_flow(passenger_id: str, session_id: str, user_message: str, lat: Optional[float], lon: Optional[float]) -> str:
    g = _build_graph()
    stations = g["stations"]
    by_id = g["by_id"]
    adj = g["adj"]

    session = get_session(passenger_id, session_id)  # ✅ UPDATED
    state = session.get("state") or "menu"
    data = session.get("data", {}) or {}

    if state == "rt_wait_dest":
        msg = (user_message or "").strip()

        dest_map = (data.get("rt_dest_map") or {})
        start_id = data.get("rt_start_station_id")

        if not start_id or start_id not in by_id:
            save_session(passenger_id, session_id, "menu", {})  # ✅ UPDATED
            return "صار خطأ في تحديد نقطة الانطلاق. رجعي اختاري تخطيط المسار من القائمة."

        if msg in dest_map:
            dest_id = dest_map[msg]
            if dest_id not in by_id:
                return "الاختيار غير صحيح. اختاري رقم من الخيارات."
        else:
            dest_station = _find_station_by_text(msg, stations)
            if not dest_station:
                return "ما قدرت أحدد الوجهة. اكتبي اسم محطة الوجهة أو اختاري رقم من الخيارات."
            dest_id = dest_station["id"]

        if dest_id == start_id:
            return "الوجهة نفس محطة الانطلاق. اختاري محطة ثانية."

        path_ids, total_min = _dijkstra(adj, start_id, dest_id)
        if not path_ids:
            return "ما قدرت ألقى مسار بين المحطتين حالياً."

        path_names = [_station_display(by_id[sid]) for sid in path_ids]
        total_min_int = int(round(total_min or 0.0))

        save_session(passenger_id, session_id, "menu", {})  # ✅ UPDATED

        lines = []
        lines.append("تم.")
        lines.append(f"محطة الانطلاق: {_station_display(by_id[start_id])}")
        lines.append(f"الوجهة: {_station_display(by_id[dest_id])}")
        lines.append(f"المدة التقديرية: {total_min_int} دقيقة")
        lines.append("")
        lines.append("المسار:")
        for i, n in enumerate(path_names, start=1):
            lines.append(f"{i}. {n}")

        return "\n".join(lines)

    save_session(passenger_id, session_id, "menu", {})  # ✅ UPDATED
    return "رجعي اختاري تخطيط المسار من القائمة."


# ----------------------------
# /ask endpoint
# ----------------------------
@app.post("/ask")
def ask(req: AskReq):
    try:
        question = (req.question or "").strip()
        session_id = req.session_id
        passenger_id = req.passenger_id
        lat = req.lat
        lon = req.lon

        # ✅ UPDATED
        session = get_session(passenger_id, session_id)
        state = (session.get("state") or "menu")

        # ✅ ALWAYS SHOW MENU ON START / EMPTY
        if question.lower() in ["", "menu", "start"]:
            reset_session(passenger_id, session_id)  # ✅ force menu
            return menu_response()

        # If user is on menu and typed something else, show menu again
        if state == "menu" and question not in ALLOWED_MENU_CHOICES:
            return menu_response()

        # OPTION 1
        if question == "1":
            save_session(passenger_id, session_id, "general", session.get("data", {}) or {})
            return {
                "matched_faq_id": None,
                "answer": "تمام ✅ اسأليني أي سؤال عام، وأنا أجاوبك.",
                "confidence": 1.0,
                "type": "text"
            }

        # LOST & FOUND
        if question == "2" or str(state).startswith("lf_"):
            # ⚠️ handle_lost_found_flow لازم داخله يكون محدث لنفس التوقيع
            reply_text = handle_lost_found_flow(
                session_id=session_id,
                user_message=question,
                passenger_id=passenger_id
            )
            return {
                "matched_faq_id": None,
                "answer": reply_text,
                "confidence": 1.0,
                "type": "text"
            }

        # OPTION 3 (placeholder)
        if question == "3":
            save_session(passenger_id, session_id, "sch_wait_station", session.get("data", {}) or {})
            return {
                "matched_faq_id": None,
                "answer": "تمام ✅ ارسلي اسم المحطة عشان أعرض لك مواعيد الرحلات.",
                "confidence": 1.0,
                "type": "text"
            }

        # OPTION 4: Route planning
        if question == "4":
            if lat is None or lon is None:
                save_session(passenger_id, session_id, "menu", session.get("data", {}) or {})
                return {
                    "matched_faq_id": None,
                    "answer": "عشان أقدر أحدد أقرب محطة لك، فعّلي الموقع في التطبيق ثم أعيدي المحاولة.",
                    "confidence": 1.0,
                    "type": "text"
                }

            stations = _load_stations()
            nearest = _find_nearest_station(lat, lon, stations)
            if not nearest:
                save_session(passenger_id, session_id, "menu", session.get("data", {}) or {})
                return {
                    "matched_faq_id": None,
                    "answer": "ما قدرت أحدد أقرب محطة حالياً.",
                    "confidence": 1.0,
                    "type": "text"
                }

            options = _make_destination_options(nearest["id"], lat, lon, stations)
            dest_map = {str(i + 1): s["id"] for i, s in enumerate(options)}

            data = session.get("data", {}) or {}
            data["rt_start_station_id"] = nearest["id"]
            data["rt_dest_map"] = dest_map
            save_session(passenger_id, session_id, "rt_wait_dest", data)  # ✅ UPDATED

            lines = []
            lines.append(f"تم تحديد أقرب محطة لك: {_station_display(nearest)}")
            lines.append("اختاري وجهتك من الخيارات التالية أو اكتبي اسم المحطة:")
            for i, s in enumerate(options, start=1):
                lines.append(f"{i}️⃣ {_station_display(s)}")

            return {
                "matched_faq_id": None,
                "answer": "\n".join(lines),
                "confidence": 1.0,
                "type": "text"
            }

        # If in route flow state
        if str(state).startswith("rt_"):
            reply_text = route_flow(
                passenger_id=passenger_id,
                session_id=session_id,
                user_message=question,
                lat=lat,
                lon=lon
            )
            return {
                "matched_faq_id": None,
                "answer": reply_text,
                "confidence": 1.0,
                "type": "text"
            }

        # GENERAL QUESTIONS (FAQ + LLM)
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

    # ✅ UPDATED
    session = get_session(passenger_id, session_id)
    data = session.get("data", {}) or {}
    data["photo_url"] = photo_url
    save_session(passenger_id, session_id, session.get("state", "menu"), data)

    return {"photo_url": photo_url}
