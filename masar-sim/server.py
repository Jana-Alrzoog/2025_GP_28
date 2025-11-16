# server.py
# FastAPI server for Masar Digital Twin Snapshot Generator
import os
import joblib
import pandas as pd
from pydantic import BaseModel

from datetime import datetime
from typing import Dict

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Import the simulation engine (snapshot generator)
from sim_core import (
    RIYADH_TZ,
    generate_all_stations_snapshot,
    make_snapshot_for_station,
)

# ------------------------------------------------------------
# Create FastAPI application
# ------------------------------------------------------------
app = FastAPI(
    title="Masar Snapshot API",
    description="On-demand congestion snapshots for Riyadh Metro stations",
    version="1.0.0",
)

# ------------------------------------------------------------

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# ../models/masar_xgb_30min_model.pkl
MODEL_PATH = os.path.join(BASE_DIR, "..", "models", "masar_xgb_30min_model.pkl")

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


@app.post("/predict_30min")
def predict_30min(req: CrowdRequest):
    row = pd.DataFrame([req.dict()])[FEATURES]

    y_pred = xgb_model.predict(row)[0]

    return {
        "crowd_level_30min": int(y_pred)  # مثال: 0=Low,1=Med,2=High,3=Extreme حسب تدريبك
    }
# ------------------------------------------------------------
# Enable CORS so the Flutter mobile app can access the API
# ------------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: restrict to your production domain later
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------------------------------------------------
# Health Check Endpoint
# ------------------------------------------------------------
@app.get("/health")
def health_check() -> Dict:
    """Simple endpoint to confirm that the server is running."""
    return {"status": "ok"}

# ------------------------------------------------------------
# Snapshot for ALL stations
# ------------------------------------------------------------
@app.get("/snapshot/all")
def snapshot_all() -> Dict:
    """
    Generate a snapshot for ALL metro stations using the current Riyadh time.

    Returns:
        {
            "timestamp": "...",
            "count": N,
            "stations": [ {...}, {...}, ... ]
        }
    """
    dt = datetime.now(RIYADH_TZ)
    snapshots = generate_all_stations_snapshot(dt)

    return {
        "timestamp": dt.isoformat(),
        "count": len(snapshots),
        "stations": snapshots,
    }

# ------------------------------------------------------------
# Snapshot for a single station
# ------------------------------------------------------------
@app.get("/snapshot/{station_id}")
def snapshot_station(station_id: str) -> Dict:
    """
    Generate a snapshot for a specific station.

    Example:
        GET /snapshot/S1
    """
    dt = datetime.now(RIYADH_TZ)
    snap = make_snapshot_for_station(station_id, dt)
    return snap

# ------------------------------------------------------------
# Local server launcher (used when running locally or in Colab)
# ------------------------------------------------------------
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)





