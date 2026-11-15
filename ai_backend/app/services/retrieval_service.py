
from app.services.embedding_service import generate_embedding
from app.services.knowledge_service import supabase


async def search_knowledge(
    question: str,
    match_count: int = 5,
    match_threshold: float = 0.30,
) -> list[dict]:
    if not question or not question.strip():
        raise ValueError("The question cannot be empty.")

    query_embedding = await generate_embedding(question.strip())

    response = supabase.rpc(
        "match_knowledge_chunks",
        {
            "query_embedding": query_embedding,
            "match_threshold": match_threshold,
            "match_count": match_count,
        },
    ).execute()

    return response.data or []
