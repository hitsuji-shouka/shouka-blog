#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

make_env() {
  local path="$1"
  local domain="$2"
  cat > "$path" <<EOF
SITE_DOMAIN=$domain
BLOG_DEEPSEEK_KEY=
BLOG_EMBED_KEY=
BLOG_LANGFUSE_PUBLIC=
BLOG_LANGFUSE_SECRET=
EOF
}

expect_success() {
  local name="$1"
  shift
  if "$@" >/tmp/shouka-env-test.out 2>&1; then
    echo "OK: $name"
  else
    cat /tmp/shouka-env-test.out >&2
    fail "$name should have passed"
  fi
}

expect_failure() {
  local name="$1"
  shift
  if "$@" >/tmp/shouka-env-test.out 2>&1; then
    cat /tmp/shouka-env-test.out >&2
    fail "$name should have failed"
  fi
  echo "OK: $name"
}

file_mode() {
  local path="$1"
  if stat -c '%a' "$path" >/dev/null 2>&1; then
    stat -c '%a' "$path"
  else
    stat -f '%Lp' "$path"
  fi
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" /tmp/shouka-env-test.out' EXIT

VALID_ENV="$TMP_DIR/valid.env"
EXAMPLE_ENV="$TMP_DIR/example.env"
SPACE_ENV="$TMP_DIR/space.env"
UNDERSCORE_ENV="$TMP_DIR/underscore.env"
DOUBLE_DOT_ENV="$TMP_DIR/double-dot.env"
IP_ENV="$TMP_DIR/ip.env"
SETUP_DIR="$TMP_DIR/setup-valid"
OUTPUT_ENV="$TMP_DIR/production.env"

make_env "$VALID_ENV" "shouka.blog"
make_env "$EXAMPLE_ENV" "blog.example.com"
make_env "$SPACE_ENV" "bad domain.com"
make_env "$UNDERSCORE_ENV" "bad_domain.com"
make_env "$DOUBLE_DOT_ENV" "bad..domain.com"
make_env "$IP_ENV" "203.0.113.10"

expect_success "valid bare domain" bash "$ROOT_DIR/scripts/check-env-file.sh" --file "$VALID_ENV" --skip-dns
expect_failure "example domain rejected" bash "$ROOT_DIR/scripts/check-env-file.sh" --file "$EXAMPLE_ENV" --skip-dns
expect_failure "domain with spaces rejected" bash "$ROOT_DIR/scripts/check-env-file.sh" --file "$SPACE_ENV" --skip-dns
expect_failure "domain with underscores rejected" bash "$ROOT_DIR/scripts/check-env-file.sh" --file "$UNDERSCORE_ENV" --skip-dns
expect_failure "domain with empty label rejected" bash "$ROOT_DIR/scripts/check-env-file.sh" --file "$DOUBLE_DOT_ENV" --skip-dns
expect_failure "domain as IP rejected" bash "$ROOT_DIR/scripts/check-env-file.sh" --file "$IP_ENV" --skip-dns
expect_success "setup-server-env writes a valid env file" bash -c "bash '$ROOT_DIR/scripts/setup-server-env.sh' --domain shouka.blog --path '$SETUP_DIR' >/dev/null && bash '$ROOT_DIR/scripts/check-env-file.sh' --file '$SETUP_DIR/.env' --skip-dns"
expect_success "setup-server-env writes a valid output file" bash -c "bash '$ROOT_DIR/scripts/setup-server-env.sh' --domain shouka.blog --output '$OUTPUT_ENV' >/dev/null && bash '$ROOT_DIR/scripts/check-env-file.sh' --file '$OUTPUT_ENV' --skip-dns"
if [[ "$(file_mode "$OUTPUT_ENV")" != "600" ]]; then
  fail "setup-server-env output file should be chmod 600"
fi
echo "OK: setup-server-env output file is chmod 600"
expect_failure "setup-server-env rejects invalid domains" bash "$ROOT_DIR/scripts/setup-server-env.sh" --domain "bad domain.com" --path "$TMP_DIR/setup-invalid"

echo "Environment validation tests complete."
