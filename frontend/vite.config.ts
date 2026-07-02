import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

const markdownPackages = [
  "bail",
  "ccount",
  "character-entities",
  "comma-separated-tokens",
  "decode-named-character-reference",
  "devlop",
  "hast-",
  "html-url-attributes",
  "is-plain-obj",
  "markdown-table",
  "mdast-",
  "micromark",
  "property-information",
  "react-markdown",
  "rehype",
  "remark",
  "space-separated-tokens",
  "trim-lines",
  "trough",
  "unified",
  "unist-",
  "vfile",
  "zwitch",
];

export default defineConfig({
  plugins: [react()],
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (!id.includes("node_modules")) return;
          if (id.includes("framer-motion") || id.includes("motion-dom") || id.includes("motion-utils")) return "motion";
          if (markdownPackages.some((pkg) => id.includes(pkg))) return "markdown";
          return;
        },
      },
    },
  },
  server: {
    proxy: { "/api": "http://localhost:8000" },
  },
});
