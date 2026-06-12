# REQ-20260613-02-visitor-rag PRD

> 文档版本：v1.0 | 创建日期：2026-06-13 | 状态：定稿 | 依赖：REQ-20260612-01-blog-core

## 1. 背景与目标

### 1.1 背景
B 阶段（REQ-20260612-01）已上线博客本体，预留了全站悬浮助理空壳。A 阶段把空壳接上访客 agent 对话：访客就博主写过的内容提问，系统检索文章 + LLM 带来源回答。博客文章已就绪，RAG 有了语料。

### 1.2 目标
单 FastAPI 进程内做最小正规 RAG 闭环：启动时把 content/*.md 分块、调 DeepSeek embedding 算向量驻内存；访客提问 → 余弦检索相关文章块 → DeepSeek v4 流式回答并附来源；无相关文章时退回纯模型直答。多轮上下文。完全贴合现有单进程 + Caddy 部署，不引外部向量服务。

### 1.3 非目标（YAGNI 裁剪）
- 专业向量库（Chroma/Qdrant）——体量小，内存余弦足够，文章多再换
- 本地嵌入模型——避免服务器启动/内存开销，用 DeepSeek embedding API
- 会话持久化/登录——多轮历史前端内存维护，刷新即清，不入库
- 对话评估 / trace——后续阶段
- 命中改写、重排、引用高亮——先做基础检索

## 2. 用户故事

| 角色 | 期望 | 目的 |
|------|------|------|
| 作为访客 | 点悬浮助理输入问题 | 不翻文章直接问博主写过什么 |
| 作为访客 | 看到带来源的回答 | 知道答案出自哪篇文章可点进去 |
| 作为访客 | 连续追问 | 顺着上下文深入 |
| 作为访客 | 博客没相关文章时仍得到回答 | 不冷场，模型直答 |
| 作为博主 | push 新文章重部署后自动入索引 | 无需额外操作，文章即语料 |

## 3. 功能需求

### 3.1 前端
- 悬浮助理由占位升级为对话面板：点击右下角按钮展开,标题/输入框/发送/关闭。
- 消息流：用户气泡 + 助理气泡，助理回答 SSE 逐字渲染。
- 来源区：回答下方列命中文章标题，可点跳详情页 `/post/{slug}`；无命中显示"未匹配文章，模型直答"。
- 多轮：前端维护当前会话 messages 数组随请求带上，刷新即清。
- 空/异常态：输入空禁发；请求失败显示"助理暂时不可用"；生成中禁重复发，可看到流式进度。
- 移动端面板不遮正文，可关闭。

### 3.2 后端
新增 `chat` 模块（APIRouter），复用 B 阶段内存文章。
- `POST /api/chat`：入参 `{messages:[{role,content}]}`，SSE 流式返回回答增量 + 末尾 sources。
- 启动加载：B 阶段加载文章后，对每篇分块（按段/定长）调 DeepSeek embedding，向量驻内存。
- 检索：对用户最新问题 embedding，余弦 top-k 文章块，拼上下文 + 多轮 messages 调 DeepSeek v4 流式。
- 退回：top-k 相似度全低于阈值或无文章 → 不带上下文纯模型直答，sources 空。
- 配置：chat（DeepSeek v4-pro，base https://api.deepseek.com）与 embedding（硅基流动 bge-m3，OpenAI 兼容）独立 key/base_url/模型，top_k、阈值走 pydantic-settings 环境变量；两端均 OpenAI 兼容可换。

## 4. 数据模型草图（无数据库）
内存 `chunks: [{slug,title,text,vector}]`，启动构建。出参 `ChatSource: {slug,title}`；SSE event：`delta`（文本增量）、`sources`（命中列表）、`done`。

## 5. 非功能需求

### 5.1 性能
向量驻内存余弦检索毫秒级；回答首字延迟取决于 DeepSeek，流式降低体感。
### 5.2 权限与安全
无登录；api_key 仅后端环境变量不进前端；单条问题/消息数长度上限防滥用；嵌入文章内容不外泄第三方除 DeepSeek。
### 5.3 兼容性
单 FastAPI 进程内新增路由，不动 B 阶段只读接口；桌面+移动端;Caddy 反代支持 SSE。

## 6. 验收标准

- [ ] Given 有相关文章，When 访客提问，Then 流式输出回答且来源列出命中文章可点进详情
- [ ] Given 无任何文章，When 提问，Then 退回纯模型直答、sources 为空、不报错
- [ ] Given 问题与所有文章相似度低于阈值，When 回答，Then 退回直答不强塞无关文章
- [ ] Given 多轮追问，When 第二问，Then 带上历史 messages 上下文连贯
- [ ] Given 输入为空，When 点发送，Then 禁止发送
- [ ] Given DeepSeek 不可用，When 提问，Then 前端显示"助理暂时不可用"不白屏
- [ ] Given 点击来源，When 跳转，Then 进对应文章详情
- [ ] Given push 新文章重部署，When 提问命中新文，Then 来源含新文章
- [ ] Given 移动端，When 展开面板，Then 不遮正文且可关闭

## 7. 待确认问题
- [x] DeepSeek 无 embedding 端点（核实官方文档）→ embedding 改用硅基流动 bge-m3，chat 用 DeepSeek v4-pro，均 OpenAI 兼容
- [ ] 后续：会话持久化、trace+eval、来源高亮、重排
