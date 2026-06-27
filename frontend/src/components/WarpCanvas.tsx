import { useEffect, useRef } from "react";

export function shouldPlayWarp(reduceMotion: boolean, from: string, to: string): boolean {
  return !reduceMotion && from !== to;
}

export function gravityTransitionProfile(width: number): { dust: number; completeAt: number; duration: number } {
  return width < 760
    ? { dust: 90, completeAt: 740, duration: 1320 }
    : { dust: 180, completeAt: 760, duration: 1380 };
}

export function WarpCanvas({ trigger, onComplete }: { trigger: boolean; onComplete?: () => void }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const frameRef = useRef<number>();
  const completeRef = useRef(onComplete);

  useEffect(() => { completeRef.current = onComplete; }, [onComplete]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const resize = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
    };
    resize();
    window.addEventListener("resize", resize);
    return () => window.removeEventListener("resize", resize);
  }, []);

  useEffect(() => {
    if (!trigger) return;
    const canvas = canvasRef.current;
    const ctx = canvas?.getContext("2d");
    if (!canvas || !ctx) {
      completeRef.current?.();
      return;
    }

    const profile = gravityTransitionProfile(window.innerWidth);
    let elapsed = 0;
    let completed = false;
    const dust = Array.from({ length: profile.dust }, (_, i) => ({
      x: ((Math.sin(i * 91.7) + 1) / 2) * canvas.width,
      y: ((Math.sin(i * 41.3) + 1) / 2) * canvas.height,
      z: 0.18 + ((Math.sin(i * 17.1) + 1) / 2) * 0.82,
      drift: Math.sin(i * 13.1) * 0.7,
    }));

    const draw = () => {
      elapsed += 16;
      const w = canvas.width;
      const h = canvas.height;
      const cx = w / 2;
      const cy = h / 2;
      const t = Math.min(elapsed / profile.duration, 1);
      const ease = 1 - Math.pow(1 - t, 3);
      const occlusion = Math.sin(Math.min(t, 0.86) / 0.86 * Math.PI);

      ctx.fillStyle = `rgba(2, 3, 6, ${0.64 + occlusion * 0.3})`;
      ctx.fillRect(0, 0, w, h);

      for (const p of dust) {
        const dx = p.x - cx;
        const dy = p.y - cy;
        const dist = Math.hypot(dx, dy) || 1;
        const nx = dx / dist;
        const ny = dy / dist;
        const bend = Math.sin(ease * Math.PI) * (22 + p.z * 28);
        const pull = 1 - ease * (0.42 + p.z * 0.2);
        const px = cx + dx * pull - ny * bend * p.drift;
        const py = cy + dy * pull + nx * bend * p.drift;
        const len = 5 + p.z * 13;

        const grad = ctx.createLinearGradient(px, py, px - nx * len, py - ny * len);
        grad.addColorStop(0, `rgba(220, 225, 232, ${0.28 + p.z * 0.16})`);
        grad.addColorStop(0.55, "rgba(178, 190, 204, .12)");
        grad.addColorStop(1, "rgba(178, 190, 204, 0)");
        ctx.strokeStyle = grad;
        ctx.lineWidth = Math.max(0.7, p.z * 1.15);
        ctx.beginPath();
        ctx.moveTo(px, py);
        ctx.lineTo(px - nx * len, py - ny * len);
        ctx.stroke();
      }

      const horizon = Math.max(w, h) * (0.08 + occlusion * 0.72);
      const ring = ctx.createRadialGradient(cx, cy, horizon * 0.18, cx, cy, horizon);
      ring.addColorStop(0, "rgba(0, 0, 0, .96)");
      ring.addColorStop(0.58, "rgba(3, 4, 7, .88)");
      ring.addColorStop(0.76, "rgba(116, 96, 64, .11)");
      ring.addColorStop(1, "rgba(0, 0, 0, 0)");
      ctx.fillStyle = ring;
      ctx.beginPath();
      ctx.arc(cx, cy, horizon, 0, Math.PI * 2);
      ctx.fill();

      if (!completed && elapsed > profile.completeAt) {
        completed = true;
        completeRef.current?.();
      }

      if (elapsed < profile.duration) frameRef.current = requestAnimationFrame(draw);
    };

    frameRef.current = requestAnimationFrame(draw);
    return () => {
      if (frameRef.current) cancelAnimationFrame(frameRef.current);
    };
  }, [trigger]);

  return <canvas ref={canvasRef} className={`warp-canvas ${trigger ? "is-active" : ""}`} aria-hidden />;
}
