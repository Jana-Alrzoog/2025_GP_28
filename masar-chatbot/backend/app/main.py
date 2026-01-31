from fastapi import FastAPI, UploadFile, File, Form
from pydantic import BaseModel

from app.firestore import fetch_all_faq
from app.llm_client import ask_llm

# Lost & Found imports
from app.lost_found_flow import handle_lost_found_flow
from app.session_store import get_session, save_session

# Image upload
from app.upload import upload_lost_found_image

app = FastAPI()


class AskReq(BaseModel):
    question: str
    session_id: str | None = None
    passenger_id: str | None = None


@app.post("/ask")
def ask(req: AskReq):
    try:
        question = (req.question or "").strip()
        session_id = req.session_id or "default_user"

        session = get_session(session_id)
        state = session.get("state", "menu")

        # -----------------------------
        # MAIN MENU
        # -----------------------------
        if question.lower() in ["menu", "start"] and state == "menu":
            return {
                "matched_faq_id": None,
                "answer": "أهلاً بك في مساعدك مسار 🤖🚇\nكيف أقدر أساعدك اليوم؟\n\n1️⃣ الأسئلة العامة\n2️⃣ الإبلاغ عن مفقودات",
                "confidence": 1.0
            }

        # -----------------------------
        # LOST & FOUND FLOW
        # -----------------------------
        if question == "2" or str(state).startswith("lf_"):
            if not req.passenger_id:
                return {
                    "matched_faq_id": None,
                    "answer": "للمتابعة في خدمة المفقودات، يرجى تسجيل الدخول أولاً.",
                    "confidence": 1.0
                }

            reply_text = handle_lost_found_flow(
                session_id=session_id,
                user_message=question,
                passenger_id=req.passenger_id
            )

            return {
                "matched_faq_id": None,
                "answer": reply_text,
                "confidence": 1.0
            }

        # -----------------------------
        # GENERAL QUESTIONS (FAQ + LLM)
        # -----------------------------
        faqs = fetch_all_faq()
        result = ask_llm(question, faqs)

        return {
            "matched_faq_id": result.get("matched_faq_id", None),
            "answer": result.get("answer", ""),
            "confidence": float(result.get("confidence", 0.0) or 0.0),
        }

    except Exception as e:
        return {
            "matched_faq_id": None,
            "answer": f"SERVER_ERROR: {type(e).__name__}: {str(e)}",
            "confidence": 0.0
        }


# ---------------------------------
# Upload image endpoint (optional)
# ---------------------------------
@app.post("/lost-found/upload-image")
async def upload_image(
    file: UploadFile = File(...),
    passenger_id: str = Form(...),
    session_id: str = Form(...),
    ticket_id: str | None = Form(None),
):
    """
    Upload lost & found image to Firebase Storage.
    Returns a public URL (or you can store it in the session).
    """
    photo_url = await upload_lost_found_image(
        file=file,
        passenger_id=passenger_id,
        ticket_id=ticket_id
    )

    # Store photo_url in session so the flow can use it later
    session = get_session(session_id)
    data = session.get("data", {}) or {}
    data["photo_url"] = photo_url
    save_session(session_id, session.get("state", "menu"), data)

    return {"photo_url": photo_url}
