import { Link } from "react-router-dom";
import { Headphones, Radio } from "lucide-react";
import type { PostMeta } from "../lib/types";

export function PostCard({ post }: { post: PostMeta }) {
  return (
    <article className="post-card hud-panel">
      {post.cover && <img className="post-card__cover" src={post.cover} alt="" loading="lazy" />}
      <div className="post-card__meta">
        <span className="hud-chip"><Radio size={13} />{post.category}</span>
        {post.audio && <span className="hud-chip hud-chip--audio"><Headphones size={13} />可听</span>}
        <time>{post.date}</time>
      </div>
      <h3>
        <Link to={`/post/${post.slug}`}>{post.title}</Link>
      </h3>
      {post.summary && <p>{post.summary}</p>}
      <div className="post-card__line" aria-hidden />
    </article>
  );
}
