from fastapi import FastAPI, UploadFile, File, Form
from pydantic import BaseModel
from typing import Optional, Dict, Any, List, Tuple
import os
import json
import math
import heapq

from app.firestore import fetch_all_faq
from app.llm_client import ask_llm

# Lost & Found
from app.lost_found_flow import handle_lost_found_flow
from app.session_store import get_session, save_session, reset_session

# Image upload
from app.upload import upload_lost_found_image

# Schedule (Firestore trips)
from app.trips_store import fetch_trips_for_station_today

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

# Station options count (for schedule suggestions)
STATION_OPTIONS_COUNT = int(os.getenv("STATION_OPTIONS_COUNT", "6"))

GENERAL_STATE = "general_qa"
SCHEDULE_STATE = "sch_wait_station"

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

    # Also allow "من ... الى ..." as a strong signal
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
    """
    Loads stations and builds multi-keys so users can search by:
    - Arabic name
    - English name
    - Station code
    (fixes 'kafd' case)
    """
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

        # Build multiple normalized keys
        keys = []
        if ar:
            keys.append(_norm_ar(ar))
        if en:
            keys.append(_norm_ar(en))
        keys.append(_norm_ar(code))  # always allow station code search

        # Remove empties + duplicates
        keys = [k for k in keys if k]
        keys = list(dict.fromkeys(keys))

        stations.append({
            "id": code,
            "code": code,
            "name_ar": ar or en or code,
            "name_en": en or ar or code,
            "keys": keys,                # ✅ NEW
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


def _find_station_by_text(text: str, stations: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    """
    Match against multiple keys: ar/en/code.
    Supports:
    - exact key match
    - contains match
    """
    q = _norm_ar(text)
    if not q:
        return None

    # exact match
    for s in stations:
        keys = s.get("keys") or []
        if q in keys:
            return s

    # contains match (fallback)
    for s in stations:
        keys = s.get("keys") or []
        for k in keys:
            if q in k:
                return s

    return None


def _station_suggestions(stations: List[Dict[str, Any]], query: Optional[str] = None, limit: int = 6) -> List[Dict[str, str]]:
    """
    Returns station options as:
      [{"id": "<code>", "label": "<arabic name>"}]
    If query is given, returns best matches.
    """
    if query:
        q = _norm_ar(query)
        scored = []
        for s in stations:
            keys = s.get("keys") or []
            # score: exact > startswith > contains
            score = 0
            for k in keys:
                if k == q:
                    score = max(score, 100)
                elif k.startswith(q):
                    score = max(score, 60)
                elif q in k:
                    score = max(score, 30)
            if score > 0:
                scored.append((score, s))
        scored.sort(key=lambda x: (-x[0], x[1].get("line", ""), x[1].get("seq") is None, x[1].get("seq") or 10**9))
        picks = [s for _, s in scored[:limit]]
    else:
        # default: stable, nice ordering
        arr = sorted(stations, key=lambda s: (s.get("line", ""), s.get("seq") is None, s.get("seq") or 10**9))
        picks = arr[:limit]

    return [{"id": s["id"], "label": _station_display(s)} for s in picks]


def _schedule_prompt_response(stations: List[Dict[str, Any]], hint: Optional[str] = None):
    text = "تم. ارسلي اسم المحطة لعرض مواعيد الرحلات."
    if hint:
        text = hint + "\n" + text
    return {
        "matched_faq_id": None,
        "answer": text,
        "confidence": 1.0,
        "type": "stations",
        "options": _station_suggestions(stations, query=None, limit=STATION_OPTIONS_COUNT)
    }


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

    session = get_session(passenger_id, session_id)
    state = session.get("state") or "menu"
    data = session.get("data", {}) or {}

    if state == "rt_wait_dest":
        msg = (user_message or "").strip()

        dest_map = (data.get("rt_dest_map") or {})
        start_id = data.get("rt_start_station_id")

        if not start_id or start_id not in by_id:
            save_session(passenger_id, session_id, "menu", {})
            return "حدث خطأ في تحديد نقطة الانطلاق. اختاري تخطيط المسار من القائمة مرة اخرى."

        if msg in dest_map:
            dest_id = dest_map[msg]
            if dest_id not in by_id:
                return "الاختيار غير صحيح. اختاري رقم من الخيارات."
        else:
            dest_station = _find_station_by_text(msg, stations)
            if not dest_station:
                return "لم استطع تحديد الوجهة. اكتبي اسم محطة الوجهة او اختاري رقم من الخيارات."
            dest_id = dest_station["id"]

        if dest_id == start_id:
            return "الوجهة هي نفس محطة الانطلاق. اختاري محطة اخرى."

        path_ids, total_min = _dijkstra(adj, start_id, dest_id)
        if not path_ids:
            return "لم استطع ايجاد مسار بين المحطتين حاليا."

        path_names = [_station_display(by_id[sid]) for sid in path_ids]
        total_min_int = int(round(total_min or 0.0))

        save_session(passenger_id, session_id, "menu", {})

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

    save_session(passenger_id, session_id, "menu", {})
    return "اختاري تخطيط المسار من القائمة."


# ----------------------------
# Schedule flow (sch_*)
# ----------------------------
def schedule_flow(passenger_id: str, session_id: str, user_message: str) -> Dict[str, Any]:
    stations = _load_stations()
    msg = (user_message or "").strip()

    # If user sends empty or "options" -> show station options again
    if msg.strip().lower() in {"", "options", "opt", "محطات", "اختيارات"}:
        return _schedule_prompt_response(stations)

    st = _find_station_by_text(msg, stations)
    if not st:
        # Return suggestions as options
        sug = _station_suggestions(stations, query=msg, limit=STATION_OPTIONS_COUNT)
        hint = "ما قدرت احدد المحطة. اختاري من الاقتراحات او اكتبي الاسم بشكل اوضح."
        return {
            "matched_faq_id": None,
            "answer": hint,
            "confidence": 1.0,
            "type": "stations",
            "options": sug
        }

    trips = fetch_trips_for_station_today(st["id"])
    if not trips:
        save_session(passenger_id, session_id, "menu", {})
        return {
            "matched_faq_id": None,
            "answer": f"ما لقيت رحلات اليوم للمحطة: {_station_display(st)}.",
            "confidence": 1.0,
            "type": "text"
        }

    lines: List[str] = []
    lines.append(f"مواعيد رحلات اليوم لمحطة: {_station_display(st)}")
    lines.append("")

    for i, tr in enumerate(trips, start=1):
        line_name = (tr.get("line") or "").strip()
        times = tr.get("times") or {}
        t_here = times.get(st["id"]) or times.get(st.get("code")) or "غير متوفر"

        row = f"{i}. {t_here}"
        if line_name:
            row += f" - {line_name}"
        lines.append(row)

    save_session(passenger_id, session_id, "menu", {})
    return {
        "matched_faq_id": None,
        "answer": "\n".join(lines),
        "confidence": 1.0,
        "type": "text"
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

        # Always show menu for explicit commands
        if question.strip().lower() in ["", "menu", "start"]:
            reset_session(passenger_id, session_id)
            return menu_response()

        # Exit to menu from any state
        if _is_exit_to_menu(question):
            reset_session(passenger_id, session_id)
            return menu_response()

        # If user is inside Lost & Found flow
        if str(state).startswith("lf_"):
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

        # If user is inside Route flow
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

        # If user is inside Schedule flow
        if state == SCHEDULE_STATE:
            return schedule_flow(
                passenger_id=passenger_id,
                session_id=session_id,
                user_message=question
            )

        # If user is inside General Questions state, do not auto-map to menu
        if state == GENERAL_STATE:
            faqs = fetch_all_faq()
            result = ask_llm(question, faqs)
            return {
                "matched_faq_id": result.get("matched_faq_id", None),
                "answer": result.get("answer", ""),
                "confidence": float(result.get("confidence", 0.0) or 0.0),
                "type": "text"
            }

        # Only map menu choice when state is menu
        mapped_menu = _menu_choice_from_text(question) if state == "menu" else None
        if mapped_menu is not None:
            question = mapped_menu

        # If still on menu and not a valid choice, show menu again
        if state == "menu" and question not in ALLOWED_MENU_CHOICES:
            return menu_response()

        # Option 1: General questions
        if question == "1":
            save_session(passenger_id, session_id, GENERAL_STATE, session.get("data", {}) or {})
            return {
                "matched_faq_id": None,
                "answer": "تم. ارسلي سؤالك العام وانا اجاوبك.",
                "confidence": 1.0,
                "type": "text"
            }

        # Option 2: Lost & Found
        if question == "2":
            reply_text = handle_lost_found_flow(
                session_id=session_id,
                user_message="menu",
                passenger_id=passenger_id
            )
            return {
                "matched_faq_id": None,
                "answer": reply_text,
                "confidence": 1.0,
                "type": "text"
            }

        # Option 3: Schedule (activate schedule state) + return station options ✅
        if question == "3":
            save_session(passenger_id, session_id, SCHEDULE_STATE, session.get("data", {}) or {})
            stations = _load_stations()
            return _schedule_prompt_response(stations)

        # Option 4: Route planning
        if question == "4":
            if lat is None or lon is None:
                save_session(passenger_id, session_id, "menu", session.get("data", {}) or {})
                return {
                    "matched_faq_id": None,
                    "answer": "لتحديد اقرب محطة، فعلي الموقع في التطبيق ثم حاولي مرة اخرى.",
                    "confidence": 1.0,
                    "type": "text"
                }

            stations = _load_stations()
            nearest = _find_nearest_station(lat, lon, stations)
            if not nearest:
                save_session(passenger_id, session_id, "menu", session.get("data", {}) or {})
                return {
                    "matched_faq_id": None,
                    "answer": "لم استطع تحديد اقرب محطة حاليا.",
                    "confidence": 1.0,
                    "type": "text"
                }

            options = _make_destination_options(nearest["id"], lat, lon, stations)
            dest_map = {str(i + 1): s["id"] for i, s in enumerate(options)}

            data = session.get("data", {}) or {}
            data["rt_start_station_id"] = nearest["id"]
            data["rt_dest_map"] = dest_map
            save_session(passenger_id, session_id, "rt_wait_dest", data)

            lines = []
            lines.append(f"تم تحديد اقرب محطة لك: {_station_display(nearest)}")
            lines.append("اختاري وجهتك برقم من الخيارات او اكتبي اسم محطة الوجهة:")
            for i, s in enumerate(options, start=1):
                lines.append(f"{i} - {_station_display(s)}")

            return {
                "matched_faq_id": None,
                "answer": "\n".join(lines),
                "confidence": 1.0,
                "type": "text"
            }

        # Default: answer with FAQ + LLM
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

    # Keep the state as-is
    save_session(passenger_id, session_id, session.get("state", "menu"), data)

    return {"photo_url": photo_url}
