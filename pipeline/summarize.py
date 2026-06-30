import logging
import sys

sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parent.parent / "backend"))
from llm import CHAT_MODEL, _chat  # noqa: E402  复用后端聊天客户端
from trace import trace  # noqa: E402

logger = logging.getLogger(__name__)

SYSTEM = "你是{domain}编辑。把多个来源近一日内容按主题归纳成中文每日报告，列要点、标注来源、附原链接，客观不预测，不要加大标题。"
NEWS_ARTICLE_SYSTEM = (
    "你是{domain}早报编辑。把近24小时新闻整理成中文{domain}早报，结构包含："
    "今日摘要、重点新闻、影响资产、今日关注、来源。客观归纳，不提供投资建议。"
    "不要把其他栏目名称写进标题或正文，例如科技早报不要写成理财早报。"
)
NEWS_SCRIPT_SYSTEM = (
    "你是{domain}播客主播。把同一批新闻写成3到6分钟可朗读中文早报稿，"
    "语气自然，保留来源名称，不朗读复杂URL，不提供投资建议。"
)


def summarize(items: list[dict], domain: str = "金融") -> str:
    """items: [{handle,text,url}] -> markdown；空则空串。"""
    if not items:
        return ""
    blob = "\n".join(f"@{t['handle']}: {t['text']} ({t['url']})" for t in items)
    with trace("daily-summary", domain=domain, count=len(items)) as rec:
        r = _chat.chat.completions.create(
            model=CHAT_MODEL,
            messages=[{"role": "system", "content": SYSTEM.format(domain=domain)}, {"role": "user", "content": blob}],
        )
        out = r.choices[0].message.content or ""
        rec(output=out, metadata={"model": CHAT_MODEL})
    return out


def summarize_news(items: list[dict], domain: str = "金融") -> dict[str, str]:
    if not items:
        return {"article": "", "script": ""}
    blob = "\n".join(
        f"- 来源：{t.get('source', '')}\n  标题：{t.get('title', '')}\n  摘要：{t.get('text', '')}\n  链接：{t.get('url', '')}"
        for t in items
    )
    with trace("morning-briefing-summary", domain=domain, count=len(items)) as rec:
        article = _complete(NEWS_ARTICLE_SYSTEM.format(domain=domain), blob)
        script = _complete(NEWS_SCRIPT_SYSTEM.format(domain=domain), blob)
        rec(output=article, metadata={"model": CHAT_MODEL, "script_chars": len(script)})
    return {"article": article, "script": script}


def _complete(system: str, user: str) -> str:
    r = _chat.chat.completions.create(
        model=CHAT_MODEL,
        messages=[{"role": "system", "content": system}, {"role": "user", "content": user}],
    )
    return r.choices[0].message.content or ""
