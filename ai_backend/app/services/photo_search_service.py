import re
import unicodedata
from typing import Any

from app.services.knowledge_service import supabase


# Mots trop fréquents pour identifier une personne.
STOP_WORDS = {
    "qui", "que", "quoi", "pour", "avec", "dans", "chez", "est",
    "une", "des", "les", "and", "the", "this", "that", "photo",
    "photographie", "image", "personne", "envoyer", "envoie",
    "montre", "montrer", "voir", "please", "send", "show",
    "directeur", "directrice", "general", "generale", "monsieur",
    "madame", "bonjour", "salut", "hello", "hi", "son", "sa",
    "ses", "lui", "elle", "his", "her", "their",
}

# Abréviations / fonctions : mot de la question -> expressions cherchées
# dans la légende de la photo (texte normalisé, sans accents).
ROLE_ALIASES = {
    "dg": ["directeur general", "directrice generale"],
    "pdg": ["president directeur general", "pdg"],
    "rh": ["ressources humaines", "drh"],
    "drh": ["ressources humaines", "drh"],
    "daf": ["administratif et financier", "daf"],
    "dsi": ["systemes d information", "dsi"],
    "directeur general": ["directeur general"],
    "directrice generale": ["directrice generale"],
    "ressources humaines": ["ressources humaines"],
}

ROLE_BONUS = 3


def normalize_text(value: str) -> str:
    value = unicodedata.normalize("NFD", (value or "").lower())
    value = "".join(
        char for char in value
        if unicodedata.category(char) != "Mn"
    )
    value = re.sub(r"[’'`\-|,]", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def extract_tokens(value: str) -> set[str]:
    tokens = set(re.findall(r"[a-z]{2,}", normalize_text(value)))
    return tokens - STOP_WORDS


def role_score(context_text: str, caption: str) -> int:
    """Bonus si la question vise une fonction (DG, RH...) citée dans la légende."""
    context = normalize_text(context_text)
    context_words = set(re.findall(r"[a-z]{2,}", context))
    caption_norm = normalize_text(caption)

    for key, phrases in ROLE_ALIASES.items():
        triggered = (
            key in context_words
            if " " not in key
            else key in context
        )

        if triggered and any(phrase in caption_norm for phrase in phrases):
            return ROLE_BONUS

    return 0


def find_photos_for_chunks(
    chunks: list[dict[str, Any]],
    context_text: str,
    limit: int = 3,
) -> list[dict[str, Any]]:
    """
    Retrouve les photos des pages renvoyées par le RAG, en comparant la légende
    de chaque photo avec la conversation (noms, fonctions, abréviations).
    """
    if not chunks:
        return []

    context_tokens = extract_tokens(context_text)

    candidates: dict[str, dict[str, Any]] = {}
    seen_pages = set()

    for chunk in chunks:
        document_id = chunk.get("document_id")
        page_number = chunk.get("page_number")

        if not document_id or page_number is None:
            continue

        page_key = (str(document_id), int(page_number))

        if page_key in seen_pages:
            continue
        seen_pages.add(page_key)

        response = (
            supabase.table("knowledge_images")
            .select("id, document_id, page_number, image_path, nearby_text")
            .eq("document_id", str(document_id))
            .eq("page_number", int(page_number))
            .execute()
        )

        for image_row in response.data or []:
            image_id = image_row.get("id")
            caption = image_row.get("nearby_text") or ""

            if not image_id or not caption.strip():
                continue

            overlap = context_tokens & extract_tokens(caption)
            score = len(overlap) + role_score(context_text, caption)

            if score == 0:
                continue

            key = str(image_id)
            previous = candidates.get(key)

            if previous is None or score > previous["score"]:
                candidates[key] = {
                    "url": f"/knowledge-images/{key}/file",
                    "caption": caption,
                    "score": score,
                }

    ranked = sorted(
        candidates.values(),
        key=lambda item: item["score"],
        reverse=True,
    )

    # Au moins 2 points : nom + prénom, ou une fonction reconnue.
    return [item for item in ranked if item["score"] >= 2][:limit]