import { useState } from "react";
import { Link } from "react-router-dom";
import { Button, Input, Tag } from "antd";
import { Send, X } from "lucide-react";
import { sendChat, type ChatMsg, type Source } from "../lib/chat";

function TarsBars() {
  return (
    <span className="tars-bars" aria-hidden>
      {[0.8, 1, 0.58, 0.9, 0.68].map((height, index) => (
        <i key={index} style={{ height: `${height * 18}px`, animationDelay: `${index * 0.13}s` }} />
      ))}
    </span>
  );
}

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

  if (!open) return (
    <button className="tars-fab" aria-label="问问 shouka" onClick={() => setOpen(true)}>
      <TarsBars />
      <span>TARS</span>
    </button>
  );
  return (
    <aside className="assistant-panel hud-panel">
      <header>
        <div><TarsBars /><strong>TARS</strong><small>shouka assistant</small></div>
        <Button type="text" size="small" icon={<X size={16} />} onClick={() => setOpen(false)} aria-label="关闭" />
      </header>
      <div className="assistant-msgs">
        {msgs.length === 0 && <div className="bubble assistant">你好，我是 TARS。你可以问我博客里写过什么，或让理财早报为你导航。</div>}
        {msgs.map((m, i) => <div key={i} className={`bubble ${m.role}`}>{m.content || "…"}</div>)}
        {sources.length > 0 && (
          <div className="sources">来源：{sources.map((s) => <Tag key={s.slug}><Link to={`/post/${s.slug}`}>{s.title}</Link></Tag>)}</div>
        )}
      </div>
      <div className="assistant-input">
        <Input value={input} onChange={(e) => setInput(e.target.value)} onPressEnter={send}
          placeholder="向 TARS 提问..." />
        <Button type="primary" icon={<Send size={14} />} loading={busy} disabled={!input.trim()} onClick={send}>发送</Button>
      </div>
    </aside>
  );
}
