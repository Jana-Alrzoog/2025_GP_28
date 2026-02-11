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
    {"id": "airport_t1_t2", "label": "المطار (1–2)"},
    {"id": "first_industrial", "label": "المدينة الصناعية الأولى"},
]

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
    photo_url: Optional[str] = None,   # ✅ يجي من التطبيق بعد رفع الصورة
) -> str:
    """
    Lost & Found flow.

    ✅ Important change:
    - User NEVER sends a URL.
    - The app uploads image -> gets downloadURL -> calls backend with photo_url.
    - Backend stores photo_url in Firestore.
    """

    pid = (passenger_id or "").strip() or "anonymous"

    session = get_session(pid, session_id)
    state = session.get("state", "menu")
    data = session.get("data", {}) or {}

    user_message = (user_message or "").strip()

    if passenger_id:
        data["passenger_id"] = passenger_id

    # START
    if state == "menu":
        save_session(pid, session_id, "lf_item_type", data)
        return (
            "🧳 تمام، بسجّل لك بلاغ مفقود.\n\n"
            "وش نوع الشيء المفقود؟\n"
            "مثال: محفظة، جوال، بطاقة، مفاتيح، شنطة..."
        )

    # ITEM TYPE
    if state == "lf_item_type":
        if not user_message:
            return "فضلاً اكتب نوع الشيء المفقود."
        data["item_type"] = user_message
        save_session(pid, session_id, "lf_color", data)
        return (
            "🎨 وش لون الغرض؟\n"
            "مثال: أسود، أبيض، أحمر، أزرق، فضي...\n"
            "إذا اللون غير واضح اكتب: غير واضح"
        )

    # COLOR
    if state == "lf_color":
        if not user_message:
            return "فضلاً اكتب لون الغرض (أو اكتب: غير واضح)."
        data["color"] = user_message
        save_session(pid, session_id, "lf_brand", data)
        return (
            "🏷️ إذا تعرف الماركة/الموديل اكتبها (اختياري)\n"
            "مثال: سامسونج، هواوي، نايك، فيزا، أديداس...\n"
            "أو اكتب: تخطي"
        )

    # BRAND (optional)
    if state == "lf_brand":
        if user_message in {"تخطي", "تجاوز", "skip"}:
            data["brand"] = None
        else:
            data["brand"] = user_message if user_message else None

        save_session(pid, session_id, "lf_description", data)
        return (
            "✏️ اكتب أي تفاصيل/علامة مميزة (اختياري لكنه يساعد):\n"
            "مثل: خدش، ستيكر، كفر، كتابة، سلسلة...\n"
            "وإذا ما عندك تفاصيل اكتب: ماعندي"
        )

    # DESCRIPTION
    if state == "lf_description":
        if not user_message:
            return "فضلاً اكتب التفاصيل (أو اكتب: ماعندي)."
        data["description"] = "" if user_message in {"ماعندي", "ما عندي", "لا يوجد", "none"} else user_message

        save_session(pid, session_id, "lf_photo_choice", data)
        return (
            "📷 تبي ترفق صورة للغرض؟ (اختياري)\n"
            "اكتب: نعم أو لا"
        )

    # PHOTO CHOICE
    if state == "lf_photo_choice":
        ans = _normalize_ar_yes_no(user_message)

        if ans == "yes":
            # ✅ ننتقل لحالة انتظار "مرفق" (مو رابط مكتوب)
            data["photo_url"] = None
            save_session(pid, session_id, "lf_expect_photo", data)
            return (
                "تمام ✅ ارفق الصورة الآن من التطبيق.\n"
                "إذا ما تبي صورة، اكتب: لا"
            )

        if ans == "no":
            data["photo_url"] = None
            save_session(pid, session_id, "lf_station", data)
            return (
                "تمام ✅ بدون صورة.\n\n"
                "📍 في أي محطة فقدت الغرض؟\n\n"
                f"{_format_options(STATION_OPTIONS)}"
            )

        return "اكتب بس: نعم أو لا."

    # EXPECT PHOTO ATTACHMENT (photo_url comes from app)
    if state == "lf_expect_photo":
        # لو التطبيق أرسل photo_url (بعد رفع الصورة لـ Storage)
     if state == "lf_expect_photo":
         # ✅ اقرأ الصورة من بيانات السيشن (اللي انحفظت في upload endpoint)
         stored_url = data.get("photo_url")

         if stored_url:
             save_session(pid, session_id, "lf_station", data)
             return (
                 "✅ تم استلام الصورة.\n\n"
                 "📍 في أي محطة فقدت الغرض؟\n\n"
                 f"{_format_options(STATION_OPTIONS)}"
             )

         # السماح للمستخدم يكمل بدون صورة
         ans = _normalize_ar_yes_no(user_message)
         if ans == "no":
             data["photo_url"] = None
             save_session(pid, session_id, "lf_station", data)
             return (
                 "تمام ✅ كملنا بدون صورة.\n\n"
                 "📍 في أي محطة فقدت الغرض؟\n\n"
                 f"{_format_options(STATION_OPTIONS)}"
             )

         return "بانتظار إرفاق الصورة من التطبيق... وإذا تبي تكمل بدون صورة اكتب: لا"


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
            "🕒 متى تقريبًا فقدت الغرض؟\n\n"
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
            return "📅 اكتب التاريخ التقريبي بصيغة YYYY-MM-DD (مثال: 2026-01-20)."

        save_session(pid, session_id, "lf_name", data)
        return "👤 اكتب اسمك الكامل؟"

    # DATE
    if state == "lf_date":
        if not _looks_like_date(user_message):
            return "فضلاً اكتب التاريخ بصيغة YYYY-MM-DD (مثال: 2026-01-20)."
        data["lost_date"] = user_message
        save_session(pid, session_id, "lf_name", data)
        return "👤 اكتب اسمك الكامل؟"

    # NAME
    if state == "lf_name":
        if not user_message:
            return "فضلاً اكتب الاسم الكامل."
        data["name"] = user_message
        save_session(pid, session_id, "lf_phone", data)
        return "📞 اكتب رقم جوالك للتواصل؟"

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
            "✅ تم تسجيل البلاغ بنجاح.\n"
            f"🎫 رقم التذكرة: {ticket_id}\n\n"
            "إذا تم العثور على الغرض بنتواصل معك.\n"
            "شكرًا لاستخدامك مساعد مسار."
        )

    return "صار خطأ غير متوقع. جرّب مرة ثانية أو اكتب: menu"
