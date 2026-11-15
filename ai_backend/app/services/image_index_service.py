
import hashlib
from io import BytesIO
from pathlib import Path

import fitz
from PIL import Image, UnidentifiedImageError

from app.services.knowledge_service import supabase


IMAGE_DIR = Path("storage/brochure_images")
MIN_IMAGE_WIDTH = 120
MIN_IMAGE_HEIGHT = 120


def extract_images_from_pdf(
    pdf_path: str,
    document_id: str,
    document_filename: str,
) -> list[dict]:

    source_path = Path(pdf_path)

    if not source_path.exists():
        raise FileNotFoundError(
            f"PDF not found: {source_path}"
        )

    pdf = fitz.open(source_path)
    extracted_records = []
    seen_hashes = set()

    output_dir = IMAGE_DIR / document_id
    output_dir.mkdir(parents=True, exist_ok=True)

    try:
        for page_index, page in enumerate(pdf):
            page_number = page_index + 1
            page_images = page.get_images(full=True)

            for image_index, image_info in enumerate(page_images):
                xref = image_info[0]

                try:
                    image_data = pdf.extract_image(xref)
                    image_bytes = image_data["image"]

                    image_hash = hashlib.sha256(
                        image_bytes
                    ).hexdigest()

                    if image_hash in seen_hashes:
                        continue

                    seen_hashes.add(image_hash)

                    try:
                        image = Image.open(
                            BytesIO(image_bytes)
                        )
                        image.load()
                    except (
                        UnidentifiedImageError,
                        OSError,
                    ):
                        continue

                    width, height = image.size

                    if (
                        width < MIN_IMAGE_WIDTH
                        or height < MIN_IMAGE_HEIGHT
                    ):
                        continue

                    image = image.convert("RGB")

                    filename = (
                        f"page_{page_number}_"
                        f"image_{image_index}_"
                        f"{image_hash[:12]}.jpg"
                    )

                    output_path = output_dir / filename

                    image.save(
                        output_path,
                        format="JPEG",
                        quality=90,
                    )

                    relative_path = output_path.as_posix()

                    extracted_records.append({
                        "document_id": document_id,
                        "filename": document_filename,
                        "image_path": relative_path,
                        "page_number": page_number,
                        "image_index": image_index,
                        "width": width,
                        "height": height,
                        "sha256": image_hash,
                    })

                except Exception as error:
                    print(
                        f"Image extraction error "
                        f"(page {page_number}, xref {xref}): "
                        f"{error}"
                    )

    finally:
        pdf.close()

    if extracted_records:
        supabase.table("knowledge_images").upsert(
            extracted_records,
            on_conflict="document_id,sha256",
        ).execute()

    return extracted_records


def index_all_brochures() -> list[dict]:

    response = (
        supabase.table("knowledge_documents")
        .select("id, filename, file_path, status")
        .eq("status", "indexed")
        .execute()
    )

    documents = response.data or []
    results = []

    for document in documents:
        file_path = document.get("file_path")

        if not file_path:
            results.append({
                "document_id": document["id"],
                "filename": document["filename"],
                "error": "Missing PDF file path",
            })
            continue

        try:
            images = extract_images_from_pdf(
                pdf_path=file_path,
                document_id=document["id"],
                document_filename=document["filename"],
            )

            results.append({
                "document_id": document["id"],
                "filename": document["filename"],
                "images_extracted": len(images),
                "status": "success",
            })

        except Exception as error:
            results.append({
                "document_id": document["id"],
                "filename": document["filename"],
                "error": str(error),
            })

    return results
