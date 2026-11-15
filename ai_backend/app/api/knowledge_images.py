
from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import FileResponse

from app.services.knowledge_service import supabase


router = APIRouter(
    prefix="/knowledge-images",
    tags=["Knowledge Images"],
)

IMAGE_DIR = Path("storage/brochure_images").resolve()


@router.get("/")
async def list_knowledge_images(
    document_id: UUID | None = None,
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
):
    try:
        query = (
            supabase.table("knowledge_images")
            .select(
                "id, document_id, filename, page_number, "
                "image_index, width, height, created_at",
                count="exact",
            )
        )

        if document_id:
            query = query.eq(
                "document_id",
                str(document_id),
            )

        response = (
            query
            .order("filename")
            .order("page_number")
            .range(offset, offset + limit - 1)
            .execute()
        )

        return {
            "total": response.count or 0,
            "limit": limit,
            "offset": offset,
            "images": response.data or [],
        }

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Could not retrieve images: {str(error)}",
        ) from error


@router.get("/{image_id}/file")
async def get_knowledge_image(image_id: UUID):
    try:
        response = (
            supabase.table("knowledge_images")
            .select("image_path")
            .eq("id", str(image_id))
            .limit(1)
            .execute()
        )

        if not response.data:
            raise HTTPException(
                status_code=404,
                detail="Image not found.",
            )

        image_path = Path(
            response.data[0]["image_path"]
        ).resolve()

        # Prevent access outside the image directory.
        try:
            image_path.relative_to(IMAGE_DIR)
        except ValueError:
            raise HTTPException(
                status_code=403,
                detail="Invalid image path.",
            )

        if not image_path.is_file():
            raise HTTPException(
                status_code=404,
                detail="Image file not found on server.",
            )

        return FileResponse(
            path=image_path,
            media_type="image/jpeg",
            filename=image_path.name,
        )

    except HTTPException:
        raise

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Could not retrieve image: {str(error)}",
        ) from error
