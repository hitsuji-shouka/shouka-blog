import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter, Link, Route, Routes } from "react-router-dom";
import { Home } from "./pages/Home";
import { Post } from "./pages/Post";
import { Category } from "./pages/Category";
import { AssistantButton } from "./components/AssistantButton";
import "./index.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <BrowserRouter>
      <div className="layout">
        <nav><Link to="/">首页</Link><Link to="/category/学习">分类</Link></nav>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/post/:slug" element={<Post />} />
          <Route path="/category/:name" element={<Category />} />
          <Route path="*" element={<p className="empty">404</p>} />
        </Routes>
      </div>
      <AssistantButton />
    </BrowserRouter>
  </React.StrictMode>
);
