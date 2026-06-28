import logging
from pathlib import Path
from threading import RLock

import frontmatter
from pydantic import ValidationError

from config import settings
from models import Category, PostDetail, PostMeta

logger = logging.getLogger(__name__)

# slug -> PostDetail，按 date 倒序的内存索引；请求前按 content 文件签名懒刷新
_posts: dict[str, PostDetail] = {}
_ordered: list[PostDetail] = []
_content_dir: Path | None = None
_signature: tuple[tuple[str, int, int], ...] = ()
_lock = RLock()


def _parse(path: Path) -> PostDetail | None:
    """解析单个 .md，slug 取文件名（不含扩展名）；失败返回 None。"""
    try:
        fm = frontmatter.load(path)
        return PostDetail(
            slug=path.stem,
            title=fm["title"],
            date=fm["date"],
            category=fm["category"],
            tags=fm.get("tags") or [],
            summary=fm.get("summary") or "",
            cover=fm.get("cover"),
            audio=fm.get("audio"),
            sources=fm.get("sources") or [],
            content=fm.content,
        )
    except (ValidationError, KeyError, ValueError) as e:
        logger.warning("skip %s: %s", path.name, e)
        return None


def load(content_dir: Path | None = None) -> None:
    """扫 content/*.md 进内存，按 date 倒序；解析失败跳过记日志。"""
    global _content_dir, _signature
    content_dir = content_dir or settings.content_dir
    with _lock:
        parsed = [p for f in sorted(content_dir.glob("*.md")) if (p := _parse(f))]
        parsed.sort(key=lambda p: p.date, reverse=True)
        _posts.clear()
        _posts.update({p.slug: p for p in parsed})
        _ordered[:] = parsed
        _content_dir = content_dir
        _signature = _content_signature(content_dir)
        logger.info("loaded %d posts from %s", len(parsed), content_dir)


def ensure_fresh() -> None:
    content_dir = _content_dir or settings.content_dir
    with _lock:
        signature = _content_signature(content_dir)
        if signature != _signature:
            load(content_dir)


def list_meta(category: str | None = None) -> list[PostMeta]:
    """元数据列表，日期倒序；category 非法返空。"""
    ensure_fresh()
    if category is not None and category not in Category._value2member_map_:
        return []
    return [PostMeta(**p.model_dump()) for p in _ordered
            if category is None or p.category.value == category]


def get(slug: str) -> PostDetail | None:
    ensure_fresh()
    return _posts.get(slug)


def categories() -> list[dict]:
    """四分类及计数。"""
    ensure_fresh()
    return [{"category": c.value,
             "count": sum(1 for p in _ordered if p.category is c)}
            for c in Category]


def _content_signature(content_dir: Path) -> tuple[tuple[str, int, int], ...]:
    signature = []
    for path in sorted(content_dir.glob("*.md")):
        if path.is_file():
            stat = path.stat()
            signature.append((path.name, stat.st_mtime_ns, stat.st_size))
    return tuple(signature)
