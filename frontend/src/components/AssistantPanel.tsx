import { type KeyboardEvent, useState } from "react";
import { Link } from "react-router-dom";
import { Send, SlidersHorizontal, X } from "lucide-react";
import { sendChat, type ChatMsg, type Source } from "../lib/chat";
import { createTextStreamer } from "../lib/typewriter";

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
  const [humor, setHumor] = useState(35);
  const [honesty, setHonesty] = useState(92);

  async function send() {
    const q = input.trim();
    if (!q || busy) return;
    const history: ChatMsg[] = [...msgs, { role: "user", content: q }];
    setMsgs([...history, { role: "assistant", content: "" }]);
    setInput(""); setSources([]); setBusy(true);
    const appendAssistantText = (text: string) => setMsgs((m) => {
      const c = [...m]; c[c.length - 1] = { role: "assistant", content: c[c.length - 1].content + text }; return c;
    });
    const streamer = createTextStreamer({ delayMs: 18, onText: appendAssistantText });
    await sendChat(history, {
      onSources: setSources,
      onDelta: streamer.enqueue,
      onError: (e) => setMsgs((m) => {
        streamer.clear();
        const c = [...m]; c[c.length - 1] = { role: "assistant", content: e }; return c;
      }),
    }, { humor, honesty });
    await streamer.drain();
    streamer.dispose();
    setBusy(false);
  }

  function onInputKeyDown(e: KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      void send();
    }
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
        <div><TarsBars /><strong>TARS</strong><small>personality interface</small></div>
        <button className="icon-button" onClick={() => setOpen(false)} aria-label="关闭"><X size={16} /></button>
      </header>
      <section className="tars-controls" aria-label="TARS 人格参数">
        <div className="tars-control-head"><SlidersHorizontal size={14} /><span>CASE / COOPER STATION LINK</span></div>
        <label>
          <span>Humor</span><b>{humor}%</b>
          <input type="range" min="0" max="100" value={humor} onChange={(e) => setHumor(Number(e.target.value))} />
        </label>
        <label>
          <span>Honesty</span><b>{honesty}%</b>
          <input type="range" min="0" max="100" value={honesty} onChange={(e) => setHonesty(Number(e.target.value))} />
        </label>
      </section>
      <div className="assistant-msgs">
        {msgs.length === 0 && <div className="bubble assistant">TARS 在线。幽默度和诚实度已接入任务参数。你可以问我博客里写过什么，或让理财早报为你导航。</div>}
        {msgs.map((m, i) => <div key={i} className={`bubble ${m.role}`}>{m.content || "…"}</div>)}
        {sources.length > 0 && (
          <div className="sources">来源：{sources.map((s) => <Link key={s.slug} className="source-chip" to={`/post/${s.slug}`}>{s.title}</Link>)}</div>
        )}
      </div>
      <div className="assistant-input">
        <textarea value={input} onChange={(e) => setInput(e.target.value)} onKeyDown={onInputKeyDown}
          placeholder="向 TARS 提问..." rows={2} />
        <button className="send-button" disabled={busy || !input.trim()} onClick={send}>
          <Send size={14} />
          {busy ? "传输" : "发送"}
        </button>
      </div>
    </aside>
  );
}
