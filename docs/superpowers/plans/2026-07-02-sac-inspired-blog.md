# Sac-Inspired Blog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update shouka.blog to borrow the editorial personal-site structure of sac-ai.com while preserving the existing FastAPI blog, article API, and assistant features, then make deployment explicit.

**Architecture:** Keep the current React + FastAPI deployment shape. Replace the current space-themed home page with a sac-ai-inspired editorial home: Hero, About, Writing, Build, and Contact sections. Keep category pages, post pages, chat/RAG API, Docker, and Caddy as the deployable production path.

**Tech Stack:** React 18, React Router, Ant Design, Framer Motion, FastAPI, Docker, Caddy.

---

### Task 1: Editorial Home Shell

**Files:**
- Modify: `frontend/src/pages/Home.tsx`
- Modify: `frontend/src/index.css`

- [ ] **Step 1: Build the home page data model in `Home.tsx`**

Create derived lists from existing posts: latest post, writing highlights, category counts, and build cards.

- [ ] **Step 2: Replace the current hero/feed markup**

Render Hero, About, Writing, Build, and Contact sections using existing post data and `Link` navigation. Keep loading and empty states.

- [ ] **Step 3: Add editorial CSS**

Introduce paper background, black/orange tokens, rail/crosshair details, serif display headings, dense content rows, and responsive layout.

- [ ] **Step 4: Verify**

Run: `npm run build`

Expected: TypeScript and Vite build exit 0.

### Task 2: Navigation and Assistant Fit

**Files:**
- Modify: `frontend/src/main.tsx`
- Modify: `frontend/src/components/AssistantPanel.tsx`
- Modify: `frontend/src/index.css`

- [ ] **Step 1: Update top navigation**

Use anchor links for home sections on the home page and keep route links for category pages.

- [ ] **Step 2: Restyle the assistant**

Keep existing chat behavior, but change the visual identity from TARS/space to a compact editorial Agent widget that matches the paper theme.

- [ ] **Step 3: Verify interaction**

Open the home page in the browser, verify nav links scroll, category links route, and assistant opens/closes on desktop and mobile.

### Task 3: Deployment Documentation and Config

**Files:**
- Modify: `README.md`
- Modify: `Caddyfile`
- Optionally create: `.env.example`

- [ ] **Step 1: Document production deployment**

Explain Docker Compose deployment, domain replacement, required secrets, and first-run commands.

- [ ] **Step 2: Make domain configurable enough for launch**

Keep `Caddyfile` simple but document replacing `shoka.example.com` with the real domain.

- [ ] **Step 3: Verify container build path**

Run: `docker compose config` and, if available, `docker compose build app`.

Expected: Compose config parses; app image builds.
