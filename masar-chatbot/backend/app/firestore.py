import os
import firebase_admin
from firebase_admin import credentials, firestore

# backend/ directory path
BASE_DIR = os.path.dirname(os.path.dirname(__file__))  # backend/
KEY_PATH = os.path.join(BASE_DIR, "serviceAccountKey.json")

# Initialize Firebase only once
if not firebase_admin._apps:
    cred = credentials.Certificate(KEY_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()

def get_all_faq():
    docs = db.collection("faq").stream()
    return [
        {
            "question": d.to_dict().get("question", ""),
            "answer": d.to_dict().get("answer", "")
        }
        for d in docs
    ]
