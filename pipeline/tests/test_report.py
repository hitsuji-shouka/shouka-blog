from datetime import date

import report


def test_render_has_tag_and_category():
    md = report.render("要点一", "AI", "每日 AI 进展", date(2026, 6, 13))
    assert "category: AI" in md and "tags: [每日报告]" in md and "要点一" in md


def test_write_skips_empty(tmp_path, monkeypatch):
    monkeypatch.setattr(report, "CONTENT", tmp_path)
    assert report.write("", "AI", "ai", "每日 AI 进展", date(2026, 6, 13)) is None
    assert list(tmp_path.glob("*.md")) == []


def test_write_creates_prefixed_file(tmp_path, monkeypatch):
    monkeypatch.setattr(report, "CONTENT", tmp_path)
    p = report.write("内容", "AI", "ai", "每日 AI 进展", date(2026, 6, 13))
    assert p.name == "ai-20260613.md" and "category: AI" in p.read_text()
