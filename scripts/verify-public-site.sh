#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/verify-public-site.sh ORIGIN

Checks a deployed public blog origin:
  - /api/health returns {"status":"ok"}
  - /api/version returns a deployment version
  - /api/posts returns a JSON array
  - / returns the React app shell and SEO/share metadata
  - /robots.txt points to /sitemap.xml
  - /sitemap.xml lists public URLs
  - /feed.xml lists public posts

Environment:
  EXPECTED_APP_VERSION  Optional exact version expected from /api/version
  EXPECT_CADDY_HEADERS  Set to 1 to verify Caddy security/cache headers

Example:
  scripts/verify-public-site.sh https://blog.example.com
USAGE
}

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

ORIGIN="${1%/}"
[[ "$ORIGIN" == http://* || "$ORIGIN" == https://* ]] || fail "origin must start with http:// or https://"

fetch() {
  curl --fail --silent --show-error --max-time 15 "$1"
}

fetch_headers() {
  curl --fail --silent --show-error --dump-header - --output /dev/null --max-time 15 "$1"
}

fetch_content_type() {
  curl --fail --silent --show-error --output /dev/null --write-out '%{content_type}' --max-time 15 "$1"
}

check_caddy_headers() {
  local home_headers api_headers asset_path asset_headers publishing_path publishing_headers
  home_headers="$(fetch_headers "$ORIGIN/" | tr '[:upper:]' '[:lower:]')"
  case "$home_headers" in
    *"strict-transport-security:"*"max-age=31536000"*) echo "OK: HSTS header" ;;
    *) fail "missing HSTS header" ;;
  esac
  case "$home_headers" in
    *"x-content-type-options:"*"nosniff"*) echo "OK: nosniff header" ;;
    *) fail "missing nosniff header" ;;
  esac
  case "$home_headers" in
    *"referrer-policy:"*"strict-origin-when-cross-origin"*) echo "OK: referrer policy header" ;;
    *) fail "missing referrer policy header" ;;
  esac
  case "$home_headers" in
    *"cache-control:"*"no-cache"*) echo "OK: HTML cache header" ;;
    *) fail "missing HTML no-cache header" ;;
  esac

  api_headers="$(fetch_headers "$ORIGIN/api/health" | tr '[:upper:]' '[:lower:]')"
  case "$api_headers" in
    *"cache-control:"*"no-store"*) echo "OK: API cache header" ;;
    *) fail "missing API no-store header" ;;
  esac

  asset_path="$(printf '%s' "$HOME_HTML" | grep -o 'src="/assets/[^"]*\.js"' | head -n 1 | sed 's/^src="//;s/"$//' || true)"
  if [[ -n "$asset_path" ]]; then
    asset_headers="$(fetch_headers "$ORIGIN$asset_path" | tr '[:upper:]' '[:lower:]')"
    case "$asset_headers" in
      *"cache-control:"*"max-age=31536000"*"immutable"*) echo "OK: asset cache header" ;;
      *) fail "missing immutable asset cache header" ;;
    esac
  fi

  for publishing_path in /robots.txt /sitemap.xml /feed.xml; do
    publishing_headers="$(fetch_headers "$ORIGIN$publishing_path" | tr '[:upper:]' '[:lower:]')"
    case "$publishing_headers" in
      *"cache-control:"*"public"*"max-age=300"*) echo "OK: publishing cache header $publishing_path" ;;
      *) fail "missing publishing cache header for $publishing_path" ;;
    esac
  done
}

HEALTH="$(fetch "$ORIGIN/api/health")"
case "$HEALTH" in
  *'"status":"ok"'*) echo "OK: $ORIGIN/api/health" ;;
  *) fail "unexpected health response: $HEALTH" ;;
esac

VERSION="$(fetch "$ORIGIN/api/version")"
case "$VERSION" in
  *'"version":"'*'"service":"shoka-blog"'*) echo "OK: $ORIGIN/api/version" ;;
  *) fail "unexpected version response from $ORIGIN/api/version: $VERSION" ;;
esac
if [[ -n "${EXPECTED_APP_VERSION:-}" ]]; then
  case "$VERSION" in
    *"\"version\":\"$EXPECTED_APP_VERSION\""*) echo "OK: deployed version is $EXPECTED_APP_VERSION" ;;
    *) fail "expected version $EXPECTED_APP_VERSION, got: $VERSION" ;;
  esac
fi

POSTS="$(fetch "$ORIGIN/api/posts")"
case "$POSTS" in
  \[*\]*) echo "OK: $ORIGIN/api/posts" ;;
  *) fail "unexpected posts response from $ORIGIN/api/posts: $POSTS" ;;
esac

HOME_HTML="$(fetch "$ORIGIN/")"
case "$HOME_HTML" in
  *'id="root"'*) echo "OK: $ORIGIN/" ;;
  *) fail "frontend app shell not found at $ORIGIN/" ;;
esac
case "$HOME_HTML" in
  *"<title>Shouka Blog | AI, Writing, Finance</title>"*) echo "OK: deployed HTML title" ;;
  *) fail "deployed HTML title is missing or stale" ;;
esac
case "$HOME_HTML" in
  *'name="description"'*'Shouka Blog is a personal blog'*) echo "OK: deployed meta description" ;;
  *) fail "deployed meta description is missing or stale" ;;
esac
case "$HOME_HTML" in
  *"rel=\"canonical\" href=\"$ORIGIN/\""*) echo "OK: deployed canonical URL" ;;
  *) fail "deployed canonical URL is missing or stale" ;;
esac
case "$HOME_HTML" in
  *"property=\"og:url\" content=\"$ORIGIN/\""*) echo "OK: deployed og:url" ;;
  *) fail "deployed Open Graph URL is missing or stale" ;;
esac
case "$HOME_HTML" in
  *"property=\"og:image\" content=\"$ORIGIN/bg/hero-space.jpg\""*) echo "OK: deployed og:image" ;;
  *) fail "deployed Open Graph image is missing or stale" ;;
esac
case "$HOME_HTML" in
  *'name="twitter:card" content="summary_large_image"'*) echo "OK: deployed twitter:card" ;;
  *) fail "deployed Twitter card metadata is missing or stale" ;;
esac
case "$HOME_HTML" in
  *"name=\"twitter:image\" content=\"$ORIGIN/bg/hero-space.jpg\""*) echo "OK: deployed twitter:image" ;;
  *) fail "deployed Twitter image is missing or stale" ;;
esac
SHARE_IMAGE_TYPE="$(fetch_content_type "$ORIGIN/bg/hero-space.jpg")"
case "$SHARE_IMAGE_TYPE" in
  image/*) echo "OK: deployed share image asset" ;;
  *) fail "deployed share image asset is missing or not an image" ;;
esac
case "$HOME_HTML" in
  *'rel="alternate" type="application/rss+xml"'*) echo "OK: deployed RSS discovery link" ;;
  *) fail "deployed RSS discovery link is missing" ;;
esac

ROBOTS="$(fetch "$ORIGIN/robots.txt")"
case "$ROBOTS" in
  *"Sitemap: $ORIGIN/sitemap.xml"*) echo "OK: $ORIGIN/robots.txt" ;;
  *) fail "robots.txt does not point to $ORIGIN/sitemap.xml" ;;
esac

SITEMAP="$(fetch "$ORIGIN/sitemap.xml")"
case "$SITEMAP" in
  *"<loc>$ORIGIN/</loc>"*"<loc>$ORIGIN/post/"*) echo "OK: $ORIGIN/sitemap.xml" ;;
  *) fail "sitemap.xml does not list the homepage and posts" ;;
esac

FEED="$(fetch "$ORIGIN/feed.xml")"
case "$FEED" in
  *'<rss version="2.0">'*"<link>$ORIGIN/post/"*) echo "OK: $ORIGIN/feed.xml" ;;
  *) fail "feed.xml does not list RSS posts" ;;
esac

if [[ "${EXPECT_CADDY_HEADERS:-}" == "1" ]]; then
  check_caddy_headers
fi

echo "Public site verification complete."
