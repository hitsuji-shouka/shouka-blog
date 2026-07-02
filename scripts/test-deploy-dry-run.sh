#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
BACKUP_ENV="$ROOT_DIR/.env.codex-backup"
OUTPUT_FILE="$(mktemp)"

cleanup() {
  rm -f "$OUTPUT_FILE"
  rm -rf "$ROOT_DIR/.deploy.lock"
  if [[ -f "$BACKUP_ENV" ]]; then
    mv "$BACKUP_ENV" "$ENV_FILE"
  else
    rm -f "$ENV_FILE"
  fi
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

expect_output() {
  local pattern="$1"
  grep -Fq "$pattern" "$OUTPUT_FILE" || fail "dry-run output missing: $pattern"
  echo "OK: dry-run output contains $pattern"
}

expect_no_output() {
  local pattern="$1"
  if grep -Fq "$pattern" "$OUTPUT_FILE"; then
    fail "dry-run output should not contain: $pattern"
  fi
  echo "OK: dry-run output omits $pattern"
}

cd "$ROOT_DIR"

if [[ -f "$BACKUP_ENV" ]]; then
  fail "refusing to overwrite existing .env.codex-backup"
fi

if [[ -f "$ENV_FILE" ]]; then
  mv "$ENV_FILE" "$BACKUP_ENV"
fi

cat > "$ENV_FILE" <<'ENV'
SITE_DOMAIN=dryrun.example.test
BLOG_DEEPSEEK_KEY=
BLOG_EMBED_KEY=
BLOG_LANGFUSE_PUBLIC=
BLOG_LANGFUSE_SECRET=
ENV

bash scripts/deploy.sh --dry-run > "$OUTPUT_FILE"

expect_output "Deploying version"
expect_output "+ mkdir $ROOT_DIR/.deploy.lock"
expect_output "+ bash scripts/deploy-preflight.sh --skip-dns"
expect_output "+ docker compose up -d --build"
expect_output "+ docker compose ps"
expect_output "+ EXPECTED_APP_VERSION="
expect_output "bash scripts/verify-public-site.sh https://dryrun.example.test"
expect_no_output "bash scripts/check-frontend-render.sh https://dryrun.example.test"

bash scripts/deploy.sh --dry-run --browser-check > "$OUTPUT_FILE"
expect_output "bash scripts/check-frontend-render.sh https://dryrun.example.test"

[[ ! -e "$ROOT_DIR/.deploy.lock" ]] || fail "dry-run must not create .deploy.lock"
echo "OK: dry-run leaves no deploy lock"

echo "Deploy dry-run tests complete."
