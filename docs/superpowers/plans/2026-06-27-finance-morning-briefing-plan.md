# Finance Morning Briefing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a daily finance morning briefing pipeline that reads structured news/OpenClaw output, summarizes it with the configured chat model, generates MiniMax TTS audio, writes a Markdown post with audio metadata, and can publish it by git.

**Architecture:** Keep generation local in `pipeline/`, keep serving simple in `backend/` and `frontend/`. MiniMax becomes the primary chat/TTS key when `BLOG_MINIMAX_API_KEY` is set, with DeepSeek kept only as a fallback for existing environments.

**Tech Stack:** Python 3.11, standard library HTTP/XML/JSON/TOML parsing, existing OpenAI-compatible chat client, React + Ant Design + Vitest, pytest.

---

## File Structure

- Modify `backend/config.py`: add MiniMax chat/TTS settings.
- Modify `backend/llm.py`: choose MiniMax chat key/base/model when configured.
- Add `backend/tests/test_llm_config.py`: verify MiniMax key takes precedence and DeepSeek fallback remains.
- Modify `backend/models.py`: add optional `audio` and `sources` metadata.
- Modify `backend/posts.py`: parse `audio` and `sources` from frontmatter.
- Modify `backend/tests/test_models.py` and `backend/tests/test_api.py`: cover audio metadata.
- Add `pipeline/news.py`: load OpenClaw JSON, load source config, parse RSS/Atom items, filter recent items, dedupe.
- Add `pipeline/tests/test_news.py`: cover OpenClaw input, RSS parsing, recent filtering, dedupe.
- Add `pipeline/minimax_tts.py`: MiniMax TTS request builder, response audio decoding, mp3 writer.
- Add `pipeline/tests/test_minimax_tts.py`: cover request shape and hex/base64 audio decoding.
- Add `pipeline/publish.py`: stage/commit/push selected generated paths only.
- Add `pipeline/tests/test_publish.py`: cover skip-empty publish and selected path commands using a fake runner.
- Modify `pipeline/summarize.py`: add article + podcast-script summarization for news items and use selected chat model.
- Modify `pipeline/report.py`: support `audio`, extra tags, and sources in frontmatter.
- Modify `pipeline/run.py`: add CLI args for news mode, OpenClaw input, audio, publish, idempotency, and minimum news count.
- Add `pipeline/sources.toml`: editable seed finance sources.
- Modify `pipeline/tests/test_report.py`: cover audio/sources frontmatter.
- Modify `frontend/src/lib/types.ts`: add `audio` and `sources`.
- Add `frontend/src/components/PostAudio.tsx` and `frontend/src/components/PostAudio.test.tsx`: reusable player.
- Modify `frontend/src/pages/Post.tsx`: render audio player above Markdown.
- Modify `frontend/src/components/PostCard.tsx` and `frontend/src/components/PostCard.test.tsx`: show a compact “可听” marker for audio posts.

## Task 1: MiniMax Chat Configuration

**Files:**
- Modify: `backend/config.py`
- Modify: `backend/llm.py`
- Create: `backend/tests/test_llm_config.py`

- [ ] **Step 1: Write failing tests**

Add tests that call a new pure helper `resolve_chat_config(settings_like)` and assert MiniMax takes precedence while DeepSeek remains fallback.

- [ ] **Step 2: Run test to verify RED**

Run: `uv run pytest tests/test_llm_config.py -v` from `backend/`.

Expected: fail because `resolve_chat_config` does not exist.

- [ ] **Step 3: Implement settings and helper**

Add MiniMax settings to `Settings` and update `_chat` / `stream_chat` to use resolved chat config.

- [ ] **Step 4: Run test to verify GREEN**

Run: `uv run pytest tests/test_llm_config.py -v`.

Expected: pass.

## Task 2: Audio Metadata Through Backend

**Files:**
- Modify: `backend/models.py`
- Modify: `backend/posts.py`
- Modify: `backend/tests/test_models.py`
- Modify: `backend/tests/test_api.py`

- [ ] **Step 1: Write failing tests**

Add assertions that `PostMeta` defaults `audio` to `None` and `sources` to `[]`, and that a parsed post returns `audio` and `sources` from frontmatter.

- [ ] **Step 2: Run focused backend tests to verify RED**

Run: `uv run pytest tests/test_models.py tests/test_api.py -v`.

Expected: fail because `audio` and `sources` fields are not parsed.

- [ ] **Step 3: Implement metadata parsing**

Add fields `audio: str | None = None` and `sources: list[str] = []`; pass `audio=fm.get("audio")` and `sources=fm.get("sources") or []` in `posts._parse`.

- [ ] **Step 4: Run focused backend tests to verify GREEN**

Run: `uv run pytest tests/test_models.py tests/test_api.py -v`.

Expected: pass.

## Task 3: News Input and Deduplication

**Files:**
- Create: `pipeline/news.py`
- Create: `pipeline/tests/test_news.py`

- [ ] **Step 1: Write failing tests**

Cover OpenClaw JSON object input, RSS item parsing, recent filtering, and URL dedupe.

- [ ] **Step 2: Run tests to verify RED**

Run: `python -m pytest pipeline/tests/test_news.py -v` from repo root.

Expected: fail because `pipeline.news` does not exist.

- [ ] **Step 3: Implement news helpers**

Use dataclasses `NewsSource` and `NewsItem`, `tomllib`, `json`, `xml.etree.ElementTree`, and `email.utils.parsedate_to_datetime`. Do not add dependencies.

- [ ] **Step 4: Run tests to verify GREEN**

Run: `python -m pytest pipeline/tests/test_news.py -v`.

Expected: pass.

## Task 4: MiniMax TTS

**Files:**
- Create: `pipeline/minimax_tts.py`
- Create: `pipeline/tests/test_minimax_tts.py`

- [ ] **Step 1: Write failing tests**

Test that `synthesize_to_file("hello", out, settings, transport=fake)` writes bytes from a fake MiniMax JSON response and sends the expected Authorization header.

- [ ] **Step 2: Run tests to verify RED**

Run: `python -m pytest pipeline/tests/test_minimax_tts.py -v`.

Expected: fail because module does not exist.

- [ ] **Step 3: Implement TTS writer**

Build a JSON request with model, text, voice settings, and mp3 audio settings. Decode `data.audio` as hex first, then base64. Write bytes after creating the parent directory.

- [ ] **Step 4: Run tests to verify GREEN**

Run: `python -m pytest pipeline/tests/test_minimax_tts.py -v`.

Expected: pass.

## Task 5: Report Frontmatter and Publish

**Files:**
- Modify: `pipeline/report.py`
- Modify: `pipeline/tests/test_report.py`
- Create: `pipeline/publish.py`
- Create: `pipeline/tests/test_publish.py`

- [ ] **Step 1: Write failing tests**

Extend `report.render` tests to expect `audio: /audio/finance-20260627.mp3`, tags `[每日报告, 理财早报]`, and `sources` list. Add publish tests with a fake runner that records `git add`, `git commit`, and optional `git push`.

- [ ] **Step 2: Run tests to verify RED**

Run: `python -m pytest pipeline/tests/test_report.py pipeline/tests/test_publish.py -v`.

Expected: fail because new parameters and publish module are missing.

- [ ] **Step 3: Implement report and publish changes**

Keep `report.write` backward compatible. Add optional `tags`, `audio`, and `sources`. `publish.publish(paths, message, push=True, runner=subprocess.run)` should only add existing paths, skip empty path lists, commit selected files, and push only when requested.

- [ ] **Step 4: Run tests to verify GREEN**

Run: `python -m pytest pipeline/tests/test_report.py pipeline/tests/test_publish.py -v`.

Expected: pass.

## Task 6: News Summarization and CLI

**Files:**
- Modify: `pipeline/summarize.py`
- Modify: `pipeline/run.py`
- Create: `pipeline/sources.toml`
- Add or modify: `pipeline/tests/test_run.py`

- [ ] **Step 1: Write failing tests**

Add tests for the CLI-level orchestration using monkeypatches: successful news + audio write, idempotent skip without `--force`, and insufficient-news skip.

- [ ] **Step 2: Run tests to verify RED**

Run: `python -m pytest pipeline/tests/test_run.py -v`.

Expected: fail because `run.main` has no CLI args/news mode.

- [ ] **Step 3: Implement summarization and CLI**

Add `summarize_news(items, domain="金融") -> dict[str, str]` returning `{"article": ..., "script": ...}`. Add argparse to `run.py` while preserving `python pipeline/run.py finance` legacy behavior. In news mode, use OpenClaw input if provided, otherwise fetch sources from `sources.toml`.

- [ ] **Step 4: Run tests to verify GREEN**

Run: `python -m pytest pipeline/tests/test_run.py -v`.

Expected: pass.

## Task 7: Frontend Audio UI

**Files:**
- Modify: `frontend/src/lib/types.ts`
- Create: `frontend/src/components/PostAudio.tsx`
- Create: `frontend/src/components/PostAudio.test.tsx`
- Modify: `frontend/src/pages/Post.tsx`
- Modify: `frontend/src/components/PostCard.tsx`
- Modify: `frontend/src/components/PostCard.test.tsx`

- [ ] **Step 1: Write failing tests**

Add a PostAudio static render test that expects an `<audio controls>` with the supplied src. Add a PostCard test that an audio post renders “可听”.

- [ ] **Step 2: Run frontend tests to verify RED**

Run: `npm test -- PostAudio PostCard`.

Expected: fail because `PostAudio` and `audio` support do not exist.

- [ ] **Step 3: Implement audio UI**

Add optional `audio?: string | null` and `sources?: string[]` to TS types. Render `<PostAudio src={post.audio} />` in `Post.tsx` before Markdown. Add a compact `SoundOutlined` + “可听” tag in `PostCard` when `post.audio` exists.

- [ ] **Step 4: Run frontend tests to verify GREEN**

Run: `npm test -- PostAudio PostCard`.

Expected: pass.

## Task 8: Full Verification

**Files:**
- All changed files.

- [ ] **Step 1: Run backend tests**

Run: `uv run pytest` from `backend/`.

Expected: all pass.

- [ ] **Step 2: Run pipeline tests**

Run: `python -m pytest pipeline/tests -v` from repo root.

Expected: all pass.

- [ ] **Step 3: Run frontend tests and build**

Run: `npm test` and `npm run build` from `frontend/`.

Expected: all pass.

- [ ] **Step 4: Review git diff**

Run: `git diff --stat` and inspect changed files.

Expected: changes are limited to the planned files.

## Task 9: Scheduled Local Publishing Entrypoint

**Files:**
- Create: `pipeline/daily_finance.py`
- Create: `pipeline/tests/test_daily_finance.py`
- Modify: `pipeline/.gitignore`
- Create: `docs/finance-morning-briefing-runbook.md`

- [x] **Step 1: Write failing tests**

Add tests for the scheduled wrapper: default command includes news mode, audio and publish; logs are written; lock files prevent concurrent runs; audio/publish can be disabled for dry runs.

- [x] **Step 2: Run focused test to verify RED**

Run: `PYTHONPATH=/Users/sxy/develop/shouka-blog/.worktrees/heavy-space-theme/pipeline uv run python -m pytest ../pipeline/tests/test_daily_finance.py -q` from `backend/`.

Observed: failed because `daily_finance` did not exist.

- [x] **Step 3: Implement scheduled wrapper and runbook**

Add `python -m pipeline.daily_finance` as the OpenClaw/cron-facing entrypoint. It writes dated logs, uses a dated lock file, delegates to `pipeline.run finance --mode news`, and defaults to audio plus publish.

- [x] **Step 4: Run focused test to verify GREEN**

Run: `PYTHONPATH=/Users/sxy/develop/shouka-blog/.worktrees/heavy-space-theme/pipeline uv run python -m pytest ../pipeline/tests/test_daily_finance.py -q`.

Observed: 3 passed.
