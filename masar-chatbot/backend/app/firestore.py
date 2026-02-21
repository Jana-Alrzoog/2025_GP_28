import os
from datetime import datetime, timezone

import firebase_admin
from firebase_admin import credentials, firestore, storage

_db = None
_bucket = None


def _resolve_cred_path() -> str:
    """
    Resolve Firebase service account credential path.
    Priority:
      1) FIREBASE_CRED
      2) GOOGLE_APPLICATION_CREDENTIALS
      3) default "serviceAccountKey.json" (project root relative)
    """
    cred_path = os.getenv("FIREBASE_CRED") or os.getenv("GOOGLE_APPLICATION_CREDENTIALS") or "serviceAccountKey.json"
    cred_path = cred_path.strip().strip('"').strip("'")
    return cred_path


def get_db():
    global _db

    if _db is not None:
        return _db

    cred_path = _resolve_cred_path()

    # Fail fast with a clear error if the file is missing
    if not os.path.exists(cred_path):
        raise RuntimeError(
            f"Firebase credential file not found: {cred_path}\n"
            f"Set FIREBASE_CRED to an absolute path, e.g.\n"
            f'  FIREBASE_CRED="C:\\\\path\\\\to\\\\serviceAccountKey.json"\n'
            f"Or place serviceAccountKey.json in the backend working directory."
        )

    cred = credentials.Certificate(cred_path)

    # Initialize Firebase once
    if not firebase_admin._apps:
        bucket_name = os.getenv("FIREBASE_STORAGE_BUCKET")
        init_opts = {}
        if bucket_name:
            init_opts["storageBucket"] = bucket_name

        firebase_admin.initialize_app(cred, init_opts)

    _db = firestore.client()
    return _db


def get_bucket():
    """
    Get Firebase Storage bucket (used for image uploads).
    FIREBASE_STORAGE_BUCKET must be set for storage operations.
    """
    global _bucket

    if _bucket is not None:
        return _bucket

    if not os.getenv("FIREBASE_STORAGE_BUCKET"):
        raise RuntimeError("FIREBASE_STORAGE_BUCKET is not set. Storage uploads will fail.")

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


def get_session(session_id: str):
    db = get_db()
    doc = db.collection("lf_sessions").document(session_id).get()

    if not doc.exists:
        return {"state": "menu", "data": {}, "updated_at": None}

    return doc.to_dict() or {"state": "menu", "data": {}, "updated_at": None}


def save_session(session_id: str, state: str, data: dict):
    db = get_db()
    db.collection("lf_sessions").document(session_id).set(
        {
            "state": state,
            "data": data,
            "updated_at": datetime.now(timezone.utc).isoformat()
        },
        merge=True
    )


def save_lost_found_report(report: dict):
    db = get_db()
    ticket_id = report["ticket_id"]
    db.collection("lost_found_reports").document(ticket_id).set(report)


def get_lost_found_report(ticket_id: str):
    db = get_db()
    doc = db.collection("lost_found_reports").document(ticket_id).get()

    if not doc.exists:
        return None

    return doc.to_dict()
