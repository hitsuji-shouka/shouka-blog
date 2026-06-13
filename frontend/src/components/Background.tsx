import { useEffect, useState } from "react";

// 背景图列表：往 public/bg/ 丢图并登记于此，定时轮换；空则纯色底
const IMAGES = ["/bg/01.jpg"];
const ROTATE_MS = 30_000;

export function Background() {
  const [i, setI] = useState(() => Math.floor(Date.now() / ROTATE_MS) % IMAGES.length);
  useEffect(() => {
    if (IMAGES.length < 2) return;
    const t = setInterval(() => setI((n) => (n + 1) % IMAGES.length), ROTATE_MS);
    return () => clearInterval(t);
  }, []);
  if (IMAGES.length === 0) return null;
  return <div className="site-bg" style={{ backgroundImage: `url(${IMAGES[i]})` }} aria-hidden />;
}
