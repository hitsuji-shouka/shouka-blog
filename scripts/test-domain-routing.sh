#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_SCRIPT="$ROOT_DIR/scripts/check-domain-routing.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

RESOLVER="$TMP_DIR/resolve"
cat > "$RESOLVER" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  blog.example.com) echo "203.0.113.10" ;;
  deploy.example.com) echo "203.0.113.10" ;;
  other.example.com) echo "203.0.113.20" ;;
  multi.example.com) echo "203.0.113.30 203.0.113.10" ;;
  *) exit 1 ;;
esac
MOCK
chmod +x "$RESOLVER"

ENV_FILE="$TMP_DIR/.env"
printf '%s\n' 'SITE_DOMAIN=blog.example.com' > "$ENV_FILE"

run_check() {
  env DNS_LOOKUP_CMD="$RESOLVER" "$CHECK_SCRIPT" "$@"
}

expect_pass() {
  local name="$1"
  shift
  if "$@" >/dev/null; then
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

expect_pass "domain matches deploy host" run_check --env-file "$ENV_FILE" --expected-host deploy.example.com
expect_pass "domain contains expected IP" run_check --site-domain multi.example.com --expected-host 203.0.113.10
expect_fail "domain mismatch rejected" run_check --env-file "$ENV_FILE" --expected-host other.example.com
expect_fail "missing site domain rejected" run_check --expected-host deploy.example.com
expect_fail "unresolvable deploy host rejected" run_check --env-file "$ENV_FILE" --expected-host missing.example.com
expect_fail "site domain URL rejected" run_check --site-domain https://blog.example.com --expected-host https://blog.example.com
expect_fail "site domain IP rejected" run_check --site-domain 203.0.113.10 --expected-host 203.0.113.10
expect_fail "expected host URL rejected" run_check --site-domain blog.example.com --expected-host https://blog.example.com

DEPLOY_ENV_VALUE=$'SITE_DOMAIN=blog.example.com\nBLOG_DEEPSEEK_KEY='
expect_pass "DEPLOY_ENV site domain supported" env DEPLOY_ENV="$DEPLOY_ENV_VALUE" DNS_LOOKUP_CMD="$RESOLVER" "$CHECK_SCRIPT" --expected-host deploy.example.com

echo "Domain routing tests complete."
