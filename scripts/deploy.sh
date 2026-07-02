#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
LOCK_DIR="$ROOT_DIR/.deploy.lock"
WITH_OBSERVABILITY=false
PULL_IMAGES=false
SKIP_HEALTH=false
DRY_RUN=false
BROWSER_CHECK=false

usage() {
  cat <<'USAGE'
Usage: scripts/deploy.sh [options]

Runs the production deployment flow for shouka.blog:
  1. preflight checks
  2. docker compose up -d --build
  3. local service status
  4. public site verification

Options:
  --observability  Start optional Langfuse services too
  --pull-images    Verify Docker Hub deployment image pulls before building
  --skip-health    Skip public HTTPS site verification
  --browser-check  Run browser render verification after public verification
  --dry-run        Print the commands without starting containers
  -h, --help       Show this help
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --observability) WITH_OBSERVABILITY=true ;;
    --pull-images) PULL_IMAGES=true ;;
    --skip-health) SKIP_HEALTH=true ;;
    --browser-check) BROWSER_CHECK=true ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

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

run() {
  echo "+ $*"
  if [[ "$DRY_RUN" == false ]]; then
    "$@"
  fi
}

print_diagnostics() {
  echo "Deployment diagnostics:"
  echo "+ docker compose ps"
  docker compose ps || true
  echo "+ docker compose logs --tail=120 app"
  docker compose logs --tail=120 app || true
  echo "+ docker compose logs --tail=120 caddy"
  docker compose logs --tail=120 caddy || true
}

release_lock() {
  if [[ "${LOCK_ACQUIRED:-false}" == true ]]; then
    rm -rf "$LOCK_DIR"
  fi
}

acquire_lock() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "+ mkdir $LOCK_DIR"
    return
  fi
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    LOCK_ACQUIRED=true
    trap release_lock EXIT
    {
      echo "pid=$$"
      echo "version=$APP_VERSION"
      date -u +"started_at=%Y-%m-%dT%H:%M:%SZ"
    } > "$LOCK_DIR/info"
    return
  fi

  echo "FAIL: another deployment appears to be running: $LOCK_DIR" >&2
  if [[ -f "$LOCK_DIR/info" ]]; then
    cat "$LOCK_DIR/info" >&2
  fi
  exit 1
}

cd "$ROOT_DIR"

[[ -f "$ENV_FILE" ]] || fail "missing .env; run: cp .env.example .env"

SITE_DOMAIN="$(read_env_value SITE_DOMAIN)"
[[ -n "$SITE_DOMAIN" ]] || fail "SITE_DOMAIN is empty in .env"
APP_VERSION="${APP_VERSION:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"
export APP_VERSION
echo "Deploying version $APP_VERSION"
acquire_lock

COMPOSE_ARGS=(docker compose)
if [[ "$WITH_OBSERVABILITY" == true ]]; then
  COMPOSE_ARGS+=(--profile observability)
fi

PREFLIGHT_ARGS=(bash scripts/deploy-preflight.sh)
if [[ "$PULL_IMAGES" == true ]]; then
  PREFLIGHT_ARGS+=(--pull-images)
fi
if [[ "$WITH_OBSERVABILITY" == true ]]; then
  PREFLIGHT_ARGS+=(--observability)
fi
if [[ "$DRY_RUN" == true ]]; then
  PREFLIGHT_ARGS+=(--skip-dns)
fi
run "${PREFLIGHT_ARGS[@]}"
if [[ "$DRY_RUN" == true ]]; then
  run "${COMPOSE_ARGS[@]}" up -d --build
elif ! "${COMPOSE_ARGS[@]}" up -d --build; then
  print_diagnostics
  fail "compose up failed"
fi
run docker compose ps

if [[ "$SKIP_HEALTH" == true ]]; then
  echo "SKIP: public site verification"
  exit 0
fi

SITE_ORIGIN="https://${SITE_DOMAIN}"
echo "Checking $SITE_ORIGIN"

if [[ "$DRY_RUN" == true ]]; then
  echo "+ EXPECTED_APP_VERSION=$APP_VERSION EXPECT_CADDY_HEADERS=1 bash scripts/verify-public-site.sh $SITE_ORIGIN"
  if [[ "$BROWSER_CHECK" == true ]]; then
    echo "+ bash scripts/check-frontend-render.sh $SITE_ORIGIN"
  fi
  exit 0
fi

for attempt in 1 2 3 4 5 6; do
  if EXPECTED_APP_VERSION="$APP_VERSION" EXPECT_CADDY_HEADERS=1 bash scripts/verify-public-site.sh "$SITE_ORIGIN"; then
    if [[ "$BROWSER_CHECK" == true ]]; then
      if ! bash scripts/check-frontend-render.sh "$SITE_ORIGIN"; then
        print_diagnostics
        fail "browser render verification failed: $SITE_ORIGIN"
      fi
    fi
    echo "Deploy complete."
    exit 0
  fi
  if [[ "$attempt" == 6 ]]; then
    break
  fi
  echo "Public verification attempt $attempt failed; retrying in 10s..."
  sleep 10
done

print_diagnostics
fail "public site verification failed: $SITE_ORIGIN"
