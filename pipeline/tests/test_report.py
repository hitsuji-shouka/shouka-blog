from datetime import date

import report


def test_render_has_report_tag_and_category():
    md = report.render("要点一", date(2026, 6, 13))
    assert "category: 理财" in md and "tags: [每日报告]" in md and "要点一" in md


def test_write_skips_empty(tmp_path, monkeypatch):
    monkeypatch.setattr(report, "CONTENT", tmp_path)
    assert report.write("", date(2026, 6, 13)) is None
    assert list(tmp_path.glob("*.md")) == []


def test_write_creates_file(tmp_path, monkeypatch):
    monkeypatch.setattr(report, "CONTENT", tmp_path)
    p = report.write("内容", date(2026, 6, 13))
    assert p.name == "finance-20260613.md" and "每日报告" in p.read_text()
