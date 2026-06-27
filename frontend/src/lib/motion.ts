export interface SceneQuality {
  particles: number;
  pixelRatio: number;
  fullEffects: boolean;
}

export function isCompactViewport(width: number): boolean {
  return width < 760;
}

export function sceneQuality(width: number, dpr: number): SceneQuality {
  if (isCompactViewport(width)) {
    return { particles: 1400, pixelRatio: Math.min(dpr, 1.25), fullEffects: false };
  }
  return { particles: 5200, pixelRatio: Math.min(dpr, 1.75), fullEffects: true };
}

export function shouldReduceMotion(win: Window = window): boolean {
  return win.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false;
}
