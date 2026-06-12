import { useState } from "react";
import { Link } from "react-router-dom";
import { sendChat, type ChatMsg, type Source } from "../lib/chat";

export function AssistantPanel() {
  const [open, setOpen] = useState(false);
  const [msgs, setMsgs] = useState<ChatMsg[]>([]);
  const [sources, setSources] = useState<Source[]>([]);
  const [input, setInput] = useState("");
  const [busy, setBusy] = useState(false);

  async function send() {
    const q = input.trim();
    if (!q || busy) return;
    const history: ChatMsg[] = [...msgs, { role: "user", content: q }];
    setMsgs([...history, { role: "assistant", content: "" }]);
    setInput(""); setSources([]); setBusy(true);
    await sendChat(history, {
      onSources: setSources,
      onDelta: (t) => setMsgs((m) => {
        const c = [...m]; c[c.length - 1] = { role: "assistant", content: c[c.length - 1].content + t }; return c;
      }),
      onError: (e) => setMsgs((m) => {
        const c = [...m]; c[c.length - 1] = { role: "assistant", content: e }; return c;
      }),
    });
    setBusy(false);
  }

  if (!open) return <button className="assistant-fab" aria-label="助理" onClick={() => setOpen(true)}>💬</button>;
  return (
    <div className="assistant-panel">
      <header>问问 shoka<button onClick={() => setOpen(false)} aria-label="关闭">×</button></header>
      <div className="assistant-msgs">
        {msgs.map((m, i) => <div key={i} className={`bubble ${m.role}`}>{m.content || "…"}</div>)}
        {sources.length > 0 && (
          <div className="sources">来源：{sources.map((s) => <Link key={s.slug} to={`/post/${s.slug}`}>{s.title}</Link>)}</div>
        )}
      </div>
      <div className="assistant-input">
        <input value={input} onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && send()} placeholder="问博主写过什么…" />
        <button onClick={send} disabled={busy || !input.trim()}>发送</button>
      </div>
    </div>
  );
}
