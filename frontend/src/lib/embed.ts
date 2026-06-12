import type { Plugin } from "unified";
import { visit } from "unist-util-visit";

// 白名单：platform -> 内嵌播放器 URL 构造
const PLAYERS: Record<string, (id: string) => string> = {
  bilibili: (id) => `https://player.bilibili.com/player.html?bvid=${id}`,
  youtube: (id) => `https://www.youtube.com/embed/${id}`,
  netease: (id) => `https://music.163.com/outchain/player?id=${id}`,
  spotify: (id) => `https://open.spotify.com/embed/${id}`,
  xiaoyuzhou: (id) => `https://www.xiaoyuzhoufm.com/episode/${id}`,
};

const ID_RE = /^[A-Za-z0-9/_-]+$/;

/**
 * 解析 ::platform{id=xxx} leafDirective：白名单 + 合法 id 渲染 sandbox iframe，
 * 否则原样输出文本，杜绝任意 HTML / XSS。
 */
export const remarkEmbed: Plugin = () => (tree) => {
  visit(tree, "leafDirective", (node: any) => {
    const id = node.attributes?.id;
    const url = PLAYERS[node.name]?.(id);
    if (!url || !id || !ID_RE.test(id)) {
      // 非白名单或非法：还原为原始文本，不渲染播放器
      node.type = "text";
      node.value = `::${node.name}{id=${id ?? ""}}`;
      return;
    }
    node.data = {
      hName: "iframe",
      hProperties: {
        src: url,
        sandbox: "allow-scripts allow-same-origin allow-presentation",
        allowFullScreen: true,
        loading: "lazy",
        className: "embed-player",
      },
    };
  });
};
