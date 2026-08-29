<script lang="ts">
	import { shouldUseEffects } from '../lib/capabilities';

	let x = $state(0);
	let y = $state(0);
	let on = $state(false);
	const active = shouldUseEffects();

	function onpointermove(event: PointerEvent) {
		if (!active) return;
		x = event.clientX;
		y = event.clientY;
		on = true;
	}
</script>

<svelte:window {onpointermove} />

{#if active && on}
	<div
		class="lens"
		style:transform={`translate3d(${x - 60}px, ${y - 60}px, 0)`}
		aria-hidden="true"
	></div>
{/if}

<style>
	.lens {
		position: fixed;
		top: 0;
		left: 0;
		z-index: 70;
		width: 120px;
		height: 120px;
		border-radius: 50%;
		pointer-events: none;
		mix-blend-mode: overlay;
		opacity: 0.7;
		background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='80' height='80'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='3' stitchTiles='stitch'/><feColorMatrix values='0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 0.85 0'/></filter><rect width='100%' height='100%' filter='url(%23n)'/></svg>");
		background-size: 80px 80px;
		background-color: color-mix(in srgb, var(--ink-1) 18%, transparent);
		border: 1px solid var(--line);
	}

	:global([data-theme='light']) .lens {
		mix-blend-mode: multiply;
	}
</style>
