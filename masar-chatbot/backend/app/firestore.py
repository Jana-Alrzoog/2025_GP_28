import os
from datetime import datetime, timezone

import firebase_admin
from firebase_admin import credentials, firestore, storage

_db = None
_bucket = None


def get_db():
    global _db

    if _db is None:
        cred_path = os.getenv("FIREBASE_CRED", "serviceAccountKey.json")
        cred = credentials.Certificate(cred_path)

        # Initialize Firebase once
        if not firebase_admin._apps:
            firebase_admin.initialize_app(
                cred,
                {
                    # Needed for Firebase Storage uploads
                    "storageBucket": os.getenv("FIREBASE_STORAGE_BUCKET")
                }
            )

        _db = firestore.client()

    return _db


def get_bucket():
    """
    Get Firebase Storage bucket (used for image uploads).
    """
    global _bucket

    if _bucket is None:
        # This uses the bucket name from initialize_app(storageBucket=...)
        _bucket = storage.bucket()

    return _bucket


def fetch_all_faq():
    db = get_db()
    docs = db.collection("faq").stream()

    items = []
    for d in docs:
        data = d.to_dict() or {}
        items.append({
            "id": d.id,
            "question": data.get("question", ""),
            "answer": data.get("answer", ""),
            "category": data.get("category", ""),
        })

    return items


# Lost & Found Sessions (conversation state)

def get_session(session_id: str):
    # Get the current session state for this user
    db = get_db()
    doc = db.collection("lf_sessions").document(session_id).get()

    if not doc.exists:
        # If no session exists yet, start from the main menu
        return {"state": "menu", "data": {}, "updated_at": None}

    return doc.to_dict()


def save_session(session_id: str, state: str, data: dict):
    # Save or update the user's current conversation state
    db = get_db()
    db.collection("lf_sessions").document(session_id).set({
        "state": state,
        "data": data,
        "updated_at": datetime.now(timezone.utc).isoformat()
    }, merge=True)


# =========================
# Save Lost & Found Reports
# =========================
def save_lost_found_report(report: dict):
    # Store the final lost item report using ticket_id as the document ID
    db = get_db()
    ticket_id = report["ticket_id"]
    db.collection("lost_found_reports").document(ticket_id).set(report)


def get_lost_found_report(ticket_id: str):
    # Fetch a lost item report using its ticket number
    db = get_db()
    doc = db.collection("lost_found_reports").document(ticket_id).get()

    if not doc.exists:
        return None

    return doc.to_dict()
