#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_SCRIPT="$ROOT_DIR/scripts/check-remote-server.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

KEY_FILE="$TMP_DIR/deploy_key"
ssh-keygen -q -t ed25519 -N '' -f "$KEY_FILE" >/dev/null
VALID_KEY="$(cat "$KEY_FILE")"

MOCK_BIN="$TMP_DIR/bin"
LOG_FILE="$TMP_DIR/commands.log"
mkdir -p "$MOCK_BIN"

cat > "$MOCK_BIN/rsync" <<'MOCK'
#!/usr/bin/env bash
echo "rsync $*" >> "$REMOTE_CHECK_LOG"
exit 0
MOCK

cat > "$MOCK_BIN/ssh" <<'MOCK'
#!/usr/bin/env bash
echo "ssh $*" >> "$REMOTE_CHECK_LOG"
case "$*" in
  *"ss -ltn"*)
    if [[ "${REMOTE_PORTS_BUSY:-}" == "1" ]]; then
      echo "LISTEN 0 4096 0.0.0.0:80 0.0.0.0:*" >&2
      exit 1
    fi
    ;;
  *"cat '"*) printf '%s\n' "${REMOTE_ENV_CONTENT:-}" ;;
  *"SITE_DOMAIN="*) echo "blog.example.com" ;;
  *"fail-deps"*) exit 1 ;;
  *) exit 0 ;;
esac
MOCK

cat > "$MOCK_BIN/resolve" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  blog.example.com) echo "203.0.113.10" ;;
  deploy.example.com) echo "203.0.113.10" ;;
  *) exit 1 ;;
esac
MOCK

chmod +x "$MOCK_BIN/rsync" "$MOCK_BIN/ssh" "$MOCK_BIN/resolve"

run_check() {
  local path="${1:-/srv/shouka-blog}"
  local env_value="${2:-}"
  shift $(( $# > 0 ? 1 : 0 ))
  shift $(( $# > 0 ? 1 : 0 ))

  : > "$LOG_FILE"
  env \
    PATH="$MOCK_BIN:$PATH" \
    REMOTE_CHECK_LOG="$LOG_FILE" \
    DEPLOY_HOST="deploy.example.com" \
    DEPLOY_USER="deploy_user" \
    DEPLOY_PATH="$path" \
    DEPLOY_SSH_KEY="$VALID_KEY" \
    DEPLOY_PORT="22" \
    DEPLOY_ENV="$env_value" \
    DNS_LOOKUP_CMD="$MOCK_BIN/resolve" \
    "$CHECK_SCRIPT" "$@" >/dev/null
}

run_check_with_remote_env() {
  local remote_env="$1"
  shift

  : > "$LOG_FILE"
  env \
    PATH="$MOCK_BIN:$PATH" \
    REMOTE_CHECK_LOG="$LOG_FILE" \
    REMOTE_ENV_CONTENT="$remote_env" \
    DEPLOY_HOST="deploy.example.com" \
    DEPLOY_USER="deploy_user" \
    DEPLOY_PATH="/srv/shouka-blog" \
    DEPLOY_SSH_KEY="$VALID_KEY" \
    DEPLOY_PORT="22" \
    DEPLOY_ENV="" \
    DNS_LOOKUP_CMD="$MOCK_BIN/resolve" \
    "$CHECK_SCRIPT" "$@" >/dev/null
}

run_check_with_port_state() {
  local busy="$1"
  shift

  : > "$LOG_FILE"
  env \
    PATH="$MOCK_BIN:$PATH" \
    REMOTE_CHECK_LOG="$LOG_FILE" \
    REMOTE_PORTS_BUSY="$busy" \
    DEPLOY_HOST="deploy.example.com" \
    DEPLOY_USER="deploy_user" \
    DEPLOY_PATH="/srv/shouka-blog" \
    DEPLOY_SSH_KEY="$VALID_KEY" \
    DEPLOY_PORT="22" \
    DEPLOY_ENV="$VALID_DEPLOY_ENV" \
    DNS_LOOKUP_CMD="$MOCK_BIN/resolve" \
    "$CHECK_SCRIPT" "$@" >/dev/null
}

expect_pass() {
  local name="$1"
  shift
  if "$@"; then
    echo "OK: $name"
  else
    echo "FAIL: $name" >&2
    exit 1
  fi
}

expect_fail() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>/dev/null; then
    echo "FAIL: $name" >&2
    exit 1
  else
    echo "OK: $name"
  fi
}

expect_log_contains() {
  local pattern="$1"
  if grep -q "$pattern" "$LOG_FILE"; then
    echo "OK: log contains $pattern"
  else
    echo "FAIL: log missing $pattern" >&2
    cat "$LOG_FILE" >&2
    exit 1
  fi
}

expect_pass "remote server check with existing .env" run_check
expect_log_contains "command -v rsync"
expect_log_contains "mkdir -p '/srv/shouka-blog'"
expect_log_contains "docker compose version"
expect_log_contains "test -f '/srv/shouka-blog/.env'"

VALID_DEPLOY_ENV=$'SITE_DOMAIN=example.com\nBLOG_DEEPSEEK_KEY=\nBLOG_EMBED_KEY=\nLANGFUSE_PUBLIC_KEY='
VALID_OBSERVABILITY_DEPLOY_ENV=$'SITE_DOMAIN=shouka.blog\nBLOG_DEEPSEEK_KEY=\nBLOG_EMBED_KEY=\nLANGFUSE_DB_PASSWORD=prod-db-password\nLANGFUSE_NEXTAUTH_SECRET=prod-nextauth-secret\nLANGFUSE_SALT=prod-salt\nLANGFUSE_NEXTAUTH_URL=https://trace.shouka.blog\nLANGFUSE_INIT_PROJECT_PUBLIC_KEY=pk-lf-prod\nLANGFUSE_INIT_PROJECT_SECRET_KEY=sk-lf-prod\nLANGFUSE_INIT_USER_EMAIL=ops@shouka.blog\nLANGFUSE_INIT_USER_PASSWORD=prod-admin-password'
expect_pass "remote server check with provided DEPLOY_ENV" run_check "/srv/shouka-blog" "$VALID_DEPLOY_ENV"
if grep -q "test -f '/srv/shouka-blog/.env'" "$LOG_FILE"; then
  echo "FAIL: provided DEPLOY_ENV should skip remote .env existence check" >&2
  exit 1
fi
echo "OK: provided DEPLOY_ENV skips remote .env existence check"

LEAK_DIR="$TMP_DIR/leak-check"
mkdir -p "$LEAK_DIR"
INVALID_DEPLOY_ENV=$'SITE_DOMAIN=blog.example.com\nBLOG_DEEPSEEK_KEY=prod-secret'
expect_fail "invalid DEPLOY_ENV rejected without temp file leak" env \
  PATH="$MOCK_BIN:$PATH" \
  TMPDIR="$LEAK_DIR" \
  REMOTE_CHECK_LOG="$LOG_FILE" \
  DEPLOY_HOST="deploy.example.com" \
  DEPLOY_USER="deploy_user" \
  DEPLOY_PATH="/srv/shouka-blog" \
  DEPLOY_SSH_KEY="$VALID_KEY" \
  DEPLOY_PORT="22" \
  DEPLOY_ENV="$INVALID_DEPLOY_ENV" \
  DNS_LOOKUP_CMD="$MOCK_BIN/resolve" \
  "$CHECK_SCRIPT"
if find "$LEAK_DIR" -type f -print -quit | grep -q .; then
  echo "FAIL: invalid DEPLOY_ENV left temporary files behind" >&2
  exit 1
fi
echo "OK: invalid DEPLOY_ENV leaves no temporary files"

expect_fail "remote dependency failure rejected" run_check "/srv/fail-deps"
expect_pass "remote Docker image pulls" run_check "/srv/shouka-blog" "" --pull-images
expect_log_contains "docker pull node:22-slim"
expect_log_contains "docker pull python:3.12-slim"
expect_log_contains "docker pull caddy:2"
expect_pass "free remote web ports accepted" run_check_with_port_state 0 --check-ports
expect_log_contains "ss -ltn"
expect_fail "busy remote web ports rejected" run_check_with_port_state 1 --check-ports
expect_fail "observability DEPLOY_ENV requires bootstrap secrets" run_check "/srv/shouka-blog" "$VALID_DEPLOY_ENV" --observability
expect_pass "remote observability image pulls" run_check "/srv/shouka-blog" "$VALID_OBSERVABILITY_DEPLOY_ENV" --pull-images --observability
expect_log_contains "docker pull postgres:16"
expect_log_contains "docker pull langfuse/langfuse:2"
expect_fail "remote observability .env requires bootstrap secrets" run_check_with_remote_env "$VALID_DEPLOY_ENV" --observability
expect_pass "remote observability .env is validated" run_check_with_remote_env "$VALID_OBSERVABILITY_DEPLOY_ENV" --observability
expect_pass "remote env domain routing check" run_check "/srv/shouka-blog" "" --domain-routing
expect_log_contains "SITE_DOMAIN="

echo "Remote server check tests complete."
