#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_HOST_VALUE=""
DEPLOY_USER_VALUE=""
DEPLOY_PATH_VALUE=""
DEPLOY_PORT_VALUE="22"
SSH_KEY_FILE=""
ENV_FILE=""
WITH_OBSERVABILITY=false
CHECK_DNS=false
OUTPUT_MODE="gh"

usage() {
  cat <<'USAGE'
Usage: scripts/print-github-secrets-commands.sh --host HOST --user USER --path PATH --ssh-key-file FILE --env-file FILE [options]

Validates local launch inputs and prints safe GitHub CLI commands for setting
Actions deployment secrets. Secret file contents are never printed.

Required:
  --host HOST           Deployment server hostname or IPv4 address.
  --user USER           SSH user used for deployment.
  --path PATH           Absolute deployment path, for example /srv/shouka-blog.
  --ssh-key-file FILE   Private SSH key file for DEPLOY_SSH_KEY.
  --env-file FILE       Production env file for DEPLOY_ENV.

Options:
  --port PORT           SSH port. Defaults to 22.
  --manual              Print a GitHub web UI checklist instead of gh commands.
  --observability       Validate Langfuse bootstrap values in the env file.
  --check-dns           Validate SITE_DOMAIN DNS resolution before printing.
  -h, --help            Show this help.
USAGE
}

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

shell_quote() {
  printf '%q' "$1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      [[ $# -ge 2 ]] || fail "--host requires a value"
      DEPLOY_HOST_VALUE="$2"
      shift 2
      ;;
    --user)
      [[ $# -ge 2 ]] || fail "--user requires a value"
      DEPLOY_USER_VALUE="$2"
      shift 2
      ;;
    --path)
      [[ $# -ge 2 ]] || fail "--path requires a value"
      DEPLOY_PATH_VALUE="$2"
      shift 2
      ;;
    --port)
      [[ $# -ge 2 ]] || fail "--port requires a value"
      DEPLOY_PORT_VALUE="$2"
      shift 2
      ;;
    --manual)
      OUTPUT_MODE="manual"
      shift
      ;;
    --ssh-key-file)
      [[ $# -ge 2 ]] || fail "--ssh-key-file requires a value"
      SSH_KEY_FILE="$2"
      shift 2
      ;;
    --env-file)
      [[ $# -ge 2 ]] || fail "--env-file requires a value"
      ENV_FILE="$2"
      shift 2
      ;;
    --observability)
      WITH_OBSERVABILITY=true
      shift
      ;;
    --check-dns)
      CHECK_DNS=true
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

[[ -n "$DEPLOY_HOST_VALUE" ]] || fail "--host is required"
[[ -n "$DEPLOY_USER_VALUE" ]] || fail "--user is required"
[[ -n "$DEPLOY_PATH_VALUE" ]] || fail "--path is required"
[[ -n "$SSH_KEY_FILE" ]] || fail "--ssh-key-file is required"
[[ -n "$ENV_FILE" ]] || fail "--env-file is required"
[[ -f "$SSH_KEY_FILE" ]] || fail "missing SSH key file: $SSH_KEY_FILE"
[[ -f "$ENV_FILE" ]] || fail "missing env file: $ENV_FILE"

cd "$ROOT_DIR"

ENV_CHECK_ARGS=(bash scripts/check-env-file.sh --file "$ENV_FILE")
if [[ "$CHECK_DNS" != true ]]; then
  ENV_CHECK_ARGS+=(--skip-dns)
fi
if [[ "$WITH_OBSERVABILITY" == true ]]; then
  ENV_CHECK_ARGS+=(--observability)
fi
"${ENV_CHECK_ARGS[@]}" >/dev/null

DEPLOY_HOST="$DEPLOY_HOST_VALUE" \
DEPLOY_USER="$DEPLOY_USER_VALUE" \
DEPLOY_PATH="$DEPLOY_PATH_VALUE" \
DEPLOY_PORT="$DEPLOY_PORT_VALUE" \
DEPLOY_SSH_KEY="$(cat "$SSH_KEY_FILE")" \
bash scripts/check-deploy-secrets.sh >/dev/null

if [[ "$OUTPUT_MODE" == "manual" ]]; then
  cat <<MANUAL
# Open GitHub repository settings:
# Settings > Secrets and variables > Actions > Repository secrets
#
# Add or update these repository secrets. File contents are referenced by path
# and are not printed here.
DEPLOY_HOST = $DEPLOY_HOST_VALUE
DEPLOY_USER = $DEPLOY_USER_VALUE
DEPLOY_PATH = $DEPLOY_PATH_VALUE
DEPLOY_PORT = $DEPLOY_PORT_VALUE
DEPLOY_SSH_KEY = contents of $(shell_quote "$SSH_KEY_FILE")
DEPLOY_ENV = contents of $(shell_quote "$ENV_FILE")
MANUAL
  exit 0
fi

cat <<COMMANDS
# Run these from the GitHub repository after reviewing the target values.
# Secret file contents are read from disk and are not printed here.
gh secret set DEPLOY_HOST --body $(shell_quote "$DEPLOY_HOST_VALUE")
gh secret set DEPLOY_USER --body $(shell_quote "$DEPLOY_USER_VALUE")
gh secret set DEPLOY_PATH --body $(shell_quote "$DEPLOY_PATH_VALUE")
gh secret set DEPLOY_PORT --body $(shell_quote "$DEPLOY_PORT_VALUE")
gh secret set DEPLOY_SSH_KEY < $(shell_quote "$SSH_KEY_FILE")
gh secret set DEPLOY_ENV < $(shell_quote "$ENV_FILE")
COMMANDS
