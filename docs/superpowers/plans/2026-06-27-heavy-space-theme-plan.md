# Heavy Space Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the frontend into a heavy Interstellar-style HUD site with Three.js black-hole hero, galaxy category navigation, warp route transitions, TARS-style assistant UI, and mobile/reduced-motion fallbacks.

**Architecture:** Keep backend and pipeline untouched. Add focused frontend components for visual effects and replace the current light AntD layout with a custom dark HUD shell while preserving existing post/chat APIs.

**Tech Stack:** React 18, Vite, TypeScript, Ant Design for small primitives where useful, Three.js, @react-three/fiber, @react-three/drei, GSAP, lucide-react, Vitest.

---

## File Structure

- Modify `frontend/package.json` / `frontend/package-lock.json`: add 3D/animation dependencies.
- Create `frontend/src/lib/motion.ts`: reduced-motion and mobile helpers.
- Create `frontend/src/components/BlackHoleScene.tsx`: Three.js black-hole and star field hero.
- Create `frontend/src/components/GalaxyNav.tsx`: category orbital navigation.
- Create `frontend/src/components/WarpCanvas.tsx`: route transition canvas.
- Create `frontend/src/components/ScrollProgress.tsx`: right-edge scroll progress line.
- Modify `frontend/src/main.tsx`: replace AntD layout/header with HUD shell and route transition wrapper.
- Modify `frontend/src/pages/Home.tsx`: add full-viewport hero and latest posts section.
- Modify `frontend/src/pages/Category.tsx`: add HUD section headings.
- Modify `frontend/src/pages/Post.tsx`: add HUD article header and keep readable body.
- Modify `frontend/src/components/PostCard.tsx`: convert to HUD panel.
- Modify `frontend/src/components/PostAudio.tsx`: convert to HUD audio panel.
- Modify `frontend/src/components/AssistantPanel.tsx`: convert Totoro panel to TARS-style assistant while keeping chat API.
- Rewrite `frontend/src/index.css`: deep-space theme, HUD borders, responsive behavior, markdown dark mode.
- Add/update tests under `frontend/src/**/*.test.tsx` and `frontend/src/lib/motion.test.ts`.

## Task 1: Dependencies and Motion Helpers

**Files:**
- Modify: `frontend/package.json`
- Modify: `frontend/package-lock.json`
- Create: `frontend/src/lib/motion.ts`
- Create: `frontend/src/lib/motion.test.ts`

- [ ] **Step 1: Write failing tests**

Create `motion.test.ts` with tests for `shouldReduceMotion`, `isCompactViewport`, and `sceneQuality`.

- [ ] **Step 2: Run tests to verify RED**

Run: `npm test -- motion`.

Expected: fail because `motion.ts` does not exist.

- [ ] **Step 3: Install dependencies**

Run: `npm install three @react-three/fiber @react-three/drei gsap lucide-react`.

- [ ] **Step 4: Implement helpers**

Implement pure helpers that accept optional `Window`-like values so tests do not require a browser:

- `shouldReduceMotion(win = window): boolean`
- `isCompactViewport(width: number): boolean`
- `sceneQuality(width: number, dpr: number): { particles: number; pixelRatio: number; fullEffects: boolean }`

- [ ] **Step 5: Run tests to verify GREEN**

Run: `npm test -- motion`.

Expected: pass.

## Task 2: Black Hole Hero and Galaxy Navigation

**Files:**
- Create: `frontend/src/components/BlackHoleScene.tsx`
- Create: `frontend/src/components/GalaxyNav.tsx`
- Create: `frontend/src/components/GalaxyNav.test.tsx`
- Modify: `frontend/src/pages/Home.tsx`

- [ ] **Step 1: Write failing tests**

Test `GalaxyNav` static markup renders links for `/category/科技`, `/category/理财`, `/category/随笔`.

- [ ] **Step 2: Run tests to verify RED**

Run: `npm test -- GalaxyNav`.

Expected: fail because the component does not exist.

- [ ] **Step 3: Implement components**

Build `BlackHoleScene` with `Canvas`, a rotating accretion ring, star points, and mobile quality settings from `sceneQuality`. Build `GalaxyNav` as orbit-style links on desktop and HUD button row on mobile via CSS.

- [ ] **Step 4: Update Home**

Add full-viewport hero containing `BlackHoleScene`, brand copy, `GalaxyNav`, and latest posts below the fold.

- [ ] **Step 5: Run tests to verify GREEN**

Run: `npm test -- GalaxyNav`.

Expected: pass.

## Task 3: Warp Route Transition and HUD Shell

**Files:**
- Create: `frontend/src/components/WarpCanvas.tsx`
- Create: `frontend/src/components/ScrollProgress.tsx`
- Modify: `frontend/src/main.tsx`

- [ ] **Step 1: Write failing tests**

Add a small test for `WarpCanvas` reduced-motion behavior by exporting `shouldPlayWarp(reduceMotion: boolean, from: string, to: string)`.

- [ ] **Step 2: Run tests to verify RED**

Run: `npm test -- WarpCanvas`.

Expected: fail because `WarpCanvas` does not exist.

- [ ] **Step 3: Implement WarpCanvas**

Use a fixed full-screen canvas with a state machine: accelerating, warping, decelerating, fading. Export `shouldPlayWarp`.

- [ ] **Step 4: Implement HUD shell**

Replace current AntD `Layout/Header/Menu` shell with a custom `HudNav`, `WarpRouter`, and `ScrollProgress`. Preserve routes `/`, `/post/:slug`, `/category/:name`.

- [ ] **Step 5: Run tests to verify GREEN**

Run: `npm test -- WarpCanvas`.

Expected: pass.

## Task 4: HUD Cards, Audio, Category, and Post Pages

**Files:**
- Modify: `frontend/src/components/PostCard.tsx`
- Modify: `frontend/src/components/PostCard.test.tsx`
- Modify: `frontend/src/components/PostAudio.tsx`
- Modify: `frontend/src/components/PostAudio.test.tsx`
- Modify: `frontend/src/pages/Category.tsx`
- Modify: `frontend/src/pages/Post.tsx`

- [ ] **Step 1: Update tests first**

Keep existing behavior assertions: title, link, summary, cover image, and “可听” marker. Add `PostAudio` assertion for HUD label “AUDIO BRIEFING”.

- [ ] **Step 2: Run tests to verify RED**

Run: `npm test -- PostCard PostAudio`.

Expected: fail on the new HUD audio label.

- [ ] **Step 3: Implement HUD UI**

Rewrite card/audio markup using semantic div/article elements and CSS classes. Update category and post pages with HUD headings and article header blocks.

- [ ] **Step 4: Run tests to verify GREEN**

Run: `npm test -- PostCard PostAudio`.

Expected: pass.

## Task 5: TARS Assistant Panel

**Files:**
- Modify: `frontend/src/components/AssistantPanel.tsx`

- [ ] **Step 1: Preserve behavior**

Do not alter `sendChat`, streaming state, sources rendering, or input submission behavior.

- [ ] **Step 2: Implement TARS UI**

Replace the Totoro floating button and panel classes with TARS breathing bars, HUD header, cyan/amber message bubbles, and dark input deck. Keep AntD `Input` only if it does not fight the dark style.

- [ ] **Step 3: Smoke test by build**

Run: `npm run build`.

Expected: TypeScript build passes.

## Task 6: Global Theme CSS

**Files:**
- Rewrite: `frontend/src/index.css`
- Modify: `frontend/src/components/Background.tsx` if needed

- [ ] **Step 1: Add theme CSS**

Define deep-space variables, body background, HUD borders, scanline nav, cards, markdown dark theme, assistant panel, mobile breakpoints, and reduced-motion overrides.

- [ ] **Step 2: Remove obsolete light theme assumptions**

Keep class names needed by components and remove bright background image reliance. `Background` may become a CSS starfield layer.

- [ ] **Step 3: Run frontend tests**

Run: `npm test`.

Expected: pass.

## Task 7: Browser Verification

**Files:**
- No source edits unless visual issues are found.

- [ ] **Step 1: Start dev server**

Run: `npm run dev -- --host 127.0.0.1`.

- [ ] **Step 2: Desktop browser check**

Open `http://127.0.0.1:5173` in the in-app browser. Capture 1440x900 screenshot. Verify nonblank 3D hero, HUD nav, visible latest section hint, and no overlap.

- [ ] **Step 3: Mobile browser check**

Capture 390x844 screenshot. Verify no horizontal overflow, nav is usable, hero text fits, and cards do not overlap.

- [ ] **Step 4: Canvas check**

Use browser evaluation to confirm the hero canvas has nonblank pixels.

## Task 8: Final Verification

**Files:**
- All changed frontend files.

- [ ] **Step 1: Run frontend tests**

Run: `npm test`.

Expected: all tests pass.

- [ ] **Step 2: Run frontend build**

Run: `npm run build`.

Expected: build succeeds. Vite large chunk warnings are acceptable.

- [ ] **Step 3: Review git diff**

Run: `git diff --stat`.

Expected: changes limited to frontend, docs plan, and package metadata.
