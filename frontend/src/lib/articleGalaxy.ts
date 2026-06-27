import type { Category, PostMeta } from "./types";

export interface GalaxyConfig {
  name: string;
  color: string;
  mutedColor: string;
  center: [number, number, number];
}

export interface ArticlePlanet {
  post: PostMeta;
  position: [number, number, number];
  radius: number;
  glow: number;
  readMinutes: number;
  textureSeed: number;
}

export interface ArticleGalaxy {
  category: Category;
  config: GalaxyConfig;
  planets: ArticlePlanet[];
}

export const GALAXY_CONFIG: Record<Category, GalaxyConfig> = {
  科技: { name: "科技星云", color: "#00d4ff", mutedColor: "#7cc7d8", center: [-4.2, 1.15, 0] },
  理财: { name: "财富星域", color: "#f5a623", mutedColor: "#c49a62", center: [3.9, 0.9, -0.35] },
  随笔: { name: "幻想之境", color: "#a855f7", mutedColor: "#9b83b7", center: [-0.2, -2.5, 0.25] },
};

const CATEGORY_ORDER: Category[] = ["科技", "理财", "随笔"];

export function categoryPath(category: Category): string {
  return `/category/${encodeURIComponent(category)}`;
}

export function stableHash(value: string): number {
  let hash = 2166136261;
  for (let i = 0; i < value.length; i += 1) {
    hash ^= value.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function seededUnit(seed: number, salt: number): number {
  const x = Math.sin(seed * 12.9898 + salt * 78.233) * 43758.5453;
  return x - Math.floor(x);
}

export function estimateReadMinutes(post: PostMeta): number {
  const weightedLength = post.title.length * 1.4 + post.summary.length + post.tags.join("").length * 0.8;
  return Math.max(2, Math.min(18, Math.ceil(weightedLength / 170)));
}

export function buildArticleGalaxy(posts: PostMeta[]): ArticleGalaxy[] {
  return CATEGORY_ORDER.map((category) => {
    const categoryPosts = posts.filter((post) => post.category === category);
    const config = GALAXY_CONFIG[category];
    const planets = categoryPosts.map((post, index) => {
      const seed = stableHash(`${post.slug}:${post.date}`);
      const readMinutes = estimateReadMinutes(post);
      const orbit = 1.35 + index * 0.52 + seededUnit(seed, 1) * 0.34;
      const angle = (index / Math.max(categoryPosts.length, 1)) * Math.PI * 2 + seededUnit(seed, 2) * 0.72;
      const height = (seededUnit(seed, 3) - 0.5) * 0.72;
      return {
        post,
        readMinutes,
        textureSeed: seed,
        radius: 0.16 + Math.min(readMinutes, 14) * 0.018,
        glow: 0.34 + (1 / (index + 1)) * 0.36,
        position: [
          config.center[0] + Math.cos(angle) * orbit,
          config.center[1] + height,
          config.center[2] + Math.sin(angle) * orbit * 0.72,
        ] as [number, number, number],
      };
    });

    return { category, config, planets };
  });
}
