import type { Vec3 } from './types';
import { SOCIAL_PICK_BASE } from './picks';

/**
 * Right-wall social beacons — MUST sit in front of shelves toward room (-X).
 * Shelves hug the wall (~x 3.43–3.67); beacons at x≈3.18 so camera rays hit
 * the pick sphere (covers core + gyro rings) before any shelf slab.
 */
const SOCIAL_BASE: Vec3[] = [
  [3.18, 2.54, -1.5],
  [3.18, 2.54, -0.7],
  [3.18, 2.54, 0.1],
  [3.18, 1.79, -1.2],
  [3.18, 1.79, -0.2],
  [3.18, 1.04, -1.2],
  [3.18, 1.04, -0.2]
];

export { SOCIAL_PICK_BASE } from './picks';
export const SOCIAL_ORB_RADIUS = 0.09;

export function socialPosJS(i: number, time: number): Vec3 {
  const b = SOCIAL_BASE[i];
  const bob = 0.008 * Math.sin(time * 1.4 + i * 1.7);
  return [b[0], b[1] + bob, b[2]];
}

export function isSocialPick(id: number): boolean {
  return id >= SOCIAL_PICK_BASE && id < SOCIAL_PICK_BASE + SOCIAL_BASE.length;
}

export function socialIndexFromPick(id: number): number {
  return id - SOCIAL_PICK_BASE;
}
