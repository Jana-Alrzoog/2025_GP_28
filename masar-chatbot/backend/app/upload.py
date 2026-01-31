import os
import uuid
import mimetypes
from fastapi import UploadFile
from firebase_admin import storage
import firebase_admin

# Firebase Storage bucket name (loaded from .env file)
BUCKET_NAME = os.getenv("FIREBASE_STORAGE_BUCKET")  

def get_bucket():
    # Here we just get the storage bucket to upload images
    app = firebase_admin.get_app()
    return storage.bucket(name=BUCKET_NAME, app=app)


async def upload_lost_found_image(file: UploadFile, passenger_id: str, ticket_id: str | None = None) -> str:
    # Get the bucket reference
    bucket = get_bucket()

    # Get file extension (default to .jpg if missing)
    ext = os.path.splitext(file.filename or "")[1] or ".jpg"

    # Generate a random filename to avoid conflicts
    filename = f"{uuid.uuid4().hex}{ext}"

    # Organize the storage path like this:
    # lost_found_images / passenger_id / ticket_id (optional) / filename
    folder = f"lost_found_images/{passenger_id}"
    if ticket_id:
        folder += f"/{ticket_id}"
    blob_path = f"{folder}/{filename}"

    # Create a file reference (blob) in this path
    blob = bucket.blob(blob_path)

    # Detect the file content type (like image/png or image/jpeg)
    content_type = file.content_type or mimetypes.guess_type(file.filename)[0] or "application/octet-stream"

    # Read file data from the uploaded image
    data = await file.read()

    # Upload the image to Firebase Storage
    blob.upload_from_string(data, content_type=content_type)

    # Make the image public so we can store and display its URL later
    blob.make_public()

    # Return the public image URL to save it in Firestore with the report
    return blob.public_url
