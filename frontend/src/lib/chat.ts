export interface ChatMsg { role: "user" | "assistant"; content: string; }
export interface Source { slug: string; title: string; }
export interface ChatPersonality { humor: number; honesty: number; }

export interface ChatHandlers {
  onSources: (s: Source[]) => void;
  onDelta: (t: string) => void;
  onError: (m: string) => void;
}

// 解析 SSE 文本块，逐 event 分发；返回未消费的残余
export function parseSSE(buf: string, h: ChatHandlers): string {
  const parts = buf.split("\n\n");
  const rest = parts.pop() ?? "";
  for (const block of parts) {
    const ev = /event: (\w+)/.exec(block)?.[1];
    const data = /data: (.+)/.exec(block)?.[1];
    if (!ev || !data) continue;
    const p = JSON.parse(data);
    if (ev === "sources") h.onSources(p.sources);
    else if (ev === "delta") h.onDelta(p.text);
    else if (ev === "error") h.onError(p.message);
  }
  return rest;
}

export async function sendChat(messages: ChatMsg[], h: ChatHandlers, personality?: ChatPersonality): Promise<void> {
  const r = await fetch("/api/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(personality ? { messages, personality } : { messages }),
  });
  if (!r.ok || !r.body) return h.onError("助理暂时不可用");
  const reader = r.body.getReader();
  const dec = new TextDecoder();
  let buf = "";
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    buf = parseSSE(buf + dec.decode(value, { stream: true }), h);
  }
}
