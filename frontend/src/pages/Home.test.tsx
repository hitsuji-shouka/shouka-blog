import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { StaticRouter } from "react-router-dom/server";
import { HomeContent } from "./Home";
import type { PostMeta } from "../lib/types";

const posts: PostMeta[] = [
  {
    slug: "ai-notes",
    title: "AI 观察",
    date: "2026-07-01",
    category: "科技",
    tags: [],
    summary: "把信息流整理成长期笔记。",
    cover: null,
    audio: null,
    sources: [],
  },
  {
    slug: "money-review",
    title: "理财复盘",
    date: "2026-06-30",
    category: "理财",
    tags: [],
    summary: "记录策略和结果。",
    cover: null,
    audio: null,
    sources: [],
  },
  {
    slug: "daily-writing",
    title: "日常随笔",
    date: "2026-06-29",
    category: "随笔",
    tags: [],
    summary: "给想法留下坐标。",
    cover: null,
    audio: null,
    sources: [],
  },
];

const html = () =>
  renderToStaticMarkup(
    <StaticRouter location="/">
      <HomeContent posts={posts} />
    </StaticRouter>,
  );

describe("HomeContent", () => {
  it("保留参照站点启发的个人品牌首页结构", () => {
    const out = html();
    expect(out).toContain("AI writing x investing x build in public");
    expect(out).toContain("shouka");
    expect(out).toContain("ABOUT");
    expect(out).toContain("WRITING");
    expect(out).toContain("BUILD");
    expect(out).toContain("CONTACT");
    expect(out).toContain('src="/avatar/shouka-avatar.png"');
    expect(out).toContain('alt="Shouka creator avatar"');
    expect(out).toContain("LATEST SIGNAL");
    expect(out).toContain("AI 观察");
    expect(out).toContain("BLOG CORE");
    expect(out).toContain("RAG AGENT");
    expect(out).toContain("/category/科技");
    expect(out).toContain("/category/理财");
    expect(out).toContain("/category/随笔");
  });
});
