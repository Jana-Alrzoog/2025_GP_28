import os, json
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()
print("API KEY starts with:", (os.getenv("OPENAI_API_KEY") or "")[:10])
print("API KEY length:", len(os.getenv("OPENAI_API_KEY") or ""))

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

SYSTEM = """أنت مساعد ذكي خاص بمترو الرياض.
- استخدم فقط المعلومات الموجودة في قائمة FAQ المرسلة لك.
- ممنوع تخترع أو تضيف معلومات من عندك.
- إذا ما لقيت جواب واضح داخل FAQ رجّع matched_faq_id=null.
- رجّع JSON فقط بالشكل:
{"matched_faq_id": null, "answer": "...", "confidence": 0.0}
"""

def ask_llm(question: str, faqs: list[dict]) -> dict:
    payload = {
        "question": question,
        "faqs": [{"id": f["id"], "q": f["question"], "a": f["answer"]} for f in faqs],
    }

    try:
        resp = client.responses.create(
            model="gpt-4o-mini",
            input=[
                {"role": "system", "content": SYSTEM},
                {"role": "user", "content": json.dumps(payload, ensure_ascii=False)},
            ],
        )
        text = resp.output_text.strip()

        try:
            return json.loads(text)
        except Exception:
            return {"matched_faq_id": None, "answer": text, "confidence": 0.0}

    except Exception as e:
        return {
            "matched_faq_id": None,
            "answer": f"LLM_ERROR: {type(e).__name__}: {str(e)}",
            "confidence": 0.0,
        }
