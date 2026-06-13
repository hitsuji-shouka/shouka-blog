import { useState } from "react";
import { Link } from "react-router-dom";
import { Button, Input, Tag } from "antd";
import { CloseOutlined, SendOutlined } from "@ant-design/icons";
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

  if (!open) return (
    <button className="totoro-fab" aria-label="问问 shouka" onClick={() => setOpen(true)}>
      <img src="/totoro.png" alt="" />
    </button>
  );
  return (
    <div className="assistant-panel">
      <header><img className="totoro-mini" src="/totoro.png" alt="" />问问 shouka
        <Button type="text" size="small" icon={<CloseOutlined />} onClick={() => setOpen(false)} aria-label="关闭" /></header>
      <div className="assistant-msgs">
        {msgs.map((m, i) => <div key={i} className={`bubble ${m.role}`}>{m.content || "…"}</div>)}
        {sources.length > 0 && (
          <div className="sources">来源：{sources.map((s) => <Tag key={s.slug} color="green"><Link to={`/post/${s.slug}`}>{s.title}</Link></Tag>)}</div>
        )}
      </div>
      <div className="assistant-input">
        <Input value={input} onChange={(e) => setInput(e.target.value)} onPressEnter={send}
          placeholder="问博主写过什么…" />
        <Button type="primary" icon={<SendOutlined />} loading={busy} disabled={!input.trim()} onClick={send}>发送</Button>
      </div>
    </div>
  );
}
