#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_SCRIPT="$ROOT_DIR/scripts/check-github-secrets.sh"
TMP_DIR="$(mktemp -d)"
LOG_FILE="$TMP_DIR/gh.log"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "gh $*" >> "$GH_SECRET_TEST_LOG"
printf '%s\n' "$GH_SECRET_TEST_NAMES"
SH
chmod +x "$TMP_DIR/gh"

run_check_with() {
  local names="$1"
  shift
  env \
    PATH="$TMP_DIR:$PATH" \
    GH_SECRET_TEST_LOG="$LOG_FILE" \
    GH_SECRET_TEST_NAMES="$names" \
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

expect_fail_output_contains() {
  local name="$1"
  local pattern="$2"
  shift 2
  local output
  if output="$("$@" 2>&1 >/dev/null)"; then
    echo "FAIL: $name" >&2
    exit 1
  fi
  if grep -Fq "$pattern" <<< "$output"; then
    echo "OK: $name"
  else
    echo "FAIL: $name" >&2
    echo "$output" >&2
    exit 1
  fi
}

REQUIRED_SECRETS=$'DEPLOY_HOST\nDEPLOY_USER\nDEPLOY_PATH\nDEPLOY_SSH_KEY'
ALL_SECRETS=$'DEPLOY_HOST\nDEPLOY_USER\nDEPLOY_PATH\nDEPLOY_SSH_KEY\nDEPLOY_PORT\nDEPLOY_ENV'

expect_pass "required GitHub secrets present" run_check_with "$REQUIRED_SECRETS"
expect_fail "missing DEPLOY_SSH_KEY rejected" run_check_with $'DEPLOY_HOST\nDEPLOY_USER\nDEPLOY_PATH'
expect_fail "required DEPLOY_ENV rejected when missing" run_check_with "$REQUIRED_SECRETS" --require-deploy-env
expect_pass "DEPLOY_ENV accepted when explicitly required" run_check_with "$ALL_SECRETS" --require-deploy-env
expect_fail_output_contains "missing gh explains manual setup path" "scripts/print-github-secrets-commands.sh" env PATH="/usr/bin:/bin" "$CHECK_SCRIPT"
expect_fail_output_contains "missing gh points to GitHub web secrets page" "Settings > Secrets and variables > Actions" env PATH="/usr/bin:/bin" "$CHECK_SCRIPT"

grep -Fq "gh secret list --json name --jq .[].name" "$LOG_FILE" || {
  echo "FAIL: gh secret list was not called with JSON name query" >&2
  cat "$LOG_FILE" >&2
  exit 1
}
echo "OK: GitHub secrets check uses gh secret list"

echo "GitHub secrets tests complete."
