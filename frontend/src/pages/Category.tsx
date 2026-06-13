import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { Empty, Skeleton, Space } from "antd";
import { listPosts } from "../lib/api";
import type { PostMeta } from "../lib/types";
import { PostCard } from "../components/PostCard";

export function Category() {
  const { name } = useParams();
  const [posts, setPosts] = useState<PostMeta[] | null>(null);
  useEffect(() => {
    setPosts(null);
    listPosts(name).then(setPosts).catch(() => setPosts([]));
  }, [name]);
  return (
    <>
      <h1 className="page-title">{name}</h1>
      {!posts ? <Skeleton active paragraph={{ rows: 3 }} />
        : posts.length === 0 ? <Empty description="还没有文章" />
        : <Space direction="vertical" size={16} style={{ width: "100%" }}>
            {posts.map((p) => <PostCard key={p.slug} post={p} />)}
          </Space>}
    </>
  );
}
