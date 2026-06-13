import logging
import sys

sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parent.parent / "backend"))
from llm import _chat  # noqa: E402  复用 DeepSeek 客户端
from config import settings  # noqa: E402
from trace import trace  # noqa: E402

logger = logging.getLogger(__name__)

SYSTEM = "你是{domain}编辑。把多个来源近一日内容按主题归纳成中文每日报告，列要点、标注来源、附原链接，客观不预测，不要加大标题。"


def summarize(items: list[dict], domain: str = "金融") -> str:
    """items: [{handle,text,url}] -> markdown；空则空串。"""
    if not items:
        return ""
    blob = "\n".join(f"@{t['handle']}: {t['text']} ({t['url']})" for t in items)
    with trace("daily-summary", domain=domain, count=len(items)) as rec:
        r = _chat.chat.completions.create(
            model=settings.deepseek_model,
            messages=[{"role": "system", "content": SYSTEM.format(domain=domain)}, {"role": "user", "content": blob}],
        )
        out = r.choices[0].message.content or ""
        rec(output=out, metadata={"model": settings.deepseek_model})
    return out
