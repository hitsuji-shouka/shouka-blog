import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { PostAudio } from "./PostAudio";

describe("PostAudio", () => {
  it("renders an audio player for a source", () => {
    const out = renderToStaticMarkup(<PostAudio src="/audio/finance-20260627.mp3" />);

    expect(out).toContain("<audio");
    expect(out).toContain("controls");
    expect(out).toContain("/audio/finance-20260627.mp3");
    expect(out).toContain("AUDIO BRIEFING");
  });

  it("renders nothing without a source", () => {
    const out = renderToStaticMarkup(<PostAudio src={null} />);

    expect(out).toBe("");
  });
});
