#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INDEX_HTML="$ROOT_DIR/frontend/index.html"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "OK: $*"
}

need_text() {
  local text="$1"
  local message="$2"
  grep -q "$text" "$INDEX_HTML" || fail "$message"
}

[[ -f "$INDEX_HTML" ]] || fail "missing frontend/index.html"

grep -q '<html lang="zh-CN">' "$INDEX_HTML" || fail "index.html must set zh-CN language"
grep -q '<title>Shouka Blog | AI, Writing, Finance</title>' "$INDEX_HTML" || fail "index.html must set the production title"
need_text 'name="description"' "index.html must include a meta description"
need_text 'property="og:title"' "index.html must include og:title"
need_text 'property="og:description"' "index.html must include og:description"
need_text 'property="og:type" content="website"' "index.html must mark the page as an OG website"
need_text 'property="og:image" content="/bg/hero-space.jpg"' "index.html must set the hero image as og:image"
need_text 'name="twitter:card" content="summary_large_image"' "index.html must set a large Twitter card"
need_text 'rel="alternate" type="application/rss+xml"' "index.html must expose the RSS feed"

pass "frontend SEO metadata is present"
