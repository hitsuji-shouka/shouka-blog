import { describe, expect, it } from "vitest";
import { unified } from "unified";
import remarkParse from "remark-parse";
import remarkDirective from "remark-directive";
import remarkRehype from "remark-rehype";
import rehypeStringify from "rehype-stringify";
import { remarkEmbed } from "./embed";

const render = (md: string) =>
  unified()
    .use(remarkParse)
    .use(remarkDirective)
    .use(remarkEmbed)
    .use(remarkRehype)
    .use(rehypeStringify)
    .processSync(md)
    .toString();

describe("remarkEmbed", () => {
  it("bilibili 合法 → sandbox iframe", () => {
    const html = render("::bilibili{id=BV1xx}");
    expect(html).toContain('src="https://player.bilibili.com/player.html?bvid=BV1xx"');
    expect(html).toContain('sandbox="allow-scripts allow-same-origin allow-presentation"');
  });

  it.each(["youtube", "netease", "spotify", "xiaoyuzhou"])("%s 白名单渲染", (p) => {
    expect(render(`::${p}{id=abc}`)).toContain("<iframe");
  });

  it("非白名单平台 → 原样文本无 iframe", () => {
    const html = render("::vimeo{id=123}");
    expect(html).not.toContain("<iframe");
    expect(html).toContain("::vimeo{id=123}");
  });

  it("缺 id → 原样文本", () => {
    expect(render("::bilibili{}")).not.toContain("<iframe");
  });

  it("非法 id 含尖括号 → 不渲染，杜绝 XSS", () => {
    const html = render('::bilibili{id="><script>"}');
    expect(html).not.toContain("<iframe");
    expect(html).not.toContain("<script>");
  });
});
