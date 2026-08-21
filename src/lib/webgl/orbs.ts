import type { SceneConfig, Vec3 } from './types';

export function orbRadius(years: number, scene: SceneConfig): number {
  return scene.orbRadiusBase + years * scene.orbRadiusPerYear;
}

/** Keep the original 4-orb z-span (1.18 → 0.70) and compress as count grows. */
const Z_FRONT = 1.18;
const Z_SPAN = 0.48;

export function orbPosJS(i: number, time: number, radius: number, count = 4): Vec3 {
  const n = Math.max(count, 1);
  const z = Z_FRONT - (n <= 1 ? 0 : (i / (n - 1)) * Z_SPAN);
  const xOff = i % 2 < 1 ? -0.05 : 0.25;
  return [-0.22 + xOff, 0.795 + radius + 0.015 * Math.sin(time * 1.3 + i * 1.9), z];
}
