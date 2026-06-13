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

SYSTEM = "你是 shoka 的博客助理。基于给定文章片段回答访客提问；无片段时凭你自己的知识简洁作答。"


class Msg(BaseModel):
    role: str
    content: str = Field(max_length=2000)


class ChatReq(BaseModel):
    messages: list[Msg] = Field(max_length=20)


def _sse(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


def build_messages(history: list[Msg], hits: list[dict]) -> list[dict]:
    ctx = "\n\n".join(f"《{h['title']}》\n{h['text']}" for h in hits)
    sys = SYSTEM + (f"\n\n相关文章：\n{ctx}" if ctx else "")
    return [{"role": "system", "content": sys}, *[m.model_dump() for m in history]]


def stream(req: ChatReq, embed, chat) -> Iterator[str]:
    question = next((m.content for m in reversed(req.messages) if m.role == "user"), "")
    with trace("chat", question=question) as rec:
        hits = rag.search(embed([question])[0]) if question else []
        sources = list({h["slug"]: {"slug": h["slug"], "title": h["title"]} for h in hits}.values())
        yield _sse("sources", {"sources": sources})
        answer = ""
        try:
            for delta in chat(build_messages(req.messages, hits)):
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
