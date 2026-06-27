from datetime import date
import os
from pathlib import Path
import subprocess
import sys

import daily_finance


def test_daily_finance_runs_publish_command_and_writes_log(tmp_path):
    calls = []

    def fake_runner(cmd, cwd, stdout, stderr, text):
        calls.append((cmd, cwd, stdout is stderr, text))
        stdout.write("generated\n")
        return daily_finance.RunResult(returncode=0)

    code = daily_finance.run_daily_finance(
        root=tmp_path,
        run_date=date(2026, 6, 27),
        runner=fake_runner,
    )

    assert code == 0
    assert calls == [
        (
            [
                daily_finance.PYTHON,
                "-m",
                "pipeline.run",
                "finance",
                "--mode",
                "news",
                "--with-audio",
                "--publish",
            ],
            tmp_path,
            True,
            True,
        )
    ]
    log = tmp_path / "pipeline" / "logs" / "finance-20260627.log"
    assert "generated" in log.read_text(encoding="utf-8")
    assert not (tmp_path / "pipeline" / "logs" / "finance-20260627.lock").exists()


def test_daily_finance_refuses_when_lock_exists(tmp_path):
    log_dir = tmp_path / "pipeline" / "logs"
    log_dir.mkdir(parents=True)
    (log_dir / "finance-20260627.lock").write_text("busy", encoding="utf-8")

    def should_not_run(*_args, **_kwargs):
        raise AssertionError("runner should not be called when lock exists")

    code = daily_finance.run_daily_finance(
        root=tmp_path,
        run_date=date(2026, 6, 27),
        runner=should_not_run,
    )

    assert code == 2
    assert "already running" in (log_dir / "finance-20260627.log").read_text(encoding="utf-8")


def test_daily_finance_can_disable_audio_and_publish(tmp_path):
    calls = []

    def fake_runner(cmd, **_kwargs):
        calls.append(cmd)
        return daily_finance.RunResult(returncode=0)

    code = daily_finance.run_daily_finance(
        root=tmp_path,
        run_date=date(2026, 6, 27),
        with_audio=False,
        publish=False,
        runner=fake_runner,
    )

    assert code == 0
    assert calls == [[daily_finance.PYTHON, "-m", "pipeline.run", "finance", "--mode", "news"]]


def test_pipeline_run_can_start_as_module():
    root = Path(__file__).resolve().parents[2]
    env = {key: value for key, value in os.environ.items() if key != "PYTHONPATH"}

    result = subprocess.run(
        [sys.executable, "-m", "pipeline.run", "--help"],
        cwd=root,
        env=env,
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, result.stderr
    assert "Generate daily blog reports" in result.stdout
