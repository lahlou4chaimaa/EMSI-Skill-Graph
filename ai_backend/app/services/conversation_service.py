
from datetime import datetime, timezone
from typing import Any

from app.services.knowledge_service import supabase


def create_conversation(
    student_id: str,
    first_message: str,
) -> str:
    title = first_message.strip().replace("\n", " ")[:70]

    if not title:
        title = "Nouvelle conversation"

    response = (
        supabase.table("tutor_conversations")
        .insert({
            "student_id": student_id,
            "title": title,
        })
        .execute()
    )

    if not response.data:
        raise RuntimeError("Could not create the conversation.")

    return str(response.data[0]["id"])


def verify_conversation_owner(
    conversation_id: str,
    student_id: str,
) -> bool:
    response = (
        supabase.table("tutor_conversations")
        .select("id")
        .eq("id", conversation_id)
        .eq("student_id", student_id)
        .maybe_single()
        .execute()
    )

    return response.data is not None


def get_conversation_history(
    conversation_id: str,
    limit: int = 10,
) -> list[dict[str, str]]:
    response = (
        supabase.table("tutor_messages")
        .select("role, content")
        .eq("conversation_id", conversation_id)
        .order("created_at", desc=True)
        .limit(limit)
        .execute()
    )

    messages = response.data or []

    # The database returns newest first.
    # Ollama needs chronological order.
    messages.reverse()

    return [
        {
            "role": message["role"],
            "content": message["content"],
        }
        for message in messages
        if message.get("role") in ("user", "assistant")
        and isinstance(message.get("content"), str)
    ]


def save_message(
    conversation_id: str,
    role: str,
    content: str,
) -> None:
    if role not in ("user", "assistant"):
        raise ValueError("Invalid message role.")

    if not content.strip():
        raise ValueError("Message content cannot be empty.")

    supabase.table("tutor_messages").insert({
        "conversation_id": conversation_id,
        "role": role,
        "content": content.strip(),
    }).execute()

    supabase.table("tutor_conversations").update({
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", conversation_id).execute()
