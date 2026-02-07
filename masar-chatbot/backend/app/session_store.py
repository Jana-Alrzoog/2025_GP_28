from datetime import datetime, timezone
from app.firestore import get_db

SESSIONS_COL = "lf_sessions"


def _build_doc_id(passenger_id: str, session_id: str) -> str:
    """
    Make each chat session unique per passenger + session.
    This prevents old conversations from leaking into new ones.
    """
    return f"{passenger_id}_{session_id}"


def get_session(passenger_id: str, session_id: str):
    db = get_db()
    doc_id = _build_doc_id(passenger_id, session_id)

    doc = db.collection(SESSIONS_COL).document(doc_id).get()

    if not doc.exists:
        return {"state": "menu", "data": {}, "updated_at": None}

    session = doc.to_dict() or {}
    return {
        "state": session.get("state", "menu"),
        "data": session.get("data", {}) or {},
        "updated_at": session.get("updated_at")
    }


def save_session(passenger_id: str, session_id: str, state: str, data: dict):
    db = get_db()
    doc_id = _build_doc_id(passenger_id, session_id)

    if data is None:
        data = {}

    db.collection(SESSIONS_COL).document(doc_id).set({
        "state": state,
        "data": data,
        "updated_at": datetime.now(timezone.utc).isoformat()
    }, merge=True)


def reset_session(passenger_id: str, session_id: str):
    """
    Force session back to menu state (used when user opens assistant or sends MENU).
    """
    db = get_db()
    doc_id = _build_doc_id(passenger_id, session_id)

    db.collection(SESSIONS_COL).document(doc_id).set({
        "state": "menu",
        "data": {},
        "updated_at": datetime.now(timezone.utc).isoformat()
    }, merge=True)
