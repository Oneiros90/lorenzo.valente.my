import type { Orb } from './orbs';

export const field = $state({
  orbs: [] as Orb[],
  enabled: false,
  tick: 0
});

const listeners = new Set<() => void>();

export function onOrbFrame(fn: () => void): () => void {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

export function notifyOrbFrame() {
  field.tick += 1;
  for (const fn of listeners) fn();
}
