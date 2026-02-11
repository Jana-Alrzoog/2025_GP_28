import os
import uuid
import mimetypes
from datetime import timedelta
from fastapi import UploadFile

from app.firestore import get_bucket  # نفس التهيئة عندك

async def upload_lost_found_image(
    file: UploadFile,
    passenger_id: str,
    ticket_id: str | None = None
) -> str:
    bucket = get_bucket()

    ext = os.path.splitext(file.filename or "")[1] or ".jpg"
    filename = f"{uuid.uuid4().hex}{ext}"

    folder = f"lost_found_images/{passenger_id}"
    if ticket_id:
        folder += f"/{ticket_id}"
    blob_path = f"{folder}/{filename}"

    blob = bucket.blob(blob_path)

    content_type = (
        file.content_type
        or mimetypes.guess_type(file.filename or "")[0]
        or "application/octet-stream"
    )

    data = await file.read()
    blob.upload_from_string(data, content_type=content_type)

    # ✅ بدل make_public: نرجع Signed URL (يشتغل حتى لو البكت ما يسمح public)
    signed_url = blob.generate_signed_url(
        expiration=timedelta(days=7),
        method="GET"
    )
    return signed_url
