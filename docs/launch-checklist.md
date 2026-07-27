# Launch Checklist

Use this checklist for the final public launch after the code has passed local release verification.

## 1. Server

- A Linux server is available and reachable by SSH.
- Docker and Docker Compose are installed on the server.
- The deploy user can create and write to `DEPLOY_PATH`, for example `/srv/shouka-blog`.
- The public half of `DEPLOY_SSH_KEY` is installed in `~/.ssh/authorized_keys` for `DEPLOY_USER`.
- Ports `80` and `443` are open to the public internet and not already occupied by another service before the first deploy.
- The server can pull Docker images from Docker Hub.

## 2. Domain

- `SITE_DOMAIN` is a bare domain such as `example.com`, without `https://` or a path.
- DNS `A` or `AAAA` records point `SITE_DOMAIN` to the deploy server.
- DNS has propagated before running the production deploy.

## 3. GitHub Secrets

Set these repository secrets before enabling automatic deployment:

- `DEPLOY_HOST`: server hostname or IPv4 address.
- `DEPLOY_USER`: SSH user used for deployment.
- `DEPLOY_PATH`: absolute remote path, for example `/srv/shouka-blog`.
- `DEPLOY_SSH_KEY`: private SSH key for `DEPLOY_USER`.
- `DEPLOY_PORT`: optional SSH port. Defaults to `22` when empty.
- `DEPLOY_ENV`: optional full production `.env` content. If omitted, `DEPLOY_PATH/.env` must already exist on the server.

`DEPLOY_ENV` must include `SITE_DOMAIN`. Optional model and tracing keys may stay empty, but placeholder values such as `change-me` should be replaced before production use.

If you create a new deploy key, keep the private key for `DEPLOY_SSH_KEY` and install the public key on the server:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/shouka_blog_deploy -C shouka-blog-deploy
ssh-copy-id -i ~/.ssh/shouka_blog_deploy.pub your-server-user@your-server-ip-or-host
```

If `ssh-copy-id` is unavailable, append the `.pub` file contents to `~/.ssh/authorized_keys` for `DEPLOY_USER` on the server.

Generate a local `DEPLOY_ENV` source file without creating a root `.env`:

```bash
bash scripts/setup-server-env.sh --domain your-domain.com --output ./production.env
```

Edit `production.env` and replace any placeholder values before uploading it as a secret.

After setting repository secrets, verify the secret names without printing values:

```bash
bash scripts/check-github-secrets.sh
```

If GitHub Actions should manage the server `.env`, require `DEPLOY_ENV` too:

```bash
bash scripts/check-github-secrets.sh --require-deploy-env
```

To generate safe GitHub CLI commands without printing the private key or `DEPLOY_ENV` contents, run:

```bash
bash scripts/print-github-secrets-commands.sh \
  --host your-server-ip-or-host \
  --user your-server-user \
  --path /srv/shouka-blog \
  --ssh-key-file ~/.ssh/your_deploy_key \
  --env-file ./production.env
```

Review the printed commands, then run them from this repository. Add `--check-dns` when DNS has propagated, and add `--observability` if the deployment uses Langfuse.

If `gh` is not installed, add `--manual` and use the printed checklist in GitHub's web UI:

```bash
bash scripts/print-github-secrets-commands.sh \
  --manual \
  --host your-server-ip-or-host \
  --user your-server-user \
  --path /srv/shouka-blog \
  --ssh-key-file ~/.ssh/your_deploy_key \
  --env-file ./production.env
```

## 4. Preflight

Run these checks before the first public deploy:

```bash
bash scripts/verify-release.sh
bash scripts/check-launch-readiness.sh --github-secrets --remote-server --domain-routing --pull-images --check-ports
```

If GitHub Actions should manage the server `.env`, add `--require-deploy-env`.

If the launch will use `observability=true`, add `--observability` so Langfuse bootstrap values are checked from `DEPLOY_ENV` or the server `.env`, and remote observability images are checked too.

Use `--check-ports` before the first deploy to catch another service already occupying `80` or `443`. Omit it for routine redeploys after Caddy is already running.

When this command is run from a local machine without a local `.env`, it skips local server preflight and uses the remote server checks instead. With `--pull-images`, image pulls are verified on the deployment server.

If Docker Hub access is slow or blocked, fix the server mirror or proxy first, then retry the readiness check.

## 5. Deploy

Manual server deploy:

```bash
bash scripts/deploy.sh --pull-images
```

Only use `--browser-check` from a machine that has frontend dependencies and Playwright Chromium installed:

```bash
bash scripts/deploy.sh --browser-check
```

Do not require `--browser-check` on the production server. GitHub Actions runs browser rendering checks from the runner after the remote deploy.

GitHub Actions deploy:

- Push to `main`, or run the `Deploy Blog` workflow manually.
- Leave `skip_health` as `false` for real launches.
- Use `observability=true` only when Langfuse bootstrap secrets are configured.

## 6. Public Verification

After deploy, verify the live site from outside the server:

```bash
bash scripts/verify-public-site.sh https://your-domain.com
bash scripts/check-frontend-render.sh https://your-domain.com
```

The checks must pass for `/api/health`, `/api/version`, `/api/posts`, the frontend shell, canonical URL, Open Graph and Twitter metadata, share image asset, `robots.txt`, `sitemap.xml`, `feed.xml`, and mobile/desktop rendering.

## 7. Rollback

If the deploy fails after writing a new server env file:

- The previous server env is saved as `DEPLOY_PATH/.env.previous`.
- From inside `DEPLOY_PATH`, run:

```bash
bash scripts/rollback-env.sh
```

- The current failed `.env` is saved as `.env.rollback-current` before `.env.previous` is restored.
- Use `bash scripts/rollback-env.sh --browser-check` only from a machine that has frontend dependencies and Playwright Chromium installed.
- Check `docker compose ps`, `docker compose logs --tail=120 app`, and `docker compose logs --tail=120 caddy` if rollback verification fails.

If public verification fails, do not mark the launch complete until `scripts/verify-public-site.sh` and `scripts/check-frontend-render.sh` both pass against the real domain.
