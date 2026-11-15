from supabase import Client, create_client

from app.core.config import settings


supabase: Client = create_client(
    settings.supabase_url,
    settings.supabase_service_role_key,
)


def save_document(
    document_id: str,
    filename: str,
    total_pages: int,
    total_chunks: int,
    file_path: str | None = None,
) -> None:
    document_data = {
        "id": document_id,
        "filename": filename,
        "total_pages": total_pages,
        "total_chunks": total_chunks,
        "status": "processing",
    }

    if file_path:
        document_data["file_path"] = file_path

    supabase.table("knowledge_documents").upsert(
        document_data
    ).execute()


def save_chunks(
    document_id: str,
    chunks: list[dict],
) -> int:
    batch_size = 20

    # Validate all chunks before writing anything.
    for index, chunk in enumerate(chunks):
        embedding = chunk.get("embedding")

        if not isinstance(embedding, list) or len(embedding) != 768:
            raise ValueError(
                f"Chunk {index} must contain an embedding of 768 dimensions."
            )

        if chunk.get("document_id") != document_id:
            raise ValueError(
                f"Chunk {index} has an incorrect document_id."
            )

    # Remove previous chunks for this document to avoid duplicates
    # when the same document is indexed again.
    supabase.table("knowledge_chunks").delete().eq(
        "document_id", document_id
    ).execute()

    inserted_count = 0

    try:
        for start in range(0, len(chunks), batch_size):
            batch = chunks[start:start + batch_size]

            supabase.table("knowledge_chunks").insert(
                batch
            ).execute()

            inserted_count += len(batch)

        supabase.table("knowledge_documents").update({
            "status": "indexed",
        }).eq("id", document_id).execute()

        return inserted_count

    except Exception:
        # Avoid leaving a partially indexed document.
        supabase.table("knowledge_chunks").delete().eq(
            "document_id", document_id
        ).execute()

        supabase.table("knowledge_documents").update({
            "status": "failed",
        }).eq("id", document_id).execute()

        raise