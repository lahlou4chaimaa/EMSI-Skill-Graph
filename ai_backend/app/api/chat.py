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
    match_count: int = Field(
        default=5,
        ge=1,
        le=10,
    )


class ChatResponse(BaseModel):
    question: str
    answer: str


@router.post("/ask", response_model=ChatResponse)
async def ask_question(request: ChatRequest):
    try:
        chunks = await search_knowledge(
            question=request.question,
            match_count=request.match_count,
            match_threshold=0.30,
        )

        answer = await generate_answer(
            question=request.question,
            context_chunks=chunks,
        )

        return {
            "question": request.question,
            "answer": answer,
        }

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Chat processing failed: {str(error)}",
        ) from error