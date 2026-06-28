from __future__ import annotations

import argparse
import os
import subprocess
import sys
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parent.parent
PYTHON = sys.executable


@dataclass
class RunResult:
    returncode: int


Runner = Callable[..., RunResult]


def run_daily_finance(
    *,
    root: Path = ROOT,
    run_date: date | None = None,
    with_audio: bool = True,
    publish: bool = True,
    force: bool = False,
    input_path: Path | None = None,
    min_items: int | None = None,
    hours: int | None = None,
    voice: str | None = None,
    runner: Runner = subprocess.run,
) -> int:
    return run_daily_briefing(
        topic="finance",
        root=root,
        run_date=run_date,
        with_audio=with_audio,
        publish=publish,
        force=force,
        input_path=input_path,
        min_items=min_items,
        hours=hours,
        voice=voice,
        runner=runner,
    )


def run_daily_briefing(
    *,
    topic: str,
    root: Path = ROOT,
    run_date: date | None = None,
    with_audio: bool = True,
    publish: bool = True,
    force: bool = False,
    input_path: Path | None = None,
    min_items: int | None = None,
    hours: int | None = None,
    voice: str | None = None,
    default_voice: str | None = None,
    runner: Runner = subprocess.run,
) -> int:
    run_date = run_date or date.today()
    log_dir = root / "pipeline" / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_path = log_dir / f"{topic}-{run_date:%Y%m%d}.log"
    lock_path = log_dir / f"{topic}-{run_date:%Y%m%d}.lock"

    try:
        lock_fd = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        with log_path.open("a", encoding="utf-8") as log:
            log.write(f"[{_now()}] already running: {lock_path.name}\n")
        return 2

    try:
        with os.fdopen(lock_fd, "w", encoding="utf-8") as lock:
            lock.write(f"pid={os.getpid()}\nstarted={_now()}\n")

        cmd = _build_command(
            topic=topic,
            python=resolve_python(root),
            with_audio=with_audio,
            publish=publish,
            force=force,
            input_path=input_path,
            min_items=min_items,
            hours=hours,
            voice=voice or default_voice,
        )
        with log_path.open("a", encoding="utf-8") as log:
            log.write(f"[{_now()}] start: {' '.join(str(part) for part in cmd)}\n")
            try:
                result = runner(cmd, cwd=root, stdout=log, stderr=log, text=True)
            except Exception as exc:
                log.write(f"[{_now()}] failed: {exc}\n")
                return 1
            log.write(f"[{_now()}] exit: {result.returncode}\n")
            return int(result.returncode)
    finally:
        lock_path.unlink(missing_ok=True)


def _build_command(
    *,
    topic: str = "finance",
    python: str = PYTHON,
    with_audio: bool,
    publish: bool,
    force: bool,
    input_path: Path | None,
    min_items: int | None,
    hours: int | None,
    voice: str | None,
) -> list[str]:
    cmd = [python, "-m", "pipeline.run", topic, "--mode", "news"]
    if input_path:
        cmd.extend(["--input", str(input_path)])
    if with_audio:
        cmd.append("--with-audio")
    if publish:
        cmd.append("--publish")
    if force:
        cmd.append("--force")
    if min_items is not None:
        cmd.extend(["--min-items", str(min_items)])
    if hours is not None:
        cmd.extend(["--hours", str(hours)])
    if voice:
        cmd.extend(["--voice", voice])
    return cmd


def resolve_python(root: Path = ROOT) -> str:
    project_python = root / "backend" / ".venv" / "bin" / "python"
    if project_python.exists():
        return str(project_python)
    return PYTHON


def _now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the scheduled finance morning briefing")
    parser.add_argument("--date", help="Run date in YYYY-MM-DD, used for log and lock names")
    parser.add_argument("--input", type=Path, help="OpenClaw JSON input path")
    parser.add_argument("--no-audio", action="store_true", help="Skip MiniMax TTS generation")
    parser.add_argument("--no-publish", action="store_true", help="Generate files without git commit/push")
    parser.add_argument("--force", action="store_true", help="Overwrite today's briefing if it already exists")
    parser.add_argument("--min-items", type=int, help="Minimum effective news items required")
    parser.add_argument("--hours", type=int, help="News recency window")
    parser.add_argument("--voice", help="MiniMax TTS voice id, e.g. presenter_female")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    run_date = date.fromisoformat(args.date) if args.date else None
    return run_daily_finance(
        run_date=run_date,
        input_path=args.input,
        with_audio=not args.no_audio,
        publish=not args.no_publish,
        force=args.force,
        min_items=args.min_items,
        hours=args.hours,
        voice=args.voice,
    )


if __name__ == "__main__":
    raise SystemExit(main())
