# app/places_service.py
import os
import re
import requests
from typing import Optional, Dict, Any

GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY", "")

# Endpoints
GEOCODE_URL = "https://maps.googleapis.com/maps/api/geocode/json"
PLACES_TEXTSEARCH_URL = "https://maps.googleapis.com/maps/api/place/textsearch/json"

# مرادفات اماكن مشهورة (تقدرين تزيدين)
PLACE_ALIASES = {
    "البوليفارد": "Riyadh Boulevard City",
    "بوليفارد": "Riyadh Boulevard City",
    "البوليفارد سيتي": "Riyadh Boulevard City",
    "بوليفارد سيتي": "Riyadh Boulevard City",
    "واجهة الرياض": "Riyadh Front",
    "الواجهة": "Riyadh Front",
    "المطار": "King Khalid International Airport",
    "جامعة الملك سعود": "King Saud University",
    "الرياض بارك": "Riyadh Park Mall",
}

# كلمات/عبارات زايدة نحذفها (كـ كلمات كاملة فقط)
FILLER_WORDS = [
    "ابي", "أبي", "ابغى", "أبغى", "ودي",
    "اروح", "أروح", "روح", "اذهب", "أذهب",
    "ل", "لـ", "الى", "إلى",
]

def normalize_place(text: str) -> str:
    """
    - يخفف الكلمات الزايدة بدون ما يخرب اسم المكان
    - يطبّق aliases للأماكن المعروفة
    """
    original = (text or "").strip()
    if not original:
        return ""

    t = original.strip().lower()

    # احذف كلمات زايدة ككلمات كاملة (مو replace عشوائي)
    # مثال: "ابي اروح البوليفارد" -> "البوليفارد"
    for w in FILLER_WORDS:
        t = re.sub(rf"\b{re.escape(w.lower())}\b", " ", t)

    # نظف المسافات
    t = " ".join(t.split())

    # aliases (بحث contains)
    for k, v in PLACE_ALIASES.items():
        if k in t:
            return v

    # رجّع النص بعد التنظيف، وإذا صار فاضي رجّع الأصل
    return t if t else original


def _safe_float(x) -> Optional[float]:
    try:
        if x is None:
            return None
        return float(x)
    except Exception:
        return None


def _places_textsearch(query: str) -> Optional[Dict[str, Any]]:
    """
    أدق للأماكن المشهورة (Boulevard/مول/واجهة...) بشرط تفعيل Places API
    """
    if not GOOGLE_MAPS_API_KEY or not query:
        return None

    params = {
        "query": query,
        "key": GOOGLE_MAPS_API_KEY,
        "language": "ar",
        "region": "sa",
    }

    r = requests.get(PLACES_TEXTSEARCH_URL, params=params, timeout=8)
    r.raise_for_status()
    data = r.json()

    if data.get("status") != "OK":
        return None

    result = (data.get("results") or [None])[0]
    if not result:
        return None

    loc = (result.get("geometry") or {}).get("location") or {}
    lat = _safe_float(loc.get("lat"))
    lon = _safe_float(loc.get("lng"))
    if lat is None or lon is None:
        return None

    name = (result.get("name") or "").strip()
    address = (result.get("formatted_address") or query).strip()

    return {
        "lat": lat,
        "lon": lon,
        "name": name or address,
        "formatted_address": address,
        "source": "places_textsearch",
    }


def _geocode(query: str) -> Optional[Dict[str, Any]]:
    """
    fallback: Geocode API
    """
    if not GOOGLE_MAPS_API_KEY or not query:
        return None

    params = {
        "address": query,
        "key": GOOGLE_MAPS_API_KEY,
        "language": "ar",
        "region": "sa",
    }

    r = requests.get(GEOCODE_URL, params=params, timeout=8)
    r.raise_for_status()
    data = r.json()

    if data.get("status") != "OK":
        return None

    result = (data.get("results") or [None])[0]
    if not result:
        return None

    loc = (result.get("geometry") or {}).get("location") or {}
    lat = _safe_float(loc.get("lat"))
    lon = _safe_float(loc.get("lng"))
    if lat is None or lon is None:
        return None

    address = (result.get("formatted_address") or query).strip()

    # أحيانًا الاسم ما يكون موجود في geocode، نخليه نفس العنوان
    return {
        "lat": lat,
        "lon": lon,
        "name": address,
        "formatted_address": address,
        "source": "geocode",
    }


def geocode_place(place_name: str) -> Optional[Dict[str, Any]]:
    """
    Returns dict or None

    Output shape (مهم عشان main.py):
      {
        "lat": float,
        "lon": float,
        "name": str,
        "formatted_address": str
      }
    """
    if not GOOGLE_MAPS_API_KEY:
        return None

    query = normalize_place(place_name)
    if not query:
        return None

    try:
        # 1) جرّبي Places Text Search أول (أدق)
        res = _places_textsearch(query)
        if res:
            return {
                "lat": res["lat"],
                "lon": res["lon"],
                "name": res.get("name") or res.get("formatted_address") or query,
                "formatted_address": res.get("formatted_address") or query,
            }

        # 2) fallback: Geocode
        res = _geocode(query)
        if res:
            return {
                "lat": res["lat"],
                "lon": res["lon"],
                "name": res.get("name") or res.get("formatted_address") or query,
                "formatted_address": res.get("formatted_address") or query,
            }

        return None

    except Exception:
        return None