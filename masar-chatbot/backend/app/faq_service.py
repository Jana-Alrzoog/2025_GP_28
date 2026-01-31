import re
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

# -------- Normalization (light Arabic) --------
def normalize(text: str) -> str:
    text = str(text).strip().lower()

    replacements = {
        "أ": "ا", "إ": "ا", "آ": "ا",
        "ة": "ه",
        "ى": "ي",
        "ؤ": "و",
        "ئ": "ي",
        "ـ": "",
    }
    for k, v in replacements.items():
        text = text.replace(k, v)

    # remove punctuation/symbols
    text = re.sub(r"[^\w\s]", " ", text, flags=re.UNICODE)
    text = " ".join(text.split())
    return text

# -------- Build TF-IDF Index once --------
_vectorizer = None
_faq_matrix = None
_faq_questions = None
_faq_answers = None

def build_faq_index(faq_list: list):
    """
    Build TF-IDF matrix for all FAQ questions.
    Uses character n-grams which works better for Arabic variations.
    Call this ONCE after fetching FAQs from Firestore.
    """
    global _vectorizer, _faq_matrix, _faq_questions, _faq_answers

    _faq_questions = [normalize(f.get("question", "")) for f in faq_list]
    _faq_answers = [f.get("answer", "") for f in faq_list]

    # Character n-grams handle typos, synonyms variations, and Arabic morphology better
    _vectorizer = TfidfVectorizer(analyzer="char_wb", ngram_range=(3, 5))
    _faq_matrix = _vectorizer.fit_transform(_faq_questions)

def best_match(user_question: str, threshold: float = 0.20):
    """
    Returns: (answer, score, matched_question)
    threshold suggestions:
      - 0.18 to 0.22 for Arabic FAQ (start with 0.20)
    """
    if _vectorizer is None or _faq_matrix is None:
        raise RuntimeError("FAQ index not built. Call build_faq_index(faq_list) first.")

    user_q = normalize(user_question)
    user_vec = _vectorizer.transform([user_q])

    sims = cosine_similarity(user_vec, _faq_matrix)[0]
    best_idx = int(sims.argmax())
    best_score = float(sims[best_idx])

    if best_score >= threshold:
        return _faq_answers[best_idx], best_score, _faq_questions[best_idx]

    return None, best_score, None


