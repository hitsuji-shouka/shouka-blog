import { useEffect, useState } from "react";
import { listPosts } from "../lib/api";
import type { PostMeta } from "../lib/types";
import { PostCard } from "../components/PostCard";
import { BlackHoleScene } from "../components/BlackHoleScene";
import { ArticleGalaxy } from "../components/ArticleGalaxy";

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
            这里不是信息流，是一艘慢速穿过噪声的飞船。科技、理财早报与私人随笔被整理成可追踪的信号，留给仍然愿意思考的人。
          </p>
          <div className="mission-telemetry" aria-label="任务遥测">
            <span><b>MISSION CLOCK</b> 06:45 CST</span>
            <span><b>SIGNAL DELAY</b> HUMAN REVIEW</span>
            <span><b>GRAVITY WELL</b> MARKETS / AGENTS</span>
          </div>
        </div>
        <div className="hero-galaxy">
          {posts ? <ArticleGalaxy posts={posts} variant="home" /> : <div className="loading-signal">正在校准星图...</div>}
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
        {!posts ? <div className="loading-signal">正在校准信号...</div> : posts.length === 0 ? (
          <div className="empty">还没有文章</div>
        ) : (
          <div className="post-stack">
            {posts.map((p) => <PostCard key={p.slug} post={p} />)}
          </div>
        )}
      </section>
    </>
  );
}
