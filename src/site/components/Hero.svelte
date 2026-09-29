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
			<div class="copy">
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
			<div class="portrait-layer">
				<Portrait />
			</div>
		</div>
	</div>
</section>

<style>
	.hero {
		min-height: 100svh;
		padding-top: calc(var(--nav-h) + var(--space-3));
		padding-bottom: var(--space-5);
		border-top: 0;
		overflow: clip;
	}

	.hero::before,
	.hero::after {
		display: none;
	}

	.hero-frame {
		position: relative;
		display: flex;
		flex-direction: column;
		min-height: calc(100svh - var(--nav-h) - var(--space-5));
	}

	.hero-frame :global(.section-head) {
		margin-bottom: var(--space-4);
	}

	.opening {
		position: relative;
		flex: 1;
		align-items: start;
		align-content: start;
	}

	.copy {
		display: contents;
	}

	.nameplate {
		position: relative;
		grid-column: 1 / -1;
		min-width: 0;
		z-index: 3;
	}

	.portrait-layer {
		position: relative;
		z-index: 1;
		grid-column: 1 / -1;
		grid-row: 2;
		width: min(72vw, 22rem);
		min-width: 0;
		justify-self: center;
		pointer-events: none;
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
		grid-column: 1 / -1;
		z-index: 3;
		display: grid;
		border-top: 1px solid var(--line);
	}

	.lede {
		grid-column: 1 / -1;
		z-index: 3;
		font-family: var(--font-serif);
		font-size: clamp(1.05rem, 1.7vw, 1.45rem);
		line-height: 1.35;
		color: var(--ink-2);
		max-width: 46ch;
		text-wrap: pretty;
		hyphens: none;
	}

	.rail-row,
	.cv-link {
		display: grid;
		grid-template-columns: minmax(9.5rem, 0.42fr) 1fr;
		gap: var(--space-3);
		align-items: center;
		min-height: 2.75rem;
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
			min-height: 100svh;
			overflow: visible;
		}

		.hero-frame {
			min-height: calc(100svh - var(--nav-h) - var(--space-4));
		}

		.hero-frame :global(.section-head) {
			margin-bottom: var(--space-5);
		}

		.opening {
			align-items: stretch;
			align-content: stretch;
			grid-template-rows: minmax(0, 1fr);
		}

		.copy {
			display: flex;
			flex-direction: column;
			grid-column: 1 / 8;
			grid-row: 1;
			min-width: 0;
			justify-content: center;
			gap: var(--space-4);
			padding-right: var(--grid-gap);
		}

		.nameplate,
		.rail,
		.lede {
			grid-column: auto;
			grid-row: auto;
		}

		.name {
			font-size: clamp(6rem, 11.4vw, 12.8rem);
			line-height: 0.74;
		}

		.portrait-layer {
			grid-column: 8 / 13;
			grid-row: 1;
			width: auto;
			height: 100%;
			min-height: 0;
			margin: 0;
			justify-self: stretch;
			align-self: stretch;
			display: flex;
			align-items: center;
			justify-content: center;
		}

		.portrait-layer :global(.portrait) {
			width: 100%;
			height: 100%;
			display: flex;
			align-items: center;
			justify-content: center;
		}

		.portrait-layer :global(svg) {
			width: 100%;
			height: auto;
			max-height: 100%;
		}

		.lede {
			padding-top: 0;
			max-width: 42ch;
		}
	}

	@media (min-width: 1400px) {
		.copy {
			grid-column: 1 / 7;
		}

		.portrait-layer {
			grid-column: 7 / 13;
		}
	}

	@media (min-width: 900px) and (max-height: 820px) {
		.hero-frame :global(.section-head) {
			margin-bottom: var(--space-3);
		}

		.copy {
			gap: var(--space-3);
		}

		.name {
			font-size: clamp(4.6rem, 16vh, 9.5rem);
		}

		.rail-row,
		.cv-link {
			min-height: 2.35rem;
		}

		.lede {
			margin-top: 0;
		}
	}
</style>
