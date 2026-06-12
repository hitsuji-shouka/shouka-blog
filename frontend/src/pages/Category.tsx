import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { listPosts } from "../lib/api";
import type { PostMeta } from "../lib/types";
import { PostCard } from "../components/PostCard";

const CATS = ["学习", "阅读", "音乐", "理财"];

export function Category() {
  const { name } = useParams();
  const [posts, setPosts] = useState<PostMeta[] | null>(null);
  useEffect(() => {
    setPosts(null);
    listPosts(name).then(setPosts).catch(() => setPosts([]));
  }, [name]);
  return (
    <>
      <nav>{CATS.map((c) => <a key={c} href={`/category/${c}`}>{c}</a>)}</nav>
      <h1>{name}</h1>
      {!posts ? <p className="empty">加载中…</p>
        : posts.length === 0 ? <p className="empty">还没有文章</p>
        : posts.map((p) => <PostCard key={p.slug} post={p} />)}
    </>
  );
}
