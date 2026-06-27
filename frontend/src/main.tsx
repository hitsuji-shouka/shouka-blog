import React, { useCallback, useEffect, useState } from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter, Link, Route, Routes, useLocation, useNavigate } from "react-router-dom";
import { ConfigProvider, theme } from "antd";
import { Home } from "./pages/Home";
import { Post } from "./pages/Post";
import { Category } from "./pages/Category";
import { AssistantPanel } from "./components/AssistantPanel";
import { Background } from "./components/Background";
import { WarpCanvas, shouldPlayWarp } from "./components/WarpCanvas";
import { ScrollProgress } from "./components/ScrollProgress";
import { CATS } from "./lib/cat";
import { shouldReduceMotion } from "./lib/motion";
import "./index.css";

function HudNav() {
  const nav = useNavigate();
  const loc = useLocation();
  const items = [{ key: "/", label: "首页", code: "HOME" }, ...CATS.map((c) => ({
    key: `/category/${c}`, label: c, code: c === "科技" ? "TECH" : c === "理财" ? "FIN" : "LOG",
  }))];
  return (
    <header className="hud-nav">
      <Link to="/" className="brand">shouka<span>.blog</span></Link>
      <nav className="hud-menu" aria-label="主导航">
        {items.map((item) => (
          <button
            key={item.key}
            className={loc.pathname === item.key ? "is-active" : ""}
            onClick={() => nav(item.key)}
          >
            <small>{item.code}</small>
            {item.label}
          </button>
        ))}
      </nav>
      <span className="hud-status">AGENT ONLINE</span>
    </header>
  );
}

function WarpRouter() {
  const location = useLocation();
  const [displayLocation, setDisplayLocation] = useState(location);
  const [warp, setWarp] = useState(false);
  const [reduceMotion] = useState(() => shouldReduceMotion());

  useEffect(() => {
    if (shouldPlayWarp(reduceMotion, displayLocation.pathname, location.pathname)) {
      setWarp(true);
    } else {
      setDisplayLocation(location);
      window.scrollTo(0, 0);
    }
  }, [displayLocation.pathname, location, reduceMotion]);

  const handleComplete = useCallback(() => {
    setDisplayLocation(location);
    requestAnimationFrame(() => {
      setWarp(false);
      window.scrollTo(0, 0);
    });
  }, [location]);

  return (
    <>
      <WarpCanvas trigger={warp} onComplete={handleComplete} />
      <div className={warp ? "route-shell is-warping" : "route-shell"}>
        <HudNav />
        <main className="site-content">
          <Routes location={displayLocation}>
            <Route path="/" element={<Home />} />
            <Route path="/post/:slug" element={<Post />} />
            <Route path="/category/:name" element={<Category />} />
            <Route path="*" element={<p className="empty">404</p>} />
          </Routes>
        </main>
        <footer className="site-footer">shouka · knowledge station · agent enabled</footer>
      </div>
      <ScrollProgress />
    </>
  );
}

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <ConfigProvider theme={{
      algorithm: theme.darkAlgorithm,
      token: { colorPrimary: "#00d4ff", colorSuccess: "#f5a623", borderRadius: 4, fontSize: 15 },
    }}>
      <BrowserRouter>
        <Background />
        <WarpRouter />
        <AssistantPanel />
      </BrowserRouter>
    </ConfigProvider>
  </React.StrictMode>
);
