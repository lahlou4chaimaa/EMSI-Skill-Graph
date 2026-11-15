
import io

import easyocr
import numpy as np
from PIL import Image, UnidentifiedImageError


_reader = None


def get_reader():
    global _reader

    if _reader is None:
        _reader = easyocr.Reader(
            ["fr", "en"],
            gpu=False,
        )

    return _reader


def extract_image_text(image_bytes: bytes) -> list[dict]:
    try:
        image = Image.open(io.BytesIO(image_bytes))
        image.verify()

        image = Image.open(io.BytesIO(image_bytes))
        image = image.convert("RGB")

    except (UnidentifiedImageError, OSError) as error:
        raise ValueError("Invalid or unsupported image.") from error

    if image.width * image.height > 20_000_000:
        raise ValueError("Image dimensions are too large.")

    image_array = np.array(image)
    reader = get_reader()

    results = reader.readtext(
        image_array,
        detail=1,
        paragraph=False,
    )

    extracted = []

    for result in results:
        text = result[1].strip()
        confidence = float(result[2])

        if text:
            extracted.append({
                "text": text,
                "confidence": round(confidence, 3),
            })

    return extracted
