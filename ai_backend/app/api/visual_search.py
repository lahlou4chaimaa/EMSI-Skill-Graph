
from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel

from app.services.ocr_service import extract_image_text
from app.services.retrieval_service import search_knowledge
from app.services.llm_service import generate_answer
from app.services.image_index_service import index_all_brochures


router = APIRouter(
    prefix="/visual-search",
    tags=["Visual Search"],
)

MAX_IMAGE_SIZE = 10 * 1024 * 1024


class VisualSource(BaseModel):
    document_id: str
    page_number: int
    chunk_index: int
    similarity: float


class VisualSearchResponse(BaseModel):
    extracted_text: list[dict]
    answer: str
    sources: list[VisualSource]


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


@router.post(
    "/analyze",
    response_model=VisualSearchResponse,
)
async def analyze_image(file: UploadFile = File(...)):

    allowed_types = {
        "image/jpeg",
        "image/png",
        "image/webp",
    }

    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail="Only JPG, PNG and WEBP images are supported.",
        )

    image_bytes = await file.read(MAX_IMAGE_SIZE + 1)

    if len(image_bytes) > MAX_IMAGE_SIZE:
        raise HTTPException(
            status_code=413,
            detail="Image exceeds 10 MB.",
        )

    if not image_bytes:
        raise HTTPException(
            status_code=400,
            detail="The image is empty.",
        )

    try:
        extracted = extract_image_text(image_bytes)

        if not extracted:
            return {
                "extracted_text": [],
                "answer": (
                    "Aucun texte exploitable n'a été détecté "
                    "dans cette image. Je ne peux donc pas "
                    "retrouver d'information documentaire fiable."
                ),
                "sources": [],
            }

        ocr_text = "\n".join(
            item["text"] for item in extracted
        )

        question = (
            "Recherche des informations documentaires "
            "correspondant aux textes visibles dans cette image. "
            "Retrouve les personnes mentionnées uniquement "
            "si les documents établissent explicitement "
            "leur nom et leur fonction.\n\n"
            f"Textes extraits de l'image :\n{ocr_text}"
        )

        chunks = await search_knowledge(
            question=question,
            match_count=5,
            match_threshold=0.30,
        )

        answer = await generate_answer(
            question=question,
            context_chunks=chunks,
        )

        sources = [
            {
                "document_id": str(chunk["document_id"]),
                "page_number": chunk["page_number"],
                "chunk_index": chunk["chunk_index"],
                "similarity": round(
                    float(chunk["similarity"]), 4
                ),
            }
            for chunk in chunks
        ]

        return {
            "extracted_text": extracted,
            "answer": answer,
            "sources": sources,
        }

    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail=str(error),
        ) from error

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Image analysis failed: {str(error)}",
        ) from error
