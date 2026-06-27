import { useEffect, useRef } from "react";

export function shouldPlayWarp(reduceMotion: boolean, from: string, to: string): boolean {
  return !reduceMotion && from !== to;
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

    let elapsed = 0;
    let completed = false;
    const particles = Array.from({ length: window.innerWidth < 760 ? 170 : 460 }, (_, i) => ({
      x: ((Math.sin(i * 91.7) + 1) / 2) * canvas.width,
      y: ((Math.sin(i * 41.3) + 1) / 2) * canvas.height,
      z: 0.2 + ((Math.sin(i * 17.1) + 1) / 2),
    }));

    const draw = () => {
      elapsed += 16;
      const w = canvas.width;
      const h = canvas.height;
      const cx = w / 2;
      const cy = h / 2;
      const t = Math.min(elapsed / 1150, 1);
      const speed = 4 + Math.sin(t * Math.PI) * 86;

      ctx.fillStyle = `rgba(3, 5, 8, ${t > 0.82 ? 1 - (t - 0.82) / 0.18 : 0.96})`;
      ctx.fillRect(0, 0, w, h);

      for (const p of particles) {
        const dx = p.x - cx;
        const dy = p.y - cy;
        const dist = Math.hypot(dx, dy) || 1;
        const nx = dx / dist;
        const ny = dy / dist;
        const len = speed * p.z * 2.4;
        const px = cx + nx * ((dist + speed * p.z * 7) % Math.max(w, h));
        const py = cy + ny * ((dist + speed * p.z * 7) % Math.max(w, h));

        const grad = ctx.createLinearGradient(px, py, px - nx * len, py - ny * len);
        grad.addColorStop(0, "rgba(232, 236, 244, .95)");
        grad.addColorStop(0.45, "rgba(0, 212, 255, .58)");
        grad.addColorStop(1, "rgba(168, 85, 247, 0)");
        ctx.strokeStyle = grad;
        ctx.lineWidth = Math.max(1, p.z * 1.6);
        ctx.beginPath();
        ctx.moveTo(px, py);
        ctx.lineTo(px - nx * len, py - ny * len);
        ctx.stroke();
      }

      if (!completed && elapsed > 520) {
        completed = true;
        completeRef.current?.();
      }

      if (elapsed < 1150) frameRef.current = requestAnimationFrame(draw);
    };

    frameRef.current = requestAnimationFrame(draw);
    return () => {
      if (frameRef.current) cancelAnimationFrame(frameRef.current);
    };
  }, [trigger]);

  return <canvas ref={canvasRef} className={`warp-canvas ${trigger ? "is-active" : ""}`} aria-hidden />;
}
