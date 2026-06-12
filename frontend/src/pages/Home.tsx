import { useEffect, useState } from "react";
import { listPosts } from "../lib/api";
import type { PostMeta } from "../lib/types";
import { PostCard } from "../components/PostCard";

export function Home() {
  const [posts, setPosts] = useState<PostMeta[] | null>(null);
  useEffect(() => { listPosts().then(setPosts).catch(() => setPosts([])); }, []);
  if (!posts) return <p className="empty">加载中…</p>;
  if (posts.length === 0) return <p className="empty">还没有文章</p>;
  return <>{posts.map((p) => <PostCard key={p.slug} post={p} />)}</>;
}
