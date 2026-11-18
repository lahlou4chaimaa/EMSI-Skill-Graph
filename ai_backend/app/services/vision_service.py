
import base64
from io import BytesIO

import httpx
from PIL import Image, UnidentifiedImageError

from app.core.config import settings

MAX_IMAGE_PIXELS = 20_000_000

VISION_PROMPT = """
Tu es le moteur d'analyse visuelle de l'assistant EMSI.

Analyse attentivement l'image.

Objectifs :

1. Décris précisément ce qui est visible.
2. Si une personne est visible, décris :
   - son apparence générale,
   - ses vêtements,
   - sa position,
   - les éléments distinctifs visibles.
3. Lis tout texte visible dans l'image.
4. Identifie les logos, titres, légendes, fonctions ou autres
   informations institutionnelles visibles.
5. Si l'image semble provenir d'une brochure, indique les éléments
   pouvant aider à retrouver la personne ou le contenu dans cette
   brochure.
6. Ne fabrique aucune information.
7. Ne déduis jamais l'identité d'une personne uniquement à partir
   de son visage.
8. L'identité finale doit être déterminée uniquement à partir des
   informations textuelles ou institutionnelles retrouvées dans
   les documents EMSI.
9. Réponds en français.

Retourne une description claire et concise.
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