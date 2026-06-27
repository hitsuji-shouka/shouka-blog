import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { Empty, Skeleton, Space } from "antd";
import { listPosts } from "../lib/api";
import type { PostMeta } from "../lib/types";
import { PostCard } from "../components/PostCard";

const REPORT_TAG = "每日报告";

function List({ items }: { items: PostMeta[] }) {
  return <Space orientation="vertical" size={16} style={{ width: "100%" }}>
    {items.map((p) => <PostCard key={p.slug} post={p} />)}
  </Space>;
}

export function Category() {
  const { name } = useParams();
  const [posts, setPosts] = useState<PostMeta[] | null>(null);
  useEffect(() => {
    setPosts(null);
    listPosts(name).then(setPosts).catch(() => setPosts([]));
  }, [name]);

  let body;
  if (!posts) body = <Skeleton active paragraph={{ rows: 3 }} />;
  else if (posts.length === 0) body = <Empty description="还没有文章" />;
  else if (name === "理财" || name === "科技") {
    const reports = posts.filter((p) => p.tags.includes(REPORT_TAG));
    const originals = posts.filter((p) => !p.tags.includes(REPORT_TAG));
    body = <>
      <div className="section-heading section-heading--small"><p>ORIGINAL SIGNALS</p><h2>原创</h2></div>
      {originals.length ? <List items={originals} /> : <Empty description="还没有原创文章" />}
      <div className="section-heading section-heading--small section-heading--spaced"><p>DAILY BRIEFINGS</p><h2>每日报告</h2></div>
      {reports.length ? <List items={reports} /> : <Empty description="还没有报告" />}
    </>;
  } else body = <List items={posts} />;

  return <section className="content-band"><div className="page-title-block"><p>CATEGORY ARCHIVE</p><h1>{name}</h1></div>{body}</section>;
}
