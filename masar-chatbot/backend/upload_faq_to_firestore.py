import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore

# Paths (all files are located inside the backend folder)
EXCEL_PATH = "Dataset_metro.xlsx"
SERVICE_KEY = "serviceAccountKey.json"
COLLECTION = "faq"

# Initialize Firebase Admin SDK using the service account key
cred = credentials.Certificate(SERVICE_KEY)
firebase_admin.initialize_app(cred)
db = firestore.client()

# Read the Excel file containing the FAQ data
# The file includes two columns: "السؤال" and "الإجابة"
df = pd.read_excel(EXCEL_PATH)

# Column names as they appear in the Excel file
QUESTION_COL = "السؤال"
ANSWER_COL = "الإجابة"

# Firestore allows a maximum of 500 operations per batch
batch = db.batch()
count = 0

for _, row in df.iterrows():
    question = str(row.get(QUESTION_COL, "")).strip()
    answer = str(row.get(ANSWER_COL, "")).strip()

    # Skip empty or invalid rows
    if not question or not answer or question == "nan" or answer == "nan":
        continue

    # Create a new document with an auto-generated IpD
    doc_ref = db.collection(COLLECTION).document()
    batch.set(doc_ref, {
        "question": question,
        "answer": answer,
        "category": "general"
    })

    count += 1

    # Commit the batch every 400 documents to stay within Firestore limits
    if count % 400 == 0:
        batch.commit()
        batch = db.batch()

# Commit any remaining documents
batch.commit()

print(f"Successfully uploaded {count} FAQ items to the '{COLLECTION}' collection.")
