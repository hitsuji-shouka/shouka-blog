#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".env"
SITE_DOMAIN_ARG=""
EXPECTED_HOST="${DEPLOY_HOST:-}"

usage() {
  cat <<'USAGE'
Usage: scripts/check-domain-routing.sh [--env-file PATH] [--site-domain DOMAIN] [--expected-host HOST]

Checks that SITE_DOMAIN DNS resolves to the same address as the deployment host.

Sources:
  --site-domain wins over DEPLOY_ENV and --env-file
  --expected-host defaults to DEPLOY_HOST
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
    --env-file)
      [[ $# -ge 2 ]] || fail "--env-file requires a value"
      ENV_FILE="$2"
      shift 2
      ;;
    --site-domain)
      [[ $# -ge 2 ]] || fail "--site-domain requires a value"
      SITE_DOMAIN_ARG="$2"
      shift 2
      ;;
    --expected-host)
      [[ $# -ge 2 ]] || fail "--expected-host requires a value"
      EXPECTED_HOST="$2"
      shift 2
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

read_key_from_text() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 == key {
      sub(/^[^=]*=/, "")
      gsub(/^["'\'' ]+|["'\'' ]+$/, "")
      gsub(/\r$/, "")
      print
      exit
    }
  '
}

read_env_file_value() {
  local key="$1"
  [[ -f "$ENV_FILE" ]] || return 0
  read_key_from_text "$key" < "$ENV_FILE"
}

resolve_host() {
  local host="$1"
  local result=""

  if [[ "$host" =~ ^[0-9]+(\.[0-9]+){3}$ || "$host" == *:* ]]; then
    printf '%s\n' "$host"
    return 0
  fi

  if [[ -n "${DNS_LOOKUP_CMD:-}" ]]; then
    "$DNS_LOOKUP_CMD" "$host"
    return
  fi

  if command -v getent >/dev/null 2>&1; then
    result="$(getent ahosts "$host" 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ' || true)"
    if [[ -n "${result// }" ]]; then
      printf '%s\n' "$result"
      return 0
    fi
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import socket, sys; addrs=sorted({item[4][0] for item in socket.getaddrinfo(sys.argv[1], None)}); print(" ".join(addrs)) if addrs else sys.exit(1)' "$host"
    return
  fi

  if command -v dig >/dev/null 2>&1; then
    result="$(dig +short "$host" 2>/dev/null | awk '/^[0-9a-fA-F:.]+$/ {print}' | sort -u | tr '\n' ' ' || true)"
    if [[ -n "${result// }" ]]; then
      printf '%s\n' "$result"
      return 0
    fi
  fi

  if command -v nslookup >/dev/null 2>&1; then
    result="$(nslookup "$host" 2>/dev/null | awk '/^Address: / {print $2}' | sort -u | tr '\n' ' ' || true)"
    if [[ -n "${result// }" ]]; then
      printf '%s\n' "$result"
      return 0
    fi
  fi

  return 1
}

validate_site_domain() {
  local domain="$1"
  local label

  [[ "$domain" == *"."* ]] || fail "SITE_DOMAIN must be a bare domain with at least one dot"
  [[ "$domain" != http://* && "$domain" != https://* && "$domain" != */* ]] || fail "SITE_DOMAIN must be a bare domain, not a URL or path"
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

validate_expected_host() {
  local host="$1"

  [[ "$host" != *"://"* && "$host" != */* && ! "$host" =~ [[:space:]] ]] || fail "expected deployment host must be a hostname or IP address, not a URL or path"
}

contains_any_address() {
  local domain_addresses="$1"
  local expected_addresses="$2"
  local domain_address
  local expected_address

  for domain_address in $domain_addresses; do
    for expected_address in $expected_addresses; do
      if [[ "$domain_address" == "$expected_address" ]]; then
        return 0
      fi
    done
  done
  return 1
}

SITE_DOMAIN="$SITE_DOMAIN_ARG"
if [[ -z "$SITE_DOMAIN" && -n "${DEPLOY_ENV:-}" ]]; then
  SITE_DOMAIN="$(printf '%s\n' "$DEPLOY_ENV" | read_key_from_text SITE_DOMAIN)"
fi
if [[ -z "$SITE_DOMAIN" ]]; then
  SITE_DOMAIN="$(read_env_file_value SITE_DOMAIN)"
fi

[[ -n "$SITE_DOMAIN" ]] || fail "SITE_DOMAIN is required"
[[ -n "$EXPECTED_HOST" ]] || fail "expected deployment host is required; pass --expected-host or set DEPLOY_HOST"
validate_site_domain "$SITE_DOMAIN"
validate_expected_host "$EXPECTED_HOST"

SITE_ADDRESSES="$(resolve_host "$SITE_DOMAIN" 2>/dev/null || true)"
[[ -n "${SITE_ADDRESSES// }" ]] || fail "SITE_DOMAIN does not resolve: $SITE_DOMAIN"

EXPECTED_ADDRESSES="$(resolve_host "$EXPECTED_HOST" 2>/dev/null || true)"
[[ -n "${EXPECTED_ADDRESSES// }" ]] || fail "expected deployment host does not resolve: $EXPECTED_HOST"

if ! contains_any_address "$SITE_ADDRESSES" "$EXPECTED_ADDRESSES"; then
  fail "SITE_DOMAIN does not point at DEPLOY_HOST ($SITE_DOMAIN -> $SITE_ADDRESSES, $EXPECTED_HOST -> $EXPECTED_ADDRESSES)"
fi

pass "SITE_DOMAIN points at deployment host"
