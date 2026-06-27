from datetime import date
from pathlib import Path

CONTENT = Path(__file__).resolve().parent.parent / "content"


def render(
    summary: str,
    category: str,
    title: str,
    d: date,
    tags: list[str] | None = None,
    audio: str | None = None,
    sources: list[str] | None = None,
) -> str:
    """汇总正文 + frontmatter，标分类与每日报告 tag。"""
    tags = tags or ["每日报告"]
    sources = sources or []
    frontmatter = (
        "---\n"
        f"title: {title} · {d:%m-%d}\n"
        f"date: {d:%Y-%m-%d}\n"
        f"category: {category}\n"
        f"tags: [{', '.join(tags)}]\n"
        f"summary: {d:%m-%d} {title}汇总\n"
    )
    if audio:
        frontmatter += f"audio: {audio}\n"
    if sources:
        frontmatter += "sources:\n" + "".join(f"  - {source}\n" for source in sources)
    return (
        frontmatter +
        "---\n\n"
        f"{summary.strip()}\n"
    )


def write(
    summary: str,
    category: str,
    prefix: str,
    title: str,
    d: date | None = None,
    tags: list[str] | None = None,
    audio: str | None = None,
    sources: list[str] | None = None,
) -> Path | None:
    """空汇总不生成；否则落 content/{prefix}-YYYYMMDD.md。"""
    d = d or date.today()
    if not summary.strip():
        return None
    p = CONTENT / f"{prefix}-{d:%Y%m%d}.md"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(render(summary, category, title, d, tags=tags, audio=audio, sources=sources), encoding="utf-8")
    return p
