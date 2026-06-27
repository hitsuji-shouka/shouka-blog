import { Link } from "react-router-dom";
import { Card, Tag, Typography } from "antd";
import { SoundOutlined } from "@ant-design/icons";
import type { PostMeta } from "../lib/types";
import { CAT_COLOR } from "../lib/cat";

export function PostCard({ post }: { post: PostMeta }) {
  return (
    <Card hoverable className="post-card"
      cover={post.cover ? <img className="post-card__cover" src={post.cover} alt="" loading="lazy" /> : undefined}>
      <div className="post-card__meta">
        <Tag color={CAT_COLOR[post.category]} bordered={false}>{post.category}</Tag>
        {post.audio && <Tag icon={<SoundOutlined />} color="green" bordered={false}>可听</Tag>}
        <span>{post.date}</span>
      </div>
      <Typography.Title level={4} style={{ margin: "8px 0 4px" }}>
        <Link to={`/post/${post.slug}`}>{post.title}</Link>
      </Typography.Title>
      {post.summary && <Typography.Paragraph type="secondary" style={{ margin: 0 }}>{post.summary}</Typography.Paragraph>}
    </Card>
  );
}
