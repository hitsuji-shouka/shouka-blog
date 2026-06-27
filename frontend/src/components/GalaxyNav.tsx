import { Link } from "react-router-dom";
import { Cpu, Landmark, PenLine } from "lucide-react";

const nodes = [
  { category: "科技", code: "TECH", icon: Cpu, desc: "systems / agents / code" },
  { category: "理财", code: "FIN", icon: Landmark, desc: "markets / briefing / audio" },
  { category: "随笔", code: "LOG", icon: PenLine, desc: "notes / essays / traces" },
];

export function GalaxyNav() {
  return (
    <nav className="galaxy-nav" aria-label="分类星系导航">
      {nodes.map((node, index) => {
        const Icon = node.icon;
        return (
          <Link
            key={node.category}
            to={`/category/${node.category}`}
            className={`galaxy-node galaxy-node--${index + 1}`}
          >
            <span className="galaxy-node__orbit" aria-hidden />
            <span className="galaxy-node__core"><Icon size={18} /></span>
            <span className="galaxy-node__label">{node.category}</span>
            <span className="galaxy-node__code">{node.code}</span>
            <span className="galaxy-node__desc">{node.desc}</span>
          </Link>
        );
      })}
    </nav>
  );
}
