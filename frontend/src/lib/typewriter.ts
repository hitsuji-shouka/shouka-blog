export interface TextStreamer {
  enqueue: (text: string) => void;
  clear: () => void;
  drain: () => Promise<void>;
  dispose: () => void;
}

export function createTextStreamer({
  delayMs = 16,
  onText,
}: {
  delayMs?: number;
  onText: (text: string) => void;
}): TextStreamer {
  const queue: string[] = [];
  let timer: ReturnType<typeof setTimeout> | null = null;
  let disposed = false;
  let waiters: Array<() => void> = [];

  const notifyDrain = () => {
    if (queue.length > 0 || timer) return;
    const pending = waiters;
    waiters = [];
    pending.forEach((resolve) => resolve());
  };

  const schedule = () => {
    if (disposed || timer) return;
    if (queue.length === 0) {
      notifyDrain();
      return;
    }
    timer = setTimeout(() => {
      timer = null;
      const next = queue.shift();
      if (next) onText(next);
      schedule();
    }, delayMs);
  };

  return {
    enqueue(text) {
      if (disposed || !text) return;
      queue.push(...Array.from(text));
      schedule();
    },
    clear() {
      queue.length = 0;
      if (timer) {
        clearTimeout(timer);
        timer = null;
      }
      notifyDrain();
    },
    drain() {
      if (queue.length === 0 && !timer) return Promise.resolve();
      return new Promise<void>((resolve) => waiters.push(resolve));
    },
    dispose() {
      disposed = true;
      queue.length = 0;
      if (timer) clearTimeout(timer);
      timer = null;
      notifyDrain();
    },
  };
}
