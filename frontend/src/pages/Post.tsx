import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { getPost } from "../lib/api";
import type { PostDetail } from "../lib/types";
import { Markdown } from "../components/Markdown";

export function Post() {
  const { slug } = useParams();
  const [post, setPost] = useState<PostDetail | null>(null);
  const [missing, setMissing] = useState(false);
  useEffect(() => { getPost(slug!).then(setPost).catch(() => setMissing(true)); }, [slug]);
  if (missing) return <p className="empty">404 · 文章不存在</p>;
  if (!post) return <p className="empty">加载中…</p>;
  return (
    <article>
      <h1>{post.title}</h1>
      <div className="post-card__meta">
        <span>{post.date}</span>
        <span className="post-card__cat">{post.category}</span>
      </div>
      <div>{post.tags.map((t) => <Link key={t} className="tag" to={`/category/${post.category}`}>#{t}</Link>)}</div>
      <Markdown content={post.content} />
    </article>
  );
}
