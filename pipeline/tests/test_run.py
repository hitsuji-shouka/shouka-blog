from datetime import date

import report
import run


def write_input(tmp_path, count=2):
    items = []
    for i in range(count):
        items.append(
            {
                "source": f"S{i}",
                "title": f"T{i}",
                "url": f"https://x/{i}",
                "text": "Body",
                "published_at": "",
            }
        )
    p = tmp_path / "openclaw.json"
    import json

    p.write_text(json.dumps({"items": items}), encoding="utf-8")
    return p


def test_news_mode_writes_markdown_and_audio(tmp_path, monkeypatch):
    monkeypatch.setattr(report, "CONTENT", tmp_path / "content")
    monkeypatch.setattr(run, "AUDIO_DIR", tmp_path / "audio")
    monkeypatch.setattr(run, "today", lambda: date(2026, 6, 27))
    monkeypatch.setattr(run, "summarize_news", lambda items, domain: {"article": "正文", "script": "播客稿"})

    def fake_tts(text, path, settings):
        path.write_bytes(b"mp3")
        return path

    monkeypatch.setattr(run, "synthesize_to_file", fake_tts)

    out = run.main([
        "finance",
        "--mode",
        "news",
        "--input",
        str(write_input(tmp_path)),
        "--with-audio",
        "--min-items",
        "1",
        "--hours",
        "72",
    ])

    assert out is not None
    assert out.name == "finance-20260627.md"
    assert "audio: /audio/finance-20260627.mp3" in out.read_text(encoding="utf-8")
    assert (tmp_path / "audio" / "finance-20260627.mp3").read_bytes() == b"mp3"


def test_tech_news_mode_writes_tech_briefing_tags_and_audio(tmp_path, monkeypatch):
    monkeypatch.setattr(report, "CONTENT", tmp_path / "content")
    monkeypatch.setattr(run, "AUDIO_DIR", tmp_path / "audio")
    monkeypatch.setattr(run, "today", lambda: date(2026, 6, 27))
    monkeypatch.setattr(run, "summarize_news", lambda items, domain: {"article": "科技正文", "script": "科技播客稿"})

    def fake_tts(text, path, settings):
        path.write_bytes(b"mp3")
        return path

    monkeypatch.setattr(run, "synthesize_to_file", fake_tts)

    out = run.main([
        "tech",
        "--mode",
        "news",
        "--input",
        str(write_input(tmp_path)),
        "--with-audio",
        "--min-items",
        "1",
        "--hours",
        "72",
    ])

    assert out is not None
    assert out.name == "tech-20260627.md"
    text = out.read_text(encoding="utf-8")
    assert "title: 科技早报 · 06-27" in text
    assert "category: 科技" in text
    assert "tags: [每日报告, 科技早报]" in text
    assert "audio: /audio/tech-20260627.mp3" in text
    assert (tmp_path / "audio" / "tech-20260627.mp3").read_bytes() == b"mp3"


def test_news_mode_can_use_explicit_date(tmp_path, monkeypatch):
    monkeypatch.setattr(report, "CONTENT", tmp_path / "content")
    monkeypatch.setattr(run, "AUDIO_DIR", tmp_path / "audio")
    monkeypatch.setattr(run, "today", lambda: date(2026, 6, 27))
    monkeypatch.setattr(run, "summarize_news", lambda items, domain: {"article": "正文", "script": "播客稿"})

    def fake_tts(text, path, settings):
        path.write_bytes(b"mp3")
        return path

    monkeypatch.setattr(run, "synthesize_to_file", fake_tts)

    out = run.main([
        "finance",
        "--mode",
        "news",
        "--date",
        "2026-07-04",
        "--input",
        str(write_input(tmp_path)),
        "--with-audio",
        "--min-items",
        "1",
    ])

    assert out is not None
    assert out.name == "finance-20260704.md"
    assert "title: 理财早报 · 07-04" in out.read_text(encoding="utf-8")
    assert (tmp_path / "audio" / "finance-20260704.mp3").read_bytes() == b"mp3"


def test_news_mode_can_override_tts_voice(tmp_path, monkeypatch):
    monkeypatch.setattr(report, "CONTENT", tmp_path / "content")
    monkeypatch.setattr(run, "AUDIO_DIR", tmp_path / "audio")
    monkeypatch.setattr(run, "today", lambda: date(2026, 6, 27))
    monkeypatch.setattr(run, "summarize_news", lambda items, domain: {"article": "正文", "script": "播客稿"})
    voices = []

    def fake_tts(_text, path, settings):
        voices.append(settings.minimax_tts_voice)
        path.write_bytes(b"mp3")
        return path

    monkeypatch.setattr(run, "synthesize_to_file", fake_tts)

    run.main(
        [
            "finance",
            "--mode",
            "news",
            "--input",
            str(write_input(tmp_path)),
            "--with-audio",
            "--voice",
            "presenter_female",
            "--min-items",
            "1",
            "--hours",
            "72",
        ]
    )

    assert voices == ["presenter_female"]


def test_news_mode_skips_existing_without_force(tmp_path, monkeypatch):
    monkeypatch.setattr(report, "CONTENT", tmp_path)
    monkeypatch.setattr(run, "today", lambda: date(2026, 6, 27))
    existing = tmp_path / "finance-20260627.md"
    existing.write_text("old", encoding="utf-8")

    def should_not_call(*_args, **_kwargs):
        raise AssertionError("summarize should not run")

    monkeypatch.setattr(run, "summarize_news", should_not_call)

    assert run.main(["finance", "--mode", "news", "--input", str(write_input(tmp_path)), "--min-items", "1"]) is None


def test_news_mode_skips_when_not_enough_items(tmp_path, monkeypatch):
    monkeypatch.setattr(report, "CONTENT", tmp_path)
    monkeypatch.setattr(run, "today", lambda: date(2026, 6, 27))
    monkeypatch.setattr(run, "summarize_news", lambda *_: {"article": "x", "script": "y"})

    assert run.main(["finance", "--mode", "news", "--input", str(write_input(tmp_path, count=1)), "--min-items", "2"]) is None
    assert not (tmp_path / "finance-20260627.md").exists()
