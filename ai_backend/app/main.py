from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.documents import router as documents_router
from app.api.chat import router as chat_router
from app.api.knowledge_images import router as knowledge_images_router
from app.api.visual_search import router as visual_search_router


app = FastAPI(
    title="EMSI Skill Graph AI",
    description="AI backend for academic and career intelligence",
    version="1.0.0",
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_origin_regex=r"^http://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static files: brochure images served to the front-end
IMAGES_DIR = Path("storage/brochure_images")
IMAGES_DIR.mkdir(parents=True, exist_ok=True)

app.mount(
    "/brochure-images",
    StaticFiles(directory=str(IMAGES_DIR)),
    name="brochure-images",
)

# API routers
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