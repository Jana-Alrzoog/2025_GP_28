from datetime import datetime, timezone
import uuid

from app.session_store import get_session, save_session
from app.report_store import save_lost_found_report


# Station options
STATION_OPTIONS = [
    {"id": "kafd", "label": "كافد"},
    {"id": "stc_olaya", "label": "محطة STC العليا"},
    {"id": "qasr_alhokm", "label": "قصر الحكم"},
    {"id": "national_museum", "label": "المتحف الوطني"},
    {"id": "airport_t1_t2", "label": "المطار (1–2)"},
    {"id": "first_industrial", "label": "المدينة الصناعية الأولى"},
]

# Time options
WHEN_OPTIONS = [
    {"id": "today_morning", "label": "اليوم صباحًا"},
    {"id": "today_noon", "label": "اليوم ظهرًا"},
    {"id": "today_evening", "label": "اليوم مساءً"},
    {"id": "yesterday", "label": "أمس"},
    {"id": "older", "label": "قبل أكثر من يوم"},
    {"id": "not_sure", "label": "لا أتذكر"},
]


def _format_options(options):
    return "\n".join([f"{i+1}️⃣ {opt['label']}" for i, opt in enumerate(options)])


def _looks_like_date(s: str) -> bool:
    s = (s or "").strip()
    if len(s) != 10:
        return False
    if s[4] != "-" or s[7] != "-":
        return False
    y, m, d = s.split("-")
    return y.isdigit() and m.isdigit() and d.isdigit()


def _is_photo_url_message(msg: str) -> bool:
    msg = (msg or "").strip()
    return msg.startswith("PHOTO_URL:") or msg.startswith("http")


def _extract_photo_url(msg: str) -> str:
    msg = (msg or "").strip()
    if msg.startswith("PHOTO_URL:"):
        return msg.replace("PHOTO_URL:", "", 1).strip()
    return msg


def handle_lost_found_flow(session_id: str, user_message: str, passenger_id: str) -> str:
    """
    Lost & Found flow (chat-based form).
    Requires passenger_id (user is logged in).

    ✅ Updated to use per-user session key:
    get_session(passenger_id, session_id)
    save_session(passenger_id, session_id, state, data)
    """

    # ✅ Safety: ensure we always have some passenger_id key
    pid = (passenger_id or "").strip()
    if not pid:
        pid = "anonymous"

    session = get_session(pid, session_id)
    state = session.get("state", "menu")
    data = session.get("data", {}) or {}

    user_message = (user_message or "").strip()

    # Always bind passenger_id to the session data (so it is not lost mid-flow)
    if passenger_id:
        data["passenger_id"] = passenger_id

    # START FLOW
    if state == "menu":
        save_session(pid, session_id, "lf_item_type", data)
        return (
            "🧳 سأساعدك في الإبلاغ عن مفقود.\n\n"
            "ما نوع الشيء المفقود؟\n"
            "مثال: حقيبة، جوال، بطاقة، ساعة..."
        )

    # ITEM TYPE
    if state == "lf_item_type":
        if not user_message:
            return "فضلاً اكتب نوع الشيء المفقود (مثال: جوال، حقيبة...)."
        data["item_type"] = user_message
        save_session(pid, session_id, "lf_description", data)
        return "✏️ صف الشيء المفقود بتفصيل (اللون، الحجم، أي علامة مميزة)."

    # DESCRIPTION
    if state == "lf_description":
        if not user_message:
            return "فضلاً اكتب وصفًا مختصرًا للشيء المفقود."
        data["description"] = user_message

        # Ask about optional photo
        save_session(pid, session_id, "lf_photo_choice", data)
        return (
            "📷 هل ترغب/ين بإرفاق صورة للغرض المفقود؟ (اختياري)\n\n"
            "1️⃣ نعم\n"
            "2️⃣ لا"
        )

    # PHOTO CHOICE
    if state == "lf_photo_choice":
        if user_message == "1":
            data["photo_url"] = None
            save_session(pid, session_id, "lf_waiting_photo", data)
            return (
                "📤 ارفعي/ارفع الصورة من التطبيق الآن.\n"
                "بعد الرفع، أرسلي الرسالة التالية من التطبيق (أو سيتم إرسالها تلقائيًا):\n"
                "PHOTO_URL:<الرابط>"
            )

        if user_message == "2":
            data["photo_url"] = None
            save_session(pid, session_id, "lf_station", data)
            return (
                "📍 في أي محطة فُقد الغرض؟\n\n"
                f"{_format_options(STATION_OPTIONS)}"
            )

        return "الرجاء اختيار رقم صحيح: 1 أو 2."

    # WAIT FOR PHOTO URL
    if state == "lf_waiting_photo":
        # Allow skipping photo
        if user_message == "2":
            data["photo_url"] = None
            save_session(pid, session_id, "lf_station", data)
            return (
                "تمام ✅ بدون صورة.\n\n"
                "📍 في أي محطة فُقد الغرض؟\n\n"
                f"{_format_options(STATION_OPTIONS)}"
            )

        # Accept PHOTO_URL:... or direct url
        if not _is_photo_url_message(user_message):
            return (
                "بانتظار رابط الصورة...\n"
                "إذا تبين تكملين بدون صورة اكتبي: 2"
            )

        photo_url = _extract_photo_url(user_message)
        if not photo_url:
            return "لم أستلم رابط الصورة بشكل صحيح. حاول رفع الصورة مرة أخرى."

        data["photo_url"] = photo_url
        save_session(pid, session_id, "lf_station", data)
        return (
            "✅ تم استلام الصورة.\n\n"
            "📍 في أي محطة فُقد الغرض؟\n\n"
            f"{_format_options(STATION_OPTIONS)}"
        )

    # STATION
    if state == "lf_station":
        try:
            idx = int(user_message) - 1
            station = STATION_OPTIONS[idx]
            data["station_id"] = station["id"]
            data["station_name"] = station["label"]
        except Exception:
            return "الرجاء اختيار رقم صحيح من قائمة المحطات."

        save_session(pid, session_id, "lf_when", data)
        return (
            "🕒 متى تقريبًا فُقد الغرض؟\n\n"
            f"{_format_options(WHEN_OPTIONS)}"
        )

    # WHEN LOST
    if state == "lf_when":
        try:
            idx = int(user_message) - 1
            when = WHEN_OPTIONS[idx]
            data["lost_time_id"] = when["id"]
            data["lost_time_label"] = when["label"]
        except Exception:
            return "الرجاء اختيار رقم صحيح من القائمة."

        if data["lost_time_id"] == "older":
            save_session(pid, session_id, "lf_date", data)
            return "📅 يرجى كتابة التاريخ التقريبي بصيغة YYYY-MM-DD (مثال: 2026-01-20)."

        save_session(pid, session_id, "lf_name", data)
        return "👤 ما الاسم الكامل؟"

    # DATE
    if state == "lf_date":
        if not _looks_like_date(user_message):
            return "فضلاً اكتب التاريخ بصيغة YYYY-MM-DD (مثال: 2026-01-20)."
        data["lost_date"] = user_message
        save_session(pid, session_id, "lf_name", data)
        return "👤 ما الاسم الكامل؟"

    # NAME
    if state == "lf_name":
        if not user_message:
            return "فضلاً اكتب الاسم الكامل."
        data["name"] = user_message
        save_session(pid, session_id, "lf_phone", data)
        return "📞 ما رقم الجوال للتواصل؟"

    # PHONE
    if state == "lf_phone":
        if not user_message:
            return "فضلاً اكتب رقم الجوال."
        data["phone"] = user_message

        ticket_id = str(uuid.uuid4())[:8].upper()

        report = {
            "ticket_id": ticket_id,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "status": "open",

            "passenger_id": data.get("passenger_id", passenger_id),

            "item_type": data.get("item_type", ""),
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

        # ✅ reset session for this passenger+session
        save_session(pid, session_id, "menu", {})

        return (
            "✅ تم تسجيل البلاغ بنجاح.\n"
            f"🎫 رقم التذكرة: {ticket_id}\n\n"
            "سيتم التواصل عند العثور على المفقود.\n"
            "شكرًا لاستخدامك مساعد مسار."
        )

    return "حدث خطأ غير متوقع. فضلاً أعد المحاولة أو اكتب: menu"
