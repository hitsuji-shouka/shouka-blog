import { describe, expect, it } from "vitest";
import { shouldPlayWarp } from "./WarpCanvas";

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
