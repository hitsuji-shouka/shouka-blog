# 理财早报与播客设计

> 日期：2026-06-27  
> 状态：待用户复核  
> 范围：替代现有“抓金融博主观点”的理财日报 pipeline，升级为新闻源早报、MiniMax TTS 播客和定时发布流水线。

## 背景

当前理财日报依赖抓取 X/Twitter 金融博主内容，再由 DeepSeek 汇总为“每日金融观点”。这个方案受登录态、反爬和博主内容波动影响较大。新的方向是每天早上自动抓取影响金融市场的新闻，由 AI 整理成可读的理财早报，并用 MiniMax 文转语音生成播客音频，让理财页同时支持阅读和收听。

用户本机已有 OpenClaw，可作为定时任务和本地抓取执行环境。网站继续保持“Markdown 内容 + git 发布”的模式，服务器只负责展示，不承担抓取和生成任务。

## 目标

- 每天早上准时生成一篇“理财早报”文章。
- 早报同时包含完整文字版和音频播客版。
- 新闻来源优先使用稳定、可结构化解析的新闻源，降低维护成本。
- 生成结果自动发布到网站，失败时不发布空内容或半成品。
- 用 MiniMax 账号统一支撑 TTS 和后续问答助手的生成模型迁移。
- 保持“每日报告”类内容不进入 RAG 索引，避免资讯聚合污染原创问答语料。

## 非目标

- 不在服务器端执行新闻抓取或 TTS。
- 不在第一版实现复杂的个性化投资建议、持仓分析或交易信号。
- 不把 MiniMax API key 写入仓库或 Markdown 内容。
- 不依赖博主抓取作为主流程；如后续需要，可作为“市场声音”小节单独扩展。

## 推荐方案

采用“结构化新闻源优先”的本地 pipeline：

1. OpenClaw 每天早上定时触发 pipeline。
2. pipeline 按新闻源配置抓取近 24 小时内容。
3. 抓取结果按 URL、标题和正文摘要去重。
4. AI 生成文字早报和播客稿。
5. MiniMax TTS 将播客稿生成 mp3。
6. pipeline 写入 Markdown 和音频文件。
7. 文字和音频都成功后，自动 git commit 并 push。
8. 现有网站发布机制拉取新提交并更新页面。

这条链路优先保证稳定和可追溯。OpenClaw 负责本机定时、抓取执行和必要重试；项目内 pipeline 负责数据清洗、AI 整理、文件生成、发布前校验和 git 发布。

## 内容形态

每天生成一篇文章：

```text
content/finance-YYYYMMDD.md
```

音频文件放在前端可静态访问的位置：

```text
frontend/public/audio/finance-YYYYMMDD.mp3
```

文章 frontmatter 增加音频字段：

```yaml
---
title: 理财早报 · 06-27
date: 2026-06-27
category: 理财
tags: [每日报告, 理财早报]
summary: 06-27 全球市场与财经新闻早报
audio: /audio/finance-20260627.mp3
sources:
  - Reuters
  - CNBC
---
```

正文结构：

```markdown
## 今日摘要

## 重点新闻

## 影响资产

## 今日关注

## 来源
```

详情页如果发现 `audio` 字段，则在正文上方显示音频播放器。理财分类页继续按 tag 分“原创文章”和“每日报告”，早报卡片可以显示“可听”标记。

## 新闻源策略

第一版使用可配置新闻源列表，按市场影响分组：

- 全球市场：宏观、央行、利率、外汇、美股、大宗商品。
- 中国市场：A 股、港股、中概股、国内政策和重点公司新闻。
- 风险资产：加密资产、科技股和风险偏好变化。

配置文件建议新增：

```text
pipeline/sources.toml
```

每个来源包含名称、URL、类型、分类、权重和语言：

```toml
[[finance.sources]]
name = "CNBC Markets"
url = "https://www.cnbc.com/markets/"
kind = "web"
market = "global"
weight = 2
language = "en"
```

pipeline 优先解析 RSS 或结构化页面。网页源失败时记录日志并跳过，不阻断整个早报，除非有效新闻数量低于发布阈值。

## AI 整理

AI 生成分两步：

1. 文字早报：面向网站阅读，要求客观、按主题归纳、附来源链接，不给投资建议。
2. 播客稿：面向 3 到 6 分钟收听，语气自然，保留重点来源，不朗读复杂 URL。

文字早报和播客稿都基于同一批筛选后的新闻，避免音频和正文结论不一致。AI 输出必须包含来源映射，pipeline 在发布前校验至少有一条来源链接。

## MiniMax 与密钥迁移

新增统一的 MiniMax 配置：

```text
BLOG_MINIMAX_API_KEY
BLOG_MINIMAX_BASE_URL
BLOG_MINIMAX_CHAT_MODEL
BLOG_MINIMAX_TTS_MODEL
BLOG_MINIMAX_TTS_VOICE
```

用途：

- TTS：MiniMax 文转语音使用 `BLOG_MINIMAX_API_KEY`。
- 问答助手：后续把当前 `BLOG_DEEPSEEK_KEY` 对应的聊天模型迁移到 MiniMax 聊天模型，同样读取 `BLOG_MINIMAX_API_KEY`。
- OpenClaw：OpenClaw 触发本项目 pipeline 时，AI 生成和 TTS 都读取同一份 MiniMax key。若 OpenClaw 自身还需要本地调度访问令牌，该令牌只用于 OpenClaw 自身鉴权，不混入项目代码。

密钥只放在本机和部署环境的 `.env` 或密钥管理中，不提交到 git。项目代码只读取环境变量。

## 定时发布

推荐每天早上按如下节奏执行：

- 06:30 OpenClaw 触发抓取。
- 06:40 AI 生成文字早报和播客稿。
- 06:45 MiniMax TTS 生成音频。
- 06:50 写入 Markdown 和 mp3。
- 06:55 git commit 并 push。
- 07:00 网站完成更新。

OpenClaw 执行的命令建议设计为：

```text
python -m pipeline.run finance --mode news --with-audio --publish
```

如果网站部署依赖 git 自动发布，则 push 后由现有部署链路处理。如果线上服务器需要手动拉取，则后续可增加一个受控的部署步骤，但第一版优先采用 git push 触发发布。

## 可靠性规则

- 幂等：当天已有 `finance-YYYYMMDD.md` 时默认跳过，手动传 `--force` 才覆盖。
- 空数据保护：有效新闻少于阈值时不生成文章。
- 音频保护：TTS 失败时默认不发布当天早报，避免出现“可听”但无音频的文章。
- 原子发布：先写临时目录，正文、来源和音频都校验成功后再移动到正式路径。
- 重试：新闻抓取和 TTS 支持有限次数重试；AI 整理失败直接终止。
- 日志：每天写入 `pipeline/logs/finance-YYYYMMDD.log`，记录来源成功率、新闻数量、AI/TTS 状态和发布结果。

## 代码影响范围

- `pipeline/`：新增新闻抓取、来源配置、去重、MiniMax TTS、发布控制和 CLI 参数。
- `backend/models.py` / `backend/posts.py`：文章模型支持可选 `audio` 字段。
- `frontend/src/pages/Post.tsx`：详情页顶部显示音频播放器。
- `frontend/src/components/PostCard.tsx` 或分类页：报告卡片显示可听状态。
- `backend/rag.py`：继续跳过 tag 含“每日报告”的文章。
- `docs/`：更新原 finance daily 文档，说明从博主流升级为新闻早报流。

## 验收标准

- 给定新闻源配置，运行 finance news pipeline 后，生成当天 Markdown 和 mp3。
- 生成文章包含 `category: 理财`、`tags: [每日报告, 理财早报]` 和 `audio` 字段。
- 详情页展示音频播放器，播放器可加载当天 mp3。
- 理财页仍能按“原创文章 / 每日报告”分区展示。
- 当新闻不足、AI 失败或 TTS 失败时，不 commit、不 push、不发布半成品。
- 当当天早报已经存在时，默认不重复生成。
- 问答助手迁移后聊天模型读取 `BLOG_MINIMAX_API_KEY`，不再依赖 `BLOG_DEEPSEEK_KEY`。
- RAG 构建继续排除 tag 含“每日报告”的文章。
