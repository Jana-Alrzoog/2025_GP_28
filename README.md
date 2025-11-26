<h1 align="center">Masar 🚆</h1>

<p align="center">
  <img src="https://readme-typing-svg.demolab.com?size=20&duration=4000&pause=800&color=808080&center=true&vCenter=true&width=1000&lines=AI-Powered+Digital+Twin+System+for+Enhanced+Riyadh+Metro+Services" />
</p>

---

## Introduction
**Masar** is an AI-powered **Digital Twin system** designed to enhance passenger experience and optimize metro operations in the Riyadh Metro.  
The system predicts station crowd levels 30 minutes ahead, provides real-time congestion visualizations, and offers an intelligent dashboard for metro staff to monitor and manage high-traffic situations.  
Masar supports the goals of **Saudi Vision 2030** by enabling smarter, safer, and more efficient public transportation.

---

## Technology Stack

###  Frontend (Mobile App)
- **Flutter (Dart)**
- Google Maps integration  
- Real-time UI updates via Firestore

###  AI & Prediction Models
- **Python** (NumPy, Pandas, Scikit-Learn, XGBoost)
- Pre-trained **XGBoost model** for 30-minute crowd forecasting  
- Digital Twin–based data simulation (`masar-sim`)
- Training notebooks located in: `masar_forecasting/notebooks`

###  Backend & Services
- **FastAPI** for REST APIs  
- Deployed on **Render**  
- Endpoints for trips, live snapshots, alerts, and predictions  
- Firebase Admin SDK for secure Firestore access  

###  Databases & Cloud
- **Firestore NoSQL Database**  
- Firebase Authentication  
- Cloud Storage for assets/configs  

###  Web Dashboard (Staff)
- Flutter Web (or basic JS depending on build)
- Real-time crowd monitoring  
- Integrated with XGBoost prediction outputs  

---

## Launch Instructions

### 1️⃣ Clone the Repository
```bash
git clone https://github.com/your-username/your-repo-name.git
cd your-repo-name
```

---

## 2️⃣ Run the Flutter App
```bash
flutter pub get
flutter run
```

For web:
```bash
flutter run -d chrome
```

---

## 3️⃣ Run the FastAPI Backend
```bash
pip install -r requirements.txt
uvicorn main:app --reload
```

---

## 4️⃣ Run the Forecasting Module

Since the project uses **notebooks** instead of `.py` scripts:

```bash
cd masar_forecasting
pip install -r requirements.txt
```

To **train or retrain** the XGBoost model:
- Open the notebook:
  ```
  notebooks/XGBoost_Training_CrowdPrediction.ipynb
  ```
- Run all cells to generate a new model under:
  ```
  models/masar_xgb_30min_model.pkl
  ```

To **generate predictions**:
- Use the prediction cells inside the same notebook.
- Export results to CSV as needed for the backend.

---

## 5️⃣ Firebase Setup
Make sure the following files are added (not committed):

- `google-services.json` → **Android**
- `GoogleService-Info.plist` → **iOS**
- Backend service account key → For FastAPI Firestore access

---

## Project Structure

```
lib/                 # Flutter mobile app
masar-sim/           # Digital Twin data simulation
masar_forecasting/   # XGBoost forecasting notebooks + model
web/                 # Staff dashboard
assets/              # Images and static files
android/ios/web/     # Flutter platform folders
```

---


