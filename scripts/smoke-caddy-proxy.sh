#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-18081}"
APP_VERSION="${APP_VERSION:-caddy-smoke}"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-shouka-caddy-smoke-$$}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/shouka-caddy-smoke.XXXXXX")"
COMPOSE_FILE="$TMP_DIR/compose.yml"
ORIGIN="http://127.0.0.1:$PORT"

cleanup() {
  docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat > "$COMPOSE_FILE" <<YAML
services:
  app:
    build:
      context: "$ROOT_DIR"
      args:
        APP_VERSION: "$APP_VERSION"
    expose:
      - "8000"
    environment:
      APP_VERSION: "$APP_VERSION"
      SITE_DOMAIN: "$ORIGIN"
      BLOG_DEEPSEEK_KEY: ""
      BLOG_EMBED_KEY: ""
    healthcheck:
      test: ["CMD-SHELL", "python -c \\"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/health', timeout=3).read()\\""]
      interval: 5s
      timeout: 5s
      retries: 12
      start_period: 10s
  caddy:
    image: caddy:2
    ports:
      - "127.0.0.1:$PORT:$PORT"
    environment:
      SITE_DOMAIN: "http://:$PORT"
    volumes:
      - "$ROOT_DIR/Caddyfile:/etc/caddy/Caddyfile:ro"
    depends_on:
      app:
        condition: service_healthy
YAML

cd "$ROOT_DIR"

docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" up -d --build

for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if curl --fail --silent "$ORIGIN/api/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

EXPECTED_APP_VERSION="$APP_VERSION" EXPECT_CADDY_HEADERS=1 bash scripts/verify-public-site.sh "$ORIGIN"
bash scripts/check-frontend-render.sh "$ORIGIN"

echo "Caddy reverse proxy smoke test complete."
