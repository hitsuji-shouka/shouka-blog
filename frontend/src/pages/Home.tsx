import { useEffect, useState, type PointerEvent } from "react";
import { Link } from "react-router-dom";
import { motion } from "framer-motion";
import { listPosts } from "../lib/api";
import { CATS } from "../lib/cat";
import { shouldReduceMotion } from "../lib/motion";
import type { PostMeta } from "../lib/types";

const AVATAR_REFRESH_FINAL_FRAME = 11;

export function avatarRefreshInitialFrame(reduceMotion: boolean): number {
  return reduceMotion ? AVATAR_REFRESH_FINAL_FRAME : 0;
}

export function nextAvatarRefreshFrame(frame: number): number {
  return Math.min(frame + 1, AVATAR_REFRESH_FINAL_FRAME);
}

const buildCards = [
  { label: "BLOG CORE", title: "Markdown 写作流", text: "本地写作、Git 发布、FastAPI 只读服务。" },
  { label: "RAG AGENT", title: "访客问答助手", text: "基于站内文章回答问题，给出来源链接。" },
  { label: "DAILY REPORT", title: "科技 / 理财日报", text: "把短期信息流整理成长期记录。" },
];

function countByCategory(posts: PostMeta[]) {
  return CATS.map((cat) => ({
    cat,
    count: posts.filter((post) => post.category === cat).length,
  }));
}

export function Home() {
  const [posts, setPosts] = useState<PostMeta[] | null>(null);
  useEffect(() => { listPosts().then(setPosts).catch(() => setPosts([])); }, []);
  if (!posts) return <p className="loading-state">正在加载文章…</p>;
  if (posts.length === 0) return <p className="empty">还没有文章</p>;

  return <HomeContent posts={posts} />;
}

export function HomeContent({ posts }: { posts: PostMeta[] }) {
  const [latest, ...rest] = posts;
  const highlights = [latest, ...rest].slice(0, 5);
  const cats = countByCategory(posts);
  const [portraitFrame, setPortraitFrame] = useState(0);
  useEffect(() => {
    if (shouldReduceMotion()) {
      setPortraitFrame(avatarRefreshInitialFrame(true));
      return undefined;
    }

    const timer = window.setInterval(() => {
      setPortraitFrame((frame) => {
        const nextFrame = nextAvatarRefreshFrame(frame);
        if (nextFrame === frame) {
          window.clearInterval(timer);
        }
        return nextFrame;
      });
    }, 115);
    return () => window.clearInterval(timer);
  }, []);
  const handleHeroPointerMove = (event: PointerEvent<HTMLElement>) => {
    const rect = event.currentTarget.getBoundingClientRect();
    const x = ((event.clientX - rect.left) / rect.width - 0.5) * 2;
    const y = ((event.clientY - rect.top) / rect.height - 0.5) * 2;
    event.currentTarget.style.setProperty("--hero-x", x.toFixed(3));
    event.currentTarget.style.setProperty("--hero-y", y.toFixed(3));
  };

  return (
    <>
      <span className="cross cross--tr" aria-hidden />
      <span className="cross cross--bl" aria-hidden />

      <section className="hero editorial-section" id="hero" onPointerMove={handleHeroPointerMove}>
        <motion.div className="hero__copy" initial={{ opacity: 0, y: 28 }} animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.75, ease: "easeOut" }}>
          <p className="eyebrow"><span /> AI writing x investing x build in public</p>
          <h1 className="hero__wordmark">Shouka</h1>
          <p className="hero__slogan">把技术、理财和随笔写成一条可追踪的个人知识流。</p>
          <div className="hero__actions">
            <a className="btn btn--primary" href="#writing">查看内容</a>
            <a className="btn btn--ghost" href="#build">看构建记录</a>
          </div>
        </motion.div>

        <motion.aside className="hero__visual" initial={{ opacity: 0, x: 36 }} animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.75, delay: 0.12, ease: "easeOut" }}>
          <div className="hero-portrait" aria-label="Shouka creator avatar">
            <img
              className="hero-portrait__base"
              src={`/avatar/refresh/frame-${String(portraitFrame).padStart(2, "0")}.png`}
              alt="Shouka creator avatar refreshing into view"
            />
          </div>
          <div className="hero-brief">
            <p className="profile-card__label">LATEST SIGNAL</p>
            <Link to={`/post/${latest.slug}`} className="profile-card__title">{latest.title}</Link>
            <p>{latest.summary}</p>
            <div className="profile-card__meta">{latest.date} / {latest.category}</div>
          </div>
          <div className="signal-board">
            {cats.map((item) => (
              <Link key={item.cat} to={`/category/${item.cat}`} className="signal-row">
                <span>{item.cat}</span>
                <b>{item.count}</b>
                <i aria-hidden />
              </Link>
            ))}
          </div>
        </motion.aside>
      </section>

      <section className="about editorial-section" id="about">
        <div>
          <p className="section-kicker">ABOUT</p>
          <h2>一个面向长期记录的个人博客。</h2>
        </div>
        <div className="about__body">
          <p>这里不只是文章列表，而是一套持续更新的个人工作台：技术观察、理财复盘、随笔沉淀，以及面向访客的站内问答 agent。</p>
          <p>首页负责建立“我是谁、我在写什么、我正在构建什么”的第一印象；文章和分类页继续承担可检索的内容归档。</p>
        </div>
      </section>

      <section className="writing editorial-section" id="writing">
        <div className="section-head">
          <div>
            <p className="section-kicker">WRITING</p>
            <h2>最新内容</h2>
          </div>
          <Link to={`/post/${latest.slug}`}>继续阅读最新文章 →</Link>
        </div>
        <div className="writing-list">
          {highlights.map((post, index) => (
            <article className="writing-row" key={post.slug}>
              <span className="writing-row__index">{String(index + 1).padStart(2, "0")}</span>
              <div>
                <Link to={`/post/${post.slug}`}>{post.title}</Link>
                {post.summary && <p>{post.summary}</p>}
              </div>
              <span className="writing-row__meta">{post.category} / {post.date}</span>
            </article>
          ))}
        </div>
      </section>

      <section className="build editorial-section" id="build">
        <div className="section-head">
          <div>
            <p className="section-kicker">BUILD</p>
            <h2>正在构建</h2>
          </div>
          <span>公开记录，而不是一次性作品集。</span>
        </div>
        <div className="build-grid">
          {buildCards.map((card) => (
            <article className="build-card" key={card.label}>
              <span>{card.label}</span>
              <h3>{card.title}</h3>
              <p>{card.text}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="contact editorial-section" id="contact">
        <p className="section-kicker">CONTACT</p>
        <h2>如果你也在把 AI、内容和个人系统放到同一张桌子上，欢迎从文章开始聊起。</h2>
        <div className="contact__links">
          {CATS.map((cat) => (
            <Link key={cat} to={`/category/${cat}`}>{cat}</Link>
          ))}
          <a href="#hero">回到顶部</a>
        </div>
      </section>
    </>
  );
}
