#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".env"
SKIP_DNS=false
WITH_OBSERVABILITY=false

usage() {
  cat <<'USAGE'
Usage: scripts/check-env-file.sh [--file PATH] [--observability] [--skip-dns]

Validates a production .env file without printing secret values.

Checks:
  - SITE_DOMAIN is set to a bare real domain
  - optional Agent and tracing keys are either empty or not placeholders
  - observability mode has required Langfuse bootstrap values
  - SITE_DOMAIN resolves in DNS unless --skip-dns is passed
USAGE
}

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "OK: $*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      [[ $# -ge 2 ]] || fail "--file requires a value"
      ENV_FILE="$2"
      shift 2
      ;;
    --observability)
      WITH_OBSERVABILITY=true
      shift
      ;;
    --skip-dns)
      SKIP_DNS=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ -f "$ENV_FILE" ]] || fail "missing env file: $ENV_FILE"

read_env_value() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 == key {
      sub(/^[^=]*=/, "")
      gsub(/^["'\'' ]+|["'\'' ]+$/, "")
      gsub(/\r$/, "")
      print
      exit
    }
  ' "$ENV_FILE"
}

is_placeholder_value() {
  local value="$1"
  case "$value" in
    ""|"-") return 1 ;;
    *example.com*|*replace-with*|*replace-me*|your-*|changeme|change-me|password|secret) return 0 ;;
    *) return 1 ;;
  esac
}

need_non_placeholder_if_set() {
  local key="$1"
  local value
  value="$(read_env_value "$key")"
  if is_placeholder_value "$value"; then
    fail "$key still contains a placeholder value"
  fi
  if [[ -n "$value" ]]; then
    pass "$key is set and not a placeholder"
  else
    echo "SKIP: $key is empty"
  fi
}

need_required_secret() {
  local key="$1"
  local value
  value="$(read_env_value "$key")"
  if [[ -z "$value" ]]; then
    fail "$key is required when --observability is enabled"
  fi
  if is_placeholder_value "$value"; then
    fail "$key still contains a placeholder value"
  fi
  pass "$key is set and not a placeholder"
}

resolve_domain() {
  local domain="$1"
  local result=""

  if command -v getent >/dev/null 2>&1; then
    result="$(getent ahosts "$domain" 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ' || true)"
    if [[ -n "${result// }" ]]; then
      printf '%s\n' "$result"
      return 0
    fi
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import socket, sys; addrs=sorted({item[4][0] for item in socket.getaddrinfo(sys.argv[1], None)}); print(" ".join(addrs)) if addrs else sys.exit(1)' "$domain"
    return
  fi

  if command -v dig >/dev/null 2>&1; then
    result="$(dig +short "$domain" 2>/dev/null | awk '/^[0-9a-fA-F:.]+$/ {print}' | sort -u | tr '\n' ' ' || true)"
    if [[ -n "${result// }" ]]; then
      printf '%s\n' "$result"
      return 0
    fi
  fi

  if command -v nslookup >/dev/null 2>&1; then
    result="$(nslookup "$domain" 2>/dev/null | awk '/^Address: / {print $2}' | sort -u | tr '\n' ' ' || true)"
    if [[ -n "${result// }" ]]; then
      printf '%s\n' "$result"
      return 0
    fi
  fi

  return 1
}

validate_domain_syntax() {
  local domain="$1"
  local label

  [[ "$domain" == *"."* ]] || fail "SITE_DOMAIN must include at least one dot"
  [[ ! "$domain" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || fail "SITE_DOMAIN must be a domain, not an IP address"
  [[ "$domain" != .* && "$domain" != *. ]] || fail "SITE_DOMAIN must not start or end with a dot"
  [[ "$domain" != *..* ]] || fail "SITE_DOMAIN must not contain empty labels"
  [[ "$domain" =~ ^[A-Za-z0-9.-]+$ ]] || fail "SITE_DOMAIN contains invalid characters"

  IFS='.' read -r -a labels <<< "$domain"
  for label in "${labels[@]}"; do
    [[ ${#label} -ge 1 && ${#label} -le 63 ]] || fail "SITE_DOMAIN labels must be 1-63 characters"
    [[ "$label" != -* && "$label" != *- ]] || fail "SITE_DOMAIN labels must not start or end with '-'"
  done
}

SITE_DOMAIN="$(read_env_value SITE_DOMAIN)"
if [[ -z "$SITE_DOMAIN" || "$SITE_DOMAIN" == "blog.example.com" || "$SITE_DOMAIN" == "shoka.example.com" ]]; then
  fail "SITE_DOMAIN must be set to your real domain"
fi
if [[ "$SITE_DOMAIN" == http://* || "$SITE_DOMAIN" == https://* || "$SITE_DOMAIN" == */* ]]; then
  fail "SITE_DOMAIN must be a bare domain, for example shouka.blog"
fi
validate_domain_syntax "$SITE_DOMAIN"
pass "SITE_DOMAIN is set"

need_non_placeholder_if_set BLOG_DEEPSEEK_KEY
need_non_placeholder_if_set BLOG_EMBED_KEY
need_non_placeholder_if_set BLOG_LANGFUSE_PUBLIC
need_non_placeholder_if_set BLOG_LANGFUSE_SECRET

if [[ "$WITH_OBSERVABILITY" == true ]]; then
  need_required_secret LANGFUSE_DB_PASSWORD
  need_required_secret LANGFUSE_NEXTAUTH_SECRET
  need_required_secret LANGFUSE_SALT
  need_required_secret LANGFUSE_NEXTAUTH_URL
  need_required_secret LANGFUSE_INIT_PROJECT_PUBLIC_KEY
  need_required_secret LANGFUSE_INIT_PROJECT_SECRET_KEY
  need_required_secret LANGFUSE_INIT_USER_EMAIL
  need_required_secret LANGFUSE_INIT_USER_PASSWORD
else
  echo "SKIP: Langfuse bootstrap secret checks. Run with --observability to require them."
fi

if [[ "$SKIP_DNS" == true ]]; then
  echo "SKIP: SITE_DOMAIN DNS resolution. Remove --skip-dns before a real deployment."
else
  DNS_RESULT="$(resolve_domain "$SITE_DOMAIN" 2>/dev/null || true)"
  if [[ -z "${DNS_RESULT// }" ]]; then
    fail "SITE_DOMAIN does not resolve in DNS"
  fi
  pass "SITE_DOMAIN resolves"
fi

echo "Environment file validation complete."
