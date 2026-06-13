import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { MemoryRouter } from "react-router-dom";
import { PostCard } from "./PostCard";
import type { PostMeta } from "../lib/types";

const base: PostMeta = {
  slug: "a", title: "标题A", date: "2026-06-12", category: "科技",
  tags: [], summary: "摘要", cover: null,
};

const html = (p: PostMeta) =>
  renderToStaticMarkup(<MemoryRouter><PostCard post={p} /></MemoryRouter>);

describe("PostCard", () => {
  it("显示标题/日期/分类/摘要，链接到详情", () => {
    const out = html(base);
    expect(out).toContain("标题A");
    expect(out).toContain("/post/a");
    expect(out).toContain("摘要");
  });
  it("无封面不渲染 img，有封面渲染", () => {
    expect(html(base)).not.toContain("<img");
    expect(html({ ...base, cover: "http://c/x.png" })).toContain("http://c/x.png");
  });
});
