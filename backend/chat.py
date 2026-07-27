import json
import logging
from typing import Callable, Iterator

from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

import rag
from trace import trace

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api")

SYSTEM = "你是 shoka 的博客 Agent。基于给定文章片段回答访客提问；无片段时凭你自己的知识简洁作答。"


class Msg(BaseModel):
    role: str
    content: str = Field(max_length=2000)


class ChatReq(BaseModel):
    messages: list[Msg] = Field(max_length=20)
    personality: dict[str, int] = Field(default_factory=dict)


def _sse(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


def _clamp_percent(value: int | None, fallback: int) -> int:
    if value is None:
        return fallback
    return max(0, min(100, value))


def personality_prompt(personality: dict[str, int]) -> str:
    humor = _clamp_percent(personality.get("humor"), 35)
    honesty = _clamp_percent(personality.get("honesty"), 90)
    return (
        f"\n\nAgent 语气参数：幽默度 {humor}%，诚实度 {honesty}%。"
        "幽默度越高，允许更克制、短促的作者式玩笑；幽默度低时保持冷静直接。"
        "诚实度越高，越要明确区分文章依据、常识推断和未知信息，不要编造来源。"
        "整体语气应像一位清醒的个人博客向导，避免营销腔。"
    )


def build_messages(history: list[Msg], hits: list[dict], personality: dict[str, int] | None = None) -> list[dict]:
    ctx = "\n\n".join(f"《{h['title']}》\n{h['text']}" for h in hits)
    sys = SYSTEM + personality_prompt(personality or {}) + (f"\n\n相关文章：\n{ctx}" if ctx else "")
    return [{"role": "system", "content": sys}, *[m.model_dump() for m in history]]


def stream(req: ChatReq, embed, chat) -> Iterator[str]:
    question = next((m.content for m in reversed(req.messages) if m.role == "user"), "")
    with trace("chat", question=question) as rec:
        hits = []
        if question:
            try:
                hits = rag.search(embed([question])[0])
            except Exception as e:  # noqa: BLE001
                logger.warning("chat retrieval skipped: %s", e)
        sources = list({h["slug"]: {"slug": h["slug"], "title": h["title"]} for h in hits}.values())
        yield _sse("sources", {"sources": sources})
        answer = ""
        try:
            for delta in chat(build_messages(req.messages, hits, req.personality)):
                answer += delta
                yield _sse("delta", {"text": delta})
        except Exception as e:  # noqa: BLE001
            logger.warning("chat stream error: %s", e)
            yield _sse("error", {"message": "助理暂时不可用"})
        rec(input=question, output=answer, metadata={"sources": sources})
    yield _sse("done", {})


@router.post("/chat")
def chat(req: ChatReq) -> StreamingResponse:
    from llm import embed, stream_chat
    return StreamingResponse(stream(req, embed, stream_chat), media_type="text/event-stream")
