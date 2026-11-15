from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, File, HTTPException, UploadFile

from app.services.pdf_service import (
    extract_pdf_text,
    split_into_chunks,
)
from app.services.embedding_service import generate_embedding
from app.services.knowledge_service import (
    save_document,
    save_chunks,
)

router = APIRouter(prefix="/documents", tags=["Documents"])

UPLOAD_DIR = Path("storage/uploads")
MAX_FILE_SIZE = 50 * 1024 * 1024


@router.post("/upload")
async def upload_document(file: UploadFile = File(...)):
    if not file.filename:
        raise HTTPException(400, "Filename is required.")

    if Path(file.filename).suffix.lower() != ".pdf":
        raise HTTPException(400, "Only PDF files are supported.")

    pdf_bytes = await file.read(MAX_FILE_SIZE + 1)

    if len(pdf_bytes) > MAX_FILE_SIZE:
        raise HTTPException(413, "PDF exceeds 50 MB.")

    if not pdf_bytes.startswith(b"%PDF-"):
        raise HTTPException(400, "Invalid PDF file.")

    document_id = str(uuid4())
    file_path = UPLOAD_DIR / f"{document_id}.pdf"

    try:
        pages = extract_pdf_text(pdf_bytes)
        chunks = split_into_chunks(pages)

        UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
        file_path.write_bytes(pdf_bytes)

        # Generate one embedding for every chunk.
        chunk_records = []

        for chunk in chunks:
            embedding = await generate_embedding(chunk.content)

            chunk_records.append({
                "document_id": document_id,
                "content": chunk.content,
                "page_number": chunk.page_number,
                "chunk_index": chunk.chunk_index,
                "embedding": embedding,
            })

        # Save the document and its chunks.
        save_document(
                document_id=document_id,
                filename=Path(file.filename).name,
                total_pages=len(pages),
                total_chunks=len(chunks),
                file_path=str(file_path),
            )

        inserted_count = save_chunks(
                    document_id=document_id,
                    chunks=chunk_records,
                )

        return {
            "document_id": document_id,
            "filename": Path(file.filename).name,
            "pages_extracted": len(pages),
            "chunks_created": len(chunks),
            "embeddings_created": inserted_count,
            "embedding_dimensions": 768,
            "status": "indexed",
        }

    except Exception as error:
        file_path.unlink(missing_ok=True)

        raise HTTPException(
            status_code=500,
            detail=f"Document processing failed: {str(error)}",
        ) from error