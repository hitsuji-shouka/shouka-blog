import { useState } from "react";
import { Link } from "react-router-dom";
import { AnimatePresence, motion } from "framer-motion";
import { sendChat, type ChatMsg, type Source } from "../lib/chat";

function AgentMark({ talking }: { talking?: boolean }) {
  return (
    <div className="tars" aria-hidden>
      {[0, 1, 2, 3].map((i) => (
        <motion.span key={i} className="tars__slab"
          animate={talking ? { y: [0, -6, 0] } : { y: 0 }}
          transition={{ duration: 0.6, repeat: talking ? Infinity : 0, delay: i * 0.08 }} />
      ))}
    </div>
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
      onDelta: (t) => setMsgs((m) => { const c = [...m]; c[c.length - 1] = { role: "assistant", content: c[c.length - 1].content + t }; return c; }),
      onError: (e) => setMsgs((m) => { const c = [...m]; c[c.length - 1] = { role: "assistant", content: e }; return c; }),
    });
    setBusy(false);
  }

  return (
    <>
      {!open && (
        <motion.button className="tars-fab" aria-label="打开站内 Agent" onClick={() => setOpen(true)}
          whileHover={{ rotate: 4, scale: 1.05 }} whileTap={{ scale: 0.96 }}>
          <AgentMark /><span>AGENT</span>
        </motion.button>
      )}
      <AnimatePresence>
        {open && (
          <motion.div className="tars-panel" initial={{ opacity: 0, y: 30, scale: .96 }}
            animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0, y: 30, scale: .96 }}
            transition={{ type: "spring", stiffness: 260, damping: 24 }}>
            <header><AgentMark talking={busy} /><b>Agent</b><span className="tars-status">site memory</span>
              <button onClick={() => setOpen(false)} aria-label="关闭">✕</button></header>
            <div className="tars-msgs">
              {msgs.length === 0 && <div className="bubble bot">问我关于站内文章、技术记录或理财复盘的问题。</div>}
              {msgs.map((m, i) => <div key={i} className={`bubble ${m.role === "user" ? "me" : "bot"}`}>{m.content || "…"}</div>)}
              {sources.length > 0 && <div className="sources">来源 · {sources.map((s) => <Link key={s.slug} to={`/post/${s.slug}`}>{s.title}</Link>)}</div>}
            </div>
            <div className="tars-input">
              <input value={input} onChange={(e) => setInput(e.target.value)} onKeyDown={(e) => e.key === "Enter" && send()} placeholder="向站内 Agent 提问…" />
              <button disabled={busy || !input.trim()} onClick={send}>{busy ? "···" : "↑"}</button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
