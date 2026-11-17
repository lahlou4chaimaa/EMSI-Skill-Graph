
from app.services.embedding_service import generate_embedding
from app.services.knowledge_service import supabase


def get_chunk_key(item: dict) -> tuple:
    """Build a stable key to identify the same chunk in both searches."""
    return (
        str(item.get("document_id", "")),
        int(item.get("page_number", 0)),
        int(item.get("chunk_index", 0)),
    )


async def search_knowledge(
    question: str,
    match_count: int = 5,
    match_threshold: float = 0.30,
) -> list[dict]:

    if not question or not question.strip():
        raise ValueError("The question cannot be empty.")

    question = question.strip()

    # 1. Vector search
    query_embedding = await generate_embedding(question)

    vector_response = supabase.rpc(
        "match_knowledge_chunks",
        {
            "query_embedding": query_embedding,
            "match_threshold": match_threshold,
            "match_count": match_count * 3,
        },
    ).execute()

    vector_results = vector_response.data or []

    # 2. Keyword search
    keyword_response = supabase.rpc(
        "search_knowledge_chunks",
        {
            "search_query": question,
            "result_limit": match_count * 5,
        },
    ).execute()

    keyword_results = keyword_response.data or []

    print(f"[RAG] Vector results: {len(vector_results)}")
    print(f"[RAG] Keyword results: {len(keyword_results)}")

    # 3. Merge using the same key for both searches
    merged = {}

    for rank, item in enumerate(vector_results):
        key = get_chunk_key(item)

        merged[key] = {
            **item,
            "vector_score": float(item.get("similarity", 0)),
            "vector_rank": rank + 1,
            "keyword_score": 0.0,
            "keyword_rank": None,
        }

    for rank, item in enumerate(keyword_results):
        key = get_chunk_key(item)

        if key in merged:
            merged[key]["keyword_score"] = float(
                item.get("keyword_score", 0)
            )
            merged[key]["keyword_rank"] = rank + 1
        else:
            merged[key] = {
                **item,
                "vector_score": 0.0,
                "vector_rank": None,
                "keyword_score": float(
                    item.get("keyword_score", 0)
                ),
                "keyword_rank": rank + 1,
            }

    # 4. Rank fusion
    results = list(merged.values())

    vector_count = max(len(vector_results), 1)
    keyword_count = max(len(keyword_results), 1)

    for item in results:
        vector_rank = item["vector_rank"]
        keyword_rank = item["keyword_rank"]

        vector_part = (
            1 - (vector_rank - 1) / vector_count
            if vector_rank is not None
            else 0.0
        )

        keyword_part = (
            1 - (keyword_rank - 1) / keyword_count
            if keyword_rank is not None
            else 0.0
        )

        item["combined_score"] = (
            0.35 * vector_part
            + 0.65 * keyword_part
        )

        # Keep compatibility with chat.py and the LLM
        item["similarity"] = item["combined_score"]

    results.sort(
        key=lambda item: item["combined_score"],
        reverse=True,
    )

    selected = results[:match_count]

    print("[RAG] Selected chunks:")
    for item in selected:
        print(
            f"  Page {item.get('page_number')} | "
            f"Chunk {item.get('chunk_index')} | "
            f"Score {item.get('combined_score'):.4f} | "
            f"Keyword rank {item.get('keyword_rank')}"
        )

    return selected
