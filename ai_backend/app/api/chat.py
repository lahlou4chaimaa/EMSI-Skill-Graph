
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.services.retrieval_service import search_knowledge
from app.services.llm_service import generate_answer

router = APIRouter(prefix="/chat", tags=["AI Chat"])


class ChatRequest(BaseModel):
    question: str = Field(
        min_length=2,
        max_length=2000,
    )
    match_count: int = Field(default=5, ge=1, le=10)


class SourceItem(BaseModel):
    document_id: str
    page_number: int
    chunk_index: int
    similarity: float


class ChatResponse(BaseModel):
    question: str
    answer: str
    sources: list[SourceItem]


@router.post("/ask", response_model=ChatResponse)
async def ask_question(request: ChatRequest):
    try:
        # 1. Retrieve relevant document passages.
        chunks = await search_knowledge(
            question=request.question,
            match_count=request.match_count,
            match_threshold=0.30,
        )

        # 2. Generate an answer using Ollama.
        answer = await generate_answer(
            question=request.question,
            context_chunks=chunks,
        )

        # 3. Return the answer and its sources.
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
            "question": request.question,
            "answer": answer,
            "sources": sources,
        }

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Chat processing failed: {str(error)}",
        ) from error
