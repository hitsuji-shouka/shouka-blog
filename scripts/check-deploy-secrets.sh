#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require_env() {
  local key="$1"
  local value="${!key:-}"
  [[ -n "$value" ]] || fail "$key is required"
}

require_env DEPLOY_HOST
require_env DEPLOY_PATH
require_env DEPLOY_SSH_KEY
require_env DEPLOY_USER

validate_deploy_host() {
  local host="$1"
  local label octet

  if [[ "$host" == *"://"* || "$host" == */* || "$host" =~ [[:space:]] ]]; then
    fail "DEPLOY_HOST must be a hostname or IP address, not a URL or path"
  fi

  if [[ ! "$host" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]]; then
    fail "DEPLOY_HOST may only contain letters, numbers, dots, and hyphens"
  fi

  [[ "$host" != .* && "$host" != *. ]] || fail "DEPLOY_HOST must not start or end with a dot"
  [[ "$host" != *..* ]] || fail "DEPLOY_HOST must not contain empty labels"

  if [[ "$host" =~ ^[0-9]+(\.[0-9]+){3}$ ]]; then
    IFS='.' read -r -a labels <<< "$host"
    for octet in "${labels[@]}"; do
      [[ "$octet" -ge 0 && "$octet" -le 255 ]] || fail "DEPLOY_HOST IPv4 octets must be between 0 and 255"
    done
    return
  fi

  IFS='.' read -r -a labels <<< "$host"
  for label in "${labels[@]}"; do
    [[ ${#label} -le 63 ]] || fail "DEPLOY_HOST labels must be 1-63 characters"
    [[ "$label" != -* && "$label" != *- ]] || fail "DEPLOY_HOST labels must not start or end with '-'"
  done
}

validate_deploy_host "$DEPLOY_HOST"

if [[ ! "$DEPLOY_USER" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ ]]; then
  fail "DEPLOY_USER may only contain letters, numbers, dots, underscores, and hyphens"
fi

case "$DEPLOY_PATH" in
  /*) ;;
  *) fail "DEPLOY_PATH must be an absolute path" ;;
esac

if [[ "$DEPLOY_PATH" == "/" ]]; then
  fail "DEPLOY_PATH must not be /"
fi

if [[ ! "$DEPLOY_PATH" =~ ^/[A-Za-z0-9._/-]+$ ]]; then
  fail "DEPLOY_PATH may only contain letters, numbers, slash, dot, underscore, and hyphen"
fi

if [[ -n "${DEPLOY_PORT:-}" && ! "$DEPLOY_PORT" =~ ^[0-9]+$ ]]; then
  fail "DEPLOY_PORT must be numeric"
fi

if [[ -n "${DEPLOY_PORT:-}" && ( "$DEPLOY_PORT" -lt 1 || "$DEPLOY_PORT" -gt 65535 ) ]]; then
  fail "DEPLOY_PORT must be between 1 and 65535"
fi

KEY_FILE="$(mktemp)"
cleanup() {
  rm -f "$KEY_FILE"
}
trap cleanup EXIT

printf '%s\n' "$DEPLOY_SSH_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"
ssh-keygen -y -f "$KEY_FILE" >/dev/null || fail "DEPLOY_SSH_KEY must be a parseable private SSH key"

echo "OK: deploy secrets are valid"
