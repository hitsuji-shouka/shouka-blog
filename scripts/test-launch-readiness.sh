#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
LOG_FILE="$TMP_DIR/commands.log"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/scripts"
cp "$ROOT_DIR/scripts/check-launch-readiness.sh" "$TMP_DIR/scripts/check-launch-readiness.sh"

cat > "$TMP_DIR/scripts/verify-release.sh" <<'MOCK'
#!/usr/bin/env bash
echo "verify-release" >> "$LAUNCH_READINESS_LOG"
MOCK

cat > "$TMP_DIR/scripts/deploy-preflight.sh" <<'MOCK'
#!/usr/bin/env bash
echo "deploy-preflight $*" >> "$LAUNCH_READINESS_LOG"
MOCK

cat > "$TMP_DIR/scripts/check-github-secrets.sh" <<'MOCK'
#!/usr/bin/env bash
echo "check-github-secrets $*" >> "$LAUNCH_READINESS_LOG"
MOCK

cat > "$TMP_DIR/scripts/check-remote-server.sh" <<'MOCK'
#!/usr/bin/env bash
echo "check-remote-server $*" >> "$LAUNCH_READINESS_LOG"
MOCK

cat > "$TMP_DIR/scripts/verify-public-site.sh" <<'MOCK'
#!/usr/bin/env bash
echo "verify-public-site EXPECTED_APP_VERSION=${EXPECTED_APP_VERSION:-} EXPECT_CADDY_HEADERS=${EXPECT_CADDY_HEADERS:-} $*" >> "$LAUNCH_READINESS_LOG"
MOCK

cat > "$TMP_DIR/scripts/check-frontend-render.sh" <<'MOCK'
#!/usr/bin/env bash
echo "check-frontend-render $*" >> "$LAUNCH_READINESS_LOG"
MOCK

chmod +x "$TMP_DIR"/scripts/*.sh

expect_log_contains() {
  local pattern="$1"
  if grep -Fq "$pattern" "$LOG_FILE"; then
    echo "OK: launch readiness log contains $pattern"
  else
    echo "FAIL: launch readiness log missing $pattern" >&2
    cat "$LOG_FILE" >&2
    exit 1
  fi
}

: > "$LOG_FILE"
LAUNCH_READINESS_LOG="$LOG_FILE" bash "$TMP_DIR/scripts/check-launch-readiness.sh" \
  --skip-release \
  --skip-preflight \
  --site-origin https://blog.example.com \
  --expected-version abc123 \
  --expect-caddy-headers >/dev/null

expect_log_contains "verify-public-site EXPECTED_APP_VERSION=abc123 EXPECT_CADDY_HEADERS=1 https://blog.example.com"
expect_log_contains "check-frontend-render https://blog.example.com"

: > "$LOG_FILE"
LAUNCH_READINESS_LOG="$LOG_FILE" bash "$TMP_DIR/scripts/check-launch-readiness.sh" \
  --skip-release \
  --skip-preflight \
  --site-origin https://blog.example.com >/dev/null

expect_log_contains "verify-public-site EXPECTED_APP_VERSION= EXPECT_CADDY_HEADERS= https://blog.example.com"

: > "$LOG_FILE"
LAUNCH_READINESS_LOG="$LOG_FILE" bash "$TMP_DIR/scripts/check-launch-readiness.sh" \
  --skip-release \
  --skip-preflight \
  --skip-public \
  --github-secrets \
  --require-deploy-env >/dev/null

expect_log_contains "check-github-secrets --require-deploy-env"

: > "$LOG_FILE"
LAUNCH_READINESS_LOG="$LOG_FILE" bash "$TMP_DIR/scripts/check-launch-readiness.sh" \
  --skip-release \
  --skip-public \
  --remote-server \
  --domain-routing \
  --pull-images \
  --check-ports \
  --observability >/dev/null

if grep -Fq "deploy-preflight" "$LOG_FILE"; then
  echo "FAIL: launch readiness should skip local preflight when .env is missing and --remote-server is enabled" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi
expect_log_contains "check-remote-server --domain-routing --pull-images --observability --check-ports"

echo "Launch readiness tests complete."
