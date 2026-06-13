from datetime import date
from pathlib import Path

CONTENT = Path(__file__).resolve().parent.parent / "content"


def render(summary: str, category: str, title: str, d: date) -> str:
    """汇总正文 + frontmatter，标分类与每日报告 tag。"""
    return (
        "---\n"
        f"title: {title} · {d:%m-%d}\n"
        f"date: {d:%Y-%m-%d}\n"
        f"category: {category}\n"
        "tags: [每日报告]\n"
        f"summary: {d:%m-%d} {title}汇总\n"
        "---\n\n"
        f"{summary.strip()}\n"
    )


def write(summary: str, category: str, prefix: str, title: str, d: date | None = None) -> Path | None:
    """空汇总不生成；否则落 content/{prefix}-YYYYMMDD.md。"""
    d = d or date.today()
    if not summary.strip():
        return None
    p = CONTENT / f"{prefix}-{d:%Y%m%d}.md"
    p.write_text(render(summary, category, title, d), encoding="utf-8")
    return p
