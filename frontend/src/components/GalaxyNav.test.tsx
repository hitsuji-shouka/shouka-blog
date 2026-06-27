import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { MemoryRouter } from "react-router-dom";
import { GalaxyNav } from "./GalaxyNav";

describe("GalaxyNav", () => {
  it("renders category orbit links", () => {
    const out = renderToStaticMarkup(<MemoryRouter><GalaxyNav /></MemoryRouter>);

    expect(out).toContain("/category/科技");
    expect(out).toContain("/category/理财");
    expect(out).toContain("/category/随笔");
  });
});
