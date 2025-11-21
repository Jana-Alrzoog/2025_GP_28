# server.py
# FastAPI server for Masar Digital Twin + ML Forecasting

import os
import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional

import joblib
import pandas as pd
from pydantic import BaseModel
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

import firebase_admin
from firebase_admin import credentials, firestore

# Import simulation engine
from sim_core import (
    RIYADH_TZ,
    generate_all_stations_snapshot,
    make_snapshot_for_station,
    get_capacity,
    classify_from_cap,
)

# ------------------------------------------------------------
# Model loading
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
# FastAPI + CORS
# ------------------------------------------------------------

app = FastAPI(
    title="Masar Snapshot & Forecast API",
    description="On-demand congestion snapshots + 30-min ML forecast",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # TODO: restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------------------------------------------------
# Firestore init with env variable
# ------------------------------------------------------------

_firestore_client = None


def init_firebase_app():
    """
    Initialize Firebase app using either an environment variable
    or a local serviceAccount.json file.
    """
    global _firestore_client
    if _firestore_client is not None:
        return _firestore_client

    svc_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")

    if svc_json:
        info = json.loads(svc_json)
        cred = credentials.Certificate(info)
    else:
        # Local development fallback
        local_path = os.path.join(BASE_DIR, "serviceAccount.json")
        cred = credentials.Certificate(local_path)

    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)

    _firestore_client = firestore.client()
    return _firestore_client


def get_firestore_client():
    """Return a singleton Firestore client."""
    return init_firebase_app()

# ------------------------------------------------------------
# Prediction input (manual mode - for testing)
# ------------------------------------------------------------


class CrowdRequest(BaseModel):
    """
    Manual prediction input. This is kept for debugging / testing.
    In production, /predict_30min_live/{station_id} is recommended.
    """
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
# Helper: read last 120 minutes from Firestore and build lags
# ------------------------------------------------------------

def read_history_for_station(
    station_code: str,
    now: datetime,
    minutes_back: int = 120,
    max_docs: int = 240,
) -> pd.DataFrame:
    """
    Read recent history for a station from Firestore.

    We read up to max_docs ordered by timestamp desc,
    then filter to [now - minutes_back, now] and sort ascending.
    """
    db = get_firestore_client()

    col_ref = (
        db.collection("live")
        .document(station_code)
        .collection("ticks")
    )

    # Read most recent documents
    docs = (
        col_ref
        .order_by("timestamp", direction=firestore.Query.DESCENDING)
        .limit(max_docs)
        .stream()
    )

    rows = []
    cutoff = now - timedelta(minutes=minutes_back)

    for d in docs:
        data = d.to_dict() or {}
        ts = data.get("timestamp")
        total = data.get("station_total")

        if ts is None or total is None:
            continue

        # Firestore timestamp might be a datetime already
        if isinstance(ts, datetime):
            ts_dt = ts
        else:
            # Fallback, just in case
            ts_dt = ts

        if ts_dt < cutoff:
            # Older than the window we care about; we can skip
            continue

        rows.append(
            {
                "timestamp": ts_dt,
                "station_total": float(total),
            }
        )

    if not rows:
        return pd.DataFrame(columns=["timestamp", "station_total"])

    df = pd.DataFrame(rows).sort_values("timestamp").reset_index(drop=True)
    return df


def pick_lag(df: pd.DataFrame, now: datetime, minutes: int) -> float:
    """
    Pick the station_total value closest to (<= now - minutes),
    or fall back to earliest available value, or 0.0 if empty.
    """
    if df.empty:
        return 0.0

    target_time = now - timedelta(minutes=minutes)
    # Filter rows that are <= target_time
    subset = df[df["timestamp"] <= target_time]
    if not subset.empty:
        return float(subset["station_total"].iloc[-1])

    # If no row <= target_time, fall back to the earliest row
    return float(df["station_total"].iloc[0])


def rolling_mean(df: pd.DataFrame, now: datetime, window_min: int) -> float:
    """
    Compute rolling mean over the last 'window_min' minutes.
    Uses station_total values in [now - window_min, now].
    """
    if df.empty:
        return 0.0

    cutoff = now - timedelta(minutes=window_min)
    subset = df[df["timestamp"] >= cutoff]
    if subset.empty:
        return 0.0

    return float(subset["station_total"].mean())


def rolling_std(df: pd.DataFrame, now: datetime, window_min: int) -> float:
    """
    Compute rolling standard deviation over the last 'window_min' minutes.
    If fewer than 2 points are available, we return 0.0 to avoid NaN.
    """
    if df.empty:
        return 0.0

    cutoff = now - timedelta(minutes=window_min)
    subset = df[df["timestamp"] >= cutoff]
    if len(subset) < 2:
        return 0.0

    return float(subset["station_total"].std(ddof=0))


def station_code_to_numeric(station_code: str) -> int:
    """
    Convert 'S1' -> 1, 'S10' -> 10, etc.
    If the code is already numeric, we parse it directly.
    """
    s = station_code.strip()
    if s.upper().startswith("S"):
        s = s[1:]
    try:
        return int(s)
    except ValueError:
        # Fallback: 0 if parsing fails
        return 0


def build_feature_row_from_live(station_code: str) -> Dict:
    """
    Build a full feature row for the model using:
    - current Riyadh time
    - last 120 minutes from Firestore (for lags & rolling stats)
    - simple defaults for headway / event / holiday flags

    This is the main "smart" function for live prediction.
    """
    now = datetime.now(RIYADH_TZ)

    # 1) Read live history from Firestore (last 120 minutes)
    df = read_history_for_station(station_code, now, minutes_back=120)

    if df.empty:
        raise HTTPException(
            status_code=400,
            detail=f"No live history found for station {station_code}. "
                   f"Run /backfill_last_2h and /tick_live first."
        )

    # 2) Current crowd level = latest station_total
    current_total = float(df["station_total"].iloc[-1])

    # 3) Compute lags (using timestamps)
    lag_5 = pick_lag(df, now, 5)
    lag_15 = pick_lag(df, now, 15)
    lag_30 = pick_lag(df, now, 30)
    lag_60 = pick_lag(df, now, 60)
    lag_120 = pick_lag(df, now, 120)

    # 4) Rolling statistics
    roll_mean_15 = rolling_mean(df, now, 15)
    roll_std_15 = rolling_std(df, now, 15)
    roll_mean_60 = rolling_mean(df, now, 60)

    # 5) Time features
    hour = now.hour
    minute_of_day = now.hour * 60 + now.minute
    day_of_week = now.weekday()  # Monday=0 ... Sunday=6
    # Saudi weekend: Friday (4) and Saturday (5)
    is_weekend = 1 if day_of_week in (4, 5) else 0

    # 6) Station numeric ID
    station_id_numeric = station_code_to_numeric(station_code)

    # 7) Simple defaults (can be improved later)
    # In a real system, headway_seconds + event_flag + holiday_flag
    # could be derived from separate data sources or config.
    headway_seconds = 300.0
    event_flag = 0
    holiday_flag = 0
    special_event_type = 0

    features = {
        "hour": hour,
        "minute_of_day": minute_of_day,
        "day_of_week": day_of_week,
        "is_weekend": is_weekend,
        "station_id": station_id_numeric,
        "headway_seconds": headway_seconds,
        "event_flag": event_flag,
        "holiday_flag": holiday_flag,
        "special_event_type": special_event_type,
        "lag_5": lag_5,
        "lag_15": lag_15,
        "lag_30": lag_30,
        "lag_60": lag_60,
        "lag_120": lag_120,
        "roll_mean_15": roll_mean_15,
        "roll_std_15": roll_std_15,
        "roll_mean_60": roll_mean_60,
        # We also return current_total for convenience
        "current_total": current_total,
        "timestamp_now": now,
    }

    return features

# ------------------------------------------------------------
# Prediction APIs
# ------------------------------------------------------------


@app.post("/predict_30min")
def predict_30min(req: CrowdRequest):
    """
    Manual prediction endpoint (for debugging / experiments).

    Assumes the client already computed all features including
    lags and rolling statistics.
    """
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


@app.get("/predict_30min_live/{station_code}")
def predict_30min_live(station_code: str):
    """
    Live prediction endpoint.

    - Reads last 120 minutes for the given station from Firestore.
    - Computes lag features and rolling statistics on the backend.
    - Builds the full feature vector for the XGBoost model.
    - Returns a 30-min ahead crowd forecast + crowd level.

    This is the recommended endpoint for the Flutter app.
    """

    # Normalize station code, allow "1" or "S1"
    s = station_code.strip()
    if not s.upper().startswith("S"):
        s = f"S{s}"

    # Build all features from live history
    features = build_feature_row_from_live(s)

    # Prepare the row for the model
    model_input = {k: features[k] for k in FEATURES}
    row = pd.DataFrame([model_input])[FEATURES]

    # Run the model
    y_pred = float(xgb_model.predict(row)[0])
    predicted_total = max(0.0, y_pred)

    # Capacity-based classification
    capacity = get_capacity(s)
    level_text, ratio = classify_from_cap(predicted_total, capacity)
    level_code = LEVEL_TO_INT[level_text]

    now_ts = features["timestamp_now"]
    current_total = features["current_total"]

    return {
        "station_id": s,
        "station_id_ml": station_code_to_numeric(s),
        "timestamp_now": now_ts.isoformat(),
        "current_occupancy": current_total,
        "predicted_occupancy_30min": predicted_total,
        "capacity_station": capacity,
        "utilization_ratio": ratio,
        "crowd_level_30min": level_text,
        "crowd_level_30min_code": level_code,
        # Debug / transparency fields (optional, useful for the thesis)
        "features_used": {
            "hour": model_input["hour"],
            "minute_of_day": model_input["minute_of_day"],
            "day_of_week": model_input["day_of_week"],
            "is_weekend": model_input["is_weekend"],
            "lag_5": model_input["lag_5"],
            "lag_15": model_input["lag_15"],
            "lag_30": model_input["lag_30"],
            "lag_60": model_input["lag_60"],
            "lag_120": model_input["lag_120"],
            "roll_mean_15": model_input["roll_mean_15"],
            "roll_std_15": model_input["roll_std_15"],
            "roll_mean_60": model_input["roll_mean_60"],
        },
    }

# ------------------------------------------------------------
# Health
# ------------------------------------------------------------


@app.get("/health")
def health_check():
    """Simple health-check endpoint."""
    return {"status": "ok"}

# ------------------------------------------------------------
# Snapshots
# ------------------------------------------------------------


@app.get("/snapshot/all")
def snapshot_all():
    """
    Generate a snapshot for ALL metro stations at the current Riyadh time.
    """
    dt = datetime.now(RIYADH_TZ)
    snaps = generate_all_stations_snapshot(dt)
    return {
        "timestamp": dt.isoformat(),
        "count": len(snaps),
        "stations": snaps,
    }


@app.get("/snapshot/{station_id}")
def snapshot_station(station_id: str):
    """
    Generate a snapshot for a single station at the current Riyadh time.
    Example: /snapshot/S1
    """
    dt = datetime.now(RIYADH_TZ)
    return make_snapshot_for_station(station_id, dt)

# ------------------------------------------------------------
# BACKFILL last 2 hours (timestamp = Firestore Timestamp)
# ------------------------------------------------------------


def generate_last_2h_history(step_minutes=1):
    """
    Generate synthetic history for the last 2 hours using the simulator.
    The timestamps are minute-based and stored as datetime objects.
    """
    now = datetime.now(RIYADH_TZ)
    start = now - timedelta(hours=2)

    snapshots = []
    t = start

    while t <= now:
        frame = generate_all_stations_snapshot(t)
        for s in frame:
            item = s.copy()
            item["timestamp"] = t           # Firestore timestamp
            snapshots.append(item)
        t += timedelta(minutes=step_minutes)

    return snapshots


def write_last_2h_to_firestore(step_minutes=1):
    """
    Write the last 2 hours of synthetic history into Firestore
    under live/{station_id}/ticks/{YYYYMMDDHHMM}.
    """
    db = get_firestore_client()
    snaps = generate_last_2h_history(step_minutes)

    batch = db.batch()
    count = 0

    for snap in snaps:
        station_id = snap["station_id"]
        ts = snap["timestamp"]

        doc_id = ts.strftime("%Y%m%d%H%M")     # clean ID
        doc_ref = (
            db.collection("live")
            .document(station_id)
            .collection("ticks")
            .document(doc_id)
        )

        batch.set(doc_ref, snap)
        count += 1

        if count % 400 == 0:
            batch.commit()
            batch = db.batch()

    batch.commit()
    return count


@app.api_route("/backfill_last_2h", methods=["GET", "POST"])
def backfill_last_2h():
    """
    One-shot endpoint to pre-fill the last 2 hours of data in Firestore.
    Useful when the server starts (to avoid cold history for the model).
    """
    try:
        written = write_last_2h_to_firestore(step_minutes=1)
        return {"status": "ok", "written_ticks": written}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ------------------------------------------------------------
# LIVE tick (every minute)
# ------------------------------------------------------------


def write_current_tick(now):
    """
    Generate a snapshot for all stations at the given 'now' datetime
    and append it to Firestore as the current live tick.
    """
    db = get_firestore_client()
    frame = generate_all_stations_snapshot(now)

    batch = db.batch()

    for snap in frame:
        station_id = snap["station_id"]
        doc_id = now.strftime("%Y%m%d%H%M")

        snap["timestamp"] = now   # Firestore timestamp

        doc_ref = (
            db.collection("live")
            .document(station_id)
            .collection("ticks")
            .document(doc_id)
        )

        batch.set(doc_ref, snap)

    batch.commit()


def delete_old(now):
    """
    Delete any tick older than 2 hours for all stations,
    keeping a rolling 2-hour window of live data.

    Uses pagination (limit 300) per station to avoid exceeding
    Firestore batch operation limits.
    """
    cutoff = now - timedelta(hours=2)
    db = get_firestore_client()

    stations = db.collection("live").stream()
    deleted_total = 0

    for station in stations:
        ticks_ref = station.reference.collection("ticks")

        while True:
            # Take a small batch of old docs per station
            docs = list(
                ticks_ref
                .where("timestamp", "<", cutoff)
                .limit(300)
                .stream()
            )

            if not docs:
                # No more old docs for this station
                break

            batch = db.batch()
            for doc in docs:
                batch.delete(doc.reference)
                deleted_total += 1
            batch.commit()

    return deleted_total


@app.api_route("/tick_live", methods=["GET", "POST"])
def tick_live():
    """
    Live tick endpoint.

    - Generates a snapshot "now" for all stations.
    - Writes it to Firestore as the latest tick.
    - Deletes any tick older than 2 hours.
    """
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
# Local run
# ------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
