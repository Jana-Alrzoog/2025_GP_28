import re

def _norm(text: str) -> str:
    text = str(text).strip().lower()
    text = (text.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
                .replace("ة", "ه").replace("ى", "ي"))
    text = re.sub(r"[^\w\s]", " ", text, flags=re.UNICODE)
    return " ".join(text.split())

def _has_any(q: str, keywords: list[str]) -> bool:
    return any(k in q for k in keywords)

GENERAL_RULES = {
    "support": [
        "تواصل", "رقم", "هاتف", "خدمة العملاء", "شكوى", "بلاغ", "اقتراح",
        "دعم", "مساعدة", "مفقود", "ضايع", "لقيت", "نسيت", "lost", "found",
        "التطبيق ما يشتغل", "ما يشتغل", "تعليق"
    ],
    "prices": [
        "سعر", "اسعار", "كم ريال", "ريال", "رسوم", "تكلفه", "تذكره", "تذاكر",
        "اشتراك", "بطاقه", "دفع", "سداد", "مدى", "ابل باي", "فيزا",
        "شحن", "رصيد", "خصم", "مجاني", "طلاب"
    ],
    "hours": [
        "متى", "وقت", "الساعة", "يفتح", "يقفل", "دوام", "ساعات",
        "اول", "أول", "اخر", "آخر", "بدايه", "نهايه",
        "الجمعه", "الويكند", "كل كم", "تردد", "كم دقيقه", "انتظار",
        "كم يستغرق", "مده", "رحله", "قطار"
    ],
    "stations": [
        "محطه", "محطات", "اقرب محطه", "وين محطه",
        "خط", "خطوط", "مسار", "المسار",
        "من", "الى", "تحويل", "تبديل", "انتقال", "اتجاه", "وجهه",
        "خريطه", "map"
    ],
    "rules": [
        "مسموح", "ممنوع", "سياسه", "قانون",
        "اكل", "شرب", "تدخين", "تصوير", "كاميرا",
        "حيوانات", "اطفال", "عربه", "امتعه", "شنط", "حقيبه",
        "تفتيش", "امن"
    ],
    "services": [
        "ذوي الاعاقه", "احتياجات", "مصعد", "سلم كهربائي",
        "كرسي متحرك", "منحدر", "مواقف", "باركنق",
        "حمام", "دورات مياه", "واي فاي", "شحن جوال"
    ],
}

# Priority matters to avoid confusion
PRIORITY = ["support", "prices", "hours", "stations", "rules", "services"]

def detect_general_subcategory(user_question: str) -> str:
    q = _norm(user_question)

    for cat in PRIORITY:
        if _has_any(q, GENERAL_RULES[cat]):
            return cat

    return "other"
