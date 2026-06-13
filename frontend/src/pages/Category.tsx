import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { Empty, Skeleton, Space, Typography } from "antd";
import { listPosts } from "../lib/api";
import type { PostMeta } from "../lib/types";
import { PostCard } from "../components/PostCard";

const REPORT_TAG = "每日报告";

function List({ items }: { items: PostMeta[] }) {
  return <Space direction="vertical" size={16} style={{ width: "100%" }}>
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
  else if (name === "理财") {
    const reports = posts.filter((p) => p.tags.includes(REPORT_TAG));
    const originals = posts.filter((p) => !p.tags.includes(REPORT_TAG));
    body = <>
      <Typography.Title level={4}>原创</Typography.Title>
      {originals.length ? <List items={originals} /> : <Empty description="还没有原创文章" />}
      <Typography.Title level={4} style={{ marginTop: 28 }}>每日报告</Typography.Title>
      {reports.length ? <List items={reports} /> : <Empty description="还没有报告" />}
    </>;
  } else body = <List items={posts} />;

  return <><h1 className="page-title">{name}</h1>{body}</>;
}
