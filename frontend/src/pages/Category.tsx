import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { listPosts } from "../lib/api";
import type { PostMeta } from "../lib/types";
import { PostCard } from "../components/PostCard";

const REPORT_TAG = "每日报告";

function List({ items }: { items: PostMeta[] }) {
  return <div className="content-stack">
    {items.map((p) => <PostCard key={p.slug} post={p} />)}
  </div>;
}

export function Category() {
  const { name } = useParams();
  const [posts, setPosts] = useState<PostMeta[] | null>(null);
  useEffect(() => {
    setPosts(null);
    listPosts(name).then(setPosts).catch(() => setPosts([]));
  }, [name]);

  let body;
  if (!posts) body = <p className="loading-state">正在加载文章…</p>;
  else if (posts.length === 0) body = <p className="empty">还没有文章</p>;
  else if (name === "理财" || name === "科技") {
    const reports = posts.filter((p) => p.tags.includes(REPORT_TAG));
    const originals = posts.filter((p) => !p.tags.includes(REPORT_TAG));
    body = <>
      <h2 className="subsection-title">原创</h2>
      {originals.length ? <List items={originals} /> : <p className="empty">还没有原创文章</p>}
      <h2 className="subsection-title">每日报告</h2>
      {reports.length ? <List items={reports} /> : <p className="empty">还没有报告</p>}
    </>;
  } else body = <List items={posts} />;

  return <>
    <div className="cat-bg" style={{ backgroundImage: `url(/bg/cat-${encodeURIComponent(name!)}.jpg)` }} aria-hidden />
    <h1 className="page-title">{name}</h1>{body}
  </>;
}
