<script lang="ts">
	import type { SiteLocaleData } from '$lib/i18n';
	import { scrollScene } from '../lib/scroll';
	import type { Theme } from '../lib/theme';
	import CanvasGate from './CanvasGate.svelte';
	import Portrait from './Portrait.svelte';
	import PretextField from './PretextField.svelte';
	import SectionHead from './SectionHead.svelte';

	interface Props {
		strings: SiteLocaleData;
		name: string;
		role: string;
		description: string;
		cvUrl: string;
		born: string;
		place: string;
		workplace: string;
		theme: Theme;
	}

	let { strings, name, role, description, cvUrl, born, place, workplace, theme }: Props = $props();

	const nameParts = $derived(name.trim().split(/\s+/).filter(Boolean));

	const decryptColor = $derived.by(() => {
		void theme;
		return getComputedStyle(document.documentElement).getPropertyValue('--ink-1').trim();
	});
	const decryptBg = $derived.by(() => {
		void theme;
		return getComputedStyle(document.documentElement).getPropertyValue('--paper').trim();
	});
</script>

<section id="bio" class="section hero" {@attach scrollScene()}>
	<div class="hero-frame">
		<SectionHead index={strings.bio.index} kicker={strings.bio.kicker} />
		<div class="opening editorial-grid">
			<div class="portrait-layer">
				<Portrait />
			</div>
			<div class="nameplate">
				<CanvasGate
					class="hero-decrypt"
					kind="decrypt"
					color={decryptColor}
					background={decryptBg}
					radius={320}
					passthrough={0.12}
					scramble={0.08}
				>
					<h1 class="name">
						{#each nameParts as part (part)}
							<PretextField text={part} tag="span" orbs={false} />
						{/each}
					</h1>
				</CanvasGate>
			</div>
			<aside class="rail" aria-label={strings.bio.kicker}>
				<div class="rail-row primary">
					<span class="rail-label">{strings.bio.role}</span>
					<PretextField text={role} tag="p" orbs={false} />
				</div>
				<div class="rail-row">
					<span class="rail-label">{strings.bio.born}</span>
					<PretextField text={born} tag="span" orbs={false} />
				</div>
				<div class="rail-row">
					<span class="rail-label">{strings.bio.place}</span>
					<PretextField text={place} tag="span" orbs={false} />
				</div>
				<div class="rail-row">
					<span class="rail-label">{strings.bio.workplace}</span>
					<PretextField text={workplace} tag="span" orbs={false} />
				</div>
				<a class="cv-link" href={cvUrl} target="_blank" rel="noopener">
					<PretextField text={strings.bio.cv} tag="span" orbs={false} />
					<span aria-hidden="true">↗</span>
				</a>
			</aside>
			<div class="lede">
				<PretextField text={description} tag="p" orbs={false} />
			</div>
		</div>
	</div>
</section>

<style>
	.hero {
		min-height: max(100svh, 48rem);
		padding-top: calc(var(--nav-h) + var(--space-3));
		padding-bottom: var(--space-4);
		border-top: 0;
		overflow: clip;
	}

	.hero::before,
	.hero::after {
		display: none;
	}

	.hero-frame {
		position: relative;
		min-height: calc(100svh - var(--nav-h) - var(--space-7));
		padding: var(--space-3);
	}

	.opening {
		position: relative;
		align-items: start;
		align-content: start;
		min-height: calc(100svh - var(--nav-h) - 9rem);
	}

	.portrait-layer {
		position: relative;
		z-index: 1;
		grid-column: 6 / -1;
		grid-row: 2;
		align-self: start;
		justify-self: end;
		width: min(52vw, 16rem);
		min-width: 0;
		margin-top: var(--space-2);
		opacity: 0.82;
		pointer-events: none;
	}

	.nameplate {
		position: relative;
		z-index: 3;
		grid-column: 1 / -1;
		grid-row: 1;
		align-self: start;
		min-width: 0;
		padding-top: clamp(var(--space-3), 6vh, var(--space-6));
	}

	.nameplate :global(.hero-decrypt),
	.nameplate :global(.hero-decrypt *) {
		overflow: visible !important;
	}

	.name {
		display: flex;
		flex-direction: column;
		align-items: stretch;
		font-size: clamp(3.1rem, 14vw, 5.5rem);
		font-weight: 500;
		letter-spacing: -0.075em;
		line-height: 0.77;
		margin: 0;
		overflow: visible;
		text-transform: uppercase;
	}

	.name :global(.pretext) {
		display: block;
		white-space: nowrap;
	}

	.rail {
		z-index: 4;
		grid-column: 1 / -1;
		display: grid;
		border-top: 1px solid var(--line);
		background: color-mix(in srgb, var(--paper) 82%, transparent);
	}

	.rail-row,
	.cv-link {
		display: grid;
		grid-template-columns: minmax(9.5rem, 0.48fr) 1fr;
		gap: var(--space-3);
		align-items: center;
		min-height: 3rem;
		border-bottom: 1px solid var(--line);
		font-family: var(--font-mono);
		font-size: 0.68rem;
		letter-spacing: 0.08em;
		text-transform: uppercase;
	}

	.rail-row :global(p),
	.rail-row :global(span) {
		margin: 0;
	}

	.rail-label {
		color: var(--ink-4);
		white-space: nowrap;
	}

	.rail-row.primary {
		color: var(--ink-2);
	}

	.lede {
		z-index: 4;
		grid-column: 1 / -1;
		padding-top: var(--space-4);
		font-family: var(--font-serif);
		font-size: clamp(1.05rem, 1.8vw, 1.5rem);
		line-height: 1.35;
		color: var(--ink-2);
		max-width: 64ch;
		text-wrap: pretty;
		hyphens: none;
	}

	.cv-link {
		grid-template-columns: 1fr auto;
		color: var(--ink-1);
		text-decoration: none;
	}

	.cv-link:hover span:last-child {
		transform: translate(2px, -2px);
	}

	@media (min-width: 900px) {
		.hero {
			min-height: 120vh;
		}

		.hero-frame {
			min-height: calc(100svh - var(--nav-h) - var(--space-4));
			padding: var(--space-4);
			overflow: visible;
		}

		.opening {
			align-items: end;
			align-content: stretch;
		}

		.name {
			font-size: clamp(6rem, 11.4vw, 12.8rem);
			line-height: 0.74;
		}

		.nameplate {
			grid-column: 1 / 10;
			grid-row: 1 / 3;
			align-self: center;
			transform: translate3d(0, var(--scene-y), 0);
			will-change: transform;
		}

		.portrait-layer {
			grid-column: 5 / 13;
			grid-row: 1 / 5;
			width: min(38vw, 36rem);
			align-self: center;
			justify-self: end;
			margin: 0 -4% 0 0;
			opacity: 0.82;
		}

		.rail {
			grid-column: 1 / 4;
			grid-row: 3 / 5;
			align-self: end;
		}

		.lede {
			grid-column: 4 / 9;
			grid-row: 4;
			padding: var(--space-5) 0 0;
			background: color-mix(in srgb, var(--paper) 55%, transparent);
		}
	}

	@media (prefers-reduced-motion: reduce), (pointer: coarse) {
		.nameplate {
			transform: none;
		}
	}
</style>
