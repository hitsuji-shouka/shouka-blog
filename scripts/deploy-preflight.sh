#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
PULL_IMAGES=false
SKIP_DNS=false
WITH_OBSERVABILITY=false

for arg in "$@"; do
  case "$arg" in
    --observability) WITH_OBSERVABILITY=true ;;
    --pull-images) PULL_IMAGES=true ;;
    --skip-dns) SKIP_DNS=true ;;
    -h|--help)
      cat <<'USAGE'
Usage: scripts/deploy-preflight.sh [--observability] [--pull-images] [--skip-dns]

Checks whether the server is ready to deploy shouka.blog.

Default checks are local and quick:
  - required files exist
  - Docker and Docker Compose are available
  - .env exists and SITE_DOMAIN is not the example value
  - SITE_DOMAIN resolves in DNS
  - default Compose services are app + caddy
  - observability profile adds Langfuse services

Use --pull-images to also test Docker Hub access for deployment images.
Use --skip-dns for local dry-runs with a temporary non-public domain.
Use --observability to require non-placeholder Langfuse bootstrap secrets.
USAGE
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "OK: $*"
}

need_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing $path"
  pass "found ${path#$ROOT_DIR/}"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is not installed or not on PATH"
  pass "$1 is available"
}

read_env_value() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 == key {
      sub(/^[^=]*=/, "")
      gsub(/^["'\'' ]+|["'\'' ]+$/, "")
      print
      exit
    }
  ' "$ENV_FILE"
}

cd "$ROOT_DIR"

need_file "$ROOT_DIR/Dockerfile"
need_file "$ROOT_DIR/docker-compose.yml"
need_file "$ROOT_DIR/Caddyfile"
need_file "$ROOT_DIR/.env.example"

need_cmd docker
docker compose version >/dev/null 2>&1 || fail "docker compose is not available"
pass "docker compose is available"

if [[ ! -f "$ENV_FILE" ]]; then
  fail "missing .env; run: cp .env.example .env"
fi
pass "found .env"

ENV_CHECK_ARGS=(bash scripts/check-env-file.sh --file "$ENV_FILE")
if [[ "$WITH_OBSERVABILITY" == true ]]; then
  ENV_CHECK_ARGS+=(--observability)
fi
if [[ "$SKIP_DNS" == true ]]; then
  ENV_CHECK_ARGS+=(--skip-dns)
fi
"${ENV_CHECK_ARGS[@]}"

DEFAULT_SERVICES="$(docker compose config --services | sort | tr '\n' ' ')"
[[ "$DEFAULT_SERVICES" == "app caddy " ]] || fail "default compose services should be 'app caddy', got: $DEFAULT_SERVICES"
pass "default compose services are app + caddy"

OBS_SERVICES="$(docker compose --profile observability config --services | sort | tr '\n' ' ')"
[[ "$OBS_SERVICES" == "app caddy langfuse langfuse-db " ]] || fail "observability services unexpected: $OBS_SERVICES"
pass "observability profile includes Langfuse services"

if [[ "$PULL_IMAGES" == true ]]; then
  echo "Checking Docker Hub access for deployment images..."
  docker pull node:22-slim
  docker pull python:3.12-slim
  docker pull caddy:2
  if [[ "$WITH_OBSERVABILITY" == true ]]; then
    docker pull postgres:16
    docker pull langfuse/langfuse:2
  fi
  pass "deployment images are pullable"
else
  echo "SKIP: deployment image pulls. Run with --pull-images to verify Docker Hub access."
fi

echo "Preflight complete."
