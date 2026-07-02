# shouka.blog

融入 agent 能力的个人博客。站点参考 [sac-ai.com](https://sac-ai.com/) 的个人主页表达方式：首屏建立个人品牌，首页串起 About / Writing / Build / Contact，文章与分类页继续作为可检索的内容归档。

## 结构

- `content/` - Markdown 文章，Git 即存储
- `backend/` - FastAPI，只读加载文章，提供文章 API、分类 API、RAG 聊天 API
- `frontend/` - Vite + React + TypeScript，首页、分类页、文章页、站内 Agent
- `docs/` - PRD、system design、实施计划
- `Dockerfile` - 前端构建 + 后端运行的一体化镜像
- `docker-compose.yml` / `Caddyfile` - 生产部署入口

## 本地开发

```bash
cd backend
uv sync
uv run uvicorn main:app --reload
```

```bash
cd frontend
npm install
npm run dev
```

前端默认通过 Vite 代理访问后端 `/api`。

## 生产部署

部署形态是 Docker Compose：

1. 前端先构建成静态文件。
2. FastAPI 容器托管 `/api` 和前端 `dist`。
3. Caddy 负责公网 80/443、HTTPS 证书和反向代理。

### 1. 准备服务器

服务器需要：

- Docker 和 Docker Compose
- rsync
- 一个解析到服务器公网 IP 的域名
- 开放 80 和 443 端口

`SITE_DOMAIN` 要填写裸域名，例如 `shouka.blog`，不要带 `https://` 或路径。预检会默认检查这个域名是否已经能解析；本地 dry-run 演练可以跳过 DNS 检查。这个值会同时提供给 Caddy 和 app 容器，Caddy 用它申请证书，app 用它生成 sitemap、RSS 和分享卡片里的公开 URL。

### 2. 配置环境变量

服务器上推荐用初始化脚本生成生产 `.env`：

```bash
bash scripts/setup-server-env.sh --domain your-domain.com
```

如果要同时写入模型密钥：

```bash
bash scripts/setup-server-env.sh \
  --domain your-domain.com \
  --deepseek-key your-chat-model-key \
  --embed-key your-embedding-key
```

也可以手动复制示例配置：

```bash
cp .env.example .env
```

至少修改：

```bash
SITE_DOMAIN=your-domain.com
BLOG_DEEPSEEK_KEY=your-chat-model-key
BLOG_EMBED_KEY=your-embedding-key
```

如果暂时不配置模型密钥，博客文章浏览仍可用，站内 Agent 会在调用模型时返回不可用提示。

默认部署不会启动 Langfuse，博客和站内 Agent 可独立运行。如果要启用内置 Langfuse，请同时修改 `.env` 中所有 `LANGFUSE_*` 默认值，尤其是数据库密码、`NEXTAUTH_SECRET`、`SALT` 和初始管理员密码。只在内网使用时，也建议换成强随机值。

### 3. 预检

第一次公开上线前，先按 [docs/launch-checklist.md](docs/launch-checklist.md) 逐项确认服务器、域名、Secrets、验证命令和回滚路径。

部署前建议先跑完整 release 验收：

```bash
bash scripts/verify-release.sh
```

它会检查部署资产、前端 lockfile 一致性、前端 SEO 元信息、前端测试、前端生产构建、JS bundle 体积、后端测试、本地生产形态冒烟，以及 Chromium 中的桌面/移动端真实渲染。GitHub Actions 还会额外运行 `npm --prefix frontend audit --audit-level=high`，阻止高危或严重级别的前端依赖审计项进入部署。

首次运行浏览器渲染检查前，本机需要安装 Playwright Chromium：

```bash
npx --prefix frontend playwright install chromium
```

如果只想单独做一次生产形态冒烟测试：

```bash
bash scripts/smoke-production.sh
```

它会构建前端、启动 FastAPI，并检查 `/api/health`、`/api/posts`、首页 HTML、桌面/移动端浏览器渲染、`robots.txt` 和 `sitemap.xml`。

如果要在本机提前验证 Caddy 反向代理路径，可以跑：

```bash
bash scripts/smoke-caddy-proxy.sh
```

它会用 Docker Compose 启动 app 和 Caddy，通过真实 Caddyfile 访问站点，检查 Caddy 安全头、缓存策略、公开 SEO 元信息，以及桌面/移动端浏览器渲染。GitHub Actions 在发布验证中也会自动跑这一步。

先运行快速预检：

```bash
bash scripts/deploy-preflight.sh
```

如果只是用临时域名做本地部署演练：

```bash
bash scripts/deploy-preflight.sh --skip-dns
```

默认预检会拒绝非空的 placeholder 密钥值，但允许模型密钥和 Langfuse 追踪密钥留空。启用内置 Langfuse 观测面板前，请用 observability 模式检查所有 bootstrap 密钥都已经替换：

```bash
bash scripts/deploy-preflight.sh --observability
```

如果这是服务器上的首次部署，建议额外检查 Docker Hub 部署镜像能否拉取：

```bash
bash scripts/deploy-preflight.sh --pull-images
```

也可以使用上线就绪总检查，把本地 release 验收和服务器预检串起来：

```bash
bash scripts/check-launch-readiness.sh --pull-images
```

部署完成后，带上公网地址再跑一次，它会额外检查公网 API、SEO 元信息和桌面/移动端真实浏览器渲染：

```bash
bash scripts/check-launch-readiness.sh \
  --skip-release \
  --skip-preflight \
  --site-origin https://your-domain.com \
  --expected-version expected-app-version \
  --expect-caddy-headers
```

`expected-app-version` 对应 `/api/version` 返回的部署版本；GitHub Actions 自动部署时通常就是本次提交 SHA。`--expect-caddy-headers` 会额外检查 HSTS、安全头和缓存策略。

### 4. 启动

推荐使用部署脚本，它会自动执行预检、启动服务并检查公网可访问性：

```bash
bash scripts/deploy.sh --pull-images
```

`scripts/deploy.sh --dry-run` 会自动跳过 DNS 检查，只打印将要执行的部署步骤；真实部署不会跳过。dry-run 不会创建部署锁、不会启动容器，完整 release 验收会检查这条彩排路径保持可用。

如果已经确认服务器能拉取部署镜像，可以省略 `--pull-images`：

```bash
bash scripts/deploy.sh
```

如果是在已经安装前端依赖和 Playwright Chromium 的本机手动部署，也可以让部署脚本在公网验证后顺手跑浏览器渲染检查：

```bash
bash scripts/deploy.sh --browser-check
```

服务器端自动部署不需要这个参数；GitHub Actions 会在 runner 侧安装前端依赖并单独执行公网浏览器检查。

启用 Langfuse 观测面板时使用：

```bash
bash scripts/deploy.sh --observability
```

也可以手动启动：

```bash
docker compose up -d --build
```

手动启用 Langfuse 观测面板时使用：

```bash
docker compose --profile observability up -d --build
```

Caddy 会根据 `SITE_DOMAIN` 自动申请 HTTPS 证书。证书数据和运行配置保存在 Docker named volumes 中，容器重建不会丢失。首次启动前请确认域名已经解析到这台服务器；预检通过 DNS 检查后再启动会更稳。生产容器使用 Docker `json-file` 日志轮转，单个日志文件上限 10MB、保留 3 份，避免长期运行时日志占满磁盘。

### 5. GitHub Actions 自动部署

仓库包含 `.github/workflows/deploy.yml`。它会在推送到 `main` 或手动运行时执行：

1. 前端生产构建。
2. 后端测试。
3. 部署资产检查。
4. 生产形态冒烟测试。
5. 安装 Playwright Chromium，并在真实浏览器中检查首页渲染。
6. 使用官方 Caddy 镜像解析验证 `Caddyfile`。
7. 构建 Docker 镜像，启动 CI 容器，并对容器暴露的站点做 API、SEO 和浏览器渲染检查。
8. 通过共享远程预检脚本检查 SSH、远程目录、`rsync`、Docker、Docker Compose、`.env` 状态，以及 `SITE_DOMAIN` 是否已经解析到 `DEPLOY_HOST`。
9. 同步代码到服务器，并在服务器执行 `bash scripts/deploy.sh`。
10. 远程部署完成后，从 GitHub runner 访问公网域名，再做一次版本、安全头和 Chromium 渲染检查。

在 GitHub 仓库的 Actions secrets 中配置：

```bash
DEPLOY_HOST=your-server-ip-or-host
DEPLOY_USER=your-server-user
DEPLOY_PATH=/srv/shouka-blog
DEPLOY_SSH_KEY=your-private-ssh-key
DEPLOY_PORT=22
DEPLOY_ENV=the-complete-production-env-file
```

`DEPLOY_HOST` 填服务器域名或 IPv4 地址，只使用字母、数字、点和连字符，不要带 `http://`、`https://` 或路径。`DEPLOY_USER` 填服务器用户名，只使用字母、数字、点、下划线和连字符，且不要以连字符开头。`DEPLOY_PATH` 必须是绝对路径，例如 `/srv/shouka-blog`，不要填 `/`，并且只使用字母、数字、斜杠、点、下划线和连字符。`DEPLOY_SSH_KEY` 填完整私钥内容，不是 `.pub` 公钥；Actions 会在连接服务器前先验证这份私钥能被解析。`DEPLOY_PORT` 可省略，默认使用 `22`；如果填写，必须是 `1` 到 `65535` 之间的数字。`DEPLOY_ENV` 也可省略；如果设置了它，Actions 会在部署前把它写入服务器的 `DEPLOY_PATH/.env` 并设为 `600` 权限。如果不设置 `DEPLOY_ENV`，服务器上的 `DEPLOY_PATH/.env` 需要提前存在。Actions 会从服务器 `.env` 读取 `SITE_DOMAIN`，用于远程部署后的公网验证。

`DEPLOY_SSH_KEY` 对应的公钥必须提前放到服务器上 `DEPLOY_USER` 的 `~/.ssh/authorized_keys`。如果要新建一把专用部署 key，可以先运行：

```bash
ssh-keygen -t ed25519 -f ~/.ssh/shouka_blog_deploy -C shouka-blog-deploy
ssh-copy-id -i ~/.ssh/shouka_blog_deploy.pub your-server-user@your-server-ip-or-host
```

然后把 `~/.ssh/shouka_blog_deploy` 的完整私钥内容写入 GitHub secret `DEPLOY_SSH_KEY`。如果服务器没有 `ssh-copy-id`，就把 `.pub` 文件内容追加到服务器用户的 `~/.ssh/authorized_keys`。

如果配置了 `DEPLOY_ENV`，Actions 会先校验其中的 `SITE_DOMAIN`、placeholder 密钥和 observability 必填值；校验失败时不会继续写入服务器。写入服务器时会先落到 `DEPLOY_PATH/.env.next`，成功写完并设置 `600` 权限后再替换正式 `.env`，避免中途断线留下半份生产配置；失败路径会清理 `.env.next`，减少生产密钥副本残留。

当 Actions 需要用 `DEPLOY_ENV` 覆盖服务器 `.env` 时，会先把服务器现有文件保存为 `.env.previous` 并保持 `600` 权限，方便部署配置写错时找回上一份。

自动同步会刻意跳过仓库里的 `.env`、`.env.*`、部署锁、本地日志和 agent/GitHub 元数据，避免把本地配置或临时状态带到线上。

可以用脚本生成安全的 GitHub CLI 配置命令。脚本会先校验本地 `.env` 和私钥格式，但不会把私钥或 `DEPLOY_ENV` 内容打印出来：

```bash
bash scripts/print-github-secrets-commands.sh \
  --host your-server-ip-or-host \
  --user your-server-user \
  --path /srv/shouka-blog \
  --ssh-key-file ~/.ssh/your_deploy_key \
  --env-file ./production.env
```

确认输出里的服务器地址、用户和路径无误后，在仓库根目录运行这些 `gh secret set ...` 命令。DNS 已经生效时可加 `--check-dns`，启用 Langfuse 时可加 `--observability`。

如果本机没有安装 `gh`，可以加 `--manual` 输出 GitHub 网页界面的填写清单：

```bash
bash scripts/print-github-secrets-commands.sh \
  --manual \
  --host your-server-ip-or-host \
  --user your-server-user \
  --path /srv/shouka-blog \
  --ssh-key-file ~/.ssh/your_deploy_key \
  --env-file ./production.env
```

生成 `DEPLOY_ENV` 内容时，可以先在本地或服务器运行：

```bash
bash scripts/setup-server-env.sh --domain your-domain.com
```

然后把生成的 `.env` 完整复制到 GitHub secret `DEPLOY_ENV`。如果选择不使用 `DEPLOY_ENV`，就把这份 `.env` 留在服务器的 `DEPLOY_PATH/.env`。

如果只想为 GitHub Secret 生成一个本地文件，不想在仓库根目录留下 `.env`，可以直接输出到 `production.env`：

```bash
bash scripts/setup-server-env.sh --domain your-domain.com --output ./production.env
```

确认并编辑 `production.env` 后，再用它作为 `DEPLOY_ENV` 的来源。

把 GitHub secrets 写入前，可以先在本地用同一组环境变量检查格式：

```bash
DEPLOY_HOST=your-server-ip-or-host \
DEPLOY_USER=your-server-user \
DEPLOY_PATH=/srv/shouka-blog \
DEPLOY_PORT=22 \
DEPLOY_SSH_KEY="$(cat ~/.ssh/your_deploy_key)" \
bash scripts/check-deploy-secrets.sh
```

如果服务器已经准备好 SSH 访问，也可以在本地提前检查服务器依赖和远程目录：

```bash
DEPLOY_HOST=your-server-ip-or-host \
DEPLOY_USER=your-server-user \
DEPLOY_PATH=/srv/shouka-blog \
DEPLOY_PORT=22 \
DEPLOY_SSH_KEY="$(cat ~/.ssh/your_deploy_key)" \
bash scripts/check-remote-server.sh
```

如果没有设置 `DEPLOY_ENV`，远程预检会要求服务器上已经存在 `DEPLOY_PATH/.env`；如果设置了 `DEPLOY_ENV`，它会先本地校验这份内容，并跳过远程 `.env` 存在性检查，因为 Actions 部署时会写入它。

域名解析生效后，再确认 `SITE_DOMAIN` 已经指向部署服务器：

```bash
DEPLOY_HOST=your-server-ip-or-host \
bash scripts/check-domain-routing.sh --env-file .env
```

如果用 `DEPLOY_ENV` 管理生产配置，也可以把 `DEPLOY_ENV` 和 `DEPLOY_HOST` 一起放进环境变量后运行同一条检查。上线就绪总检查支持把远程服务器和域名指向一起跑：

```bash
bash scripts/check-launch-readiness.sh --remote-server --domain-routing --pull-images
```

同时启用 `--remote-server` 和 `--domain-routing` 时，如果没有本地 `.env` 或 `DEPLOY_ENV`，脚本会通过 SSH 读取服务器 `DEPLOY_PATH/.env` 中的 `SITE_DOMAIN` 再做解析对比。

首次部署前建议确认服务器预检通过：

```bash
bash scripts/deploy-preflight.sh --pull-images
```

确认 Docker、域名和部署镜像都正常后，再启用 Actions 自动部署。

如果构建长时间停在类似下面的输出：

```text
load metadata for docker.io/library/node:22-slim
load metadata for docker.io/library/python:3.12-slim
```

说明 Docker 正在等待部署镜像元数据，通常是服务器访问 Docker Hub 不通或过慢。先在服务器上配置 Docker 镜像源/代理，或手动执行：

```bash
docker pull node:22-slim
docker pull python:3.12-slim
```

这两条能完成后，再重新运行 `docker compose up -d --build`。

### 6. 检查

```bash
docker compose ps
docker compose logs -f app
docker compose logs -f caddy
```

浏览器打开：

```text
https://your-domain.com
```

公网整站验证：

```bash
bash scripts/verify-public-site.sh https://your-domain.com
bash scripts/check-frontend-render.sh https://your-domain.com
```

它会检查：

- `/api/health` 返回正常状态。
- `/api/version` 返回当前部署版本。
- `/api/posts` 返回文章 JSON。
- `/` 返回前端应用入口，并包含 title、description、canonical URL、Open Graph 和 Twitter card 元信息。
- 首页在桌面和移动端 Chromium 中能真实渲染，并且没有移动端横向溢出。
- `/robots.txt` 指向站点地图。
- `/sitemap.xml` 包含首页和文章 URL。
- `/feed.xml` 返回可订阅的 RSS 文章源。

通过 `scripts/deploy.sh` 部署时，还会额外检查 Caddy 提供的安全响应头和缓存策略。

如果公网验证最终失败，部署脚本会自动输出 `docker compose ps` 以及 `app`、`caddy` 的最近日志，方便直接定位容器启动、证书、反向代理或应用错误。

GitHub Actions 的远程部署如果在 runner 侧公网复核失败，也会回连服务器输出同样的 compose 状态和最近日志，避免只看到一个外部访问失败而缺少服务器现场信息。

单独查看部署版本：

```bash
curl https://your-domain.com/api/version
```

### 7. 发布新文章

把 Markdown 放进 `content/` 后重新部署：

```bash
git pull
docker compose up -d --build
```

## 当前设计方向

- 首页借鉴 sac-ai.com 的纸张质感、黑橙强调、强个人品牌首屏和分区导航。
- 保留现有博客能力，不改成纯静态站点，因为站内 Agent 和 RAG 需要后端。
- 上线优先使用 Docker + Caddy；Cloudflare Pages 这类纯静态部署只适合以后拆出无后端版本。
