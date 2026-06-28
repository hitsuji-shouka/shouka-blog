from __future__ import annotations

import argparse
from datetime import date
from pathlib import Path

try:
    from .daily_finance import PYTHON, RunResult, run_daily_briefing
except ImportError:
    from daily_finance import PYTHON, RunResult, run_daily_briefing

TECH_VOICE = "Chinese_radio_reporter_nv1"
TECH_MIN_ITEMS = 3
TECH_HOURS = 72


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the scheduled tech morning briefing")
    parser.add_argument("--date", help="Run date in YYYY-MM-DD, used for log and lock names")
    parser.add_argument("--input", type=Path, help="OpenClaw JSON input path")
    parser.add_argument("--no-audio", action="store_true", help="Skip MiniMax TTS generation")
    parser.add_argument("--no-publish", action="store_true", help="Generate files without git commit/push")
    parser.add_argument("--force", action="store_true", help="Overwrite today's briefing if it already exists")
    parser.add_argument("--min-items", type=int, help="Minimum effective news items required")
    parser.add_argument("--hours", type=int, help="News recency window")
    parser.add_argument("--voice", default=TECH_VOICE, help="MiniMax TTS voice id")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    run_date = date.fromisoformat(args.date) if args.date else None
    return run_daily_tech(
        run_date=run_date,
        input_path=args.input,
        with_audio=not args.no_audio,
        publish=not args.no_publish,
        force=args.force,
        min_items=args.min_items,
        hours=args.hours,
        voice=args.voice,
    )


def run_daily_tech(
    *,
    root: Path | None = None,
    run_date: date | None = None,
    with_audio: bool = True,
    publish: bool = True,
    force: bool = False,
    input_path: Path | None = None,
    min_items: int | None = None,
    hours: int | None = None,
    voice: str | None = TECH_VOICE,
    runner=None,
) -> int:
    kwargs = {}
    if root is not None:
        kwargs["root"] = root
    if runner is not None:
        kwargs["runner"] = runner
    return run_daily_briefing(
        topic="tech",
        **kwargs,
        run_date=run_date,
        input_path=input_path,
        with_audio=with_audio,
        publish=publish,
        force=force,
        min_items=min_items if min_items is not None else TECH_MIN_ITEMS,
        hours=hours if hours is not None else TECH_HOURS,
        voice=voice,
    )


if __name__ == "__main__":
    raise SystemExit(main())
