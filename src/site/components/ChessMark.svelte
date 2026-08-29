<script lang="ts">
	const uid = $props.id();

	const N = 8;
	const TW = 18;
	const TH = 10;
	const OX = 160;
	const OY = 22;
	const FRAME = 1.8;
	const GRID_INSET = 2.4;
	const CHAMFER = 8;

	type Pt = { x: number; y: number };

	function iso(i: number, j: number): Pt {
		return { x: OX + (i - j) * TW, y: OY + (i + j) * TH };
	}

	function diamond(pts: Pt[]) {
		return `M${pts.map((p) => `${p.x} ${p.y}`).join('L')}Z`;
	}

	function inset(pts: Pt[], amount: number) {
		const cx = pts.reduce((sum, p) => sum + p.x, 0) / pts.length;
		const cy = pts.reduce((sum, p) => sum + p.y, 0) / pts.length;
		return pts.map((p) => {
			const dx = cx - p.x;
			const dy = cy - p.y;
			const len = Math.hypot(dx, dy) || 1;
			return { x: p.x + (dx / len) * amount, y: p.y + (dy / len) * amount };
		});
	}

	function shorten(a: Pt, b: Pt, pad: number) {
		const dx = b.x - a.x;
		const dy = b.y - a.y;
		const len = Math.hypot(dx, dy) || 1;
		const ux = dx / len;
		const uy = dy / len;
		return {
			a: { x: a.x + ux * pad, y: a.y + uy * pad },
			b: { x: b.x - ux * pad, y: b.y - uy * pad }
		};
	}

	function chamfer(pts: Pt[], cut: number) {
		const out: Pt[] = [];
		const n = pts.length;
		for (let i = 0; i < n; i++) {
			const prev = pts[(i + n - 1) % n];
			const cur = pts[i];
			const next = pts[(i + 1) % n];
			const d0 = Math.hypot(cur.x - prev.x, cur.y - prev.y) || 1;
			const d1 = Math.hypot(next.x - cur.x, next.y - cur.y) || 1;
			out.push({
				x: cur.x + ((prev.x - cur.x) / d0) * cut,
				y: cur.y + ((prev.y - cur.y) / d0) * cut
			});
			out.push({
				x: cur.x + ((next.x - cur.x) / d1) * cut,
				y: cur.y + ((next.y - cur.y) / d1) * cut
			});
		}
		return out;
	}

	const corners = chamfer([iso(0, 0), iso(N, 0), iso(N, N), iso(0, N)], CHAMFER);
	const inner = inset(corners, FRAME);
	const clip = diamond(inner);
	const frame = `${diamond(corners)} ${diamond(inner)}`;

	const dark = (() => {
		const parts: string[] = [];
		for (let file = 0; file < N; file++) {
			for (let rank = 0; rank < N; rank++) {
				if ((file + rank) % 2 === 0) continue;
				parts.push(
					diamond([
						iso(file, rank),
						iso(file + 1, rank),
						iso(file + 1, rank + 1),
						iso(file, rank + 1)
					])
				);
			}
		}
		return parts.join('');
	})();

	const grid = Array.from({ length: N - 1 }, (_, n) => {
		const i = n + 1;
		const ab = shorten(iso(i, 0), iso(i, N), GRID_INSET);
		const cd = shorten(iso(0, i), iso(N, i), GRID_INSET);
		return `M${ab.a.x} ${ab.a.y}L${ab.b.x} ${ab.b.y}M${cd.a.x} ${cd.a.y}L${cd.b.x} ${cd.b.y}`;
	}).join('');
</script>

<figure class="mark" aria-hidden="true">
	<svg viewBox="0 8 320 188" fill="none">
		<defs>
			<clipPath id="{uid}-board">
				<path d={clip} />
			</clipPath>
		</defs>
		<g clip-path="url(#{uid}-board)">
			<path class="dark" d={dark} />
			<path class="grid" d={grid} />
		</g>
		<path class="frame" d={frame} fill-rule="evenodd" />
	</svg>
</figure>

<style>
	.mark {
		margin: 0;
		width: min(18rem, 78vw);
		overflow: hidden;
		background: transparent;
	}

	svg {
		display: block;
		width: 100%;
		height: auto;
		overflow: hidden;
	}

	.dark {
		fill: color-mix(in srgb, var(--ink-1) 38%, transparent);
		stroke: none;
	}

	.grid {
		fill: none;
		stroke: var(--ink-1);
		stroke-width: 1;
		stroke-linecap: butt;
		stroke-linejoin: miter;
	}

	.frame {
		fill: var(--ink-1);
		stroke: none;
	}

	@media (min-width: 900px) {
		.mark {
			width: min(28vh, 18rem);
			justify-self: start;
		}
	}
</style>
