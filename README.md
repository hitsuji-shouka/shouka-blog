# shoka-blog

融入 agent 能力的个人博客。本期（REQ-20260612-01）仅含博客本体：本地写 Markdown、git push 即发布，FastAPI 全量驻内存只读 + React 前端。

## 结构
- `content/` — 文章 `.md`，git 即存储
- `backend/` — FastAPI（main/posts/models/config），扫 content 进内存
- `frontend/` — Vite + React + TS，三页 + 悬浮助理空壳 + 五平台嵌入
- `docs/` — PRD 与 system-design
- `Caddyfile` · `Dockerfile` — 部署

## 本地开发
```bash
cd backend && uv sync && uv run uvicorn main:app --reload   # :8000
cd frontend && npm i && npm run dev                          # :5173 代理 /api
```
