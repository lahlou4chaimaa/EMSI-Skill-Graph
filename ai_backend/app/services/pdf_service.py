import re
from dataclasses import dataclass

import pymupdf

@dataclass
class DocumentChunk:
    content: str
    page_number: int
    chunk_index: int


def clean_text(text: str) -> str:
    text = text.replace("\x00", " ")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def extract_pdf_text(pdf_bytes: bytes) -> list[dict]:
    pages = []

    with pymupdf.open(stream=pdf_bytes, filetype="pdf") as document:
        if document.is_encrypted:
            raise ValueError("Encrypted PDF files are not supported.")

        for page_number, page in enumerate(document, start=1):
            text = clean_text(page.get_text("text"))

            if text:
                pages.append({
                    "page_number": page_number,
                    "text": text,
                })

    if not pages:
        raise ValueError(
            "No text found in this PDF. It may be a scanned document."
        )

    return pages


def split_into_chunks(
    pages: list[dict],
    chunk_size: int = 1200,
    overlap: int = 150,
) -> list[DocumentChunk]:

    if chunk_size <= 0 or overlap < 0 or overlap >= chunk_size:
        raise ValueError("Invalid chunk_size or overlap.")

    chunks = []

    for page in pages:
        text = page["text"]
        start = 0

        while start < len(text):
            end = min(start + chunk_size, len(text))

            if end < len(text):
                boundary = text.rfind(" ", start, end)

                if boundary > start:
                    end = boundary

            content = text[start:end].strip()

            if content:
                chunks.append(
                    DocumentChunk(
                        content=content,
                        page_number=page["page_number"],
                        chunk_index=len(chunks),
                    )
                )

            if end >= len(text):
                break

            start = max(start + 1, end - overlap)

    return chunks