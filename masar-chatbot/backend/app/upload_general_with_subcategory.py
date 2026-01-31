import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore
from general_router import detect_general_subcategory

EXCEL_PATH = "Dataset_metro.xlsx"
SERVICE_KEY = "serviceAccountKey.json"
COLLECTION = "faq"

cred = credentials.Certificate(SERVICE_KEY)
firebase_admin.initialize_app(cred)
db = firestore.client()

df = pd.read_excel(EXCEL_PATH)

QUESTION_COL = "السؤال"
ANSWER_COL = "الإجابة"

batch = db.batch()
count = 0

for _, row in df.iterrows():
    question = str(row.get(QUESTION_COL, "")).strip()
    answer = str(row.get(ANSWER_COL, "")).strip()

    if not question or not answer or question == "nan" or answer == "nan":
        continue

    # Auto-detect subcategory inside General
    sub_category = detect_general_subcategory(question)

    doc_ref = db.collection(COLLECTION).document()
    batch.set(doc_ref, {
        "question": question,
        "answer": answer,
        "intent": "general",
        "sub_category": sub_category
    })

    count += 1
    if count % 400 == 0:
        batch.commit()
        batch = db.batch()

batch.commit()
print(f" Uploaded {count} general FAQs with sub_category.")
