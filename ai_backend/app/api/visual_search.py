
from fastapi import (
    APIRouter,
    File,
    Form,
    HTTPException,
    UploadFile,
)
from pydantic import BaseModel

from app.services.retrieval_service import search_knowledge
from app.services.llm_service import generate_answer
from app.services.vision_service import analyze_image_with_qwen
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
    visual_description: str
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
async def analyze_image(
    file: UploadFile = File(...),
    question: str = Form(
        default="Décris cette image et donne les informations utiles."
    ),
):
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
        # 1. Understand the image with Qwen3-VL.
        visual_description = await analyze_image_with_qwen(
            image_bytes
        )

        # 2. Combine the user's question with the visual description.
        retrieval_question = f"""
QUESTION DE L'ÉTUDIANT :
{question.strip()}

DESCRIPTION VISUELLE PRODUITE PAR QWEN3-VL :
{visual_description}

Recherche dans les documents EMSI les informations
qui répondent à la question de l'étudiant.

Si la question concerne une personne visible dans l'image,
ne lui attribue un nom ou une fonction que si les documents
contiennent une légende ou une indication textuelle explicite
qui établit cette association.
Ne déduis jamais une identité à partir du visage.
"""

        # 3. Retrieve official information from Supabase.
        chunks = await search_knowledge(
            question=retrieval_question,
            match_count=5,
            match_threshold=0.30,
        )

        # 4. Generate the final answer.
        if chunks:
            answer = await generate_answer(
                question=retrieval_question,
                context_chunks=chunks,
            )
        else:
            answer = visual_description

        sources = [
            {
                "document_id": str(chunk["document_id"]),
                "page_number": chunk["page_number"],
                "chunk_index": chunk["chunk_index"],
                "similarity": round(
                    float(chunk["similarity"]),
                    4,
                ),
            }
            for chunk in chunks
        ]

        return {
            "visual_description": visual_description,
            "extracted_text": [],
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
