from pathlib import Path

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """运行配置；content_dir 指向文章目录，static_dir 指向前端产物。"""

    content_dir: Path = Path(__file__).resolve().parent.parent / "content"
    static_dir: Path = Path(__file__).resolve().parent.parent / "frontend" / "dist"

    deepseek_key: str = ""
    deepseek_base: str = "https://api.deepseek.com"
    deepseek_model: str = "deepseek-v4-pro"
    embed_key: str = ""
    embed_base: str = "https://api.siliconflow.cn/v1"
    embed_model: str = "BAAI/bge-m3"
    top_k: int = 3
    sim_threshold: float = 0.35

    model_config = {"env_prefix": "BLOG_", "env_file": ".env", "extra": "ignore"}


settings = Settings()
