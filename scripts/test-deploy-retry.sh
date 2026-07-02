#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
LOG_FILE="$TMP_DIR/deploy.log"

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

expect_count() {
  local pattern="$1"
  local expected="$2"
  local actual
  actual="$(grep -Fc "$pattern" "$LOG_FILE" || true)"
  [[ "$actual" == "$expected" ]] || fail "expected '$pattern' $expected times, got $actual"
  echo "OK: '$pattern' appears $expected times"
}

expect_no_log() {
  local pattern="$1"
  if grep -Fq "$pattern" "$LOG_FILE"; then
    fail "deploy log should not contain: $pattern"
  fi
  echo "OK: deploy log omits $pattern"
}

mkdir -p "$TMP_DIR/scripts" "$TMP_DIR/bin"
cp "$ROOT_DIR/scripts/deploy.sh" "$TMP_DIR/scripts/deploy.sh"
chmod +x "$TMP_DIR/scripts/deploy.sh"

cat > "$TMP_DIR/.env" <<'ENV'
SITE_DOMAIN=blog.example.com
BLOG_DEEPSEEK_KEY=
BLOG_EMBED_KEY=
ENV

cat > "$TMP_DIR/scripts/deploy-preflight.sh" <<'SH'
#!/usr/bin/env bash
echo "preflight $*"
SH

cat > "$TMP_DIR/scripts/verify-public-site.sh" <<'SH'
#!/usr/bin/env bash
echo "verify-public-site $*"
exit 1
SH

chmod +x "$TMP_DIR"/scripts/*.sh

cat > "$TMP_DIR/bin/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "docker $*"
exit 0
SH

cat > "$TMP_DIR/bin/sleep" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "sleep $*"
SH

chmod +x "$TMP_DIR"/bin/*

if PATH="$TMP_DIR/bin:$PATH" APP_VERSION=retry-test bash "$TMP_DIR/scripts/deploy.sh" > "$LOG_FILE" 2>&1; then
  fail "deploy should fail when public verification never succeeds"
fi

expect_count "verify-public-site https://blog.example.com" 6
expect_count "sleep 10" 5
expect_no_log "Public verification attempt 6 failed; retrying in 10s..."
grep -Fq "FAIL: public site verification failed: https://blog.example.com" "$LOG_FILE" || fail "missing final verification failure"
echo "OK: deploy reports final public verification failure"

echo "Deploy retry tests complete."
