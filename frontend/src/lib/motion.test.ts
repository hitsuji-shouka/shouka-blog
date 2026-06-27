import { describe, expect, it } from "vitest";
import { isCompactViewport, sceneQuality, shouldReduceMotion } from "./motion";

describe("motion helpers", () => {
  it("detects compact viewports", () => {
    expect(isCompactViewport(390)).toBe(true);
    expect(isCompactViewport(900)).toBe(false);
  });

  it("reduces scene quality on small screens", () => {
    expect(sceneQuality(390, 3)).toEqual({ particles: 1400, pixelRatio: 1.25, fullEffects: false });
    expect(sceneQuality(1440, 2)).toEqual({ particles: 5200, pixelRatio: 1.75, fullEffects: true });
  });

  it("reads reduced motion preference", () => {
    const win = {
      matchMedia: (query: string) => ({ matches: query === "(prefers-reduced-motion: reduce)" }),
    } as Window;

    expect(shouldReduceMotion(win)).toBe(true);
  });
});
