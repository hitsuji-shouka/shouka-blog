import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { getPost } from "../lib/api";
import type { PostDetail } from "../lib/types";
import { Markdown } from "../components/Markdown";
import { PostAudio } from "../components/PostAudio";

export function Post() {
  const { slug } = useParams();
  const nav = useNavigate();
  const [post, setPost] = useState<PostDetail | null>(null);
  const [missing, setMissing] = useState(false);
  useEffect(() => { getPost(slug!).then(setPost).catch(() => setMissing(true)); }, [slug]);
  if (missing) return <div className="empty">404 · 文章不存在</div>;
  if (!post) return <div className="loading-signal">正在解码归档...</div>;
  return (
    <article className="post-detail content-band">
      <header className="post-hero hud-panel">
        <p className="hud-kicker">ARCHIVE ENTRY / {post.category}</p>
        <h1>{post.title}</h1>
        <div className="post-card__meta post-card__meta--spaced">
          <span className="hud-chip">{post.category}</span>
          <span>{post.date}</span>
        </div>
        <div className="post-tags">
          {post.tags.map((t) => <button key={t} className="tag" onClick={() => nav(`/category/${post.category}`)}>#{t}</button>)}
        </div>
      </header>
      <PostAudio src={post.audio} />
      <Markdown content={post.content} />
    </article>
  );
}
