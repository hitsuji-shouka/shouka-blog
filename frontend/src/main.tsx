import React, { Suspense, lazy } from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter, Link, Route, Routes, useLocation, useNavigate } from "react-router-dom";
import { Background } from "./components/Background";
import { CATS } from "./lib/cat";
import "./index.css";

const Home = lazy(() => import("./pages/Home").then((module) => ({ default: module.Home })));
const Post = lazy(() => import("./pages/Post").then((module) => ({ default: module.Post })));
const Category = lazy(() => import("./pages/Category").then((module) => ({ default: module.Category })));
const AssistantPanel = lazy(() => import("./components/AssistantPanel").then((module) => ({ default: module.AssistantPanel })));

function Nav() {
  const nav = useNavigate();
  const loc = useLocation();
  const items = [
    { key: "/", label: "首页" },
    { key: "#about", label: "ABOUT" },
    { key: "#writing", label: "WRITING" },
    { key: "#build", label: "BUILD" },
    { key: "#contact", label: "CONTACT" },
    ...CATS.map((c) => ({ key: `/category/${c}`, label: c })),
  ];
  function go(key: string) {
    if (key.startsWith("#")) {
      if (loc.pathname !== "/") {
        nav(`/${key}`);
        setTimeout(() => document.querySelector(key)?.scrollIntoView({ behavior: "smooth" }), 0);
      } else {
        document.querySelector(key)?.scrollIntoView({ behavior: "smooth" });
        history.replaceState(null, "", key);
      }
      return;
    }
    nav(key);
  }
  const selected = loc.hash ? [loc.hash] : [loc.pathname];
  return (
    <header className="site-header">
      <Link to="/" className="brand">shouka<span>.blog</span></Link>
      <nav className="site-menu" aria-label="主导航">
        {items.map((item) => (
          <button
            type="button"
            key={item.key}
            className={`site-menu__item ${selected.includes(item.key) ? "site-menu__item--active" : ""}`}
            onClick={() => go(item.key)}
          >
            {item.label}
          </button>
        ))}
      </nav>
    </header>
  );
}

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <BrowserRouter>
      <Background />
      <div className="site">
        <Nav />
        <main className="site-content">
          <Suspense fallback={<p className="empty">正在加载…</p>}>
            <Routes>
              <Route path="/" element={<Home />} />
              <Route path="/post/:slug" element={<Post />} />
              <Route path="/category/:name" element={<Category />} />
              <Route path="*" element={<p className="empty">404</p>} />
            </Routes>
          </Suspense>
        </main>
        <footer className="site-footer">shouka · 融入 agent 的个人博客</footer>
      </div>
      <Suspense fallback={null}>
        <AssistantPanel />
      </Suspense>
    </BrowserRouter>
  </React.StrictMode>
);
