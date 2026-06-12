# REQ-20260612-01-blog-core 系统设计

> v1.0 | 2026-06-12 | 对应 PRD：REQ-20260612-01

## 1. 架构概览
单 FastAPI 进程：启动扫 content/*.md 进内存，提供 /api/* 只读接口，其余路径回 React index.html。前端 react-markdown 渲染，自定义 remark 插件解析嵌入指令。Caddy 反代 + 自动 HTTPS，香港服务器。无数据库、无鉴权、无写接口。

## 2. 目录结构
shoka-blog/
  content/            文章 .md（git 即存储）
  backend/  main.py(入口+静态托管) posts.py(加载/解析/索引) models.py
  frontend/ src/{pages,components,lib} Vite+React+TS
  docs/{requirements,design}
  Caddyfile · Dockerfile

## 3. 接口契约（裸 JSON，无企业返回包）
- GET /api/posts -> 200 [PostMeta]（日期倒序，不含正文）
- GET /api/posts?category=学习 -> 过滤；非法分类返 []
- GET /api/posts/{slug} -> 200 PostDetail / 404
- GET /api/categories -> 四分类及计数
PostMeta: slug,title,date,category,tags[],summary,cover?
PostDetail: +content（原始 md）

## 4. 嵌入指令规范
remark 插件解析 ::platform{id=xxx}，白名单映射 sandbox iframe，非白名单或缺 id 原样输出。
bilibili player.bilibili.com/player.html?bvid={id}
youtube youtube.com/embed/{id}
netease music.163.com/outchain/player?id={id}
spotify open.spotify.com/embed/{id}
xiaoyuzhou xiaoyuzhoufm.com/episode/{id}
安全：仅五域名，iframe sandbox，id 仅 [A-Za-z0-9/_-]，不匹配不渲染。

## 5. 加载与部署
启动扫 content 解析 frontmatter+slug，按 date 倒序，解析失败跳过记日志，重新部署刷新。
/api/* 走接口其余回 index.html。多阶段 Docker(node 构建→python 依赖→合并)，compose app+caddy，国内镜像源。cover 走外链。
