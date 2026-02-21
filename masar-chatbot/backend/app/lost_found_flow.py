from datetime import datetime, timezone
import uuid
from typing import Optional

from app.session_store import get_session, save_session
from app.report_store import save_lost_found_report


STATION_OPTIONS = [
    {"id": "kafd", "label": "كافد"},
    {"id": "stc_olaya", "label": "محطة STC العليا"},
    {"id": "qasr_alhokm", "label": "قصر الحكم"},
    {"id": "national_museum", "label": "المتحف الوطني"},
    {"id": "airport_t1_t2", "label": "المطار (1-2)"},
    {"id": "first_industrial", "label": "المدينة الصناعية الاولى"},
]

WHEN_OPTIONS = [
    {"id": "today_morning", "label": "اليوم صباحا"},
    {"id": "today_noon", "label": "اليوم ظهرا"},
    {"id": "today_evening", "label": "اليوم مساء"},
    {"id": "yesterday", "label": "امس"},
    {"id": "older", "label": "قبل اكثر من يوم"},
    {"id": "not_sure", "label": "لا اتذكر"},
]


def _format_options(options):
    # Keep it simple so your Flutter regex catches it: "1 - xxx"
    return "\n".join([f"{i+1} - {opt['label']}" for i, opt in enumerate(options)])


def _looks_like_date(s: str) -> bool:
    s = (s or "").strip()
    if len(s) != 10:
        return False
    if s[4] != "-" or s[7] != "-":
        return False
    y, m, d = s.split("-")
    return y.isdigit() and m.isdigit() and d.isdigit()


def _normalize_ar_yes_no(msg: str) -> str:
    """
    Returns: "yes" | "no" | ""
    """
    m = (msg or "").strip().lower()
    m = " ".join(m.split())

    yes_set = {"نعم", "اي", "ايوه", "ايوا", "يب", "yes", "y"}
    no_set = {"لا", "لاا", "لااا", "مو", "no", "n"}

    if m in yes_set:
        return "yes"
    if m in no_set:
        return "no"

    if "نعم" in m or "ايو" in m or "يب" in m:
        return "yes"
    if m.startswith("لا") or "مو" in m:
        return "no"

    return ""


def handle_lost_found_flow(
    session_id: str,
    user_message: str,
    passenger_id: str,
    photo_url: Optional[str] = None,
) -> str:
    """
    Lost & Found flow.

    Important:
    - The app uploads an image to /lost-found/upload-image which stores photo_url in session data.
    - This flow reads photo_url from session data when waiting for the image.
    - This file returns text messages with stable tags (e.g., [LF_STATION]) so the mobile app can render icons.
    """

    pid = (passenger_id or "").strip() or "anonymous"

    session = get_session(pid, session_id)
    state = session.get("state", "menu")
    data = session.get("data", {}) or {}

    user_message = (user_message or "").strip()

    if passenger_id:
        data["passenger_id"] = passenger_id

    # -------------------------
    # START
    # -------------------------
    if state == "menu":
        save_session(pid, session_id, "lf_item_type", data)
        return (
            "[LF_START]\n"
            "بدينا تسجيل بلاغ مفقود.\n\n"
            "1) اكتبي نوع الغرض المفقود.\n"
            "مثال: محفظة، جوال، بطاقة، مفاتيح، شنطة."
        )

    # -------------------------
    # ITEM TYPE
    # -------------------------
    if state == "lf_item_type":
        if not user_message:
            return (
                "[LF_ERROR]\n"
                "فضلا اكتبي نوع الغرض المفقود."
            )

        data["item_type"] = user_message
        save_session(pid, session_id, "lf_color", data)

        # ✅ FIX: this step is asking for color => LF_COLOR
        return (
            "[LF_COLOR]\n"
            "تمام.\n\n"
            "2) اكتبي لون الغرض.\n"
            "مثال: اسود، ابيض، احمر، ازرق، فضي.\n"
            "اذا اللون غير واضح اكتبي: غير واضح."
        )

    # -------------------------
    # COLOR
    # -------------------------
    if state == "lf_color":
        if not user_message:
            return (
                "[LF_ERROR]\n"
                "فضلا اكتبي لون الغرض او اكتبي: غير واضح."
            )

        data["color"] = user_message
        save_session(pid, session_id, "lf_brand", data)

        # ✅ FIX: this step is brand/model => LF_BRAND
        return (
            "[LF_BRAND]\n"
            "3) اكتبي الماركة او الموديل (اختياري).\n"
            "مثال: سامسونج، هواوي، نايك.\n"
            "اذا ما تعرفين اكتبي: تخطي."
        )

    # -------------------------
    # BRAND (optional)
    # -------------------------
    if state == "lf_brand":
        if user_message in {"تخطي", "تجاوز", "skip"}:
            data["brand"] = None
        else:
            data["brand"] = user_message if user_message else None

        save_session(pid, session_id, "lf_description", data)

        # ✅ FIX: now asking for description => LF_DESC
        return (
            "[LF_DESC]\n"
            "4) اكتبي تفاصيل او علامة مميزة (اختياري لكنه يساعد).\n"
            "مثال: خدش، ستيكر، كفر، كتابة.\n"
            "اذا ما عندك تفاصيل اكتبي: ماعندي."
        )

    # -------------------------
    # DESCRIPTION
    # -------------------------
    if state == "lf_description":
        if not user_message:
            return (
                "[LF_ERROR]\n"
                "فضلا اكتبي التفاصيل او اكتبي: ماعندي."
            )

        data["description"] = "" if user_message in {"ماعندي", "ما عندي", "لا يوجد", "none"} else user_message
        save_session(pid, session_id, "lf_photo_choice", data)

        return (
            "[LF_PHOTO]\n"
            "5) هل ترغبين في ارفاق صورة للغرض؟ (اختياري)\n"
            "اكتبي: نعم او لا."
        )

    # -------------------------
    # PHOTO CHOICE
    # -------------------------
    if state == "lf_photo_choice":
        ans = _normalize_ar_yes_no(user_message)

        if ans == "yes":
            data["photo_url"] = None
            save_session(pid, session_id, "lf_expect_photo", data)
            return (
                "[LF_PHOTO]\n"
                "تمام.\n"
                "ارفقي الصورة الان من داخل التطبيق.\n"
                "اذا تبين تكملين بدون صورة اكتبي: لا."
            )

        if ans == "no":
            data["photo_url"] = None
            save_session(pid, session_id, "lf_station", data)
            return (
                "[LF_STATION]\n"
                "تم المتابعة بدون صورة.\n\n"
                "6) اختاري محطة الفقد:\n\n"
                f"{_format_options(STATION_OPTIONS)}"
            )

        return (
            "[LF_ERROR]\n"
            "الرجاء كتابة: نعم او لا."
        )

    # -------------------------
    # WAITING FOR PHOTO ATTACHMENT
    # -------------------------
    if state == "lf_expect_photo":
        stored_url = (data.get("photo_url") or "").strip()
        if stored_url:
            save_session(pid, session_id, "lf_station", data)
            return (
                "[LF_STATION]\n"
                "تم استلام الصورة.\n\n"
                "6) اختاري محطة الفقد:\n\n"
                f"{_format_options(STATION_OPTIONS)}"
            )

        ans = _normalize_ar_yes_no(user_message)
        if ans == "no":
            data["photo_url"] = None
            save_session(pid, session_id, "lf_station", data)
            return (
                "[LF_STATION]\n"
                "تم المتابعة بدون صورة.\n\n"
                "6) اختاري محطة الفقد:\n\n"
                f"{_format_options(STATION_OPTIONS)}"
            )

        return (
            "[LF_PHOTO]\n"
            "بانتظار ارفاق الصورة من التطبيق.\n"
            "اذا تبين تكملين بدون صورة اكتبي: لا."
        )

    # -------------------------
    # STATION
    # -------------------------
    if state == "lf_station":
        try:
            idx = int(user_message) - 1
            station = STATION_OPTIONS[idx]
            data["station_id"] = station["id"]
            data["station_name"] = station["label"]
        except Exception:
            return (
                "[LF_ERROR]\n"
                "الرجاء اختيار رقم صحيح من قائمة المحطات."
            )

        save_session(pid, session_id, "lf_when", data)
        return (
            "[LF_TIME]\n"
            "7) متى تقريبا فقدت الغرض؟\n\n"
            f"{_format_options(WHEN_OPTIONS)}"
        )

    # -------------------------
    # WHEN LOST
    # -------------------------
    if state == "lf_when":
        try:
            idx = int(user_message) - 1
            when = WHEN_OPTIONS[idx]
            data["lost_time_id"] = when["id"]
            data["lost_time_label"] = when["label"]
        except Exception:
            return (
                "[LF_ERROR]\n"
                "الرجاء اختيار رقم صحيح من القائمة."
            )

        if data["lost_time_id"] == "older":
            save_session(pid, session_id, "lf_date", data)
            return (
                "[LF_DATE]\n"
                "8) اكتبي التاريخ التقريبي بصيغة YYYY-MM-DD.\n"
                "مثال: 2026-01-20"
            )

        save_session(pid, session_id, "lf_name", data)
        return (
            "[LF_CONTACT]\n"
            "8) اكتبي اسمك الكامل."
        )

    # -------------------------
    # DATE
    # -------------------------
    if state == "lf_date":
        if not _looks_like_date(user_message):
            return (
                "[LF_ERROR]\n"
                "فضلا اكتبي التاريخ بصيغة YYYY-MM-DD.\n"
                "مثال: 2026-01-20"
            )

        data["lost_date"] = user_message
        save_session(pid, session_id, "lf_name", data)
        return (
            "[LF_CONTACT]\n"
            "9) اكتبي اسمك الكامل."
        )

    # -------------------------
    # NAME
    # -------------------------
    if state == "lf_name":
        if not user_message:
            return (
                "[LF_ERROR]\n"
                "فضلا اكتبي الاسم الكامل."
            )

        data["name"] = user_message

        # ✅ FIX: move to lf_phone state
        save_session(pid, session_id, "lf_phone", data)

        return (
            "[LF_CONTACT]\n"
            "10) اكتبي رقم الجوال للتواصل."
        )

    # -------------------------
    # PHONE + SAVE
    # -------------------------
    if state == "lf_phone":
        if not user_message:
            return (
                "[LF_ERROR]\n"
                "فضلا اكتبي رقم الجوال."
            )

        data["phone"] = user_message
        ticket_id = str(uuid.uuid4())[:8].upper()

        report = {
            "ticket_id": ticket_id,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "status": "open",
            "passenger_id": data.get("passenger_id", passenger_id),

            "item_type": data.get("item_type", ""),
            "color": data.get("color", ""),
            "brand": data.get("brand", None),
            "description": data.get("description", ""),
            "photo_url": data.get("photo_url", None),

            "station_id": data.get("station_id", ""),
            "station_name": data.get("station_name", ""),
            "lost_time_id": data.get("lost_time_id", ""),
            "lost_time_label": data.get("lost_time_label", ""),
            "lost_date": data.get("lost_date", None),

            "name": data.get("name", ""),
            "phone": data.get("phone", ""),
        }

        save_lost_found_report(report)
        save_session(pid, session_id, "menu", {})

        return (
            "[LF_DONE]\n"
            "تم تسجيل البلاغ بنجاح.\n"
            f"رقم التذكرة: {ticket_id}\n\n"
            "سيتم التواصل معك عند العثور على الغرض.\n"
            "شكرا لاستخدامك مساعد مسار."
        )

    return (
        "[LF_ERROR]\n"
        "حدث خطأ غير متوقع. اكتبي: menu للعودة للقائمة."
    )
