#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage: scripts/check-frontend-render.sh ORIGIN

Runs a real Chromium render check against the production frontend:
  - desktop homepage hero and writing sections render
  - nav anchors update the URL hash
  - Agent launcher is visible
  - mobile viewport has no horizontal overflow

Environment:
  SCREENSHOT_DIR  Optional directory for desktop/mobile screenshots
USAGE
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

ORIGIN="${1%/}"
if [[ "$ORIGIN" != http://* && "$ORIGIN" != https://* ]]; then
  echo "FAIL: origin must start with http:// or https://" >&2
  exit 1
fi

cd "$ROOT_DIR/frontend"
node scripts/check-render.mjs "$ORIGIN"
