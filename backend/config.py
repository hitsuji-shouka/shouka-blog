from pathlib import Path

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """运行配置；content_dir 指向文章目录，static_dir 指向前端产物。"""

    content_dir: Path = Path(__file__).resolve().parent.parent / "content"
    static_dir: Path = Path(__file__).resolve().parent.parent / "frontend" / "dist"

    model_config = {"env_prefix": "BLOG_"}


settings = Settings()
