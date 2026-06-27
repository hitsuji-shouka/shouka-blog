import { describe, expect, it } from "vitest";
import { gravityTransitionProfile, shouldPlayWarp } from "./WarpCanvas";

describe("shouldPlayWarp", () => {
  it("skips when reduced motion is enabled", () => {
    expect(shouldPlayWarp(true, "/", "/category/科技")).toBe(false);
  });

  it("skips when route does not change", () => {
    expect(shouldPlayWarp(false, "/", "/")).toBe(false);
  });

  it("plays for route changes", () => {
    expect(shouldPlayWarp(false, "/", "/category/理财")).toBe(true);
  });
});

describe("gravityTransitionProfile", () => {
  it("uses a quiet low-particle transition on mobile", () => {
    expect(gravityTransitionProfile(390)).toEqual({ dust: 90, completeAt: 740, duration: 1320 });
  });

  it("keeps the desktop transition calm instead of flashy", () => {
    expect(gravityTransitionProfile(1440)).toEqual({ dust: 180, completeAt: 760, duration: 1380 });
  });
});
