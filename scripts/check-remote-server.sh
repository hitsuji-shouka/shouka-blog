#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY_FILE="$(mktemp)"
TEMP_FILES=("$KEY_FILE")
RUN_DOMAIN_ROUTING=false
PULL_IMAGES=false
WITH_OBSERVABILITY=false
CHECK_PORTS=false

usage() {
  cat <<'USAGE'
Usage: scripts/check-remote-server.sh [--domain-routing] [--pull-images] [--observability] [--check-ports]

Checks that the deployment server is reachable and has required dependencies.

Options:
  --domain-routing  Also check SITE_DOMAIN resolves to DEPLOY_HOST.
  --pull-images     Also verify required deployment images pull on the server.
  --observability   Include optional Langfuse runtime images when pulling.
  --check-ports     Also fail if remote ports 80 or 443 already have listeners.
  -h, --help        Show this help.
USAGE
}

cleanup() {
  rm -f "${TEMP_FILES[@]}"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

run() {
  echo "+ $*"
  "$@"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain-routing)
      RUN_DOMAIN_ROUTING=true
      shift
      ;;
    --pull-images)
      PULL_IMAGES=true
      shift
      ;;
    --observability)
      WITH_OBSERVABILITY=true
      shift
      ;;
    --check-ports)
      CHECK_PORTS=true
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

write_key() {
  printf '%s\n' "$DEPLOY_SSH_KEY" > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
}

validate_deploy_env_if_present() {
  if [[ -z "${DEPLOY_ENV:-}" ]]; then
    return
  fi

  local env_file
  env_file="$(mktemp)"
  TEMP_FILES+=("$env_file")
  printf '%s\n' "$DEPLOY_ENV" > "$env_file"
  chmod 600 "$env_file"
  ENV_CHECK_ARGS=(bash scripts/check-env-file.sh --file "$env_file" --skip-dns)
  if [[ "$WITH_OBSERVABILITY" == true ]]; then
    ENV_CHECK_ARGS+=(--observability)
  fi
  "${ENV_CHECK_ARGS[@]}"
  rm -f "$env_file"
}

validate_remote_env_for_observability() {
  if [[ "$WITH_OBSERVABILITY" != true ]]; then
    return
  fi

  local env_file
  env_file="$(mktemp)"
  TEMP_FILES+=("$env_file")
  chmod 600 "$env_file"
  echo "+ ssh remote cat '$DEPLOY_PATH/.env' > temporary env file"
  "${SSH_ARGS[@]}" "cat '$DEPLOY_PATH/.env'" > "$env_file"
  bash scripts/check-env-file.sh --file "$env_file" --skip-dns --observability
  rm -f "$env_file"
}

check_remote_web_ports() {
  local port_check
  port_check="$(cat <<'REMOTE'
if ! command -v ss >/dev/null 2>&1; then
  echo "ss is required for --check-ports" >&2
  exit 1
fi
busy="$(ss -ltn | awk 'NR > 1 && ($4 ~ /:80$/ || $4 ~ /:443$/) { print }')"
if [ -n "$busy" ]; then
  echo "Ports 80/443 already have listeners:" >&2
  echo "$busy" >&2
  exit 1
fi
REMOTE
)"
  run "${SSH_ARGS[@]}" "$port_check"
}

cd "$ROOT_DIR"

bash scripts/check-deploy-secrets.sh
validate_deploy_env_if_present
command -v rsync >/dev/null || fail "local rsync is required"

write_key

SSH_ARGS=(
  ssh
  -i "$KEY_FILE"
  -p "${DEPLOY_PORT:-22}"
  -o BatchMode=yes
  -o ConnectTimeout=10
  -o StrictHostKeyChecking=accept-new
  "$DEPLOY_USER@$DEPLOY_HOST"
)

run "${SSH_ARGS[@]}" "mkdir -p '$DEPLOY_PATH'"
run "${SSH_ARGS[@]}" "command -v rsync >/dev/null"
run "${SSH_ARGS[@]}" "command -v docker >/dev/null"
run "${SSH_ARGS[@]}" "docker compose version >/dev/null"

if [[ "$CHECK_PORTS" == true ]]; then
  check_remote_web_ports
fi

if [[ "$PULL_IMAGES" == true ]]; then
  run "${SSH_ARGS[@]}" "docker pull node:22-slim"
  run "${SSH_ARGS[@]}" "docker pull python:3.12-slim"
  run "${SSH_ARGS[@]}" "docker pull caddy:2"
  if [[ "$WITH_OBSERVABILITY" == true ]]; then
    run "${SSH_ARGS[@]}" "docker pull postgres:16"
    run "${SSH_ARGS[@]}" "docker pull langfuse/langfuse:2"
  fi
fi

if [[ -n "${DEPLOY_ENV:-}" ]]; then
  echo "OK: DEPLOY_ENV is provided and validated locally; remote .env can be written by GitHub Actions"
  if [[ "$RUN_DOMAIN_ROUTING" == true ]]; then
    run bash scripts/check-domain-routing.sh --expected-host "$DEPLOY_HOST"
  fi
else
  run "${SSH_ARGS[@]}" "test -f '$DEPLOY_PATH/.env'"
  validate_remote_env_for_observability
  if [[ "$RUN_DOMAIN_ROUTING" == true ]]; then
    SITE_DOMAIN="$("${SSH_ARGS[@]}" "awk -F= '/^SITE_DOMAIN=/ { gsub(/^[\"'\\'' ]+|[\"'\\'' ]+$/, \"\", \$2); print \$2; exit }' '$DEPLOY_PATH/.env'")"
    SITE_DOMAIN="${SITE_DOMAIN//$'\r'/}"
    [[ -n "$SITE_DOMAIN" ]] || fail "SITE_DOMAIN is empty in remote .env"
    run bash scripts/check-domain-routing.sh --site-domain "$SITE_DOMAIN" --expected-host "$DEPLOY_HOST"
  fi
fi

echo "Remote server check complete."
