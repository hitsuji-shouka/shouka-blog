from datetime import date

import daily_tech


def test_daily_tech_uses_reporter_voice_and_weekend_friendly_window(tmp_path):
    calls = []

    def fake_runner(cmd, **_kwargs):
        calls.append(cmd)
        content = tmp_path / "content"
        content.mkdir()
        (content / "tech-20260628.md").write_text("ok", encoding="utf-8")
        return daily_tech.RunResult(returncode=0)

    code = daily_tech.run_daily_tech(root=tmp_path, run_date=date(2026, 6, 28), runner=fake_runner)

    assert code == 0
    assert calls == [[
        daily_tech.PYTHON,
        "-m",
        "pipeline.run",
        "tech",
        "--mode",
        "news",
        "--with-audio",
        "--publish",
        "--min-items",
        "3",
        "--hours",
        "72",
        "--voice",
        "Chinese_radio_reporter_nv1",
    ]]


def test_daily_tech_retries_when_no_article_is_written(tmp_path):
    calls = []

    def fake_runner(cmd, **_kwargs):
        calls.append(cmd)
        if len(calls) == 2:
            content = tmp_path / "content"
            content.mkdir()
            (content / "tech-20260628.md").write_text("ok", encoding="utf-8")
        return daily_tech.RunResult(returncode=0)

    code = daily_tech.run_daily_tech(
        root=tmp_path,
        run_date=date(2026, 6, 28),
        runner=fake_runner,
        retries=2,
        retry_delay_seconds=0,
    )

    assert code == 0
    assert len(calls) == 2
