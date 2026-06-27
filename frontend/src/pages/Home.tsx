import { useEffect, useState } from "react";
import { Empty, Skeleton, Space } from "antd";
import { listPosts } from "../lib/api";
import type { PostMeta } from "../lib/types";
import { PostCard } from "../components/PostCard";
import { BlackHoleScene } from "../components/BlackHoleScene";
import { GalaxyNav } from "../components/GalaxyNav";

export function Home() {
  const [posts, setPosts] = useState<PostMeta[] | null>(null);
  useEffect(() => { listPosts().then(setPosts).catch(() => setPosts([])); }, []);
  return (
    <>
      <section className="hero-shell">
        <BlackHoleScene />
        <div className="hero-content">
          <p className="hud-kicker">MISSION LOG / SHOUKA KNOWLEDGE STATION</p>
          <h1>shouka.blog</h1>
          <p className="hero-copy">
            记录科技、理财与随笔，把每日早报、长文思考和 agent 能力接入同一个深空控制台。
          </p>
          <GalaxyNav />
        </div>
        <div className="scroll-cue" aria-hidden>
          <span>SCROLL</span>
          <i />
        </div>
      </section>

      <section className="content-band content-band--latest">
        <div className="section-heading">
          <p>RECENT TRANSMISSIONS</p>
          <h2>最新文章</h2>
        </div>
        {!posts ? <Skeleton active paragraph={{ rows: 4 }} /> : posts.length === 0 ? (
          <Empty description="还没有文章" />
        ) : (
          <Space orientation="vertical" size={16} style={{ width: "100%" }}>
            {posts.map((p) => <PostCard key={p.slug} post={p} />)}
          </Space>
        )}
      </section>
    </>
  );
}
