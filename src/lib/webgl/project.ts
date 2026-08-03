import { lookBasis, type CameraPose } from './camera';
import type { Vec3 } from './types';

export interface ScreenPoint {
  x: number;
  y: number;
  depth: number;
  visible: boolean;
}

/** Project a world point to CSS viewport pixels (matches scene shader / picking). */
export function projectWorldToScreen(
  world: Vec3,
  pose: CameraPose,
  viewBias: number,
  canvasWidth: number,
  canvasHeight: number
): ScreenPoint {
  const { fw, rt, up } = lookBasis(pose.ro, pose.target);
  const d: Vec3 = [world[0] - pose.ro[0], world[1] - pose.ro[1], world[2] - pose.ro[2]];
  const depth = d[0] * fw[0] + d[1] * fw[1] + d[2] * fw[2];
  if (depth < 0.15) {
    return { x: 0, y: 0, depth, visible: false };
  }

  const uvx = (pose.focal * (d[0] * rt[0] + d[1] * rt[1] + d[2] * rt[2])) / depth;
  const uvy = (pose.focal * (d[0] * up[0] + d[1] * up[1] + d[2] * up[2])) / depth;
  const aspect = canvasWidth / Math.max(canvasHeight, 1);
  const biased = uvx + viewBias * 0.5 * aspect;

  const x = innerWidth * (0.5 + biased / (2 * aspect));
  const y = innerHeight * (0.5 - uvy / 2);

  const margin = 40;
  const visible =
    x > -margin && x < innerWidth + margin && y > -margin && y < innerHeight + margin;

  return { x, y, depth, visible };
}
