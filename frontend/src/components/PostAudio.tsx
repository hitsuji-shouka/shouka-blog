import { Download, Headphones } from "lucide-react";

export function PostAudio({ src }: { src?: string | null }) {
  if (!src) return null;
  const fileName = audioFileName(src);
  return (
    <section className="post-audio hud-panel">
      <div className="post-audio__header">
        <span><Headphones size={16} /> AUDIO BRIEFING</span>
        <a className="post-audio__download" href={src} download={fileName}>
          <Download size={14} />
          下载音频
        </a>
      </div>
      <audio controls src={src} />
    </section>
  );
}

function audioFileName(src: string): string {
  const path = src.split("?")[0];
  return path.split("/").filter(Boolean).pop() || "briefing.mp3";
}
