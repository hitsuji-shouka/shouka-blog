import type { CategoryCount, PostDetail, PostMeta } from "./types";

async function get<T>(path: string): Promise<T> {
  const r = await fetch(`/api${path}`);
  if (!r.ok) throw new Error(String(r.status));
  return r.json();
}

export const listPosts = (category?: string) =>
  get<PostMeta[]>(category ? `/posts?category=${encodeURIComponent(category)}` : "/posts");

export const getPost = (slug: string) => get<PostDetail>(`/posts/${encodeURIComponent(slug)}`);

export const listCategories = () => get<CategoryCount[]>("/categories");
