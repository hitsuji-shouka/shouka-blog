#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_SCRIPT="$ROOT_DIR/scripts/check-deploy-secrets.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

KEY_FILE="$TMP_DIR/deploy_key"
ssh-keygen -q -t ed25519 -N '' -f "$KEY_FILE" >/dev/null
VALID_KEY="$(cat "$KEY_FILE")"

run_check_with() {
  local host="${1:-deploy.example.com}"
  local user="${2:-deploy_user}"
  local path="${3:-/srv/shouka-blog}"
  local port="${4:-22}"
  local key="${5:-$VALID_KEY}"

  env \
    DEPLOY_HOST="$host" \
    DEPLOY_USER="$user" \
    DEPLOY_PATH="$path" \
    DEPLOY_SSH_KEY="$key" \
    DEPLOY_PORT="$port" \
    "$CHECK_SCRIPT" >/dev/null
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

expect_pass "valid deploy secrets" run_check_with
expect_fail "host URL rejected" run_check_with "https://deploy.example.com"
expect_fail "host path rejected" run_check_with "deploy.example.com/app"
expect_fail "host empty label rejected" run_check_with "deploy..example.com"
expect_fail "host trailing dot rejected" run_check_with "deploy.example.com."
expect_fail "host hyphen label edge rejected" run_check_with "deploy.example-.com"
expect_fail "host invalid IPv4 rejected" run_check_with "999.0.0.1"
expect_fail "unsafe user rejected" run_check_with "deploy.example.com" "-deploy"
expect_fail "unsafe path rejected" run_check_with "deploy.example.com" "deploy_user" "/srv/shouka blog"
expect_fail "root path rejected" run_check_with "deploy.example.com" "deploy_user" "/"
expect_fail "bad port rejected" run_check_with "deploy.example.com" "deploy_user" "/srv/shouka-blog" "70000"
expect_fail "public key rejected" run_check_with "deploy.example.com" "deploy_user" "/srv/shouka-blog" "22" "$(cat "$KEY_FILE.pub")"

echo "Deploy secret validation tests complete."
