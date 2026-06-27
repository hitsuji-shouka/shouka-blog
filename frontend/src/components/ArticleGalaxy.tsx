import { Canvas, useFrame } from "@react-three/fiber";
import { Html, OrbitControls, Stars } from "@react-three/drei";
import { useMemo, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import * as THREE from "three";
import { buildArticleGalaxy, categoryPath, type ArticleGalaxy as ArticleGalaxyData, type ArticlePlanet } from "../lib/articleGalaxy";
import type { PostMeta } from "../lib/types";

function planetTexture(seed: number, color: string) {
  const canvas = document.createElement("canvas");
  canvas.width = 96;
  canvas.height = 96;
  const ctx = canvas.getContext("2d")!;
  ctx.fillStyle = "#090b10";
  ctx.fillRect(0, 0, 96, 96);
  for (let y = 0; y < 96; y += 1) {
    const wave = Math.sin((y + seed % 41) * 0.11) * 10;
    ctx.fillStyle = y % 7 < 3 ? `${color}88` : "rgba(230,235,242,.10)";
    ctx.fillRect(0, y, 96, 1);
    ctx.fillStyle = "rgba(0,0,0,.18)";
    ctx.fillRect(0, y + 1, 96, Math.max(1, Math.abs(wave) * 0.05));
  }
  for (let i = 0; i < 420; i += 1) {
    const x = (Math.sin(seed + i * 31.7) + 1) * 48;
    const y = (Math.sin(seed + i * 17.3) + 1) * 48;
    ctx.fillStyle = i % 5 === 0 ? "rgba(255,255,255,.18)" : "rgba(0,0,0,.18)";
    ctx.fillRect(x, y, 1, 1);
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

function StellarCore({ galaxy, onSelect }: { galaxy: ArticleGalaxyData; onSelect: (galaxy: ArticleGalaxyData) => void }) {
  const star = useRef<THREE.Mesh>(null);
  useFrame(({ clock }) => {
    const pulse = 1 + Math.sin(clock.elapsedTime * 1.15 + galaxy.config.center[0]) * 0.045;
    star.current?.scale.setScalar(pulse);
  });

  return (
    <group
      position={galaxy.config.center}
      onPointerOver={() => { document.body.style.cursor = "pointer"; }}
      onPointerOut={() => { document.body.style.cursor = ""; }}
      onClick={(event) => {
        event.stopPropagation();
        onSelect(galaxy);
      }}
    >
      <mesh ref={star}>
        <sphereGeometry args={[0.34, 48, 48]} />
        <meshBasicMaterial color={galaxy.config.color} transparent opacity={0.82} />
      </mesh>
      <mesh>
        <sphereGeometry args={[0.58, 48, 48]} />
        <meshBasicMaterial color={galaxy.config.mutedColor} transparent opacity={0.09} />
      </mesh>
      <Html position={[0, -0.78, 0]} center distanceFactor={9}>
        <button
          className="stellar-label"
          onClick={(event) => {
            event.stopPropagation();
            onSelect(galaxy);
          }}
        >
          <strong>{galaxy.config.name}</strong>
          <span>{galaxy.category}</span>
        </button>
      </Html>
    </group>
  );
}

function ConstellationLines({ planets, color }: { planets: ArticlePlanet[]; color: string }) {
  const positions = useMemo(() => {
    const arr = new Float32Array(Math.max(0, planets.length - 1) * 6);
    planets.slice(0, -1).forEach((planet, index) => {
      const next = planets[index + 1];
      arr.set(planet.position, index * 6);
      arr.set(next.position, index * 6 + 3);
    });
    return arr;
  }, [planets]);
  if (planets.length < 2) return null;
  return (
    <lineSegments>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" count={positions.length / 3} array={positions} itemSize={3} />
      </bufferGeometry>
      <lineBasicMaterial color={color} transparent opacity={0.16} />
    </lineSegments>
  );
}

function Planet({
  planet,
  color,
  active,
  onHover,
  onSelect,
}: {
  planet: ArticlePlanet;
  color: string;
  active: boolean;
  onHover: (planet: ArticlePlanet | null) => void;
  onSelect: (planet: ArticlePlanet) => void;
}) {
  const group = useRef<THREE.Group>(null);
  const texture = useMemo(() => planetTexture(planet.textureSeed, color), [planet.textureSeed, color]);
  useFrame(({ clock }) => {
    if (!group.current) return;
    group.current.rotation.y = clock.elapsedTime * 0.08 + planet.textureSeed * 0.0001;
    const scale = active ? 1.14 : 1;
    group.current.scale.lerp(new THREE.Vector3(scale, scale, scale), 0.08);
  });

  return (
    <group
      ref={group}
      position={planet.position}
      onPointerOver={(event) => {
        event.stopPropagation();
        onHover(planet);
        document.body.style.cursor = "pointer";
      }}
      onPointerOut={() => {
        onHover(null);
        document.body.style.cursor = "";
      }}
      onClick={(event) => {
        event.stopPropagation();
        onSelect(planet);
      }}
    >
      <mesh>
        <sphereGeometry args={[planet.radius, 48, 48]} />
        <meshStandardMaterial map={texture} emissive={color} emissiveIntensity={active ? planet.glow : planet.glow * 0.36} roughness={0.78} metalness={0.08} />
      </mesh>
      <mesh rotation={[Math.PI / 2.7, 0.2, 0]}>
        <ringGeometry args={[planet.radius * 1.42, planet.radius * 1.48, 96]} />
        <meshBasicMaterial color={color} transparent opacity={active ? 0.42 : 0.2} side={THREE.DoubleSide} />
      </mesh>
      {active && (
        <Html position={[planet.radius * 1.8, planet.radius * 1.45, 0]} distanceFactor={7.5}>
          <div className="planet-hud">
            <strong>{planet.post.title}</strong>
            <span>{planet.post.date} · {planet.readMinutes} min</span>
            <p>{planet.post.summary || "暂无摘要，等待下一次信号同步。"}</p>
          </div>
        </Html>
      )}
    </group>
  );
}

function GalaxyScene({ posts, focusCategory }: { posts: PostMeta[]; focusCategory?: string }) {
  const navigate = useNavigate();
  const galaxies = useMemo(() => buildArticleGalaxy(posts), [posts]);
  const visible = focusCategory ? galaxies.filter((g) => g.category === focusCategory) : galaxies;
  const [hovered, setHovered] = useState<string | null>(null);

  return (
    <Canvas camera={{ position: [0, 0.8, focusCategory ? 6.8 : 8.8], fov: 48 }} gl={{ antialias: true, alpha: true }}>
      <ambientLight intensity={0.45} />
      <pointLight position={[0, 2, 4]} intensity={0.8} color="#d9dee7" />
      <Stars radius={46} depth={24} count={700} factor={2.1} fade speed={0.05} />
      {visible.map((galaxy) => (
        <group key={galaxy.category}>
          <StellarCore galaxy={galaxy} onSelect={(next) => navigate(categoryPath(next.category))} />
          <ConstellationLines planets={galaxy.planets} color={galaxy.config.mutedColor} />
          {galaxy.planets.map((planet) => (
            <Planet
              key={planet.post.slug}
              planet={planet}
              color={galaxy.config.color}
              active={hovered === planet.post.slug}
              onHover={(next) => setHovered(next?.post.slug ?? null)}
              onSelect={(next) => navigate(`/post/${next.post.slug}`)}
            />
          ))}
        </group>
      ))}
      <OrbitControls enablePan={false} enableDamping dampingFactor={0.06} rotateSpeed={0.42} zoomSpeed={0.45} minDistance={3.8} maxDistance={12} />
    </Canvas>
  );
}

export function ArticleGalaxy({ posts, focusCategory, variant = "home" }: { posts: PostMeta[]; focusCategory?: string; variant?: "home" | "archive" }) {
  return (
    <section className={`article-galaxy article-galaxy--${variant}`} aria-label="文章星系">
      <div className="article-galaxy__scene">
        <GalaxyScene posts={posts} focusCategory={focusCategory} />
      </div>
      <div className="article-galaxy__hint">拖拽旋转视角 · 点击恒星进入星系 · 点击行星阅读</div>
    </section>
  );
}
