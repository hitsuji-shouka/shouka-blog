#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_RELEASE=true
RUN_PREFLIGHT=true
RUN_PUBLIC=true
RUN_GITHUB_SECRETS=false
RUN_REMOTE_SERVER=false
RUN_DOMAIN_ROUTING=false
REQUIRE_DEPLOY_ENV=false
PULL_IMAGES=false
SKIP_DNS=false
WITH_OBSERVABILITY=false
CHECK_PORTS=false
SITE_ORIGIN=""
EXPECTED_VERSION=""
EXPECT_CADDY_HEADERS=false

usage() {
  cat <<'USAGE'
Usage: scripts/check-launch-readiness.sh [options]

Runs the checks that matter before or after a public launch.

Default checks:
  - local release gate: scripts/verify-release.sh
  - server preflight: scripts/deploy-preflight.sh

Options:
  --site-origin URL   Also verify a deployed public origin, for example https://shouka.blog
  --expected-version V Verify /api/version returns this exact app version
  --expect-caddy-headers
                      Also verify Caddy security and cache headers
  --github-secrets    Also verify required GitHub Actions secret names
  --require-deploy-env
                      Require DEPLOY_ENV when checking GitHub secret names
  --remote-server     Also SSH into DEPLOY_HOST and check server dependencies
  --domain-routing    Also check SITE_DOMAIN resolves to DEPLOY_HOST
  --observability     Require and preflight optional Langfuse services
  --check-ports       Fail if remote ports 80 or 443 already have listeners
  --pull-images       Include Docker Hub deployment image pulls during preflight
  --skip-dns          Skip DNS checks for local dry-runs only
  --skip-release      Skip local release verification
  --skip-preflight    Skip server preflight
  --skip-public       Skip public verification even when --site-origin is provided
  -h, --help          Show this help
USAGE
}

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

run() {
  echo "+ $*"
  "$@"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --site-origin)
      [[ $# -ge 2 ]] || fail "--site-origin requires a value"
      SITE_ORIGIN="${2%/}"
      shift 2
      ;;
    --expected-version)
      [[ $# -ge 2 ]] || fail "--expected-version requires a value"
      EXPECTED_VERSION="$2"
      shift 2
      ;;
    --expect-caddy-headers)
      EXPECT_CADDY_HEADERS=true
      shift
      ;;
    --github-secrets)
      RUN_GITHUB_SECRETS=true
      shift
      ;;
    --require-deploy-env)
      REQUIRE_DEPLOY_ENV=true
      shift
      ;;
    --remote-server)
      RUN_REMOTE_SERVER=true
      shift
      ;;
    --domain-routing)
      RUN_DOMAIN_ROUTING=true
      shift
      ;;
    --observability)
      WITH_OBSERVABILITY=true
      shift
      ;;
    --check-ports)
      CHECK_PORTS=true
      shift
      ;;
    --pull-images)
      PULL_IMAGES=true
      shift
      ;;
    --skip-dns)
      SKIP_DNS=true
      shift
      ;;
    --skip-release)
      RUN_RELEASE=false
      shift
      ;;
    --skip-preflight)
      RUN_PREFLIGHT=false
      shift
      ;;
    --skip-public)
      RUN_PUBLIC=false
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

if [[ -n "$SITE_ORIGIN" && "$SITE_ORIGIN" != http://* && "$SITE_ORIGIN" != https://* ]]; then
  fail "--site-origin must include http:// or https://"
fi

cd "$ROOT_DIR"

if [[ "$RUN_RELEASE" == true ]]; then
  run bash scripts/verify-release.sh
else
  echo "SKIP: local release verification"
fi

if [[ "$RUN_PREFLIGHT" == true && ! -f "$ROOT_DIR/.env" && "$RUN_REMOTE_SERVER" == true ]]; then
  echo "SKIP: local server preflight because .env is absent; remote server checks will be used"
elif [[ "$RUN_PREFLIGHT" == true ]]; then
  PREFLIGHT_ARGS=(bash scripts/deploy-preflight.sh)
  if [[ "$WITH_OBSERVABILITY" == true ]]; then
    PREFLIGHT_ARGS+=(--observability)
  fi
  if [[ "$PULL_IMAGES" == true ]]; then
    PREFLIGHT_ARGS+=(--pull-images)
  fi
  if [[ "$SKIP_DNS" == true ]]; then
    PREFLIGHT_ARGS+=(--skip-dns)
  fi
  run "${PREFLIGHT_ARGS[@]}"
else
  echo "SKIP: server preflight"
fi

if [[ "$RUN_GITHUB_SECRETS" == true ]]; then
  GITHUB_SECRET_ARGS=(bash scripts/check-github-secrets.sh)
  if [[ "$REQUIRE_DEPLOY_ENV" == true ]]; then
    GITHUB_SECRET_ARGS+=(--require-deploy-env)
  fi
  run "${GITHUB_SECRET_ARGS[@]}"
elif [[ "$REQUIRE_DEPLOY_ENV" == true ]]; then
  fail "--require-deploy-env requires --github-secrets"
fi

if [[ "$RUN_REMOTE_SERVER" == true ]]; then
  REMOTE_SERVER_ARGS=(bash scripts/check-remote-server.sh)
  if [[ "$RUN_DOMAIN_ROUTING" == true ]]; then
    REMOTE_SERVER_ARGS+=(--domain-routing)
  fi
  if [[ "$PULL_IMAGES" == true ]]; then
    REMOTE_SERVER_ARGS+=(--pull-images)
  fi
  if [[ "$WITH_OBSERVABILITY" == true ]]; then
    REMOTE_SERVER_ARGS+=(--observability)
  fi
  if [[ "$CHECK_PORTS" == true ]]; then
    REMOTE_SERVER_ARGS+=(--check-ports)
  fi
  run "${REMOTE_SERVER_ARGS[@]}"
elif [[ "$RUN_DOMAIN_ROUTING" == true ]]; then
  run bash scripts/check-domain-routing.sh
fi

if [[ -n "$SITE_ORIGIN" && "$RUN_PUBLIC" == true ]]; then
  PUBLIC_ENV=(env)
  if [[ -n "$EXPECTED_VERSION" ]]; then
    PUBLIC_ENV+=(EXPECTED_APP_VERSION="$EXPECTED_VERSION")
  fi
  if [[ "$EXPECT_CADDY_HEADERS" == true ]]; then
    PUBLIC_ENV+=(EXPECT_CADDY_HEADERS=1)
  fi
  run "${PUBLIC_ENV[@]}" bash scripts/verify-public-site.sh "$SITE_ORIGIN"
  run bash scripts/check-frontend-render.sh "$SITE_ORIGIN"
elif [[ -z "$SITE_ORIGIN" ]]; then
  echo "NEXT: after deployment, rerun with --site-origin https://your-domain.com"
else
  echo "SKIP: public origin verification"
fi

echo "Launch readiness checks complete."
