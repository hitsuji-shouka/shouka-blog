from pathlib import Path

from publish import publish


def test_publish_skips_empty_paths():
    calls = []

    assert publish([], "msg", runner=lambda *args, **kwargs: calls.append(args)) is False
    assert calls == []


def test_publish_adds_commits_and_pushes_existing_paths(tmp_path):
    a = tmp_path / "a.md"
    missing = tmp_path / "missing.md"
    a.write_text("x", encoding="utf-8")
    calls = []

    def fake_runner(cmd, check):
        calls.append((cmd, check))

    assert publish([a, missing], "daily", push=True, runner=fake_runner) is True

    assert calls == [
        (["git", "add", "-f", str(a)], True),
        (["git", "commit", "-m", "daily"], True),
        (["git", "push"], True),
    ]


def test_publish_can_skip_push(tmp_path):
    a = tmp_path / "a.md"
    a.write_text("x", encoding="utf-8")
    calls = []

    publish([a], "daily", push=False, runner=lambda cmd, check: calls.append(cmd))

    assert calls == [["git", "add", "-f", str(a)], ["git", "commit", "-m", "daily"]]
