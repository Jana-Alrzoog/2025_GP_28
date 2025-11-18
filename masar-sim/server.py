# server.py
# FastAPI server for Masar Digital Twin + ML Forecasting

import os
import json
from datetime import datetime, timedelta
from typing import Dict, List

import joblib
import pandas as pd
from pydantic import BaseModel
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

import firebase_admin
from firebase_admin import credentials, firestore

# Import the simulation engine (snapshot generator)
from sim_core import (
    RIYADH_TZ,
    generate_all_stations_snapshot,
    make_snapshot_for_station,
    get_capacity,
    classify_from_cap,
)

# ------------------------------------------------------------
# Paths & Model Loading
# ------------------------------------------------------------

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

MODEL_PATH = os.path.join(
    BASE_DIR,
    "..",
    "masar_forecasting",
    "models",
    "masar_xgb_30min_model.pkl",
)

xgb_model = joblib.load(MODEL_PATH)

FEATURES = [
    "hour",
    "minute_of_day",
    "day_of_week",
    "is_weekend",
    "station_id",
    "headway_seconds",
    "event_flag",
    "holiday_flag",
    "special_event_type",
    "lag_5",
    "lag_15",
    "lag_30",
    "lag_60",
    "lag_120",
    "roll_mean_15",
    "roll_std_15",
    "roll_mean_60",
]

LEVEL_TO_INT = {
    "Low": 0,
    "Medium": 1,
    "High": 2,
    "Extreme": 3,
}

# ------------------------------------------------------------
# FastAPI App
# ------------------------------------------------------------
app = FastAPI(
    title="Masar Snapshot & Forecast API",
    description="On-demand congestion snapshots + 30-min ML forecast for Riyadh Metro stations",
    version="1.0.0",
)

# CORS for Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # change in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------------------------------------------------
# Firebase / Firestore Initialization
# ------------------------------------------------------------
_firestore_client = None


def init_firebase_app():
    global _firestore_client
    if _firestore_client is not None:
        return _firestore_client

    svc_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")

    if svc_json:
        info = json.loads(svc_json)
        cred = credentials.Certificate(info)
    else:
        local_path = os.path.join(BASE_DIR, "serviceAccount.json")
        cred = credentials.Certificate(local_path)

    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)

    _firestore_client = firestore.client()
    return _firestore_client


def get_firestore_client():
    return init_firebase_app()


# ------------------------------------------------------------
# Pydantic Input for Prediction
# ------------------------------------------------------------
class CrowdRequest(BaseModel):
    hour: int
    minute_of_day: int
    day_of_week: int
    is_weekend: int
    station_id: int
    headway_seconds: float
    event_flag: int
    holiday_flag: int
    special_event_type: int
    lag_5: float
    lag_15: float
    lag_30: float
    lag_60: float
    lag_120: float
    roll_mean_15: float
    roll_std_15: float
    roll_mean_60: float


# ------------------------------------------------------------
# ML Prediction
# ------------------------------------------------------------
@app.post("/predict_30min")
def predict_30min(req: CrowdRequest):
    row = pd.DataFrame([req.dict()])[FEATURES]

    y_pred = float(xgb_model.predict(row)[0])
    predicted_total = max(0.0, y_pred)

    station_code = f"S{req.station_id}"

    capacity = get_capacity(station_code)

    level_text, ratio = classify_from_cap(predicted_total, capacity)
    level_code = LEVEL_TO_INT[level_text]

    return {
        "station_id_ml": req.station_id,
        "station_id": station_code,
        "predicted_occupancy_30min": predicted_total,
        "capacity_station": capacity,
        "utilization_ratio": ratio,
        "crowd_level_30min": level_text,
        "crowd_level_30min_code": level_code,
    }


# ------------------------------------------------------------
# Health Check
# ------------------------------------------------------------
@app.get("/health")
def health_check():
    return {"status": "ok"}


# ------------------------------------------------------------
# Snapshots: All Stations
# ------------------------------------------------------------
@app.get("/snapshot/all")
def snapshot_all():
    dt = datetime.now(RIYADH_TZ)
    snapshots = generate_all_stations_snapshot(dt)

    return {
        "timestamp": dt.isoformat(),
        "count": len(snapshots),
        "stations": snapshots,
    }


# ------------------------------------------------------------
# Snapshot: Single Station
# ------------------------------------------------------------
@app.get("/snapshot/{station_id}")
def snapshot_station(station_id: str):
    dt = datetime.now(RIYADH_TZ)
    snap = make_snapshot_for_station(station_id, dt)
    return snap


# ------------------------------------------------------------
# Backfill: Generate Last 2 Hours and Write to Firestore
# ------------------------------------------------------------
def generate_last_2h_history(step_minutes=1):
    now = datetime.now(RIYADH_TZ)
    start = now - timedelta(hours=2)
    t = start

    snapshots = []
    while t <= now:
        frame = generate_all_stations_snapshot(t)
        for s in frame:
            item = s.copy()
            item["timestamp"] = t
            snapshots.append(item)
        t += timedelta(minutes=step_minutes)

    return snapshots


def write_last_2h_to_firestore(step_minutes=1):
    db = get_firestore_client()
    snapshots = generate_last_2h_history(step_minutes)

    batch = db.batch()
    count = 0

    for snap in snapshots:
        station_id = snap["station_id"]
        ts = snap["timestamp"]

        doc_ref = (
            db.collection("live")
            .document(station_id)
            .collection("ticks")
            .document(ts.isoformat())
        )

        batch.set(doc_ref, snap)
        count += 1

        if count % 400 == 0:
            batch.commit()
            batch = db.batch()

    batch.commit()
    return count


@app.post("/backfill_last_2h")
def backfill_last_2h():
    try:
        written = write_last_2h_to_firestore(step_minutes=1)
        return {
            "status": "ok",
            "written_ticks": written,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ------------------------------------------------------------
# Live Tick: Add Now + Delete Older Than 2 Hours
# ------------------------------------------------------------
def write_current_tick(now):
    db = get_firestore_client()
    frame = generate_all_stations_snapshot(now)

    batch = db.batch()
    for snap in frame:
        station_id = snap["station_id"]

        doc_ref = (
            db.collection("live")
            .document(station_id)
            .collection("ticks")
            .document(now.isoformat())
        )

        batch.set(doc_ref, snap)

    batch.commit()


def delete_old(now):
    db = get_firestore_client()
    cutoff = now - timedelta(hours=2)

    stations = db.collection("live").stream()
    deleted = 0

    for station in stations:
        ticks = (
            station.reference.collection("ticks")
            .where("timestamp", "<", cutoff)
            .stream()
        )

        batch = db.batch()
        has = False

        for doc in ticks:
            batch.delete(doc.reference)
            has = True
            deleted += 1

        if has:
            batch.commit()

    return deleted


@app.post("/tick_live")
def tick_live():
    now = datetime.now(RIYADH_TZ)

    try:
        write_current_tick(now)
        deleted = delete_old(now)

        return {
            "status": "ok",
            "now": now.isoformat(),
            "deleted_old_ticks": deleted,
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ------------------------------------------------------------
# Local Run
# ------------------------------------------------------------
if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
