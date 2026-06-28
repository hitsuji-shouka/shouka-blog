# 理财早报定时发布运行手册

## 日常命令

在项目根目录执行：

```bash
python3 -m pipeline.daily_finance
```

默认行为：

- 抓取理财新闻源，生成当天 `content/finance-YYYYMMDD.md`
- 调用 MiniMax 生成 `frontend/public/audio/finance-YYYYMMDD.mp3`
- 成功后提交并推送生成的 Markdown 和音频文件
- 写入当天日志 `pipeline/logs/finance-YYYYMMDD.log`
- 创建当天锁 `pipeline/logs/finance-YYYYMMDD.lock`，防止同一天并发重复执行

## OpenClaw 定时任务

建议在 OpenClaw 中配置每天早上 06:40 执行：

```bash
cd /Users/sxy/develop/shouka-blog && python3 -m pipeline.daily_finance
```

如果 OpenClaw 已经先抓好结构化新闻 JSON，可以把文件交给 pipeline：

```bash
cd /Users/sxy/develop/shouka-blog && python3 -m pipeline.daily_finance --input /path/to/openclaw-finance.json
```

## 手动演练

只生成文件，不发布：

```bash
python3 -m pipeline.daily_finance --no-publish
```

只生成文字，不生成音频：

```bash
python3 -m pipeline.daily_finance --no-audio --no-publish
```

临时指定 MiniMax 音色：

```bash
python3 -m pipeline.daily_finance --voice female-yujie
```

更适合理财早报的稳重女声推荐使用：

```bash
python3 -m pipeline.daily_finance --voice presenter_female
```

覆盖当天已有早报：

```bash
python3 -m pipeline.daily_finance --force
```

降低调试时的新闻数量门槛：

```bash
python3 -m pipeline.daily_finance --min-items 1 --no-publish
```

## 失败处理

- 如果返回码是 `2`，表示当天已有任务在运行；检查 `pipeline/logs/finance-YYYYMMDD.lock`。
- 如果新闻不足，pipeline 会跳过生成，不会提交或推送。
- 如果 MiniMax TTS 失败，任务会失败并保留日志，不会发布半成品。
- 每次排查先看当天日志：`pipeline/logs/finance-YYYYMMDD.log`。

## 密钥

MiniMax 和百炼 key 只放在本机 `.env` 或部署环境变量中，不提交到仓库。定时任务运行前要确保环境能读取项目 `.env` 或已设置同名环境变量。
