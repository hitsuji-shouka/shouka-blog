# REQ-20260613-03-finance-daily PRD

> 文档版本：v1.0 | 创建日期：2026-06-13 | 状态：定稿 | 依赖：REQ-20260612-01, REQ-20260613-02

## 1. 背景与目标

### 1.1 背景
理财是博客四分类之一。除手写理财文章外，希望每天自动汇集热门金融博主（主推特）观点，生成一篇「每日报告」。报告是资讯聚合，与个人原创区分，且不应污染 RAG 问答语料。

### 1.2 目标
本地 pipeline（你登录态 Chrome）每日抓指定推特金融博主近 24h 推文 → DeepSeek 汇总成中文每日报告 → 落 content/ 为理财分类、tag「每日报告」的 .md → git push 即上线。报告不进 RAG 索引；前端理财页可按 tag 区分原创/报告。

### 1.3 非目标（YAGNI 裁剪）
- 服务器端抓取——无登录态/反爬，pipeline 跑本地
- 微博/雪球/多源——先只推特，跑通再扩
- 行情数值/持仓抓取——只汇观点
- 报告入 RAG——明确排除，避免资讯转述污染问答

## 2. 用户故事
| 角色 | 期望 | 目的 |
|------|------|------|
| 博主 shouka | 每天一键/定时生成金融博主观点报告并发布 | 不手动刷推特 |
| 访客 | 理财页区分原创文章与每日报告 | 各取所需 |
| 系统 | 报告不进助理 RAG | 问答只引原创，不混资讯 |

## 3. 功能需求

### 3.1 pipeline（本地脚本）
- 配置博主名单（推特 handle 列表）+ 抓取近 24h 推文（web-access/CDP，登录态）。
- DeepSeek 汇总：按博主/主题归纳要点，输出中文 markdown，附原推链接。
- 写 content/finance-YYYYMMDD.md：category 理财、tags 含「每日报告」、summary 自动、date 当日。
- 定时：本地 cron 每日跑；失败记日志不发空报告。

### 3.2 前端
- 理财页内按 tag 分两区：原创文章 / 每日报告（tag「每日报告」）。
- 报告卡片同列表样式，可点进详情。

### 3.3 后端（RAG 排除）
- rag 构建跳过 tags 含「每日报告」的文章；其余只读接口不变。

## 4. 数据模型
沿用文章 frontmatter，新增约定：tag「每日报告」标识报告类、RAG 跳过。无新表。

## 5. 非功能需求
性能：抓取限速防风控。安全：推特登录态仅本地，不上服务器；DeepSeek key 本地 env。合规：仅聚合公开推文+附原链，注明来源。

## 6. 验收标准
- [ ] Given 配置 N 个 handle，When 跑 pipeline，Then 生成当日 content/finance-*.md，category 理财、tag 含每日报告
- [ ] Given 报告已发，When 访客看理财页，Then 原创与每日报告分区显示
- [ ] Given 报告含「每日报告」tag，When 重建 RAG，Then 助理问答不引用报告
- [ ] Given 抓取失败，When 跑 pipeline，Then 不生成空报告并记日志
- [ ] Given git push 报告，When 访问，Then 当日报告出现且可读

## 7. 待确认问题
- [x] 初始名单：HenryinvestX、xiaomustock、aleabitoreddit、WiseInvest513、jason_chen998、LucyBuilding
- [x] 推特无 RSS → 本地 CDP 登录态抓，服务器仅展示
- [ ] 后续：多源、行情、定时 trace
