import { afterEach, describe, expect, it, vi } from "vitest";
import { parseSSE, sendChat, type Source } from "./chat";

function collect() {
  const out = { sources: [] as Source[], text: "", err: "" };
  const h = {
    onSources: (s: Source[]) => (out.sources = s),
    onDelta: (t: string) => (out.text += t),
    onError: (m: string) => (out.err = m),
  };
  return { out, h };
}

describe("parseSSE", () => {
  it("分发 sources/delta，残余回传", () => {
    const { out, h } = collect();
    const rest = parseSSE(
      'event: sources\ndata: {"sources":[{"slug":"a","title":"A"}]}\n\nevent: delta\ndata: {"text":"你"}\n\nevent: del',
      h,
    );
    expect(out.sources[0].slug).toBe("a");
    expect(out.text).toBe("你");
    expect(rest).toContain("event: del");
  });
  it("error 事件触发 onError", () => {
    const { out, h } = collect();
    parseSSE('event: error\ndata: {"message":"助理暂时不可用"}\n\n', h);
    expect(out.err).toBe("助理暂时不可用");
  });
});

describe("sendChat", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("sends TARS personality controls with the chat request", async () => {
    const body = new ReadableStream({
      start(controller) {
        controller.close();
      },
    });
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      body,
    });
    vi.stubGlobal("fetch", fetchMock);
    const { h } = collect();

    await sendChat([{ role: "user", content: "hi" }], h, { humor: 72, honesty: 94 });

    expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toEqual({
      messages: [{ role: "user", content: "hi" }],
      personality: { humor: 72, honesty: 94 },
    });
  });
});
