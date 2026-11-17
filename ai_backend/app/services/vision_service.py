
import base64
from io import BytesIO

import httpx
from PIL import Image, UnidentifiedImageError

from app.core.config import settings


MAX_IMAGE_PIXELS = 20_000_000


VISION_PROMPT = """
You are the visual analysis engine of EMSI Assistant.

Analyze the provided image carefully.

Your tasks:
1. Describe the visible scene, objects, documents and people.
2. If people are visible, describe their visible appearance, clothing,
   position and actions without identifying them by their faces.
3. Read and transcribe visible text when possible.
4. Identify logos, signs, titles and other visible information.
5. Distinguish clearly between what is visible and what is uncertain.
6. Never invent names, functions, dates or institutional information.
7. Never claim that a person is a specific real-world individual based
   only on their face.
8. If the image contains a document, describe its content and structure.
9. Answer in French.

Return a structured but concise description.
"""


def prepare_image(image_bytes: bytes) -> bytes:
    try:
        image = Image.open(BytesIO(image_bytes))
        image.verify()

        image = Image.open(BytesIO(image_bytes))

    except (UnidentifiedImageError, OSError) as error:
        raise ValueError(
            "Invalid or unsupported image."
        ) from error

    if image.width * image.height > MAX_IMAGE_PIXELS:
        raise ValueError(
            "Image dimensions are too large."
        )

    image = image.convert("RGB")

    output = BytesIO()

    image.save(
        output,
        format="JPEG",
        quality=90,
        optimize=True,
    )

    return output.getvalue()


async def analyze_image_with_qwen(
    image_bytes: bytes,
) -> str:

    prepared_image = prepare_image(image_bytes)

    encoded_image = base64.b64encode(
        prepared_image
    ).decode("utf-8")

    url = (
        f"{settings.ollama_base_url.rstrip('/')}"
        "/api/chat"
    )

    payload = {
        "model": settings.ollama_vision_model,
        "messages": [
            {
                "role": "user",
                "content": VISION_PROMPT,
                "images": [encoded_image],
            }
        ],
        "stream": False,
        "options": {
            "temperature": 0.1,
        },
    }

    try:
        async with httpx.AsyncClient(
            timeout=180.0
        ) as client:

            response = await client.post(
                url,
                json=payload,
            )

            response.raise_for_status()

        data = response.json()

        description = (
            data.get("message", {})
            .get("content", "")
            .strip()
        )

        if not description:
            raise RuntimeError(
                "Qwen3-VL returned an empty description."
            )

        return description

    except httpx.HTTPError as error:
        raise RuntimeError(
            f"Could not analyze the image with Qwen3-VL: {error}"
        ) from error
