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


def _format_options(options):
    return "\n".join([f"{i+1} - {opt['label']}" for i, opt in enumerate(options)])


def _looks_like_datetime(s: str) -> bool:
    s = (s or "").strip()
    try:
        datetime.strptime(s, "%Y-%m-%d %H:%M")
        return True
    except ValueError:
        return False


def _normalize_ar_yes_no(msg: str) -> str:
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

    pid = (passenger_id or "").strip() or "anonymous"

    session = get_session(pid, session_id)
    state = session.get("state", "menu")
    data = session.get("data", {}) or {}

    user_message = (user_message or "").strip()

    if passenger_id:
        data["passenger_id"] = passenger_id

    if photo_url:
        data["photo_url"] = photo_url

    # START
    if state == "menu":
        save_session(pid, session_id, "lf_item_type", data)
        return (
            "[LF_START]\n"
            "تم بدء تسجيل بلاغ مفقود.\n\n"
            "1) يرجى إدخال نوع الغرض المفقود.\n"
            "مثال: محفظة، جوال، بطاقة، مفاتيح، شنطة."
        )

    # ITEM TYPE
    if state == "lf_item_type":
        if not user_message:
            return "[LF_ERROR]\nيرجى إدخال نوع الغرض المفقود."

        data["item_type"] = user_message
        save_session(pid, session_id, "lf_color", data)

        return (
            "[LF_COLOR]\n"
            "تم تسجيل النوع.\n\n"
            "2) يرجى إدخال لون الغرض.\n"
            "مثال: اسود، ابيض، احمر، ازرق، فضي."
        )

    # COLOR
    if state == "lf_color":
        if not user_message:
            return "[LF_ERROR]\nيرجى إدخال لون الغرض أو كتابة: غير واضح."

        data["color"] = user_message
        save_session(pid, session_id, "lf_brand", data)

        return (
            "[LF_BRAND]\n"
            "3) يرجى إدخال الماركة أو الموديل (اختياري).\n"
            "مثال: سامسونج، هواوي.\n"
            "إذا لم يكن معروفا يمكن كتابة: تخطي."
        )

    # BRAND
    if state == "lf_brand":
        if user_message in {"تخطي", "تجاوز", "skip"}:
            data["brand"] = None
        else:
            data["brand"] = user_message if user_message else None

        save_session(pid, session_id, "lf_description", data)

        return (
            "[LF_DESC]\n"
            "4) يرجى إدخال تفاصيل أو علامة مميزة للغرض.\n"
            "مثال: شنطة يد سوداء صغيرة فيها سحاب ذهبي وخدش بسيط في الجهة الأمامية."
        )

    # DESCRIPTION
    if state == "lf_description":
        if not user_message:
            return "[LF_ERROR]\nيرجى إدخال تفاصيل الغرض."

        data["description"] = user_message
        save_session(pid, session_id, "lf_photo_choice", data)

        return (
            "[LF_PHOTO]\n"
            "5) هل ترغب في إرفاق صورة للغرض؟ (اختياري)\n"
            "يرجى كتابة: نعم أو لا."
        )

    # PHOTO CHOICE
    if state == "lf_photo_choice":
        ans = _normalize_ar_yes_no(user_message)

        if ans == "yes":
            data["photo_url"] = None
            save_session(pid, session_id, "lf_expect_photo", data)
            return (
                "[LF_PHOTO]\n"
                "تم اختيار إرفاق صورة.\n"
                "يرجى إرفاق الصورة من داخل التطبيق.\n"
                "للمتابعة بدون صورة يمكن كتابة: لا."
            )

        if ans == "no":
            data["photo_url"] = None
            save_session(pid, session_id, "lf_station", data)
            return (
                "[LF_STATION]\n"
                "تمت المتابعة بدون صورة.\n\n"
                "6) يرجى اختيار محطة الفقد:\n\n"
                f"{_format_options(STATION_OPTIONS)}"
            )

        return "[LF_ERROR]\nيرجى كتابة: نعم أو لا."

    # WAITING FOR PHOTO
    if state == "lf_expect_photo":
        stored_url = (data.get("photo_url") or "").strip()
        if stored_url:
            save_session(pid, session_id, "lf_station", data)
            return (
                "[LF_STATION]\n"
                "تم استلام الصورة.\n\n"
                "6) يرجى اختيار محطة الفقد:\n\n"
                f"{_format_options(STATION_OPTIONS)}"
            )

        ans = _normalize_ar_yes_no(user_message)
        if ans == "no":
            data["photo_url"] = None
            save_session(pid, session_id, "lf_station", data)
            return (
                "[LF_STATION]\n"
                "تمت المتابعة بدون صورة.\n\n"
                "6) يرجى اختيار محطة الفقد:\n\n"
                f"{_format_options(STATION_OPTIONS)}"
            )

        return (
            "[LF_PHOTO]\n"
            "بانتظار إرفاق الصورة من داخل التطبيق.\n"
            "للمتابعة بدون صورة يمكن كتابة: لا."
        )

    # STATION
    if state == "lf_station":
        try:
            idx = int(user_message) - 1
            station = STATION_OPTIONS[idx]
            data["station_id"] = station["id"]
            data["station_name"] = station["label"]
        except Exception:
            return "[LF_ERROR]\nيرجى اختيار رقم صحيح من قائمة المحطات."

        save_session(pid, session_id, "lf_datetime", data)

        return (
            "[LF_DATETIME]\n"
            "7) يرجى تحديد التاريخ والوقت التقريبيين لفقدان الغرض."
        )

    # DATETIME
    if state == "lf_datetime":
        if not _looks_like_datetime(user_message):
            return (
                "[LF_ERROR]\n"
                "يرجى إدخال التاريخ والوقت بصيغة صحيحة.\n"
                "مثال: 2026-03-16 14:30"
            )

        data["lost_datetime"] = user_message
        save_session(pid, session_id, "lf_name", data)

        return "[LF_CONTACT]\n8) يرجى إدخال الاسم الكامل."

    # NAME
    if state == "lf_name":
        if not user_message:
            return "[LF_ERROR]\nيرجى إدخال الاسم الكامل."

        data["name"] = user_message
        save_session(pid, session_id, "lf_phone", data)

        return "[LF_CONTACT]\n9) يرجى إدخال رقم الجوال للتواصل."

    # PHONE
    if state == "lf_phone":
        if not user_message:
            return "[LF_ERROR]\nيرجى إدخال رقم الجوال."

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
            "lost_datetime": data.get("lost_datetime", ""),
            "name": data.get("name", ""),
            "phone": data.get("phone", ""),
        }

        save_lost_found_report(report)
        save_session(pid, session_id, "menu", {})

        return (
            "[LF_DONE]\n"
            "تم تسجيل البلاغ بنجاح.\n"
            f"رقم التذكرة: {ticket_id}\n\n"
            "سيتم التواصل عند العثور على الغرض.\n"
            "شكرا لاستخدام مساعد مسار."
        )

    return "[LF_ERROR]\nحدث خطأ غير متوقع. يرجى كتابة: menu للعودة للقائمة."