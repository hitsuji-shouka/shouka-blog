from typing import Iterator

from openai import OpenAI

from config import settings


def resolve_chat_config(cfg=settings) -> tuple[str, str, str]:
    """MiniMax is the primary chat provider when its key is configured."""
    if cfg.minimax_api_key:
        return cfg.minimax_api_key, cfg.minimax_chat_base, cfg.minimax_chat_model
    return cfg.deepseek_key or "noop", cfg.deepseek_base, cfg.deepseek_model


CHAT_API_KEY, CHAT_BASE_URL, CHAT_MODEL = resolve_chat_config()

_chat = OpenAI(api_key=CHAT_API_KEY, base_url=CHAT_BASE_URL)
_embed = OpenAI(api_key=settings.embed_key or "noop", base_url=settings.embed_base)


def embed(texts: list[str]) -> list[list[float]]:
    """硅基流动 bge-m3 批量 embedding。"""
    r = _embed.embeddings.create(model=settings.embed_model, input=texts)
    return [d.embedding for d in r.data]


def stream_chat(messages: list[dict]) -> Iterator[str]:
    """DeepSeek v4 流式，逐增量文本。"""
    s = _chat.chat.completions.create(model=CHAT_MODEL, messages=messages, stream=True)
    for ch in s:
        delta = ch.choices[0].delta.content
        if delta:
            yield delta
