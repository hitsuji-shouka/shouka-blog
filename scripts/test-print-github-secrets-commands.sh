#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/print-github-secrets-commands.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

KEY_FILE="$TMP_DIR/deploy_key"
ENV_FILE="$TMP_DIR/production.env"
OUT_FILE="$TMP_DIR/commands.txt"

ssh-keygen -q -t ed25519 -N '' -f "$KEY_FILE" >/dev/null
cat > "$ENV_FILE" <<'ENV'
SITE_DOMAIN=shouka.blog
BLOG_DEEPSEEK_KEY=
BLOG_EMBED_KEY=
BLOG_LANGFUSE_PUBLIC=
BLOG_LANGFUSE_SECRET=
ENV

expect_pass() {
  local name="$1"
  shift
  if "$@"; then
    echo "OK: $name"
  else
    echo "FAIL: $name" >&2
    exit 1
  fi
}

expect_fail() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>/dev/null; then
    echo "FAIL: $name" >&2
    exit 1
  else
    echo "OK: $name"
  fi
}

expect_output_contains() {
  local pattern="$1"
  if grep -Fq "$pattern" "$OUT_FILE"; then
    echo "OK: output contains $pattern"
  else
    echo "FAIL: output missing $pattern" >&2
    cat "$OUT_FILE" >&2
    exit 1
  fi
}

expect_output_omits_secret_material() {
  if grep -Fq -- "BEGIN OPENSSH PRIVATE KEY" "$OUT_FILE"; then
    echo "FAIL: output leaked the private SSH key" >&2
    exit 1
  fi
  if grep -Fq "SITE_DOMAIN=shouka.blog" "$OUT_FILE"; then
    echo "FAIL: output leaked DEPLOY_ENV contents" >&2
    exit 1
  fi
  echo "OK: output does not leak secret material"
}

expect_pass "prints safe gh secret commands" "$SCRIPT" \
  --host deploy.example.com \
  --user deploy_user \
  --path /srv/shouka-blog \
  --port 22 \
  --ssh-key-file "$KEY_FILE" \
  --env-file "$ENV_FILE" > "$OUT_FILE"

expect_output_contains "gh secret set DEPLOY_HOST --body deploy.example.com"
expect_output_contains "gh secret set DEPLOY_USER --body deploy_user"
expect_output_contains "gh secret set DEPLOY_PATH --body /srv/shouka-blog"
expect_output_contains "gh secret set DEPLOY_PORT --body 22"
expect_output_contains "gh secret set DEPLOY_SSH_KEY < "
expect_output_contains "gh secret set DEPLOY_ENV < "
expect_output_omits_secret_material

expect_pass "prints manual GitHub web checklist" "$SCRIPT" \
  --manual \
  --host deploy.example.com \
  --user deploy_user \
  --path /srv/shouka-blog \
  --port 22 \
  --ssh-key-file "$KEY_FILE" \
  --env-file "$ENV_FILE" > "$OUT_FILE"

expect_output_contains "Settings > Secrets and variables > Actions"
expect_output_contains "DEPLOY_HOST = deploy.example.com"
expect_output_contains "DEPLOY_USER = deploy_user"
expect_output_contains "DEPLOY_PATH = /srv/shouka-blog"
expect_output_contains "DEPLOY_PORT = 22"
expect_output_contains "DEPLOY_SSH_KEY = contents of "
expect_output_contains "DEPLOY_ENV = contents of "
expect_output_omits_secret_material

BAD_ENV="$TMP_DIR/bad.env"
printf 'SITE_DOMAIN=blog.example.com\n' > "$BAD_ENV"
expect_fail "invalid env file rejected" "$SCRIPT" \
  --host deploy.example.com \
  --user deploy_user \
  --path /srv/shouka-blog \
  --ssh-key-file "$KEY_FILE" \
  --env-file "$BAD_ENV"

expect_fail "unsafe deploy path rejected" "$SCRIPT" \
  --host deploy.example.com \
  --user deploy_user \
  --path /tmp/'bad path' \
  --ssh-key-file "$KEY_FILE" \
  --env-file "$ENV_FILE"

echo "GitHub secret command printer tests complete."
