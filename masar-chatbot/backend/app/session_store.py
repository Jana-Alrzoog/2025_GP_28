from datetime import datetime, timezone
from app.firestore import get_db

SESSIONS_COL = "lf_sessions"


def get_session(session_id: str):
    db = get_db()
    doc = db.collection(SESSIONS_COL).document(session_id).get()

    if not doc.exists:
        return {"state": "menu", "data": {}, "updated_at": None}

    session = doc.to_dict() or {}
    return {
        "state": session.get("state", "menu"),
        "data": session.get("data", {}) or {},
        "updated_at": session.get("updated_at")
    }


def save_session(session_id: str, state: str, data: dict):
    db = get_db()

    if data is None:
        data = {}

    db.collection(SESSIONS_COL).document(session_id).set({
        "state": state,
        "data": data,
        "updated_at": datetime.now(timezone.utc).isoformat()
    }, merge=True)
