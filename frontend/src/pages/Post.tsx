import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { Empty, Skeleton, Space, Tag, Typography } from "antd";
import { getPost } from "../lib/api";
import type { PostDetail } from "../lib/types";
import { Markdown } from "../components/Markdown";
import { CAT_COLOR } from "../lib/cat";
import { PostAudio } from "../components/PostAudio";

export function Post() {
  const { slug } = useParams();
  const nav = useNavigate();
  const [post, setPost] = useState<PostDetail | null>(null);
  const [missing, setMissing] = useState(false);
  useEffect(() => { getPost(slug!).then(setPost).catch(() => setMissing(true)); }, [slug]);
  if (missing) return <Empty description="404 · 文章不存在" />;
  if (!post) return <Skeleton active paragraph={{ rows: 6 }} />;
  return (
    <article>
      <Typography.Title level={2}>{post.title}</Typography.Title>
      <Space className="post-card__meta" style={{ marginBottom: 12 }}>
        <Tag color={CAT_COLOR[post.category]} bordered={false}>{post.category}</Tag>
        <span>{post.date}</span>
      </Space>
      <div style={{ marginBottom: 16 }}>
        {post.tags.map((t) => <Tag key={t} className="tag" onClick={() => nav(`/category/${post.category}`)}>#{t}</Tag>)}
      </div>
      <PostAudio src={post.audio} />
      <Markdown content={post.content} />
    </article>
  );
}
