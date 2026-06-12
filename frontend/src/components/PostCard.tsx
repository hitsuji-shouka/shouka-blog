import { Link } from "react-router-dom";
import type { PostMeta } from "../lib/types";

export function PostCard({ post }: { post: PostMeta }) {
  return (
    <article className="post-card">
      {post.cover && <img className="post-card__cover" src={post.cover} alt="" loading="lazy" />}
      <h2>
        <Link to={`/post/${post.slug}`}>{post.title}</Link>
      </h2>
      <div className="post-card__meta">
        <span>{post.date}</span>
        <span className="post-card__cat">{post.category}</span>
      </div>
      {post.summary && <p className="post-card__summary">{post.summary}</p>}
    </article>
  );
}
