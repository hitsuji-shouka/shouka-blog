import logging
import os
from contextlib import asynccontextmanager
from datetime import datetime, time, timezone
from email.utils import format_datetime
from html import escape
from urllib.parse import quote

from fastapi import APIRouter, FastAPI, HTTPException
from fastapi.responses import FileResponse, HTMLResponse, PlainTextResponse, Response

import posts
from config import settings
from models import Category
from models import PostDetail, PostMeta

logging.basicConfig(level=logging.INFO)

api = APIRouter(prefix="/api")


@api.get("/posts")
def list_posts(category: str | None = None) -> list[PostMeta]:
    return posts.list_meta(category)


@api.get("/categories")
def list_categories() -> list[dict]:
    return posts.categories()


@api.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "shoka-blog"}


@api.get("/version")
def version() -> dict[str, str]:
    return {"version": os.getenv("APP_VERSION", "local"), "service": "shoka-blog"}


@api.get("/posts/{slug}")
def get_post(slug: str) -> PostDetail:
    post = posts.get(slug)
    if post is None:
        raise HTTPException(status_code=404, detail="post not found")
    return post


def build_rag_if_configured(embed_key: str, build, embed) -> bool:
    if not embed_key:
        logging.info("rag: BLOG_EMBED_KEY empty, index disabled")
        return False
    build(embed)
    return True


@asynccontextmanager
async def lifespan(app: FastAPI):
    posts.load()
    import rag
    from llm import embed
    build_rag_if_configured(settings.embed_key, rag.build, embed)
    yield


app = FastAPI(title="shoka-blog", lifespan=lifespan)
app.include_router(api)
from chat import router as chat_router  # noqa: E402
app.include_router(chat_router)


def site_origin() -> str:
    domain = os.getenv("SITE_DOMAIN", "shoka.example.com").strip().rstrip("/")
    if domain.startswith(("http://", "https://")):
        return domain
    return f"https://{domain}"


def public_index_html(index_html: str) -> str:
    origin = site_origin()
    image_url = f"{origin}/bg/hero-space.jpg"
    html = index_html.replace(
        '<meta property="og:image" content="/bg/hero-space.jpg" />',
        f'<meta property="og:image" content="{image_url}" />',
    ).replace(
        '<meta name="twitter:image" content="/bg/hero-space.jpg" />',
        f'<meta name="twitter:image" content="{image_url}" />',
    )
    if 'rel="canonical"' not in html:
        html = html.replace(
            '<meta name="theme-color" content="#f05a28" />',
            f'<meta name="theme-color" content="#f05a28" />\n    <link rel="canonical" href="{origin}/" />',
        )
    if 'property="og:url"' not in html:
        html = html.replace(
            '<meta property="og:type" content="website" />',
            f'<meta property="og:type" content="website" />\n    <meta property="og:url" content="{origin}/" />',
        )
    return html


@app.get("/robots.txt", response_class=PlainTextResponse, include_in_schema=False)
def robots_txt() -> str:
    origin = site_origin()
    return f"User-agent: *\nAllow: /\nSitemap: {origin}/sitemap.xml\n"


@app.get("/sitemap.xml", include_in_schema=False)
def sitemap_xml() -> Response:
    origin = site_origin()
    urls = [
        f"{origin}/",
        *(f"{origin}/category/{quote(category.value)}" for category in Category),
        *(f"{origin}/post/{quote(post.slug)}" for post in posts.list_meta()),
    ]
    latest = posts.list_meta()[0].date.isoformat() if posts.list_meta() else None

    items = []
    for url in urls:
        lastmod = f"\n    <lastmod>{latest}</lastmod>" if latest and url == f"{origin}/" else ""
        items.append(f"  <url>\n    <loc>{url}</loc>{lastmod}\n  </url>")
    body = "\n".join([
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
        *items,
        "</urlset>",
        "",
    ])
    return Response(content=body, media_type="application/xml")


@app.get("/feed.xml", include_in_schema=False)
def feed_xml() -> Response:
    origin = site_origin()
    items = []
    for post in posts.list_meta():
        pub_date = format_datetime(
            datetime.combine(post.date, time.min, tzinfo=timezone.utc),
            usegmt=True,
        )
        summary = post.summary or f"{post.category.value} post on Shouka Blog"
        items.append("\n".join([
            "    <item>",
            f"      <title>{escape(post.title)}</title>",
            f"      <link>{origin}/post/{quote(post.slug)}</link>",
            f"      <guid isPermaLink=\"true\">{origin}/post/{quote(post.slug)}</guid>",
            f"      <description>{escape(summary)}</description>",
            f"      <category>{escape(post.category.value)}</category>",
            f"      <pubDate>{pub_date}</pubDate>",
            "    </item>",
        ]))

    latest = posts.list_meta()[0].date if posts.list_meta() else None
    last_build = ""
    if latest:
        last_build = "\n".join([
            f"    <lastBuildDate>{format_datetime(datetime.combine(latest, time.min, tzinfo=timezone.utc), usegmt=True)}</lastBuildDate>",
        ])
    body = "\n".join([
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<rss version="2.0">',
        "  <channel>",
        "    <title>Shouka Blog</title>",
        f"    <link>{origin}/</link>",
        "    <description>AI systems, writing, finance notes, and practical experiments.</description>",
        "    <language>zh-CN</language>",
        last_build,
        *items,
        "  </channel>",
        "</rss>",
        "",
    ])
    return Response(content=body, media_type="application/rss+xml")

# 静态托管：dist 内真实文件直接给（assets/bg 等），其余路径回 index.html（SPA fallback）
if settings.static_dir.is_dir():
    index = settings.static_dir / "index.html"

    @app.get("/{full_path:path}")
    def spa(full_path: str) -> Response:
        f = settings.static_dir / full_path
        if full_path and f.is_file() and settings.static_dir in f.resolve().parents:
            return FileResponse(f)
        return HTMLResponse(public_index_html(index.read_text(encoding="utf-8")))
