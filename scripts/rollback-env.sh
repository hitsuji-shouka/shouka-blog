#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
PREVIOUS_ENV="$ROOT_DIR/.env.previous"
CURRENT_BACKUP="$ROOT_DIR/.env.rollback-current"
SKIP_HEALTH=false
BROWSER_CHECK=false
DRY_RUN=false

usage() {
  cat <<'USAGE'
Usage: scripts/rollback-env.sh [options]

Restores the previous server .env saved by GitHub Actions deployment,
restarts Docker Compose, and verifies the public site.

Options:
  --skip-health    Skip public HTTPS site verification
  --browser-check  Run browser render verification after public verification
  --dry-run        Print the commands without changing files or containers
  -h, --help       Show this help
USAGE
}

for arg in "$@"; do
  case "$arg" in
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

cd "$ROOT_DIR"

[[ -f "$PREVIOUS_ENV" ]] || fail "missing .env.previous; no saved server env to restore"
if [[ -e "$CURRENT_BACKUP" && "$DRY_RUN" == false ]]; then
  fail "refusing to overwrite .env.rollback-current; move it aside before retrying"
fi

if [[ -f "$ENV_FILE" ]]; then
  run cp "$ENV_FILE" "$CURRENT_BACKUP"
fi
run cp "$PREVIOUS_ENV" "$ENV_FILE"
run chmod 600 "$ENV_FILE"

SITE_DOMAIN="$(read_env_value SITE_DOMAIN)"
[[ -n "$SITE_DOMAIN" ]] || fail "SITE_DOMAIN is empty after rollback"
if [[ "$SITE_DOMAIN" == http://* || "$SITE_DOMAIN" == https://* ]]; then
  SITE_ORIGIN="${SITE_DOMAIN%/}"
else
  SITE_ORIGIN="https://${SITE_DOMAIN}"
fi

run docker compose up -d --build
run docker compose ps

if [[ "$SKIP_HEALTH" == true ]]; then
  echo "SKIP: public site verification"
  exit 0
fi

run bash scripts/verify-public-site.sh "$SITE_ORIGIN"
if [[ "$BROWSER_CHECK" == true ]]; then
  run bash scripts/check-frontend-render.sh "$SITE_ORIGIN"
fi

echo "Environment rollback complete."
