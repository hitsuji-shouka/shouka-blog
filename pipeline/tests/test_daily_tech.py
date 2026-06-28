from datetime import date

import daily_tech


def test_daily_tech_uses_reporter_voice_and_weekend_friendly_window(tmp_path):
    calls = []

    def fake_runner(cmd, **_kwargs):
        calls.append(cmd)
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
