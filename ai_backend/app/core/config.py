
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    supabase_url: str
    supabase_service_role_key: str

    ollama_base_url: str = "http://localhost:11434"

    ollama_embedding_model: str = "nomic-embed-text"
    ollama_chat_model: str = "llama3.2:3b"
    ollama_vision_model: str = "qwen3-vl:4b"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
