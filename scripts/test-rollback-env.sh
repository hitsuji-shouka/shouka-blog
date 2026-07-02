#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
LOG_FILE="$TMP_DIR/rollback.log"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  if [[ -f "$LOG_FILE" ]]; then
    cat "$LOG_FILE" >&2
  fi
  exit 1
}

expect_log() {
  local pattern="$1"
  grep -Fq "$pattern" "$LOG_FILE" || fail "rollback log missing: $pattern"
  echo "OK: rollback log contains $pattern"
}

mkdir -p "$TMP_DIR/scripts" "$TMP_DIR/bin"
cp "$ROOT_DIR/scripts/rollback-env.sh" "$TMP_DIR/scripts/rollback-env.sh"
chmod +x "$TMP_DIR/scripts/rollback-env.sh"

cat > "$TMP_DIR/.env" <<'ENV'
SITE_DOMAIN=broken.example.com
BLOG_DEEPSEEK_KEY=broken-key
ENV

cat > "$TMP_DIR/.env.previous" <<'ENV'
SITE_DOMAIN=blog.example.com
BLOG_DEEPSEEK_KEY=previous-key
ENV

cat > "$TMP_DIR/scripts/verify-public-site.sh" <<'SH'
#!/usr/bin/env bash
echo "verify-public-site $*" >> "$ROLLBACK_LOG"
SH

cat > "$TMP_DIR/scripts/check-frontend-render.sh" <<'SH'
#!/usr/bin/env bash
echo "check-frontend-render $*" >> "$ROLLBACK_LOG"
SH

chmod +x "$TMP_DIR"/scripts/*.sh

cat > "$TMP_DIR/bin/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "docker $*" >> "$ROLLBACK_LOG"
SH

chmod +x "$TMP_DIR/bin/docker"

PATH="$TMP_DIR/bin:$PATH" ROLLBACK_LOG="$LOG_FILE" bash "$TMP_DIR/scripts/rollback-env.sh" --browser-check > "$TMP_DIR/stdout"

grep -Fq "SITE_DOMAIN=blog.example.com" "$TMP_DIR/.env" || fail ".env was not restored from .env.previous"
grep -Fq "SITE_DOMAIN=broken.example.com" "$TMP_DIR/.env.rollback-current" || fail "current .env backup was not written"
expect_log "docker compose up -d --build"
expect_log "docker compose ps"
expect_log "verify-public-site https://blog.example.com"
expect_log "check-frontend-render https://blog.example.com"

echo "Rollback env tests complete."
