from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, Optional

from app.firestore import get_db

SESSIONS_COL = "lf_sessions"


# ----------------------------
# Internal helpers
# ----------------------------
def _build_doc_id(passenger_id: str, session_id: str) -> str:
    """
    Build a unique Firestore document id for a session.
    Using passenger_id + session_id prevents state leaking across sessions.
    """
    passenger_id = str(passenger_id or "").strip()
    session_id = str(session_id or "").strip()
    return f"{passenger_id}_{session_id}"


def _now_utc_iso() -> str:
    """Return current time in UTC as ISO-8601 string."""
    return datetime.now(timezone.utc).isoformat()


def _normalize_data(data: Any) -> Dict[str, Any]:
    """Ensure session data is always a dictionary."""
    return data if isinstance(data, dict) else {}


# ----------------------------
# Public API
# ----------------------------
def get_session(passenger_id: str, session_id: str) -> Dict[str, Any]:
    """
    Read session state from Firestore.

    Returns a normalized session dict:
      {
        "state": str,
        "data": dict,
        "updated_at": Optional[str]
      }
    """
    db = get_db()
    doc_id = _build_doc_id(passenger_id, session_id)

    doc = db.collection(SESSIONS_COL).document(doc_id).get()

    if not doc.exists:
        return {"state": "menu", "data": {}, "updated_at": None}

    session = doc.to_dict() or {}
    return {
        "state": str(session.get("state") or "menu"),
        "data": _normalize_data(session.get("data")),
        "updated_at": session.get("updated_at"),
    }


def save_session(passenger_id: str, session_id: str, state: str, data: Optional[Dict[str, Any]] = None) -> None:
    """
    Upsert session state into Firestore.
    Uses merge=True to avoid overwriting other fields if added later.
    """
    db = get_db()
    doc_id = _build_doc_id(passenger_id, session_id)

    payload = {
        "state": str(state or "menu"),
        "data": _normalize_data(data),
        "updated_at": _now_utc_iso(),
    }

    db.collection(SESSIONS_COL).document(doc_id).set(payload, merge=True)


def reset_session(passenger_id: str, session_id: str) -> None:
    """
    Reset the session back to menu state.
    """
    save_session(passenger_id, session_id, "menu", {})


def delete_session(passenger_id: str, session_id: str) -> None:
    """
    Delete the session document completely.
    Optional helper if you want hard cleanup instead of reset.
    """
    db = get_db()
    doc_id = _build_doc_id(passenger_id, session_id)
    db.collection(SESSIONS_COL).document(doc_id).delete()