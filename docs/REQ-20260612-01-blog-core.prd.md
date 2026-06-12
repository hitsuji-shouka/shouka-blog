# REQ-20260612-01-blog-core PRD

> 文档版本：v1.0 | 创建日期：2026-06-12 | 状态：草稿

## 1. 背景与目标

### 1.1 背景
开发者 shoka 计划做一个融入 agent 能力的个人博客，发布学习/阅读/音乐/理财等思考。完整产品含博客本体、访客 agent 对话、理财抓取 pipeline、RAG 人设、skill 系统等多个子系统。本 PRD 仅覆盖第一个子需求——博客本体，作为后续 agent（A 阶段）的内容载体：没有文章数据，RAG 与 agent 检索无从谈起。

### 1.2 目标
快速上线一个可公网访问的静态个人博客：本地写 Markdown、git push 即发布，展示四类内容，支持白名单平台的媒体嵌入，并预留全站悬浮助理入口的空壳，为 A 阶段对话功能做布局准备。

### 1.3 非目标（YAGNI 裁剪）
- 评论系统——明确不做
- 后台管理与登录鉴权——本地写文件即可，后端只读
- 助理对话功能——仅占位按钮，A 阶段实现
- 数据库——B 阶段文章即文件，无需数据库；A 阶段再引入
- 标签独立页、置顶/草稿、关于页独立路由——未来加 frontmatter 字段或页面成本极低

## 2. 用户故事

| 角色 | 期望 | 目的 |
|------|------|------|
| 作为博主 shoka | 本地写 .md 并 git push | 无需后台即可发布，专注写作 |
| 作为博主 shoka | 文章中以简单语法嵌入 B站/YouTube/网易云/Spotify/小宇宙 | 音乐与视频内容可直接播放 |
| 作为访客 | 浏览首页文章列表 | 快速了解博主在写什么 |
| 作为访客 | 按学习/阅读/音乐/理财分类浏览 | 找到感兴趣的领域 |
| 作为访客 | 读文章详情、点 tag 筛选 | 顺着兴趣继续读 |

---

## 3. 功能需求

### 3.1 前端
三个页面 + 一个全站组件：

- 首页：全部文章列表，按日期倒序，每条显示标题、日期、分类、summary、封面（有则显示）。点击进详情。
- 详情页：react-markdown 渲染原文，顶部显示标题/日期/分类/tags，tag 可点跳到分类页对应筛选。文章不存在显示 404。
- 分类页：学习/阅读/音乐/理财四栏，列出该类文章；为空显示"还没有文章"。
- 悬浮助理按钮（全站）：右下角占位，点击提示"即将上线"，不接对话。

媒体嵌入：详情页解析自定义指令 `::platform{id=xxx}`，platform ∈ {bilibili, youtube, netease, spotify, xiaoyuzhou}，渲染为对应平台的内嵌播放器（iframe）。语法不合法或平台不在白名单时，原样显示文本不渲染播放器。

### 3.2 后端
FastAPI 单服务，启动时全量读 content/*.md 进内存，只读不写；同时托管 React 静态产物（API 走 /api/*，其余路径回 index.html）。

- `GET /api/posts`：返回全部文章元数据（不含正文），日期倒序
- `GET /api/posts/{slug}`：返回单篇含正文 Markdown，不存在返 404
- `GET /api/posts?category=学习`：按分类过滤，分类非法返空数组
- 列表空时返回空数组，前端兜底文案

## 4. 数据模型草图（无需数据库）

文章为 `content/*.md`，frontmatter 字段：title、date、category（学习/阅读/音乐/理财）、tags[]、summary、cover（可选），正文 Markdown。slug 取文件名。

## 5. 非功能需求

### 5.1 性能
全量驻内存，接口毫秒级；React 首屏懒加载，悬浮助理与嵌入播放器不拖慢首屏。

### 5.2 权限与安全
无登录、无写接口，仅三个只读 GET。媒体嵌入仅允许五个白名单平台域名，iframe 加 sandbox 属性，自定义指令解析不放行任意 HTML，杜绝 XSS。

### 5.3 兼容性
桌面 + 移动端响应式；助理悬浮按钮与嵌入播放器移动端不遮挡正文。香港服务器单 FastAPI 进程托管 API + 静态产物，Caddy 自动 HTTPS。

## 6. 验收标准

- [ ] Given 内存有文章，When 打开首页，Then 按日期倒序显示全部文章标题/日期/分类/summary，有封面显示封面
- [ ] Given 点击文章，When 进详情页，Then react-markdown 渲染正文，顶部显示标题/日期/分类/tags
- [ ] Given 详情页点 tag，When 跳转，Then 进分类页并筛出含该 tag 文章
- [ ] Given 访问不存在 slug，When 加载详情，Then 显示 404
- [ ] Given 某分类无文章，When 访问分类页，Then 显示"还没有文章"
- [ ] Given 四个分类，When 访问分类页，Then 仅列该分类文章
- [ ] Given 文章含 `::bilibili{id=BV1xx}` 等五平台指令，When 渲染详情，Then 显示对应嵌入播放器
- [ ] Given 文章含非白名单或非法嵌入指令，When 渲染，Then 原样显示文本不出播放器
- [ ] Given 任意页面，When 看右下角，Then 显示助理按钮，点击提示"即将上线"
- [ ] Given git push 新增 .md 并重新部署，When 访问首页，Then 新文章出现
- [ ] Given 桌面与移动端，When 访问各页，Then 布局正常、按钮与播放器不遮正文

## 7. 待确认问题

- [ ] A 阶段子需求：访客 agent 对话（依赖本阶段文章数据）
- [ ] 后续：理财 pipeline / RAG 人设 / skill 系统 / trace+eval
- [ ] dev-sop 阶段需把 Java 编码规范替换为 Python/FastAPI（现 SOP 源自 finappprod Java 项目）
