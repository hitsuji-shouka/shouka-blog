import { Link } from "react-router-dom";
import type { PostMeta } from "../lib/types";
import { CAT_CLASS } from "../lib/cat";

export function PostCard({ post }: { post: PostMeta }) {
  return (
    <article className="post-card">
      {post.cover && <img className="post-card__cover" src={post.cover} alt="" loading="lazy" />}
      <div className="post-card__meta">
        <span className={`tag ${CAT_CLASS[post.category] ?? ""}`}>{post.category}</span>
        {post.audio && <span className="tag tag--audio">可听</span>}
        <span>{post.date}</span>
      </div>
      <h2 className="post-card__title">
        <Link to={`/post/${post.slug}`}>{post.title}</Link>
      </h2>
      {post.summary && <p className="post-card__summary">{post.summary}</p>}
    </article>
  );
}
