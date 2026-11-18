import re
import unicodedata

from fastapi import (
    APIRouter,
    File,
    Form,
    HTTPException,
    UploadFile,
)
from pydantic import BaseModel

from app.services.image_match_service import find_matching_images
from app.services.knowledge_service import supabase
from app.services.llm_service import generate_answer
import fitz

from app.services.image_index_service import get_nearby_text, index_all_brochures

from app.services.retrieval_service import search_knowledge


router = APIRouter(
    prefix="/visual-search",
    tags=["Visual Search"],
)

MAX_IMAGE_SIZE = 10 * 1024 * 1024
IMAGE_MATCH_THRESHOLD = 24  # somme pHash + dHash (sur 128)
AMBIGUITY_MARGIN = 2


# ---------------------------------------------------------------
# Modèles
# ---------------------------------------------------------------

class VisualSource(BaseModel):
    document_id: str
    page_number: int
    chunk_index: int
    similarity: float


class VisualSearchResponse(BaseModel):
    visual_description: str
    extracted_text: list[dict]
    answer: str
    sources: list[VisualSource]
    photo_url: str | None = None
    caption: str | None = None


class PhotoItem(BaseModel):
    url: str
    caption: str
    score: int


class AskResponse(BaseModel):
    answer: str
    photos: list[PhotoItem]


# ---------------------------------------------------------------
# Utilitaires
# ---------------------------------------------------------------

def image_public_url(image_path: str) -> str:
    """storage/brochure_images/<doc>/<file>.jpg -> /brochure-images/<doc>/<file>.jpg"""
    relative = image_path.replace("\\", "/").split("brochure_images/")[-1]
    return f"/brochure-images/{relative}"


def norm_tokens(text: str) -> set[str]:
    text = unicodedata.normalize("NFD", (text or "").lower())
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    return set(re.findall(r"[a-z]{3,}", text))


def norm_caption(text: str | None) -> str:
    return " ".join(sorted(norm_tokens(text or "")))


def get_chunk_content(chunk: dict) -> str:
    for field in ("content", "chunk_text", "text"):
        value = chunk.get(field)
        if value and str(value).strip():
            return str(value).strip()
    return ""


async def get_page_chunks(document_id: str, page_number: int) -> list[dict]:
    response = (
        supabase.table("knowledge_chunks")
        .select("*")
        .eq("document_id", document_id)
        .eq("page_number", page_number)
        .execute()
    )

    chunks = response.data or []
    chunks.sort(key=lambda item: int(item.get("chunk_index", 0)))

    return [
        {**chunk, "content": get_chunk_content(chunk)}
        for chunk in chunks
        if get_chunk_content(chunk)
    ]


def resolve_caption(
    document_id: str,
    page_number: int,
    bbox: list | None,
    stored_caption: str,
) -> str:
    """Recalcule la légende directement depuis le PDF, à l'emplacement de la photo."""
    print(f"[VISUAL] resolve_caption: page={page_number} bbox={bbox}")

    if not bbox:
        print("[VISUAL] bbox manquant dans la base -> légende stockée uniquement.")
        return stored_caption

    try:
        rows = (
            supabase.table("knowledge_documents")
            .select("file_path")
            .eq("id", document_id)
            .limit(1)
            .execute()
        ).data or []

        if not rows or not rows[0].get("file_path"):
            return stored_caption

        pdf = fitz.open(rows[0]["file_path"])

        try:
            page = pdf[page_number - 1]
            live = get_nearby_text(page, fitz.Rect(bbox))
        finally:
            pdf.close()

        return live or stored_caption

    except Exception as error:
        print(f"[VISUAL] resolve_caption error: {error}")
        return stored_caption


def answer_is_grounded(answer: str, page_text: str) -> bool:
    """Vérifie que le nom annoncé par le LLM figure bien dans le texte de la page."""
    match = re.search(r"s['’]agit d(?:e|u|'|’)\s*([^,\.\n]+)", answer or "", re.IGNORECASE)

    if not match:
        return True

    name_tokens = norm_tokens(match.group(1))

    if not name_tokens:
        return True

    page_tokens = norm_tokens(page_text)

    return len(name_tokens & page_tokens) >= min(2, len(name_tokens))


def build_direct_answer(caption: str) -> str | None:
    """'Nom | Promotion | Fonction | Société' -> 'Il s'agit de Nom, ...'"""
    parts = [p.strip() for p in (caption or "").split("|") if p.strip()]

    # Retire un titre de page collé devant (ex. "TÉMOIGNAGES")
    if len(parts) >= 3 and " " not in parts[0] and parts[0].isupper():
        parts = parts[1:]

    if len(parts) < 2:
        return None

    parts = [p.rstrip(",") for p in parts]
    name = parts[0]
    role = ", ".join(parts[1:])

    return f"Il s'agit de {name}, {role}."


def empty_response(answer: str) -> VisualSearchResponse:
    return VisualSearchResponse(
        visual_description="",
        extracted_text=[],
        answer=answer,
        sources=[],
    )


# ---------------------------------------------------------------
# Indexation
# ---------------------------------------------------------------

@router.post("/index-brochures")
async def index_brochure_images():
    try:
        results = index_all_brochures()
        return {
            "message": "Brochure image indexing completed.",
            "documents_processed": len(results),
            "results": results,
        }
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Image indexing failed: {str(error)}",
        ) from error


# ---------------------------------------------------------------
# Image -> "qui est cette personne ?"
# ---------------------------------------------------------------

@router.post("/analyze", response_model=VisualSearchResponse)
async def analyze_image(
    file: UploadFile = File(...),
    question: str = Form(default="Qui est cette personne ?"),
):
    image_bytes = await file.read(MAX_IMAGE_SIZE + 1)

    if len(image_bytes) > MAX_IMAGE_SIZE:
        raise HTTPException(status_code=413, detail="Image exceeds 10 MB.")

    if not image_bytes:
        raise HTTPException(status_code=400, detail="The image is empty.")

    try:
        # 1. Comparaison avec les images des brochures
        print("\n[VISUAL] Searching for uploaded image...")

        result = find_matching_images(
            image_bytes=image_bytes,
            top_k=10,
            max_distance=IMAGE_MATCH_THRESHOLD,
        )

        all_matches = result.get("matches", [])
        accepted = result.get("accepted_matches", [])

        print(f"[VISUAL] Images compared: {result.get('total_images_compared', 0)}")
        print(f"[VISUAL] Threshold: {IMAGE_MATCH_THRESHOLD}")
        print("\n[VISUAL] ===== TOP 10 IMAGE CANDIDATES =====")
        for i, m in enumerate(all_matches, start=1):
            print(
                f"#{i} | Page {m['page_number']} | Dist {m['distance']} | "
                f"{m['matched_variant']} | {m['image_path']} | "
                f"Légende: {m.get('nearby_text', '')[:60]}"
            )
        print("[VISUAL] ==================================\n")

        if not accepted:
            return empty_response(
                "Je n'ai pas retrouvé cette photographie dans les images "
                "indexées des brochures EMSI. Je ne peux donc pas confirmer "
                "l'identité de cette personne à partir des documents."
            )

        # 2. Meilleure correspondance
        best = accepted[0]
        document_id = str(best["document_id"])
        page_number = int(best["page_number"])
        distance = int(best["distance"])
        bbox = best.get("bbox")

        if not bbox and best.get("id"):
            row = (
                supabase.table("knowledge_images")
                .select("bbox, nearby_text")
                .eq("id", best["id"])
                .limit(1)
                .execute()
            ).data or []

            if row:
                bbox = row[0].get("bbox")
                best["nearby_text"] = best.get("nearby_text") or row[0].get("nearby_text") or ""

        caption = resolve_caption(
            document_id,
            page_number,
            bbox,
            best.get("nearby_text") or "",
        )
        print(f"[VISUAL] Caption: {caption!r}")

        # Ambiguïté : une AUTRE légende également proche
        best_caption_key = norm_caption(caption)
        competing = {
            norm_caption(m.get("nearby_text"))
            for m in accepted[1:]
            if m["distance"] <= distance + AMBIGUITY_MARGIN
            and norm_caption(m.get("nearby_text")) != best_caption_key
        }

        if competing:
            print(f"[VISUAL] Ambiguous captions: {competing}")
            return empty_response(
                "J'ai retrouvé plusieurs correspondances possibles dans les "
                "brochures EMSI. Je ne peux pas confirmer l'identité avec "
                "suffisamment de certitude."
            )

        # 3. Texte de la page
        page_chunks = await get_page_chunks(document_id, page_number)

        if not page_chunks and not caption:
            return empty_response(
                "La photographie correspond à une image d'une brochure EMSI, "
                "mais je n'ai pas retrouvé le texte associé. Je ne peux pas "
                "confirmer le nom et la fonction de cette personne."
            )

        page_text = "\n\n".join(c["content"] for c in page_chunks)

        # 4. Prompt
        if caption:
            final_question = (
                f"La personne de la photographie est présentée avec cette "
                f"légende : « {caption} ». Donne son nom et sa fonction "
                f"d'après le texte de la page. Réponds par une seule phrase : "
                f"« Il s'agit de [Nom], [fonction]. »"
            )
        else:
            final_question = (
                "Quel est le nom et la fonction de la personne présentée "
                "avec la photographie de cette page ? Réponds par une seule "
                "phrase : « Il s'agit de [Nom], [fonction]. » Si le nom "
                "n'est pas écrit dans le texte, dis-le simplement."
            )

        direct_answer = build_direct_answer(caption)

        if direct_answer:
            print("[VISUAL] Direct answer from caption.")
            answer = direct_answer
        else:
            print("[VISUAL] Generating answer with LLM...")
            answer = await generate_answer(
                question=final_question,
                context_chunks=page_chunks,
            )

            if not answer_is_grounded(answer, page_text):
                print(f"[VISUAL] Nom non présent dans la page, réponse rejetée: {answer!r}")
                answer = (
                    "J'ai retrouvé cette photo dans une brochure EMSI "
                    f"(page {page_number}), mais le texte de la page ne me "
                    "permet pas de confirmer le nom de cette personne."
                )

        similarity = round(max(0.0, 1.0 - distance / 128.0), 4)

        sources = [
            VisualSource(
                document_id=document_id,
                page_number=page_number,
                chunk_index=int(chunk.get("chunk_index", 0)),
                similarity=similarity,
            )
            for chunk in page_chunks
        ]

        extracted_text = [
            {"page_number": page_number, "text": chunk["content"]}
            for chunk in page_chunks
        ]

        print("[VISUAL] Analysis completed.\n")

        return VisualSearchResponse(
            visual_description="",
            extracted_text=extracted_text,
            answer=answer,
            sources=sources,
            photo_url=image_public_url(best["image_path"]),
            caption=caption or None,
        )

    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error

    except HTTPException:
        raise

    except Exception as error:
        print(f"[VISUAL] ERROR: {type(error).__name__}: {error}")
        raise HTTPException(
            status_code=500,
            detail=f"Image analysis failed: {str(error)}",
        ) from error


# ---------------------------------------------------------------
# Question texte -> réponse texte + photos ("qui est le RH ?")
# ---------------------------------------------------------------

@router.post("/ask", response_model=AskResponse)
async def ask_with_photos(question: str = Form(...)):
    try:
        chunks = await search_knowledge(question, match_count=5)

        answer = await generate_answer(
            question=question,
            context_chunks=chunks,
        )

        answer_tokens = norm_tokens(answer)
        photos: list[dict] = []
        seen_paths = set()

        for chunk in chunks[:3]:
            rows = (
                supabase.table("knowledge_images")
                .select("document_id, page_number, image_path, nearby_text")
                .eq("document_id", chunk["document_id"])
                .eq("page_number", chunk["page_number"])
                .execute()
            ).data or []

            for row in rows:
                if row["image_path"] in seen_paths:
                    continue

                caption = row.get("nearby_text") or ""
                overlap = len(norm_tokens(caption) & answer_tokens)

                # Au moins 2 mots communs (ex. nom + prénom, ou nom + fonction)
                if overlap >= 2:
                    seen_paths.add(row["image_path"])
                    photos.append({
                        "url": image_public_url(row["image_path"]),
                        "caption": caption,
                        "score": overlap,
                    })

        photos.sort(key=lambda p: -p["score"])

        return AskResponse(answer=answer, photos=photos[:2])

    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error

    except Exception as error:
        print(f"[ASK] ERROR: {type(error).__name__}: {error}")
        raise HTTPException(
            status_code=500,
            detail=f"Question failed: {str(error)}",
        ) from error


# ---------------------------------------------------------------
# Diagnostic : images et lignes de texte d'une page, avec coordonnées
# ---------------------------------------------------------------

@router.get("/debug-page")
async def debug_page(document_id: str, page: int):
    rows = (
        supabase.table("knowledge_documents")
        .select("file_path")
        .eq("id", document_id)
        .limit(1)
        .execute()
    ).data or []

    if not rows:
        raise HTTPException(status_code=404, detail="Document not found.")

    pdf = fitz.open(rows[0]["file_path"])

    try:
        pg = pdf[page - 1]

        images = []
        for i, info in enumerate(pg.get_image_info(xrefs=True)):
            box = [round(v) for v in info["bbox"]]
            if box[2] - box[0] >= 40 and box[3] - box[1] >= 40:
                images.append({
                    "image_index": i,
                    "bbox": box,
                    "caption": get_nearby_text(pg, fitz.Rect(info["bbox"])),
                })

        lines = []
        for block in pg.get_text("dict").get("blocks", []):
            if block.get("type") != 0:
                continue
            for line in block.get("lines", []):
                text = " ".join(
                    "".join(s["text"] for s in line["spans"]).split()
                )
                if text:
                    lines.append({
                        "bbox": [round(v) for v in line["bbox"]],
                        "text": text[:80],
                    })

        return {
            "page_size": [round(pg.rect.width), round(pg.rect.height)],
            "images": images,
            "lines": lines,
        }

    finally:
        pdf.close()