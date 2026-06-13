# REQ-20260613-03-finance-daily 系统设计

> v1.0 | 2026-06-13 | 对应 PRD：REQ-20260613-03 | 依赖：REQ-20260612-01, REQ-20260613-02

## 1. 架构概览
本地 pipeline（与服务器解耦）：抓推特 6 博主近 24h 推文 → DeepSeek v4-pro 汇总中文报告 → 写 content/finance-YYYYMMDD.md → git push，复用「push 即发布」。服务器只展示。报告靠 tag「每日报告」标识，rag.py 构建时跳过，不污染助理问答。前端理财页按该 tag 分原创/报告两区。

## 2. 目录结构（增量）
pipeline/  fetch.py(CDP 抓推) summarize.py(DeepSeek) report.py(生成 md+frontmatter+push) config.py(handles) run.py(入口) bloggers.toml
backend/   rag.py 加 tag 过滤；posts.py 不变
frontend/  pages/Category.tsx 理财分区
cron: 本地 crontab 每日跑 run.py

## 3. 抓取与生成
fetch：web-access CDP 开后台 tab 逐个 x.com/{handle}，滚动取近 24h 推文文本+链接，限速防风控，失败跳过记日志。
summarize：DeepSeek 按博主归纳要点，中文 markdown，附原推链。
report：frontmatter title「每日金融观点 6-13」、date、category 理财、tags=[每日报告]、summary 自动；slug finance-YYYYMMDD；空数据不生成；git add/commit/push。

## 4. RAG 排除与前端
rag.build 跳过 tags 含「每日报告」的文章；只读接口与 PostMeta 不变（已含 tags）。
理财页 listPosts("理财") 后前端按 tags 分「原创」「每日报告」两区渲染，空区兜底文案。

## 5. 部署与安全
pipeline 仅本地（登录态/反爬），不进 Docker。推特 cookie、DeepSeek key 本地 env。仅聚合公开推文+附原链注明来源。报告即 .md，无新接口无库；服务器重部署自动收新报告。
