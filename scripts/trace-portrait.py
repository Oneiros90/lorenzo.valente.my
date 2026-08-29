#!/usr/bin/env python3
"""JPEG stencil → stroke-only plotter SVG (contours + isometric hatch)."""

from __future__ import annotations

import math
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image

SRC = Path("/Users/oneiros/Downloads/yobro.jpeg")
SVG_OUT = Path(__file__).resolve().parents[1] / "src/site/assets/portrait.svg"
SVELTE_OUT = Path(__file__).resolve().parents[1] / "src/site/components/Portrait.svelte"

BG = np.array([136, 24, 40], dtype=np.float32)
INK = np.array([40, 40, 40], dtype=np.float32)
SKIN = np.array([248, 248, 248], dtype=np.float32)

CASES: dict[int, list[tuple[int, int]]] = {
    0: [],
    1: [(2, 3)],
    2: [(1, 2)],
    3: [(1, 3)],
    4: [(0, 1)],
    5: [(0, 3), (1, 2)],
    6: [(0, 2)],
    7: [(0, 3)],
    8: [(0, 3)],
    9: [(0, 2)],
    10: [(0, 1), (2, 3)],
    11: [(0, 1)],
    12: [(1, 3)],
    13: [(1, 2)],
    14: [(2, 3)],
    15: [],
}


def edge_point(edge: int, x: int, y: int) -> tuple[float, float]:
    if edge == 0:
        return (x + 0.5, y)
    if edge == 1:
        return (x + 1.0, y + 0.5)
    if edge == 2:
        return (x + 0.5, y + 1.0)
    return (x, y + 0.5)


def rdp(points: list[tuple[float, float]], eps: float) -> list[tuple[float, float]]:
    if len(points) < 3:
        return points
    start, end = points[0], points[-1]
    dx = end[0] - start[0]
    dy = end[1] - start[1]
    mag = math.hypot(dx, dy) or 1.0
    best_i = 0
    best_d = 0.0
    for i in range(1, len(points) - 1):
        px, py = points[i]
        dist = abs(dy * px - dx * py + end[0] * start[1] - end[1] * start[0]) / mag
        if dist > best_d:
            best_d = dist
            best_i = i
    if best_d > eps:
        left = rdp(points[: best_i + 1], eps)
        right = rdp(points[best_i:], eps)
        return left[:-1] + right
    return [start, end]


def contours(mask: np.ndarray) -> list[list[tuple[float, float]]]:
    h, w = mask.shape
    padded = np.pad(mask.astype(np.uint8), 1, constant_values=0)
    segments: list[tuple[tuple[float, float], tuple[float, float]]] = []
    for y in range(h + 1):
        for x in range(w + 1):
            a = int(padded[y, x])
            b = int(padded[y, x + 1])
            c = int(padded[y + 1, x + 1])
            d = int(padded[y + 1, x])
            idx = (a << 3) | (b << 2) | (c << 1) | d
            for e0, e1 in CASES[idx]:
                p0 = edge_point(e0, x - 1, y - 1)
                p1 = edge_point(e1, x - 1, y - 1)
                segments.append((p0, p1))

    adj: dict[tuple[float, float], list[tuple[float, float]]] = defaultdict(list)
    for a, b in segments:
        adj[a].append(b)
        adj[b].append(a)

    used: set[tuple[tuple[float, float], tuple[float, float]]] = set()
    rings: list[list[tuple[float, float]]] = []

    def mark(u: tuple[float, float], v: tuple[float, float]) -> None:
        used.add((u, v) if u < v else (v, u))

    def seen(u: tuple[float, float], v: tuple[float, float]) -> bool:
        return ((u, v) if u < v else (v, u)) in used

    for start in adj:
        for nxt in adj[start]:
            if seen(start, nxt):
                continue
            ring = [start]
            prev, cur = start, nxt
            mark(prev, cur)
            while cur != start:
                ring.append(cur)
                options = [n for n in adj[cur] if n != prev and not seen(cur, n)]
                if not options:
                    options = [n for n in adj[cur] if n != prev]
                if not options:
                    break
                prev, cur = cur, options[0]
                mark(prev, cur)
                if len(ring) > (h + 2) * (w + 2):
                    break
            if len(ring) >= 4:
                body = ring[:-1] if ring[0] == ring[-1] else ring
                simple = rdp(body, 1.1)
                if len(simple) >= 3:
                    if simple[0] != simple[-1]:
                        simple.append(simple[0])
                    rings.append(simple)
    return rings


def polyline_d(rings: list[list[tuple[float, float]]], ox: float, oy: float) -> str:
    parts: list[str] = []
    for ring in rings:
        cmds = [f"M{ring[0][0] - ox:.1f} {ring[0][1] - oy:.1f}"]
        for x, y in ring[1:]:
            cmds.append(f"L{x - ox:.1f} {y - oy:.1f}")
        parts.append("".join(cmds))
    return "".join(parts)


def hatch(mask: np.ndarray, spacing: int, angle_deg: float, ox: float, oy: float) -> str:
    h, w = mask.shape
    rad = math.radians(angle_deg)
    ca, sa = math.cos(rad), math.sin(rad)
    diag = int(math.hypot(w, h)) + spacing
    parts: list[str] = []
    for k in range(-diag, diag + 1, spacing):
        run: list[tuple[float, float]] = []
        drawing = False
        for s in range(-diag, diag + 1):
            x = int(round(k * -sa + s * ca))
            y = int(round(k * ca + s * sa))
            inside = 0 <= x < w and 0 <= y < h and bool(mask[y, x])
            if inside:
                if not drawing:
                    run = [(x + 0.5, y + 0.5)]
                    drawing = True
                else:
                    run.append((x + 0.5, y + 0.5))
            elif drawing:
                if len(run) >= 3:
                    a, b = run[0], run[-1]
                    parts.append(f"M{a[0] - ox:.1f} {a[1] - oy:.1f}L{b[0] - ox:.1f} {b[1] - oy:.1f}")
                drawing = False
                run = []
        if drawing and len(run) >= 3:
            a, b = run[0], run[-1]
            parts.append(f"M{a[0] - ox:.1f} {a[1] - oy:.1f}L{b[0] - ox:.1f} {b[1] - oy:.1f}")
    return "".join(parts)


def classify(im: Image.Image) -> np.ndarray:
    arr = np.asarray(im, dtype=np.float32)
    stacked = np.stack(
        [
            np.linalg.norm(arr - BG, axis=2),
            np.linalg.norm(arr - INK, axis=2),
            np.linalg.norm(arr - SKIN, axis=2),
        ],
        axis=2,
    )
    labels = np.argmin(stacked, axis=2)
    h, w = labels.shape
    padded = np.pad(labels, 1, mode="edge")
    clean = labels.copy()
    for y in range(h):
        for x in range(w):
            win = padded[y : y + 3, x : x + 3].ravel()
            clean[y, x] = int(np.argmax(np.bincount(win, minlength=3)))
    return clean


def main() -> None:
    im = Image.open(SRC).convert("RGB")
    labels = classify(im)
    figure = labels != 0
    ys, xs = np.where(figure)
    pad = 18
    x0 = max(int(xs.min()) - pad, 0)
    y0 = max(int(ys.min()) - pad, 0)
    x1 = min(int(xs.max()) + pad, labels.shape[1] - 1)
    y1 = min(int(ys.max()) + pad, labels.shape[0] - 1)
    vw, vh = x1 - x0, y1 - y0

    ink_mask = labels == 1
    skin_mask = labels == 2
    ink_d = polyline_d(contours(ink_mask), x0, y0)
    skin_d = polyline_d(contours(skin_mask), x0, y0)
    outer_rings = contours(figure)
    outer_d = polyline_d(outer_rings, x0, y0)
    ox3, oy3 = 14.0, -10.0
    depth_parts: list[str] = []
    for ring in outer_rings:
        if not ring:
            continue
        depth_parts.append(
            f"M{ring[0][0] - x0 + ox3:.1f} {ring[0][1] - y0 + oy3:.1f}"
        )
        for x, y in ring[1:]:
            depth_parts.append(f"L{x - x0 + ox3:.1f} {y - y0 + oy3:.1f}")
        step = max(6, len(ring) // 18)
        for i, (x, y) in enumerate(ring[:-1]):
            if i % step:
                continue
            depth_parts.append(
                f"M{x - x0:.1f} {y - y0:.1f}L{x - x0 + ox3:.1f} {y - y0 + oy3:.1f}"
            )
    depth_d = "".join(depth_parts)
    ink_h = hatch(ink_mask, 5, 38, x0, y0)
    skin_h = hatch(skin_mask, 9, 38, x0, y0)
    shade_h = hatch(ink_mask, 7, 128, x0, y0)

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {vw} {vh}" fill="none" aria-hidden="true">
  <path class="depth" d="{depth_d}"/>
  <path class="hatch-skin" d="{skin_h}"/>
  <path class="hatch-ink" d="{ink_h}"/>
  <path class="hatch-shade" d="{shade_h}"/>
  <path class="contour-skin" d="{skin_d}"/>
  <path class="contour-ink" d="{ink_d}"/>
  <path class="contour-outer" d="{outer_d}"/>
</svg>
"""
    SVG_OUT.parent.mkdir(parents=True, exist_ok=True)
    SVG_OUT.write_text(svg)

    svelte = f"""<script lang="ts"></script>

<figure class="portrait" aria-hidden="true">
	<svg viewBox="0 0 {vw} {vh}" fill="none">
		<path class="depth" d="{depth_d}" />
		<path class="hatch-skin" d="{skin_h}" />
		<path class="hatch-ink" d="{ink_h}" />
		<path class="hatch-shade" d="{shade_h}" />
		<path class="contour-skin" d="{skin_d}" />
		<path class="contour-ink" d="{ink_d}" />
		<path class="contour-outer" d="{outer_d}" />
	</svg>
</figure>

<style>
	.portrait {{
		margin: 0;
		width: min(26rem, 92vw);
		background: transparent;
	}}

	svg {{
		display: block;
		width: 100%;
		height: auto;
		overflow: visible;
	}}

	path {{
		fill: none;
		stroke-linecap: square;
		stroke-linejoin: miter;
	}}

	.depth {{
		stroke: var(--ink-4);
		stroke-width: 0.85;
	}}

	.hatch-skin {{
		stroke: var(--ink-3);
		stroke-width: 0.9;
	}}

	.hatch-ink {{
		stroke: var(--ink-1);
		stroke-width: 1.05;
	}}

	.hatch-shade {{
		stroke: var(--ink-2);
		stroke-width: 0.7;
		opacity: 0.7;
	}}

	.contour-skin {{
		stroke: var(--ink-2);
		stroke-width: 1.15;
	}}

	.contour-ink,
	.contour-outer {{
		stroke: var(--ink-1);
		stroke-width: 1.35;
	}}

	@media (min-width: 1100px) {{
		.portrait {{
			width: 100%;
			max-width: 42rem;
			justify-self: end;
		}}
	}}
</style>
"""
    SVELTE_OUT.write_text(svelte)
    print(f"wrote {SVG_OUT} ({SVG_OUT.stat().st_size} bytes)")
    print(f"wrote {SVELTE_OUT} ({SVELTE_OUT.stat().st_size} bytes) viewBox {vw}x{vh}")


if __name__ == "__main__":
    main()
