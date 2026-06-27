import { describe, expect, it } from "vitest";
import { buildArticleGalaxy, categoryPath, estimateReadMinutes, GALAXY_CONFIG } from "./articleGalaxy";
import type { PostMeta } from "./types";

const base = (slug: string, category: PostMeta["category"], summary = "short"): PostMeta => ({
  slug,
  title: slug,
  date: "2026-06-10",
  category,
  tags: [],
  summary,
  cover: null,
  audio: null,
  sources: [],
});

describe("GALAXY_CONFIG", () => {
  it("maps each blog category to a named stellar system", () => {
    expect(GALAXY_CONFIG.科技.name).toBe("科技星云");
    expect(GALAXY_CONFIG.理财.name).toBe("财富星域");
    expect(GALAXY_CONFIG.随笔.name).toBe("幻想之境");
    expect(GALAXY_CONFIG.科技.color).toBe("#00d4ff");
    expect(GALAXY_CONFIG.理财.color).toBe("#f5a623");
    expect(GALAXY_CONFIG.随笔.color).toBe("#a855f7");
  });
});

describe("estimateReadMinutes", () => {
  it("derives a stable reading estimate from metadata length", () => {
    expect(estimateReadMinutes(base("short", "科技", "摘要"))).toBe(2);
    expect(estimateReadMinutes(base("long", "科技", "x".repeat(900)))).toBeGreaterThan(2);
  });
});

describe("buildArticleGalaxy", () => {
  it("groups planets by category and scales planet radius from reading time", () => {
    const galaxy = buildArticleGalaxy([
      base("a", "科技", "x".repeat(80)),
      base("b", "科技", "x".repeat(1200)),
      base("c", "理财", "x".repeat(80)),
    ]);

    const tech = galaxy.find((g) => g.category === "科技")!;
    const finance = galaxy.find((g) => g.category === "理财")!;
    expect(tech.planets.map((p) => p.post.slug)).toEqual(["a", "b"]);
    expect(finance.planets.map((p) => p.post.slug)).toEqual(["c"]);
    expect(tech.planets[1].radius).toBeGreaterThan(tech.planets[0].radius);
  });

  it("produces deterministic planet positions for the same posts", () => {
    const posts = [base("a", "科技"), base("b", "理财"), base("c", "随笔")];

    expect(buildArticleGalaxy(posts)).toEqual(buildArticleGalaxy(posts));
  });
});

describe("categoryPath", () => {
  it("builds encoded category links for stellar systems", () => {
    expect(categoryPath("科技")).toBe("/category/%E7%A7%91%E6%8A%80");
  });
});
