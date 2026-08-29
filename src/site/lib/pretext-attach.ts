import type { Attachment } from 'svelte/attachments';
import {
	layoutNextLineRange,
	materializeLineRange,
	prepareWithSegments,
	type LayoutCursor,
	type PreparedTextWithSegments
} from '@chenglou/pretext';
import { availableStrips, nearOrbs, type Orb } from './orbs';
import { field, onOrbFrame } from './field.svelte';
import { prefersReducedMotion } from './capabilities';

export interface PretextLine {
	text: string;
	x: number;
	y: number;
}

function fontFromElement(el: HTMLElement) {
	const cs = getComputedStyle(el);
	const italic = cs.fontStyle === 'italic' ? 'italic ' : '';
	const letterSpacing = cs.letterSpacing === 'normal' ? 0 : parseFloat(cs.letterSpacing) || 0;
	let lineHeight = parseFloat(cs.lineHeight);
	if (Number.isNaN(lineHeight)) lineHeight = parseFloat(cs.fontSize) * 1.35;
	return {
		font: `${italic}${cs.fontWeight} ${cs.fontSize} ${cs.fontFamily}`,
		letterSpacing,
		lineHeight
	};
}

type PreparedMetrics = PreparedTextWithSegments & {
	widths: number[];
	kinds: string[];
};

function nextAtomWidth(prepared: PreparedTextWithSegments, cursor: LayoutCursor): number {
	if (cursor.graphemeIndex !== 0) return 0;
	const metrics = prepared as PreparedMetrics;
	let i = cursor.segmentIndex;
	while (i < metrics.kinds.length) {
		const kind = metrics.kinds[i];
		if (kind === 'space' || kind === 'glue' || kind === 'zero-width-break' || kind === 'tab') {
			i += 1;
			continue;
		}
		break;
	}
	if (i >= metrics.widths.length) return 0;
	if (metrics.kinds[i] === 'hard-break') return 0;
	return metrics.widths[i] ?? 0;
}

function layoutLines(
	prepared: PreparedTextWithSegments,
	el: HTMLElement,
	lineHeight: number,
	orbs: Orb[],
	enabled: boolean
): { lines: PretextLine[]; height: number } {
	const box = el.getBoundingClientRect();
	const useOrbs = enabled && orbs.length > 0 && nearOrbs(box, orbs);
	const next: PretextLine[] = [];
	let cursor: LayoutCursor = { segmentIndex: 0, graphemeIndex: 0 };
	let y = 0;
	let guard = 0;
	while (guard++ < 480) {
		const slots = useOrbs ? availableStrips(box, y, lineHeight, orbs) : [{ x: 0, width: box.width }];
		if (!slots.length) {
			y += lineHeight;
			continue;
		}

		let placed = false;
		for (let i = 0; i < slots.length; i++) {
			const slot = slots[i];
			const atom = nextAtomWidth(prepared, cursor);
			if (atom > slot.width + 0.5) {
				const laterFits = slots.slice(i + 1).some((s) => s.width + 0.5 >= atom);
				if (laterFits || slot.width < box.width - 1) continue;
			}

			const range = layoutNextLineRange(prepared, cursor, Math.max(24, slot.width));
			if (range === null) {
				return {
					lines: next,
					height: Math.max(placed ? y + lineHeight : y, lineHeight)
				};
			}
			const line = materializeLineRange(prepared, range);
			if (line.text) next.push({ text: line.text, x: slot.x, y });
			cursor = range.end;
			placed = true;
		}

		y += lineHeight;
		if (!placed && !useOrbs) break;
	}
	return { lines: next, height: Math.max(y, lineHeight) };
}

export function pretextAttach(
	getText: () => string,
	setLines: (lines: PretextLine[], height: number, hydrated: boolean) => void,
	useFieldOrbs = true
): Attachment {
	return (element) => {
		if (!(element instanceof HTMLElement)) return;
		if (prefersReducedMotion() || !useFieldOrbs) {
			setLines([], 0, false);
			return;
		}

		let cancelled = false;
		let prepared: PreparedTextWithSegments | null = null;
		let lineHeight = 24;
		let lastKey = '';
		let wasNear = false;

		const paint = () => {
			if (cancelled || !prepared) return;
			const box = element.getBoundingClientRect();
			if (box.width < 8) return;
			const near = useFieldOrbs && field.enabled && nearOrbs(box, field.orbs);
			const key = `${Math.round(box.width)}:${near ? field.tick : 0}:${getText()}`;
			if (key === lastKey && !wasNear && !near) return;
			if (!near && !wasNear && lastKey.startsWith(`${Math.round(box.width)}:`)) return;
			wasNear = near;
			lastKey = key;
			const result = layoutLines(
				prepared,
				element,
				lineHeight,
				field.orbs,
				useFieldOrbs && field.enabled
			);
			setLines(result.lines, result.height, true);
		};

		const boot = async () => {
			try {
				await document.fonts.ready;
			} catch {
				/* ignore */
			}
			if (cancelled) return;
			const metrics = fontFromElement(element);
			lineHeight = metrics.lineHeight;
			prepared = prepareWithSegments(getText(), metrics.font, { letterSpacing: metrics.letterSpacing });
			paint();
		};

		boot();
		const ro = new ResizeObserver(() => {
			lastKey = '';
			paint();
		});
		ro.observe(element);
		const stopOrbs = useFieldOrbs ? onOrbFrame(paint) : () => {};

		return () => {
			cancelled = true;
			ro.disconnect();
			stopOrbs();
		};
	};
}
