#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKIP_SMOKE=false

usage() {
  cat <<'USAGE'
Usage: scripts/verify-release.sh [--skip-smoke]

Runs the local release verification gate:
  - deployment asset checks
  - shell syntax checks
  - frontend package-lock dependency consistency
  - frontend SEO metadata check
  - deploy secret validation tests
  - remote server check tests
  - domain routing tests
  - deploy dry-run tests
  - launch readiness tests
  - frontend unit tests
  - frontend production build
  - frontend bundle size check
  - backend tests
  - production smoke test with browser render checks

Options:
  --skip-smoke  Skip the local production smoke test
  -h, --help    Show this help
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --skip-smoke) SKIP_SMOKE=true ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

run() {
  echo "+ $*"
  "$@"
}

cd "$ROOT_DIR"

run bash scripts/check-deploy-assets.sh
run bash -n \
  scripts/check-frontend-seo.sh \
  scripts/check-frontend-bundles.sh \
  scripts/check-frontend-render.sh \
  scripts/verify-public-site.sh \
  scripts/setup-server-env.sh \
  scripts/check-env-file.sh \
  scripts/test-env-file.sh \
  scripts/check-deploy-secrets.sh \
  scripts/test-deploy-secrets.sh \
  scripts/check-github-secrets.sh \
  scripts/test-github-secrets.sh \
  scripts/print-github-secrets-commands.sh \
  scripts/test-print-github-secrets-commands.sh \
  scripts/check-remote-server.sh \
  scripts/test-remote-server-check.sh \
  scripts/check-domain-routing.sh \
  scripts/test-domain-routing.sh \
  scripts/test-deploy-dry-run.sh \
  scripts/test-deploy-preflight.sh \
  scripts/test-deploy-retry.sh \
  scripts/rollback-env.sh \
  scripts/test-rollback-env.sh \
  scripts/test-launch-readiness.sh \
  scripts/check-launch-readiness.sh \
  scripts/check-deploy-assets.sh \
  scripts/smoke-production.sh \
  scripts/smoke-caddy-proxy.sh \
  scripts/deploy.sh \
  scripts/deploy-preflight.sh \
  scripts/verify-release.sh
run node scripts/check-frontend-lockfile.mjs
run bash scripts/check-frontend-seo.sh
run bash scripts/test-env-file.sh
run bash scripts/test-deploy-secrets.sh
run bash scripts/test-github-secrets.sh
run bash scripts/test-print-github-secrets-commands.sh
run bash scripts/test-remote-server-check.sh
run bash scripts/test-domain-routing.sh
run bash scripts/test-deploy-dry-run.sh
run bash scripts/test-deploy-preflight.sh
run bash scripts/test-deploy-retry.sh
run bash scripts/test-rollback-env.sh
run bash scripts/test-launch-readiness.sh
run npm --prefix frontend test
run npm --prefix frontend run build
run bash scripts/check-frontend-bundles.sh
run uv --directory backend run pytest -q

if [[ "$SKIP_SMOKE" == true ]]; then
  echo "SKIP: production smoke test"
else
  run bash scripts/smoke-production.sh --skip-build
fi

echo "Release verification complete."
