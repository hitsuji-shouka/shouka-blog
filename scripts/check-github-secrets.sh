#!/usr/bin/env bash
set -euo pipefail

REQUIRE_DEPLOY_ENV=false

usage() {
  cat <<'USAGE'
Usage: scripts/check-github-secrets.sh [--require-deploy-env]

Checks that the current GitHub repository has the Actions secrets required
for automatic deployment. Only secret names are inspected; secret values are
never read or printed.

Required secrets:
  DEPLOY_HOST
  DEPLOY_USER
  DEPLOY_PATH
  DEPLOY_SSH_KEY

Optional secrets:
  DEPLOY_PORT
  DEPLOY_ENV

Options:
  --require-deploy-env  Fail when DEPLOY_ENV is not configured
  -h, --help            Show this help
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --require-deploy-env) REQUIRE_DEPLOY_ENV=true ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

has_secret() {
  local name="$1"
  printf '%s\n' "$SECRET_NAMES" | grep -Fxq "$name"
}

if ! command -v gh >/dev/null 2>&1; then
  cat >&2 <<'MSG'
FAIL: GitHub CLI gh is required to check repository secrets.

Install gh and run this check again, or set the secrets manually in GitHub:
Settings > Secrets and variables > Actions > Repository secrets.

To prepare safe gh secret set commands without printing private key or DEPLOY_ENV values, run:
bash scripts/print-github-secrets-commands.sh --host HOST --user USER --path /srv/shouka-blog --ssh-key-file ~/.ssh/your_deploy_key --env-file ./production.env
MSG
  exit 1
fi

SECRET_NAMES="$(gh secret list --json name --jq '.[].name')" || fail "unable to list GitHub Actions secrets"

for name in DEPLOY_HOST DEPLOY_USER DEPLOY_PATH DEPLOY_SSH_KEY; do
  if has_secret "$name"; then
    echo "OK: $name is configured"
  else
    fail "missing required GitHub secret: $name"
  fi
done

if has_secret DEPLOY_PORT; then
  echo "OK: DEPLOY_PORT is configured"
else
  echo "SKIP: DEPLOY_PORT is optional; SSH defaults to port 22"
fi

if has_secret DEPLOY_ENV; then
  echo "OK: DEPLOY_ENV is configured"
elif [[ "$REQUIRE_DEPLOY_ENV" == true ]]; then
  fail "missing required GitHub secret: DEPLOY_ENV"
else
  echo "SKIP: DEPLOY_ENV is optional when the server already has DEPLOY_PATH/.env"
fi

echo "GitHub Actions secret name check complete."
