#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/frontend/dist"
MAX_JS_BYTES="${MAX_JS_BYTES:-512000}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -d "$DIST_DIR/assets" ]] || fail "missing frontend/dist/assets; run npm --prefix frontend run build first"

found=false
while IFS= read -r -d '' file; do
  found=true
  size="$(wc -c < "$file" | tr -d ' ')"
  name="${file#$DIST_DIR/}"
  if (( size > MAX_JS_BYTES )); then
    fail "$name is ${size} bytes; max allowed is ${MAX_JS_BYTES} bytes"
  fi
  echo "OK: $name is ${size} bytes"
done < <(find "$DIST_DIR/assets" -type f -name '*.js' -print0)

[[ "$found" == true ]] || fail "no JavaScript bundles found in frontend/dist/assets"
echo "Frontend bundle size check complete."
