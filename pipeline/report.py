from datetime import date
from pathlib import Path

CONTENT = Path(__file__).resolve().parent.parent / "content"


def slug_for(d: date) -> str:
    return f"finance-{d:%Y%m%d}"


def render(summary: str, d: date) -> str:
    """汇总正文 + frontmatter，标 理财/每日报告 tag。"""
    title = f"每日金融观点 · {d:%m-%d}"
    return (
        "---\n"
        f"title: {title}\n"
        f"date: {d:%Y-%m-%d}\n"
        "category: 理财\n"
        "tags: [每日报告]\n"
        f"summary: {d:%m-%d} 推特金融博主观点汇总\n"
        "---\n\n"
        f"{summary.strip()}\n"
    )


def write(summary: str, d: date | None = None) -> Path | None:
    """空汇总不生成；否则落 content/finance-YYYYMMDD.md。"""
    d = d or date.today()
    if not summary.strip():
        return None
    p = CONTENT / f"{slug_for(d)}.md"
    p.write_text(render(summary, d), encoding="utf-8")
    return p
