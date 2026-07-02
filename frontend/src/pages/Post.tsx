import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { getPost } from "../lib/api";
import type { PostDetail } from "../lib/types";
import { Markdown } from "../components/Markdown";
import { CAT_CLASS } from "../lib/cat";
import { PostAudio } from "../components/PostAudio";

export function Post() {
  const { slug } = useParams();
  const nav = useNavigate();
  const [post, setPost] = useState<PostDetail | null>(null);
  const [missing, setMissing] = useState(false);
  useEffect(() => { getPost(slug!).then(setPost).catch(() => setMissing(true)); }, [slug]);
  if (missing) return <p className="empty">404 · 文章不存在</p>;
  if (!post) return <p className="loading-state">正在加载文章…</p>;
  return (
    <article>
      <h1 className="post-title">{post.title}</h1>
      <div className="post-card__meta post-meta">
        <span className={`tag ${CAT_CLASS[post.category] ?? ""}`}>{post.category}</span>
        <span>{post.date}</span>
      </div>
      <div className="post-tags">
        {post.tags.map((t) => (
          <button type="button" key={t} className="tag tag--button" onClick={() => nav(`/category/${post.category}`)}>
            #{t}
          </button>
        ))}
      </div>
      <PostAudio src={post.audio} />
      <Markdown content={post.content} />
    </article>
  );
}
