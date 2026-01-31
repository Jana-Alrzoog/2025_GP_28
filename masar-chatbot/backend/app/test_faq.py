from firestore import get_all_faq
from faq_service import build_faq_index, best_match

faq_list = get_all_faq()
print("FAQ count:", len(faq_list))
print("Sample FAQ:", faq_list[0])

# Build the index once
build_faq_index(faq_list)

user_q = "متى اول رحلة؟"
answer, score, matched_q = best_match(user_q, threshold=0.20)

print("User Question:", user_q)
print("Matched Question:", matched_q)
print("Score:", round(score, 3))
print("Answer:", answer)

