export type Category = "AI" | "阅读" | "音乐" | "理财";

export interface PostMeta {
  slug: string;
  title: string;
  date: string;
  category: Category;
  tags: string[];
  summary: string;
  cover: string | null;
}

export interface PostDetail extends PostMeta {
  content: string;
}

export interface CategoryCount {
  category: Category;
  count: number;
}
