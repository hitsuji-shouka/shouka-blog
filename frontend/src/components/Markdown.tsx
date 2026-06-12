import ReactMarkdown from "react-markdown";
import remarkDirective from "remark-directive";
import { remarkEmbed } from "../lib/embed";

// 仅放行受信任 remark 插件，不启用 rehype-raw，原文 HTML 不渲染
export function Markdown({ content }: { content: string }) {
  return (
    <div className="markdown">
      <ReactMarkdown remarkPlugins={[remarkDirective, remarkEmbed]}>{content}</ReactMarkdown>
    </div>
  );
}
