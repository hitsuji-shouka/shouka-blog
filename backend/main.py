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
    import rag
    from llm import embed
    rag.build(embed)
    yield


app = FastAPI(title="shoka-blog", lifespan=lifespan)
app.include_router(api)
from chat import router as chat_router  # noqa: E402
app.include_router(chat_router)

# 静态托管：dist 内真实文件直接给（assets/bg 等），其余路径回 index.html（SPA fallback）
if settings.static_dir.is_dir():
    index = settings.static_dir / "index.html"

    @app.get("/{full_path:path}")
    def spa(full_path: str) -> FileResponse:
        f = settings.static_dir / full_path
        if full_path and f.is_file() and settings.static_dir in f.resolve().parents:
            return FileResponse(f)
        return FileResponse(index)
