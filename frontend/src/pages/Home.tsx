import { useEffect, useState } from "react";
import { Empty, Skeleton, Space } from "antd";
import { listPosts } from "../lib/api";
import type { PostMeta } from "../lib/types";
import { PostCard } from "../components/PostCard";

export function Home() {
  const [posts, setPosts] = useState<PostMeta[] | null>(null);
  useEffect(() => { listPosts().then(setPosts).catch(() => setPosts([])); }, []);
  if (!posts) return <Skeleton active paragraph={{ rows: 4 }} />;
  if (posts.length === 0) return <Empty description="还没有文章" />;
  return <Space direction="vertical" size={16} style={{ width: "100%" }}>
    {posts.map((p) => <PostCard key={p.slug} post={p} />)}
  </Space>;
}
