from app.firestore import get_db

REPORTS_COL = "lost_found_reports"


def save_lost_found_report(report: dict):
    db = get_db()

    # Make sure passenger_id exists (report must belong to a user)
    if not report.get("passenger_id"):
        raise ValueError("passenger_id is required when saving a lost & found report")

    # Make sure ticket_id exists
    ticket_id = report.get("ticket_id")
    if not ticket_id:
        raise ValueError("ticket_id is missing in report data")

    db.collection(REPORTS_COL).document(ticket_id).set(report)


def get_lost_found_report(ticket_id: str):
    db = get_db()

    if not ticket_id:
        return None

    doc = db.collection(REPORTS_COL).document(ticket_id).get()

    if not doc.exists:
        return None

    return doc.to_dict()


