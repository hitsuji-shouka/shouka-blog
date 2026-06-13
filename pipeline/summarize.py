import logging
import sys

sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parent.parent / "backend"))
from llm import _chat  # noqa: E402  复用 DeepSeek 客户端
from config import settings  # noqa: E402

logger = logging.getLogger(__name__)

SYSTEM = "你是金融编辑。把多位博主近一日推文按主题归纳成中文每日报告，列要点、标注博主、附原推链接，客观不预测。"


def summarize(tweets: list[dict]) -> str:
    """tweets: [{handle,text,url}] -> markdown；空则空串。"""
    if not tweets:
        return ""
    blob = "\n".join(f"@{t['handle']}: {t['text']} ({t['url']})" for t in tweets)
    r = _chat.chat.completions.create(
        model=settings.deepseek_model,
        messages=[{"role": "system", "content": SYSTEM}, {"role": "user", "content": blob}],
    )
    return r.choices[0].message.content or ""
