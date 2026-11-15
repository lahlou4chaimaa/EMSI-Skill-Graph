import httpx

from app.core.config import settings


async def generate_embedding(text: str) -> list[float]:
    url = f"{settings.ollama_base_url}/api/embeddings"

    payload = {
        "model": settings.ollama_embedding_model,
        "prompt": text,
    }

    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(url, json=payload)
            response.raise_for_status()

        data = response.json()
        embedding = data.get("embedding")

        if not embedding:
            raise ValueError("Ollama returned an empty embedding.")

        if len(embedding) != 768:
            raise ValueError(
                f"Expected 768 dimensions, received {len(embedding)}."
            )

        return embedding

    except httpx.HTTPError as error:
        raise RuntimeError(
            f"Could not generate embedding with Ollama: {error}"
        ) from error