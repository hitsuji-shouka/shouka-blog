#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/setup-server-env.sh --domain DOMAIN [options]

Creates or updates the production .env file on a server checkout.

Options:
  --domain DOMAIN          Public domain for the blog, for example blog.example.com
  --path PATH              Deployment directory. Defaults to the current repository.
  --output FILE            Write the env content to FILE instead of PATH/.env.
  --deepseek-key KEY       Optional chat model key for the site Agent
  --embed-key KEY          Optional embedding key for article retrieval
  --force                  Overwrite an existing .env
  -h, --help               Show this help

Run this on the server before the first deploy, then edit .env and replace any
remaining placeholder secrets.
USAGE
}

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

validate_domain_syntax() {
  local domain="$1"
  local label

  [[ "$domain" == *"."* ]] || fail "--domain must include at least one dot"
  [[ "$domain" != .* && "$domain" != *. ]] || fail "--domain must not start or end with a dot"
  [[ "$domain" != *..* ]] || fail "--domain must not contain empty labels"
  [[ "$domain" =~ ^[A-Za-z0-9.-]+$ ]] || fail "--domain contains invalid characters"

  IFS='.' read -r -a labels <<< "$domain"
  for label in "${labels[@]}"; do
    [[ ${#label} -ge 1 && ${#label} -le 63 ]] || fail "--domain labels must be 1-63 characters"
    [[ "$label" != -* && "$label" != *- ]] || fail "--domain labels must not start or end with '-'"
  done
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_PATH="$ROOT_DIR"
OUTPUT_FILE=""
SITE_DOMAIN=""
BLOG_DEEPSEEK_KEY=""
BLOG_EMBED_KEY=""
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      [[ $# -ge 2 ]] || fail "--domain requires a value"
      SITE_DOMAIN="$2"
      shift 2
      ;;
    --path)
      [[ $# -ge 2 ]] || fail "--path requires a value"
      DEPLOY_PATH="$2"
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || fail "--output requires a value"
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --deepseek-key)
      [[ $# -ge 2 ]] || fail "--deepseek-key requires a value"
      BLOG_DEEPSEEK_KEY="$2"
      shift 2
      ;;
    --embed-key)
      [[ $# -ge 2 ]] || fail "--embed-key requires a value"
      BLOG_EMBED_KEY="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ -n "$SITE_DOMAIN" ]] || fail "--domain is required"
[[ "$SITE_DOMAIN" != "blog.example.com" && "$SITE_DOMAIN" != "shoka.example.com" ]] || fail "--domain must be a real domain"
[[ "$SITE_DOMAIN" != *"://"* ]] || fail "--domain should not include http:// or https://"
[[ "$SITE_DOMAIN" != */* ]] || fail "--domain should not include a path"
validate_domain_syntax "$SITE_DOMAIN"

if [[ -n "$OUTPUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  ENV_FILE="$OUTPUT_FILE"
else
  mkdir -p "$DEPLOY_PATH"
  ENV_FILE="$DEPLOY_PATH/.env"
fi

if [[ -f "$ENV_FILE" && "$FORCE" == false ]]; then
  fail "$ENV_FILE already exists; edit it directly or rerun with --force"
fi

cat > "$ENV_FILE" <<EOF
# Public site domain used by Caddy.
SITE_DOMAIN=$SITE_DOMAIN

# Chat model for the site Agent.
BLOG_DEEPSEEK_KEY=$BLOG_DEEPSEEK_KEY
BLOG_DEEPSEEK_BASE=https://api.deepseek.com
BLOG_DEEPSEEK_MODEL=deepseek-v4-pro

# Embedding model for local article retrieval.
BLOG_EMBED_KEY=$BLOG_EMBED_KEY
BLOG_EMBED_BASE=https://api.siliconflow.cn/v1
BLOG_EMBED_MODEL=BAAI/bge-m3

# Optional Langfuse tracing. Leave keys empty to keep tracing disabled.
BLOG_LANGFUSE_PUBLIC=
BLOG_LANGFUSE_SECRET=
BLOG_LANGFUSE_HOST=http://langfuse:3000

# Optional self-hosted Langfuse for:
# docker compose --profile observability up -d --build
# Replace every value before exposing it.
LANGFUSE_DB_USER=langfuse
LANGFUSE_DB_PASSWORD=replace-with-a-long-random-password
LANGFUSE_DB_NAME=langfuse
LANGFUSE_NEXTAUTH_SECRET=replace-with-a-long-random-secret
LANGFUSE_SALT=replace-with-a-long-random-salt
LANGFUSE_NEXTAUTH_URL=https://trace.example.com
LANGFUSE_INIT_PROJECT_PUBLIC_KEY=pk-lf-replace-me
LANGFUSE_INIT_PROJECT_SECRET_KEY=sk-lf-replace-me
LANGFUSE_INIT_USER_EMAIL=admin@example.com
LANGFUSE_INIT_USER_PASSWORD=replace-with-a-strong-password
EOF

chmod 600 "$ENV_FILE"

echo "OK: wrote $ENV_FILE"
echo "Next: edit $ENV_FILE and replace any remaining placeholder secrets before deploying."
