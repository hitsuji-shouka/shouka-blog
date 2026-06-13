import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter, Link, Route, Routes, useLocation, useNavigate } from "react-router-dom";
import { ConfigProvider, Layout, Menu, theme } from "antd";
import { Home } from "./pages/Home";
import { Post } from "./pages/Post";
import { Category } from "./pages/Category";
import { AssistantPanel } from "./components/AssistantPanel";
import { Background } from "./components/Background";
import { CATS } from "./lib/cat";
import "./index.css";

const { Header, Content, Footer } = Layout;

function Nav() {
  const nav = useNavigate();
  const loc = useLocation();
  const items = [
    { key: "/", label: "首页" },
    ...CATS.map((c) => ({ key: `/category/${c}`, label: c })),
  ];
  return (
    <Header className="site-header">
      <Link to="/" className="brand">shouka<span>.blog</span></Link>
      <Menu mode="horizontal" theme="light" selectedKeys={[loc.pathname]} items={items}
        onClick={(e) => nav(e.key)} className="site-menu" />
      <span className="site-slogan">AI · 阅读 · 音乐 · 理财 · 融入 agent</span>
    </Header>
  );
}

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <ConfigProvider theme={{ algorithm: theme.defaultAlgorithm,
      token: { colorPrimary: "#1677ff", colorSuccess: "#52c41a", borderRadius: 10, fontSize: 15 } }}>
      <BrowserRouter>
        <Background />
        <Layout className="site">
          <Nav />
          <Content className="site-content">
            <Routes>
              <Route path="/" element={<Home />} />
              <Route path="/post/:slug" element={<Post />} />
              <Route path="/category/:name" element={<Category />} />
              <Route path="*" element={<p className="empty">404</p>} />
            </Routes>
          </Content>
          <Footer className="site-footer">shouka · 融入 agent 的个人博客</Footer>
        </Layout>
        <AssistantPanel />
      </BrowserRouter>
    </ConfigProvider>
  </React.StrictMode>
);
