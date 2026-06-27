import { Headphones } from "lucide-react";

export function PostAudio({ src }: { src?: string | null }) {
  if (!src) return null;
  return (
    <section className="post-audio hud-panel">
      <div className="post-audio__header">
        <span><Headphones size={16} /> AUDIO BRIEFING</span>
        <small>MINIMAX TTS STREAM</small>
      </div>
      <audio controls src={src} />
    </section>
  );
}
