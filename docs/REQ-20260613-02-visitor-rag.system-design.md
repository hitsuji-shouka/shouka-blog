# REQ-20260613-02-visitor-rag 系统设计

> v1.0 | 2026-06-13 | 对应 PRD：REQ-20260613-02 | 依赖：REQ-20260612-01

## 1. 架构概览
B 阶段单 FastAPI 进程内新增 RAG 子系统，不动现有只读接口。启动加载文章后增量构建向量索引：每篇分块 → 硅基流动 bge-m3 算 embedding 驻内存。访客 `POST /api/chat`：最新问题 embedding → 余弦 top-k 文章块 → 命中拼上下文 + 多轮 messages 调 DeepSeek v4-pro 流式（SSE）。top-k 全低于阈值或无块 → 不带上下文纯模型直答，sources 空。两端 OpenAI 兼容，key/base_url 走环境变量，前端不持密钥。

## 2. 目录结构（增量）
backend/ rag.py(分块+embedding+余弦索引) chat.py(APIRouter:/api/chat SSE) llm.py(DeepSeek/硅基流动 OpenAI 兼容客户端) config 扩展
frontend/ components/AssistantPanel.tsx(替换 AssistantButton) lib/chat.ts(SSE 解析)

## 3. 接口契约
POST /api/chat  body {messages:[{role:"user"|"assistant",content}]} ；上限 messages≤20、单条≤2000 字
-> text/event-stream，SSE event：
  delta   {text}        逐字增量
  sources [{slug,title}] 命中文章，发于首 delta 前；直答时为 []
  done    {}            结束
错误：DeepSeek/embedding 异常 → 已开流发 error 事件后 done；未开流 → 503。不动 B 阶段 /api/posts·/categories。

## 4. 检索与生成
分块：按文章正文段落聚合到 ~500 字，记 slug/title。启动顺序构建，embedding 失败跳过记日志。
检索：问题向量与各块余弦，top_k=3，相似度阈值 0.35；过阈纳入上下文并去重出 sources。
生成：system 注入 shoka 助理设定 + 命中文章正文；无命中则纯问答。chat=deepseek-v4-pro，base https://api.deepseek.com；embedding=BAAI/bge-m3，base 硅基流动。stream=True 转 SSE。
配置：BLOG_DEEPSEEK_KEY/BASE/MODEL、BLOG_EMBED_KEY/BASE/MODEL、BLOG_TOP_K、BLOG_SIM_THRESHOLD。

## 5. 部署
进程内 numpy 余弦，无外部向量服务，单进程不变；Caddy 需关 /api/chat 缓冲支持 SSE。重部署重建索引。key 仅服务端 env。无 key 时索引空 → 全部直答，不崩。
