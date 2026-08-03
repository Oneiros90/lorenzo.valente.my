import type { SceneConfig, Vec3 } from './types';

export function orbRadius(years: number, scene: SceneConfig): number {
  return scene.orbRadiusBase + years * scene.orbRadiusPerYear;
}

export function orbPosJS(i: number, time: number, radius: number): Vec3 {
  const z = 1.18 - i * 0.16;
  const xOff = i % 2 < 1 ? -0.05 : 0.25;
  return [-0.22 + xOff, 0.795 + radius + 0.015 * Math.sin(time * 1.3 + i * 1.9), z];
}
