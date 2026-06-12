from typing import Iterator

from openai import OpenAI

from config import settings

_chat = OpenAI(api_key=settings.deepseek_key or "noop", base_url=settings.deepseek_base)
_embed = OpenAI(api_key=settings.embed_key or "noop", base_url=settings.embed_base)


def embed(texts: list[str]) -> list[list[float]]:
    """硅基流动 bge-m3 批量 embedding。"""
    r = _embed.embeddings.create(model=settings.embed_model, input=texts)
    return [d.embedding for d in r.data]


def stream_chat(messages: list[dict]) -> Iterator[str]:
    """DeepSeek v4 流式，逐增量文本。"""
    s = _chat.chat.completions.create(model=settings.deepseek_model, messages=messages, stream=True)
    for ch in s:
        delta = ch.choices[0].delta.content
        if delta:
            yield delta
