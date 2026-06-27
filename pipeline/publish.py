from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Callable, Iterable


Runner = Callable[[list[str]], object]


def publish(
    paths: Iterable[Path],
    message: str,
    push: bool = True,
    runner: Callable[..., object] = subprocess.run,
) -> bool:
    existing = [Path(path) for path in paths if Path(path).exists()]
    if not existing:
        return False
    for path in existing:
        runner(["git", "add", str(path)], check=True)
    runner(["git", "commit", "-m", message], check=True)
    if push:
        runner(["git", "push"], check=True)
    return True
