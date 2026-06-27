import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { listPosts } from "../lib/api";
import type { PostMeta } from "../lib/types";
import { PostCard } from "../components/PostCard";
import { ArticleGalaxy } from "../components/ArticleGalaxy";

const REPORT_TAG = "每日报告";

function List({ items }: { items: PostMeta[] }) {
  return <div className="post-stack">
    {items.map((p) => <PostCard key={p.slug} post={p} />)}
  </div>;
}

export function Category() {
  const { name } = useParams();
  const [posts, setPosts] = useState<PostMeta[] | null>(null);
  const [mode, setMode] = useState<"galaxy" | "list">("galaxy");
  useEffect(() => {
    setPosts(null);
    listPosts(name).then(setPosts).catch(() => setPosts([]));
  }, [name]);

  let body;
  if (!posts) body = <div className="loading-signal">正在校准信号...</div>;
  else if (posts.length === 0) body = <div className="empty">还没有文章</div>;
  else if (mode === "galaxy") {
    body = <ArticleGalaxy posts={posts} focusCategory={name} variant="archive" />;
  } else if (name === "理财" || name === "科技") {
    const reports = posts.filter((p) => p.tags.includes(REPORT_TAG));
    const originals = posts.filter((p) => !p.tags.includes(REPORT_TAG));
    body = <>
      <div className="section-heading section-heading--small"><p>ORIGINAL SIGNALS</p><h2>原创</h2></div>
      {originals.length ? <List items={originals} /> : <div className="empty">还没有原创文章</div>}
      <div className="section-heading section-heading--small section-heading--spaced"><p>DAILY BRIEFINGS</p><h2>每日报告</h2></div>
      {reports.length ? <List items={reports} /> : <div className="empty">还没有报告</div>}
    </>;
  } else body = <List items={posts} />;

  return (
    <section className="content-band content-band--archive">
      <div className="page-title-block">
        <p>CATEGORY ARCHIVE</p>
        <h1>{name}</h1>
        {posts && posts.length > 0 && (
          <div className="view-toggle" aria-label="视图切换">
            <button className={mode === "galaxy" ? "is-active" : ""} onClick={() => setMode("galaxy")}>星图模式</button>
            <button className={mode === "list" ? "is-active" : ""} onClick={() => setMode("list")}>列表模式</button>
          </div>
        )}
      </div>
      {body}
    </section>
  );
}
