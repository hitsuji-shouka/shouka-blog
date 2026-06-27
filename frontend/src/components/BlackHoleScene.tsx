import { Canvas, useFrame, useThree } from "@react-three/fiber";
import { Stars } from "@react-three/drei";
import { useMemo, useRef } from "react";
import * as THREE from "three";
import { sceneQuality } from "../lib/motion";

function AccretionDisk() {
  const disk = useRef<THREE.Mesh>(null);
  const glow = useRef<THREE.Mesh>(null);

  useFrame((_state, delta) => {
    if (disk.current) disk.current.rotation.z += delta * 0.055;
    if (glow.current) glow.current.rotation.z -= delta * 0.025;
  });

  return (
    <group rotation={[1.18, 0.18, -0.38]}>
      <mesh ref={disk}>
        <torusGeometry args={[1.25, 0.09, 48, 220]} />
        <meshBasicMaterial color="#c49a62" transparent opacity={0.46} />
      </mesh>
      <mesh ref={glow} scale={[1.18, 1.18, 1.18]}>
        <torusGeometry args={[1.25, 0.15, 48, 220]} />
        <meshBasicMaterial color="#d9dee7" transparent opacity={0.07} />
      </mesh>
      <mesh scale={[0.72, 0.72, 0.72]}>
        <sphereGeometry args={[1, 64, 64]} />
        <meshBasicMaterial color="#020308" />
      </mesh>
      <mesh scale={[0.86, 0.86, 0.86]}>
        <sphereGeometry args={[1, 64, 64]} />
        <meshBasicMaterial color="#050810" transparent opacity={0.44} />
      </mesh>
    </group>
  );
}

function NebulaPoints({ count }: { count: number }) {
  const points = useRef<THREE.Points>(null);
  const positions = useMemo(() => {
    const arr = new Float32Array(count * 3);
    for (let i = 0; i < count; i += 1) {
      const radius = 2 + Math.random() * 7;
      const theta = Math.random() * Math.PI * 2;
      const phi = Math.acos(2 * Math.random() - 1);
      arr[i * 3] = radius * Math.sin(phi) * Math.cos(theta);
      arr[i * 3 + 1] = radius * Math.sin(phi) * Math.sin(theta) * 0.5;
      arr[i * 3 + 2] = radius * Math.cos(phi) - 3;
    }
    return arr;
  }, [count]);

  useFrame((_state, delta) => {
    if (points.current) points.current.rotation.y += delta * 0.006;
  });

  return (
    <points ref={points}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" count={count} array={positions} itemSize={3} />
      </bufferGeometry>
      <pointsMaterial size={0.012} color="#cfd6e0" transparent opacity={0.34} sizeAttenuation />
    </points>
  );
}

function QualityBridge({ width }: { width: number }) {
  const { gl } = useThree();
  const quality = sceneQuality(width, window.devicePixelRatio || 1);
  gl.setPixelRatio(quality.pixelRatio);
  return (
    <>
      <Stars radius={38} depth={22} count={quality.fullEffects ? 1100 : 460} factor={2.2} fade speed={0.08} />
      <NebulaPoints count={quality.particles} />
      <AccretionDisk />
    </>
  );
}

export function BlackHoleScene() {
  const width = typeof window === "undefined" ? 1440 : window.innerWidth;
  return (
    <div className="black-hole-scene" aria-hidden>
      <Canvas camera={{ position: [0, 0, 4.3], fov: 48 }} gl={{ antialias: true, alpha: true }}>
        <color attach="background" args={["#030508"]} />
        <fog attach="fog" args={["#030508", 4, 14]} />
        <QualityBridge width={width} />
      </Canvas>
    </div>
  );
}
