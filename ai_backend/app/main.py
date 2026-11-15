
from fastapi import FastAPI

from app.api.documents import router as documents_router
from app.api.chat import router as chat_router
from app.api.knowledge_images import router as knowledge_images_router
from app.api.visual_search import router as visual_search_router

app = FastAPI(
    title="EMSI Skill Graph AI",
    description="AI backend for academic and career intelligence",
    version="1.0.0",
)

app.include_router(documents_router)
app.include_router(chat_router)
app.include_router(visual_search_router)
app.include_router(knowledge_images_router)


@app.get("/")
async def root():
    return {
        "application": "EMSI Skill Graph AI",
        "status": "running",
    }


@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "ai_backend",
    }
