from pathlib import Path

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """运行配置；content_dir 指向文章目录，static_dir 指向前端产物。"""

    content_dir: Path = Path(__file__).resolve().parent.parent / "content"
    static_dir: Path = Path(__file__).resolve().parent.parent / "frontend" / "dist"

    deepseek_key: str = ""
    deepseek_base: str = "https://api.deepseek.com"
    deepseek_model: str = "deepseek-v4-pro"
    minimax_api_key: str = ""
    minimax_chat_base: str = "https://api.minimax.chat/v1"
    minimax_chat_model: str = "MiniMax-Text-01"
    minimax_tts_base: str = "https://api.minimax.chat/v1/t2a_v2"
    minimax_group_id: str = ""
    minimax_tts_model: str = "speech-02-turbo"
    minimax_tts_voice: str = "female-yujie"
    embed_key: str = ""
    embed_base: str = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    embed_model: str = "text-embedding-v4"
    top_k: int = 3
    sim_threshold: float = 0.35
    langfuse_public: str = ""
    langfuse_secret: str = ""
    langfuse_host: str = "http://localhost:3000"

    model_config = {"env_prefix": "BLOG_", "env_file": ".env", "extra": "ignore"}


settings = Settings()
