import hashlib
from pathlib import Path

import fitz
import imagehash
from PIL import Image

from app.services.knowledge_service import supabase


IMAGE_DIR = Path("storage/brochure_images")

MIN_IMAGE_WIDTH = 40    # en points PDF (taille affichée sur la page)
MIN_IMAGE_HEIGHT = 40
RENDER_DPI = 200
JPEG_QUALITY = 90
CAPTION_MAX_DISTANCE = 400  # en points PDF


def _line_text(line: dict) -> str:
    text = "".join(span["text"] for span in line.get("spans", []))
    return " ".join(text.split())


def _rect_distance(rect, box) -> float:
    x0, y0, x1, y1 = box
    dx = max(x0 - rect.x1, rect.x0 - x1, 0)
    dy = max(y0 - rect.y1, rect.y0 - y1, 0)
    return (dx ** 2 + dy ** 2) ** 0.5


def _union(boxes: list) -> tuple:
    return (
        min(b[0] for b in boxes),
        min(b[1] for b in boxes),
        max(b[2] for b in boxes),
        max(b[3] for b in boxes),
    )


def get_nearby_text(page, rect, max_dist: float = CAPTION_MAX_DISTANCE) -> str:
    """
    Retourne la légende (nom + promotion + fonction) la plus proche de l'image.

    Méthode 1 (pages de témoignages) : on parcourt les lignes dans l'ordre de
    lecture. Les lignes situées entre la fin d'un témoignage (») et le début du
    suivant («) forment la légende d'une personne.

    Méthode 2 (repli) : blocs de texte courts sans guillemets.
    """
    entries = []  # (bbox, texte)
    head, boxes = [], []
    in_quote = False

    for block in page.get_text("dict").get("blocks", []):
        if block.get("type") != 0:
            continue

        for line in block.get("lines", []):
            text = _line_text(line)

            if not text:
                continue

            if in_quote:
                if "»" in text:
                    in_quote = False
                continue

            if "«" in text:
                if head:
                    entries.append((_union(boxes), " | ".join(head[-6:])))

                head, boxes = [], []
                after = text[text.index("«"):]
                in_quote = "»" not in after
                continue

            if text.isdigit():
                continue

            head.append(text)
            boxes.append(line["bbox"])

    candidates = [
        (_rect_distance(rect, box), text)
        for box, text in entries
        if len(text) >= 3
    ]

    # Repli : blocs courts sans guillemets
    if not candidates:
        for block in page.get_text("dict").get("blocks", []):
            if block.get("type") != 0:
                continue

            lines = [_line_text(l) for l in block.get("lines", [])]
            lines = [t for t in lines if t]
            text = " | ".join(lines)

            if len(text) < 3 or len(text) > 250 or "«" in text:
                continue

            candidates.append((_rect_distance(rect, block["bbox"]), text))

    candidates = [c for c in candidates if c[0] <= max_dist]
    candidates.sort(key=lambda item: item[0])

    return candidates[0][1] if candidates else ""


def extract_images_from_pdf(
    pdf_path: str,
    document_id: str,
    document_filename: str,
) -> list[dict]:

    source_path = Path(pdf_path)

    if not source_path.exists():
        raise FileNotFoundError(f"PDF not found: {source_path}")

    pdf = fitz.open(source_path)

    output_dir = IMAGE_DIR / document_id
    output_dir.mkdir(parents=True, exist_ok=True)

    records = []
    seen = set()

    try:
        for page_index, page in enumerate(pdf):
            page_number = page_index + 1
            page_rect = page.rect

            try:
                infos = page.get_image_info(xrefs=True)
            except Exception as error:
                print(f"[IMAGE INDEX] Page {page_number}: {error}")
                continue

            for image_index, info in enumerate(infos):
                try:
                    rect = fitz.Rect(info["bbox"]) & page_rect

                    if rect.is_empty:
                        continue

                    if (
                        rect.width < MIN_IMAGE_WIDTH
                        or rect.height < MIN_IMAGE_HEIGHT
                    ):
                        continue

                    # Ignorer les images pleine page (fonds)
                    if (
                        rect.width > page_rect.width * 0.9
                        and rect.height > page_rect.height * 0.9
                    ):
                        continue

                    # On rend ce qui est VISIBLE (masques, découpes, CMYK gérés)
                    pix = page.get_pixmap(
                        clip=rect,
                        dpi=RENDER_DPI,
                        alpha=False,
                    )

                    image = Image.frombytes(
                        "RGB",
                        (pix.width, pix.height),
                        pix.samples,
                    )

                    phash = str(imagehash.phash(image))
                    dhash = str(imagehash.dhash(image))

                    key = (page_number, phash)
                    if key in seen:
                        continue
                    seen.add(key)

                    # sha unique par page + index (évite les conflits d'upsert)
                    sha = hashlib.sha256(
                        f"{page_number}-{image_index}-".encode()
                        + image.tobytes()
                    ).hexdigest()

                    filename = (
                        f"page_{page_number}_"
                        f"image_{image_index}_"
                        f"{sha[:12]}.jpg"
                    )

                    output_path = output_dir / filename

                    image.save(
                        output_path,
                        format="JPEG",
                        quality=JPEG_QUALITY,
                        optimize=True,
                    )

                    nearby_text = get_nearby_text(page, rect)

                    records.append({
                        "document_id": document_id,
                        "filename": document_filename,
                        "image_path": output_path.as_posix(),
                        "page_number": page_number,
                        "image_index": image_index,
                        "width": pix.width,
                        "height": pix.height,
                        "sha256": sha,
                        "perceptual_hash": phash,
                        "dhash": dhash,
                        "bbox": [rect.x0, rect.y0, rect.x1, rect.y1],
                        "nearby_text": nearby_text,
                    })

                    print(
                        f"[IMAGE INDEX] Page {page_number} | "
                        f"Image {image_index} | pHash: {phash} | "
                        f"Légende: {nearby_text[:80]}"
                    )

                except Exception as error:
                    print(
                        f"[IMAGE INDEX] Extraction error "
                        f"(page {page_number}, image {image_index}): {error}"
                    )

    finally:
        pdf.close()

    if records:
        supabase.table("knowledge_images").upsert(
            records,
            on_conflict="document_id,sha256",
        ).execute()

    return records


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