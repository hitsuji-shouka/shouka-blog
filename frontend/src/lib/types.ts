export type Category = "科技" | "理财" | "随笔";

export interface PostMeta {
  slug: string;
  title: string;
  date: string;
  category: Category;
  tags: string[];
  summary: string;
  cover: string | null;
  audio: string | null;
  sources: string[];
}

export interface PostDetail extends PostMeta {
  content: string;
}

export interface CategoryCount {
  category: Category;
  count: number;
}
