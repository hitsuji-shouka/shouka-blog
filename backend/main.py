import logging
from contextlib import asynccontextmanager

from fastapi import APIRouter, FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

import posts
from config import settings
from models import PostDetail, PostMeta

logging.basicConfig(level=logging.INFO)

api = APIRouter(prefix="/api")


@api.get("/posts")
def list_posts(category: str | None = None) -> list[PostMeta]:
    return posts.list_meta(category)


@api.get("/categories")
def list_categories() -> list[dict]:
    return posts.categories()


@api.get("/posts/{slug}")
def get_post(slug: str) -> PostDetail:
    post = posts.get(slug)
    if post is None:
        raise HTTPException(status_code=404, detail="post not found")
    return post


@asynccontextmanager
async def lifespan(app: FastAPI):
    posts.load()
    yield


app = FastAPI(title="shoka-blog", lifespan=lifespan)
app.include_router(api)

# 静态托管：有产物则托管，/api/* 之外回 index.html（SPA fallback）
if settings.static_dir.is_dir():
    index = settings.static_dir / "index.html"
    app.mount("/assets", StaticFiles(directory=settings.static_dir / "assets"), name="assets")

    @app.get("/{full_path:path}")
    def spa(full_path: str) -> FileResponse:
        return FileResponse(index)
