import { afterEach, describe, expect, it, vi } from "vitest";
import { createTextStreamer } from "./typewriter";

describe("createTextStreamer", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("reveals queued model chunks one character at a time", async () => {
    vi.useFakeTimers();
    let out = "";
    const streamer = createTextStreamer({ delayMs: 10, onText: (text) => { out += text; } });

    streamer.enqueue("我是");
    streamer.enqueue("TARS");

    expect(out).toBe("");
    await vi.advanceTimersByTimeAsync(10);
    expect(out).toBe("我");
    await vi.advanceTimersByTimeAsync(10);
    expect(out).toBe("我是");
    await vi.advanceTimersByTimeAsync(40);
    expect(out).toBe("我是TARS");
  });

  it("drain resolves after all queued characters are displayed", async () => {
    vi.useFakeTimers();
    let out = "";
    const streamer = createTextStreamer({ delayMs: 8, onText: (text) => { out += text; } });

    streamer.enqueue("深空");
    const drained = streamer.drain();
    await vi.advanceTimersByTimeAsync(16);
    await expect(drained).resolves.toBeUndefined();
    expect(out).toBe("深空");
  });

  it("clear drops pending text and resolves drain waiters", async () => {
    vi.useFakeTimers();
    let out = "";
    const streamer = createTextStreamer({ delayMs: 10, onText: (text) => { out += text; } });

    streamer.enqueue("abcdef");
    await vi.advanceTimersByTimeAsync(10);
    const drained = streamer.drain();
    streamer.clear();

    await expect(drained).resolves.toBeUndefined();
    await vi.advanceTimersByTimeAsync(100);
    expect(out).toBe("a");
  });
});
