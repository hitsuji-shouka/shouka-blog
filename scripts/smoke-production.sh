#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-18080}"
SKIP_BUILD=false

usage() {
  cat <<'USAGE'
Usage: scripts/smoke-production.sh [--skip-build]

Builds the frontend, starts the FastAPI app in production-like mode, and checks:
  - /api/health returns ok
  - /api/version returns the local smoke version
  - /api/posts returns JSON
  - / returns the React app shell and SEO/share metadata
  - Chromium can render the desktop and mobile homepage
  - /robots.txt, /sitemap.xml, and /feed.xml return publishing metadata

Environment:
  PORT=18080  Override the local smoke-test port
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=true ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "FAIL: $1 is not installed or not on PATH" >&2
    exit 1
  }
}

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

need_cmd npm
need_cmd uv
need_cmd curl

cd "$ROOT_DIR"

if [[ "$SKIP_BUILD" == false ]]; then
  echo "+ npm run build"
  (cd frontend && npm run build)
fi

echo "+ start FastAPI on 127.0.0.1:$PORT"
(
  cd backend
  APP_VERSION="smoke-local" SITE_DOMAIN="http://127.0.0.1:$PORT" BLOG_DEEPSEEK_KEY="" BLOG_EMBED_KEY="" uv run uvicorn main:app --host 127.0.0.1 --port "$PORT"
) &
SERVER_PID="$!"

BASE_URL="http://127.0.0.1:$PORT"

for _ in 1 2 3 4 5 6 7 8 9 10; do
  if curl --fail --silent "$BASE_URL/api/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

HEALTH="$(curl --fail --silent "$BASE_URL/api/health")"
case "$HEALTH" in
  *'"status":"ok"'*) echo "OK: /api/health" ;;
  *) echo "FAIL: unexpected health response: $HEALTH" >&2; exit 1 ;;
esac

VERSION="$(curl --fail --silent "$BASE_URL/api/version")"
case "$VERSION" in
  *'"version":"smoke-local"'*'"service":"shoka-blog"'*) echo "OK: /api/version" ;;
  *) echo "FAIL: unexpected version response: $VERSION" >&2; exit 1 ;;
esac

POSTS="$(curl --fail --silent "$BASE_URL/api/posts")"
case "$POSTS" in
  \[*\]*) echo "OK: /api/posts" ;;
  *) echo "FAIL: unexpected posts response: $POSTS" >&2; exit 1 ;;
esac

HOME_HTML="$(curl --fail --silent "$BASE_URL/")"
case "$HOME_HTML" in
  *'id="root"'*) echo "OK: frontend app shell" ;;
  *) echo "FAIL: frontend app shell not found" >&2; exit 1 ;;
esac
case "$HOME_HTML" in
  *"<title>Shouka Blog | AI, Writing, Finance</title>"*) echo "OK: HTML title" ;;
  *) echo "FAIL: HTML title is missing or stale" >&2; exit 1 ;;
esac
case "$HOME_HTML" in
  *'name="description"'*'Shouka Blog is a personal blog'*) echo "OK: meta description" ;;
  *) echo "FAIL: meta description is missing or stale" >&2; exit 1 ;;
esac
case "$HOME_HTML" in
  *"rel=\"canonical\" href=\"$BASE_URL/\""*) echo "OK: canonical URL" ;;
  *) echo "FAIL: canonical URL is missing or stale" >&2; exit 1 ;;
esac
case "$HOME_HTML" in
  *"property=\"og:url\" content=\"$BASE_URL/\""*) echo "OK: og:url" ;;
  *) echo "FAIL: og:url is missing or stale" >&2; exit 1 ;;
esac
case "$HOME_HTML" in
  *"property=\"og:image\" content=\"$BASE_URL/bg/hero-space.jpg\""*) echo "OK: og:image" ;;
  *) echo "FAIL: og:image is missing or stale" >&2; exit 1 ;;
esac
case "$HOME_HTML" in
  *'name="twitter:card" content="summary_large_image"'*) echo "OK: twitter:card" ;;
  *) echo "FAIL: twitter:card is missing or stale" >&2; exit 1 ;;
esac
case "$HOME_HTML" in
  *"name=\"twitter:image\" content=\"$BASE_URL/bg/hero-space.jpg\""*) echo "OK: twitter:image" ;;
  *) echo "FAIL: twitter:image is missing or stale" >&2; exit 1 ;;
esac
SHARE_IMAGE_TYPE="$(curl --fail --silent --show-error --output /dev/null --write-out '%{content_type}' "$BASE_URL/bg/hero-space.jpg")"
case "$SHARE_IMAGE_TYPE" in
  image/*) echo "OK: share image asset" ;;
  *) echo "FAIL: share image asset is missing or not an image" >&2; exit 1 ;;
esac
AVATAR_IMAGE_TYPE="$(curl --fail --silent --show-error --output /dev/null --write-out '%{content_type}' "$BASE_URL/avatar/shouka-avatar.png")"
case "$AVATAR_IMAGE_TYPE" in
  image/*) echo "OK: creator avatar asset" ;;
  *) echo "FAIL: creator avatar asset is missing or not an image" >&2; exit 1 ;;
esac
case "$HOME_HTML" in
  *'rel="alternate" type="application/rss+xml"'*) echo "OK: RSS discovery link" ;;
  *) echo "FAIL: RSS discovery link is missing" >&2; exit 1 ;;
esac

bash "$ROOT_DIR/scripts/check-frontend-render.sh" "$BASE_URL"

ROBOTS="$(curl --fail --silent "$BASE_URL/robots.txt")"
case "$ROBOTS" in
  *"Sitemap: $BASE_URL/sitemap.xml"*) echo "OK: /robots.txt" ;;
  *) echo "FAIL: robots.txt does not point to sitemap" >&2; exit 1 ;;
esac

SITEMAP="$(curl --fail --silent "$BASE_URL/sitemap.xml")"
case "$SITEMAP" in
  *"<loc>$BASE_URL/</loc>"*"<loc>$BASE_URL/post/"*) echo "OK: /sitemap.xml" ;;
  *) echo "FAIL: sitemap.xml does not list homepage and posts" >&2; exit 1 ;;
esac

FEED="$(curl --fail --silent "$BASE_URL/feed.xml")"
case "$FEED" in
  *'<rss version="2.0">'*"<link>$BASE_URL/post/"*) echo "OK: /feed.xml" ;;
  *) echo "FAIL: feed.xml does not list RSS posts" >&2; exit 1 ;;
esac

echo "Production smoke test complete."
