#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
BACKUP_ENV="$ROOT_DIR/.env.codex-backup"
TMP_DIR="$(mktemp -d)"
PULL_LOG="$TMP_DIR/docker-pulls.log"

cleanup() {
  rm -rf "$TMP_DIR"
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

expect_pull() {
  local image="$1"
  grep -Fxq "$image" "$PULL_LOG" || fail "expected preflight to pull $image"
  echo "OK: preflight pulls $image"
}

cd "$ROOT_DIR"

if [[ -f "$BACKUP_ENV" ]]; then
  fail "refusing to overwrite existing .env.codex-backup"
fi

if [[ -f "$ENV_FILE" ]]; then
  mv "$ENV_FILE" "$BACKUP_ENV"
fi

cat > "$ENV_FILE" <<'ENV'
SITE_DOMAIN=preflight.example.test
BLOG_DEEPSEEK_KEY=
BLOG_EMBED_KEY=
BLOG_LANGFUSE_PUBLIC=
BLOG_LANGFUSE_SECRET=
LANGFUSE_DB_PASSWORD=prod-db-password
LANGFUSE_NEXTAUTH_SECRET=prod-nextauth-secret
LANGFUSE_SALT=prod-salt
LANGFUSE_NEXTAUTH_URL=https://trace.preflight.example.test
LANGFUSE_INIT_PROJECT_PUBLIC_KEY=pk-lf-prod
LANGFUSE_INIT_PROJECT_SECRET_KEY=sk-lf-prod
LANGFUSE_INIT_USER_EMAIL=ops@preflight.example.test
LANGFUSE_INIT_USER_PASSWORD=prod-admin-password
ENV

cat > "$TMP_DIR/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "compose" && "${2:-}" == "version" ]]; then
  echo "Docker Compose version v2.0.0"
  exit 0
fi

if [[ "$1" == "compose" && "${2:-}" == "config" && "${3:-}" == "--services" ]]; then
  printf 'app\ncaddy\n'
  exit 0
fi

if [[ "$1" == "compose" && "${2:-}" == "--profile" && "${3:-}" == "observability" && "${4:-}" == "config" && "${5:-}" == "--services" ]]; then
  printf 'app\ncaddy\nlangfuse\nlangfuse-db\n'
  exit 0
fi

if [[ "$1" == "pull" ]]; then
  echo "$2" >> "$DOCKER_PULL_LOG"
  exit 0
fi

echo "unexpected docker call: $*" >&2
exit 1
SH
chmod +x "$TMP_DIR/docker"
touch "$PULL_LOG"

PATH="$TMP_DIR:$PATH" DOCKER_PULL_LOG="$PULL_LOG" bash scripts/deploy-preflight.sh --skip-dns --pull-images --observability

expect_pull "node:22-slim"
expect_pull "python:3.12-slim"
expect_pull "caddy:2"
expect_pull "postgres:16"
expect_pull "langfuse/langfuse:2"

echo "Deploy preflight tests complete."
