
from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field

from app.services.knowledge_service import supabase
from app.services.retrieval_service import search_knowledge
from app.services.llm_service import (
    generate_answer,
    generate_conversation_answer,
)
from app.services.conversation_service import (
    create_conversation,
    get_conversation_history,
    save_message,
    verify_conversation_owner,
)
from app.services.photo_search_service import find_photos_for_chunks


router = APIRouter(prefix="/chat", tags=["AI Chat"])


class ChatRequest(BaseModel):
    question: str = Field(min_length=2, max_length=2000)
    match_count: int = Field(default=5, ge=1, le=10)
    conversation_id: str | None = None


class PhotoItem(BaseModel):
    url: str
    caption: str
    score: int


class ChatResponse(BaseModel):
    question: str
    answer: str
    conversation_id: str | None = None
    photos: list[PhotoItem] = Field(default_factory=list)


def normalize_text(text: str) -> str:
    import re
    import unicodedata

    text = text.lower().strip()
    text = unicodedata.normalize("NFD", text)
    text = "".join(
        char for char in text
        if unicodedata.category(char) != "Mn"
    )

    return re.sub(r"\s+", " ", text)


def is_photo_request(question: str) -> bool:
    normalized = normalize_text(question)

    photo_keywords = [
        "photo",
        "photos",
        "photographie",
        "photographies",
        "image",
        "images",
        "picture",
        "pictures",
        "portrait",
    ]

    action_keywords = [
        "envoie",
        "envoyer",
        "montre",
        "montrer",
        "affiche",
        "afficher",
        "donne",
        "voir",
        "send",
        "show",
        "give",
    ]

    return (
        any(word in normalized for word in photo_keywords)
        and (
            any(word in normalized for word in action_keywords)
            or len(normalized.split()) <= 6
        )
    )


def is_emsi_related(question: str) -> bool:
    normalized = normalize_text(question)

    keywords = [
        "emsi",
        "ecole marocaine des sciences de l'ingenieur",
        "ecole marocaine des sciences de l ingenieur",
        "notre ecole",
        "votre ecole",
        "campus",
        "brochure",
        "filiere",
        "formation",
        "formations",
        "diplome",
        "inscription",
        "admission",
        "frais de scolarite",
        "frais d'inscription",
        "career center",
        "forum entreprises",
        "directeur general",
        "directrice generale",
        "responsable pedagogique",
        "programme de formation",
        "specialite",
        "specialisation",
        "accreditation",
        "certification emsi",
        "photo",
        "photographie",
        "image",
        "portrait",
    ]

    return any(keyword in normalized for keyword in keywords)


def authenticate_student(
    authorization: str | None,
) -> str | None:
    if not authorization:
        return None

    scheme, separator, token = authorization.partition(" ")

    if (
        not separator
        or scheme.lower() != "bearer"
        or not token.strip()
    ):
        raise HTTPException(
            status_code=401,
            detail="Invalid Authorization header.",
        )

    try:
        user_response = supabase.auth.get_user(token.strip())
        user = user_response.user

        if user is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid or expired access token.",
            )

        return str(user.id)

    except HTTPException:
        raise

    except Exception as error:
        print(f"[AUTH] Token verification failed: {error}")

        raise HTTPException(
            status_code=401,
            detail="Invalid or expired access token.",
        ) from error


def build_contextual_query(
    question: str,
    history: list[dict[str, str]],
) -> str:
    """
    Enrich a follow-up question with previous messages.

    Example:
    Previous answer: "Le directeur général est X."
    Current question: "Envoie-moi sa photo."

    Retrieval query includes the previous answer and can
    therefore retrieve the page containing X.
    """
    previous_messages = history[-6:]

    context_parts = [
        message["content"]
        for message in previous_messages
        if message.get("content")
    ]

    context_parts.append(question)

    return "\n".join(context_parts)


def build_photo_context(
    question: str,
    history: list[dict[str, str]],
    answer: str,
) -> str:
    parts = [
        message["content"]
        for message in history[-8:]
        if message.get("content")
    ]

    parts.extend([question, answer])

    return "\n".join(parts)


@router.post("/ask", response_model=ChatResponse)
async def ask_question(
    request: ChatRequest,
    authorization: str | None = Header(default=None),
):
    question = request.question.strip()

    try:
        student_id = authenticate_student(authorization)
        conversation_id = request.conversation_id
        history: list[dict[str, str]] = []

        if conversation_id and not student_id:
            raise HTTPException(
                status_code=401,
                detail=(
                    "Authentication is required "
                    "to continue a conversation."
                ),
            )

        if student_id:
            if conversation_id:
                is_owner = verify_conversation_owner(
                    conversation_id=conversation_id,
                    student_id=student_id,
                )

                if not is_owner:
                    raise HTTPException(
                        status_code=404,
                        detail="Conversation not found.",
                    )

                history = get_conversation_history(
                    conversation_id,
                    limit=10,
                )

            else:
                conversation_id = create_conversation(
                    student_id=student_id,
                    first_message=question,
                )

            save_message(
                conversation_id=conversation_id,
                role="user",
                content=question,
            )

        photo_request = is_photo_request(question)
        emsi_question = is_emsi_related(question)

        photos: list[PhotoItem] = []

        if not emsi_question:
            answer = await generate_conversation_answer(
                question=question,
                conversation_history=history,
            )

        else:
            # For follow-up questions, include previous messages
            # in the retrieval query.
            if photo_request and history:
                retrieval_query = build_contextual_query(
                    question,
                    history,
                )
            else:
                retrieval_query = question

            chunks = await search_knowledge(
                question=retrieval_query,
                match_count=request.match_count,
                match_threshold=0.30,
            )

            answer = await generate_answer(
                question=question,
                context_chunks=chunks,
                conversation_history=history,
            )

            # Search the brochure image catalog only when
            # the student explicitly requests a photo or image.
            if photo_request and chunks:
                photo_context = build_photo_context(
                    question=question,
                    history=history,
                    answer=answer,
                )

                photo_results = find_photos_for_chunks(
                    chunks=chunks,
                    context_text=photo_context,
                    limit=3,
                )

                photos = [
                    PhotoItem(**photo)
                    for photo in photo_results
                ]

                if photos:
                    answer = (
                        "Voici la photo retrouvée dans "
                        "les documents EMSI."
                    )
                else:
                    answer = (
                        "Je n'ai pas retrouvé de photo correspondant "
                        "à cette personne dans les pages pertinentes "
                        "des brochures EMSI."
                    )

        if student_id and conversation_id:
            save_message(
                conversation_id=conversation_id,
                role="assistant",
                content=answer,
            )

        return ChatResponse(
            question=question,
            answer=answer,
            conversation_id=conversation_id,
            photos=photos,
        )

    except HTTPException:
        raise

    except Exception as error:
        print(f"[CHAT] Processing failed: {error}")

        raise HTTPException(
            status_code=500,
            detail=f"Chat processing failed: {str(error)}",
        ) from error
