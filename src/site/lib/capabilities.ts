export function supportsHtmlInCanvas(): boolean {
  return typeof HTMLCanvasElement !== 'undefined' && 'requestPaint' in HTMLCanvasElement.prototype;
}

export function prefersReducedMotion(): boolean {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

export function isCoarsePointer(): boolean {
  return window.matchMedia('(pointer: coarse)').matches;
}

export function saveDataEnabled(): boolean {
  const conn = (navigator as Navigator & { connection?: { saveData?: boolean } }).connection;
  return Boolean(conn?.saveData);
}

export function shouldUseEffects(): boolean {
  if (prefersReducedMotion()) return false;
  if (isCoarsePointer()) return false;
  if (saveDataEnabled()) return false;
  if (window.matchMedia('(max-width: 767px)').matches) return false;
  return true;
}

export function shouldUseOrbs(): boolean {
  return shouldUseEffects();
}

export function idle(fn: () => void) {
  const ric = window.requestIdleCallback?.bind(window);
  if (ric) {
    const id = ric(() => fn(), { timeout: 1800 });
    return () => window.cancelIdleCallback?.(id);
  }
  const t = window.setTimeout(fn, 1);
  return () => clearTimeout(t);
}
