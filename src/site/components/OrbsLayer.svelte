<script lang="ts">
	import type { Attachment } from 'svelte/attachments';
	import { field, notifyOrbFrame } from '../lib/field.svelte';
	import {
		clampOrbs,
		createOrbs,
		drawWireGlobe,
		quantizedOrbsKey,
		stepOrbs,
		type Orb
	} from '../lib/orbs';
	import { idle, shouldUseOrbs } from '../lib/capabilities';

	function parseColor(el: HTMLElement): string {
		return getComputedStyle(el).color;
	}

	function pageSize() {
		const root = document.documentElement;
		return {
			w: Math.max(root.scrollWidth, window.innerWidth, 1),
			h: Math.max(root.scrollHeight, window.innerHeight, 1)
		};
	}

	const orbsAttach: Attachment = (element) => {
		if (!(element instanceof HTMLCanvasElement)) return;
		const el = element;

		if (!shouldUseOrbs()) {
			field.enabled = false;
			field.orbs = [];
			return;
		}

		let disposed = false;
		let raf = 0;
		let orbs: Orb[] = [];
		let lastKey = '';
		let lastNow = 0;
		let pageW = 0;
		let pageH = 0;
		const surface = el.getContext('2d');
		if (!surface) return;
		const ctx: CanvasRenderingContext2D = surface;

		function size() {
			const dpr = Math.min(window.devicePixelRatio || 1, 2);
			const w = Math.max(1, window.innerWidth);
			const h = Math.max(1, window.innerHeight);
			const bw = Math.round(w * dpr);
			const bh = Math.round(h * dpr);
			if (el.width !== bw) el.width = bw;
			if (el.height !== bh) el.height = bh;
			return { w, h, dpr };
		}

		function syncPage() {
			const next = pageSize();
			const grown = Math.abs(next.w - pageW) >= 8 || Math.abs(next.h - pageH) >= 48;
			if (!orbs.length) {
				pageW = next.w;
				pageH = next.h;
				orbs = createOrbs(pageW, pageH, window.innerHeight);
				lastKey = '';
				return;
			}
			if (!grown) return;
			pageW = next.w;
			pageH = next.h;
			orbs = clampOrbs(orbs, pageW, pageH);
		}

		function frame(now: number) {
			if (disposed) return;
			if (!shouldUseOrbs()) {
				if (field.enabled) {
					field.enabled = false;
					field.orbs = [];
					notifyOrbFrame();
				}
				raf = requestAnimationFrame(frame);
				return;
			}
			const { w, h, dpr } = size();
			syncPage();
			const dt = lastNow ? (now - lastNow) / 1000 : 0;
			lastNow = now;
			const t = now * 0.001;
			orbs = stepOrbs(orbs, dt, t, pageW, pageH);
			field.orbs = orbs;
			field.enabled = true;
			const key = quantizedOrbsKey(orbs);
			if (key !== lastKey) {
				lastKey = key;
				notifyOrbFrame();
			}

			const sx = window.scrollX;
			const sy = window.scrollY;
			ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
			ctx.clearRect(0, 0, w, h);
			const stroke = parseColor(el);
			for (const orb of orbs) {
				const x = orb.x - sx;
				const y = orb.y - sy;
				if (x + orb.r < -24 || x - orb.r > w + 24 || y + orb.r < -24 || y - orb.r > h + 24) {
					continue;
				}
				drawWireGlobe(ctx, x, y, orb.r, orb.rot, stroke);
			}
			raf = requestAnimationFrame(frame);
		}

		function resume() {
			if (disposed || raf) return;
			raf = requestAnimationFrame(frame);
		}

		const stopIdle = idle(() => {
			if (!disposed) resume();
		});

		const ro = new ResizeObserver(() => {
			if (!disposed) size();
		});
		ro.observe(document.documentElement);
		window.addEventListener('resize', size);
		document.addEventListener('visibilitychange', resume);

		return () => {
			disposed = true;
			stopIdle();
			cancelAnimationFrame(raf);
			ro.disconnect();
			window.removeEventListener('resize', size);
			document.removeEventListener('visibilitychange', resume);
			field.enabled = false;
			field.orbs = [];
		};
	};
</script>

<canvas class="orbs" aria-hidden="true" {@attach orbsAttach}></canvas>

<style>
	.orbs {
		position: fixed;
		inset: 0;
		z-index: 3;
		width: 100%;
		height: 100%;
		pointer-events: none;
		color: var(--ink-1);
	}
</style>
