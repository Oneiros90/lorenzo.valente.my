export interface Orb {
	x: number;
	y: number;
	r: number;
	heading: number;
	speed: number;
	turn: number;
	phase: number;
	baseR: number;
	rot: number;
	spin: number;
}

const SEEDS = [
	{ nx: 0.22, ny: 0.28, zone: 'view', heading: 0.4, speed: 22, turn: 0.32, phase: 0.2, baseR: 30, spin: 0.22 },
	{ nx: 0.82, ny: 0.2, zone: 'view', heading: 2.1, speed: 18, turn: 0.28, phase: 1.1, baseR: 32, spin: 0.18 },
	{ nx: 0.12, ny: 0.7, zone: 'view', heading: 5.4, speed: 26, turn: 0.41, phase: 2.0, baseR: 24, spin: 0.26 },
	{ nx: 0.52, ny: 0.16, zone: 'view', heading: 4.1, speed: 19, turn: 0.3, phase: 0.7, baseR: 28, spin: 0.2 },
	{ nx: 0.36, ny: 0.58, zone: 'view', heading: 1.7, speed: 23, turn: 0.38, phase: 1.6, baseR: 26, spin: 0.24 },
	{ nx: 0.74, ny: 0.82, zone: 'view', heading: 3.2, speed: 21, turn: 0.27, phase: 2.4, baseR: 30, spin: 0.19 },
	{ nx: 0.16, ny: 0.22, zone: 'page', heading: 5.9, speed: 20, turn: 0.33, phase: 2.9, baseR: 28, spin: 0.21 },
	{ nx: 0.84, ny: 0.3, zone: 'page', heading: 3.6, speed: 18, turn: 0.24, phase: 3.4, baseR: 30, spin: 0.18 },
	{ nx: 0.1, ny: 0.44, zone: 'page', heading: 1.2, speed: 24, turn: 0.36, phase: 3.9, baseR: 26, spin: 0.24 },
	{ nx: 0.9, ny: 0.52, zone: 'page', heading: 4.8, speed: 17, turn: 0.3, phase: 4.4, baseR: 28, spin: 0.17 },
	{ nx: 0.2, ny: 0.64, zone: 'page', heading: 0.6, speed: 22, turn: 0.29, phase: 4.9, baseR: 27, spin: 0.22 },
	{ nx: 0.78, ny: 0.72, zone: 'page', heading: 2.8, speed: 19, turn: 0.34, phase: 5.3, baseR: 31, spin: 0.2 },
	{ nx: 0.14, ny: 0.84, zone: 'page', heading: 5.1, speed: 21, turn: 0.26, phase: 5.8, baseR: 25, spin: 0.23 },
	{ nx: 0.86, ny: 0.92, zone: 'page', heading: 3.9, speed: 16, turn: 0.31, phase: 6.2, baseR: 29, spin: 0.18 }
] as const;

function clamp(value: number, min: number, max: number) {
	return Math.min(Math.max(value, min), max);
}

export function createOrbs(width: number, height: number, viewH = height): Orb[] {
	return SEEDS.map((s) => {
		const r = s.baseR;
		const m = r + 12;
		const span = s.zone === 'view' ? Math.min(viewH, height) : height;
		return {
			r,
			heading: s.heading,
			speed: s.speed,
			turn: s.turn,
			phase: s.phase,
			baseR: s.baseR,
			spin: s.spin,
			rot: s.phase,
			x: clamp(width * s.nx, m, Math.max(m, width - m)),
			y: clamp(span * s.ny, m, Math.max(m, height - m))
		};
	});
}

export function clampOrbs(orbs: Orb[], width: number, height: number): Orb[] {
	return orbs.map((orb) => {
		const m = orb.r + 12;
		return {
			...orb,
			x: clamp(orb.x, m, Math.max(m, width - m)),
			y: clamp(orb.y, m, Math.max(m, height - m))
		};
	});
}

export function stepOrbs(
	orbs: Orb[],
	dt: number,
	t: number,
	width: number,
	height: number
): Orb[] {
	const step = Math.min(Math.max(dt, 0), 0.05);
	return orbs.map((orb) => {
		const wander =
			Math.sin(t * orb.turn + orb.phase) * 0.75 +
			Math.sin(t * orb.turn * 1.37 + orb.phase * 2.1) * 0.5 +
			Math.sin(t * orb.turn * 0.53 + 1.7) * 0.28;
		let heading = orb.heading + wander * step;
		let x = orb.x + Math.cos(heading) * orb.speed * step;
		let y = orb.y + Math.sin(heading) * orb.speed * step;
		const m = orb.r + 12;
		const maxX = Math.max(m, width - m);
		const maxY = Math.max(m, height - m);
		if (x < m) {
			x = m;
			heading = Math.PI - heading;
		} else if (x > maxX) {
			x = maxX;
			heading = Math.PI - heading;
		}
		if (y < m) {
			y = m;
			heading = -heading;
		} else if (y > maxY) {
			y = maxY;
			heading = -heading;
		}
		return {
			...orb,
			x,
			y,
			heading,
			r: orb.baseR + Math.sin(t * 0.35 + orb.phase) * 1.6,
			rot: orb.rot + orb.spin * step
		};
	});
}

export function quantizedOrbsKey(orbs: Orb[]): string {
	return orbs.map((o) => `${(o.x / 4) | 0}:${(o.y / 4) | 0}:${(o.r / 2) | 0}`).join('|');
}

function project(
	lat: number,
	lon: number,
	rotY: number,
	rotX: number
): { x: number; y: number; z: number } {
	const cl = Math.cos(lat);
	let x = cl * Math.sin(lon);
	let y = Math.sin(lat);
	let z = cl * Math.cos(lon);
	const cy = Math.cos(rotY);
	const sy = Math.sin(rotY);
	const x1 = x * cy + z * sy;
	const z1 = -x * sy + z * cy;
	const cx = Math.cos(rotX);
	const sx = Math.sin(rotX);
	return { x: x1, y: y * cx - z1 * sx, z: y * sx + z1 * cx };
}

export function drawWireGlobe(
	ctx: CanvasRenderingContext2D,
	cx: number,
	cy: number,
	r: number,
	rot: number,
	stroke: string
) {
	const tilt = 0.42;
	ctx.save();
	ctx.translate(cx, cy);
	ctx.strokeStyle = stroke;
	ctx.lineWidth = 1.35;
	ctx.lineJoin = 'round';
	ctx.lineCap = 'round';

	ctx.globalAlpha = 0.9;
	ctx.beginPath();
	ctx.arc(0, 0, r, 0, Math.PI * 2);
	ctx.stroke();

	const meridians = 6;
	for (let m = 0; m < meridians; m++) {
		const lon0 = (m / meridians) * Math.PI + rot;
		ctx.globalAlpha = 0.72;
		ctx.beginPath();
		let drawing = false;
		for (let i = 0; i <= 36; i++) {
			const lat = -Math.PI / 2 + (i / 36) * Math.PI;
			const p = project(lat, lon0, rot, tilt);
			const x = p.x * r;
			const y = p.y * r;
			if (p.z < -0.08) {
				drawing = false;
				continue;
			}
			if (!drawing) {
				ctx.moveTo(x, y);
				drawing = true;
			} else {
				ctx.lineTo(x, y);
			}
		}
		ctx.stroke();
	}

	const parallels = 4;
	for (let p = 1; p < parallels; p++) {
		const lat = -Math.PI / 2 + (p / parallels) * Math.PI;
		ctx.globalAlpha = p === 2 ? 0.85 : 0.55;
		ctx.beginPath();
		let drawing = false;
		for (let i = 0; i <= 48; i++) {
			const lon = (i / 48) * Math.PI * 2 + rot;
			const pt = project(lat, lon, rot, tilt);
			const x = pt.x * r;
			const y = pt.y * r;
			if (pt.z < -0.08) {
				drawing = false;
				continue;
			}
			if (!drawing) {
				ctx.moveTo(x, y);
				drawing = true;
			} else {
				ctx.lineTo(x, y);
			}
		}
		ctx.stroke();
	}

	ctx.restore();
}

export interface LineSlot {
	x: number;
	width: number;
}

const SLOT_PAD = 10;
const MIN_SLOT = 36;

function scrollOffset() {
	return { x: window.scrollX, y: window.scrollY };
}

export function nearOrbs(box: DOMRect, orbs: Orb[]): boolean {
	const { x: sx, y: sy } = scrollOffset();
	const left = box.left + sx;
	const right = box.right + sx;
	const top = box.top + sy;
	const bottom = box.bottom + sy;
	for (const orb of orbs) {
		if (orb.x + orb.r > left && orb.x - orb.r < right && orb.y + orb.r > top && orb.y - orb.r < bottom) {
			return true;
		}
	}
	return false;
}

function mergeIntervals(items: { l: number; r: number }[]): { l: number; r: number }[] {
	if (!items.length) return [];
	items.sort((a, b) => a.l - b.l);
	const out = [{ l: items[0].l, r: items[0].r }];
	for (let i = 1; i < items.length; i++) {
		const last = out[out.length - 1];
		const next = items[i];
		if (next.l <= last.r) last.r = Math.max(last.r, next.r);
		else out.push({ l: next.l, r: next.r });
	}
	return out;
}

/** Horizontal gaps on this line that text can occupy. Empty if the row is fully covered. */
export function availableStrips(
	box: DOMRect,
	yInBox: number,
	lineHeight: number,
	orbs: Orb[]
): LineSlot[] {
	const { x: sx, y: sy } = scrollOffset();
	const boxTop = box.top + sy;
	const boxLeft = box.left + sx;
	const lineTop = boxTop + yInBox;
	const lineBottom = lineTop + lineHeight;
	const occupied: { l: number; r: number }[] = [];

	for (const orb of orbs) {
		const closestY = clamp(orb.y, lineTop, lineBottom);
		const dy = orb.y - closestY;
		if (Math.abs(dy) >= orb.r) continue;
		const dx = Math.sqrt(orb.r * orb.r - dy * dy);
		const occL = orb.x - dx - SLOT_PAD - boxLeft;
		const occR = orb.x + dx + SLOT_PAD - boxLeft;
		if (occR <= 0 || occL >= box.width) continue;
		occupied.push({
			l: Math.max(0, occL),
			r: Math.min(box.width, occR)
		});
	}

	if (!occupied.length) return [{ x: 0, width: box.width }];

	const slots: LineSlot[] = [];
	let x = 0;
	for (const iv of mergeIntervals(occupied)) {
		if (iv.l - x >= MIN_SLOT) slots.push({ x, width: iv.l - x });
		x = Math.max(x, iv.r);
	}
	if (box.width - x >= MIN_SLOT) slots.push({ x, width: box.width - x });
	return slots;
}
