from datetime import date
from enum import Enum

from pydantic import BaseModel


class Category(str, Enum):
    """四个固定分类。"""

    LEARNING = "学习"
    READING = "阅读"
    MUSIC = "音乐"
    FINANCE = "理财"


class PostMeta(BaseModel):
    """文章元数据，列表接口返回，不含正文。"""

    slug: str
    title: str
    date: date
    category: Category
    tags: list[str] = []
    summary: str = ""
    cover: str | None = None


class PostDetail(PostMeta):
    """文章详情，含原始 Markdown 正文。"""

    content: str
