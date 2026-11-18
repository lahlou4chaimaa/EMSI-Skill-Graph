"""
Matching par points caractéristiques (SIFT + RANSAC).

Contrairement au hash perceptuel, il retrouve la même photo même si elle est
recadrée, zoomée, en capture d'écran ou entourée d'autres éléments.

Dépendance : pip install opencv-python-headless numpy
"""

from pathlib import Path

import cv2
import numpy as np

from app.services.knowledge_service import supabase


BATCH_SIZE = 1000
DEFAULT_TOP_K = 10

MAX_SIDE = 600          # redimensionnement avant analyse
MAX_FEATURES = 1500
RATIO_TEST = 0.75       # test de Lowe
MIN_INLIERS = 12        # nb minimum de points cohérents pour accepter

# Le router passe max_distance : il est ignoré ici (voir MIN_INLIERS).
DEFAULT_MAX_DISTANCE = 0

# Si défini, on ne compare qu'avec les images de cette brochure.
# Mettre None pour comparer avec toutes les brochures.
FOCUS_DOCUMENT_ID = "b20df1a7-dfdd-4726-a09b-b3996e4f631b"

_sift = cv2.SIFT_create(nfeatures=MAX_FEATURES)
_matcher = cv2.BFMatcher(cv2.NORM_L2)

# Cache mémoire : image_path -> (keypoints_xy, descripteurs)
_cache: dict[str, tuple] = {}


def _resize(gray: np.ndarray) -> np.ndarray:
    h, w = gray.shape[:2]
    scale = MAX_SIDE / max(h, w)
    if scale < 1:
        gray = cv2.resize(gray, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
    return gray


def _describe(gray: np.ndarray):
    gray = _resize(gray)
    keypoints, descriptors = _sift.detectAndCompute(gray, None)
    if descriptors is None or len(keypoints) < 8:
        return None
    points = np.float32([kp.pt for kp in keypoints])
    return points, descriptors


def _describe_file(image_path: str):
    if image_path in _cache:
        return _cache[image_path]

    result = None
    path = Path(image_path)
    if path.exists():
        data = np.fromfile(str(path), dtype=np.uint8)
        gray = cv2.imdecode(data, cv2.IMREAD_GRAYSCALE)
        if gray is not None:
            result = _describe(gray)

    _cache[image_path] = result
    return result


def _count_inliers(query, target) -> int:
    q_points, q_desc = query
    t_points, t_desc = target

    if len(t_desc) < 2 or len(q_desc) < 2:
        return 0

    knn = _matcher.knnMatch(q_desc, t_desc, k=2)

    good = [
        pair[0] for pair in knn
        if len(pair) == 2 and pair[0].distance < RATIO_TEST * pair[1].distance
    ]

    if len(good) < 8:
        return len(good) if len(good) < MIN_INLIERS else 0

    src = q_points[[m.queryIdx for m in good]].reshape(-1, 1, 2)
    dst = t_points[[m.trainIdx for m in good]].reshape(-1, 1, 2)

    _, mask = cv2.findHomography(src, dst, cv2.RANSAC, 5.0)

    return int(mask.sum()) if mask is not None else 0


def get_indexed_images() -> list[dict]:
    all_images = []
    offset = 0

    while True:
        query = (
            supabase.table("knowledge_images")
            .select(
                "id, document_id, filename, image_path, "
                "page_number, image_index, width, height, nearby_text, bbox"
            )
        )

        if FOCUS_DOCUMENT_ID:
            query = query.eq("document_id", FOCUS_DOCUMENT_ID)

        response = query.range(offset, offset + BATCH_SIZE - 1).execute()

        batch = response.data or []
        all_images.extend(batch)

        if len(batch) < BATCH_SIZE:
            break

        offset += BATCH_SIZE

    return all_images


def find_matching_images(
    image_bytes: bytes,
    top_k: int = DEFAULT_TOP_K,
    max_distance: int = DEFAULT_MAX_DISTANCE,
) -> dict:

    data = np.frombuffer(image_bytes, dtype=np.uint8)
    gray = cv2.imdecode(data, cv2.IMREAD_GRAYSCALE)

    if gray is None:
        raise ValueError("Invalid or unsupported image.")

    if gray.shape[0] * gray.shape[1] > 20_000_000:
        raise ValueError("Image dimensions are too large.")

    query = _describe(gray)

    if query is None:
        raise ValueError(
            "Image trop uniforme : pas assez de détails pour la comparer."
        )

    indexed_images = get_indexed_images()

    matches = []

    for record in indexed_images:
        target = _describe_file(record["image_path"])

        if target is None:
            continue

        inliers = _count_inliers(query, target)

        if inliers <= 0:
            continue

        matches.append({
            "id": record["id"],
            "document_id": record["document_id"],
            "filename": record["filename"],
            "image_path": record["image_path"],
            "page_number": record["page_number"],
            "image_index": record["image_index"],
            "nearby_text": record.get("nearby_text") or "",
            "bbox": record.get("bbox"),
            "inliers": inliers,
            # "distance" conservé pour compatibilité avec le router : plus petit = meilleur
            "distance": max(0, 100 - inliers),
            "matched_variant": "sift",
        })

    matches.sort(key=lambda item: -item["inliers"])

    best_matches = matches[:top_k]

    accepted_matches = [m for m in best_matches if m["inliers"] >= MIN_INLIERS]

    return {
        "matched": bool(accepted_matches),
        "total_images_compared": len(indexed_images),
        "max_distance": max_distance,
        "matches": best_matches,
        "accepted_matches": accepted_matches,
    }