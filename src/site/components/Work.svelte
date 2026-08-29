<script lang="ts">
	import { displayUrl } from '$lib/format';
	import { loc, type Locale, type SiteLocaleData } from '$lib/i18n';
	import type { CompanyConfig } from '$lib/webgl/types';
	import { scrollScene } from '../lib/scroll';
	import PretextField from './PretextField.svelte';
	import SectionHead from './SectionHead.svelte';

	interface Props {
		strings: SiteLocaleData;
		companies: CompanyConfig[];
		locale: Locale;
	}

	let { strings, companies, locale }: Props = $props();

	function hideImg(event: Event) {
		const img = event.currentTarget;
		if (img instanceof HTMLImageElement) img.hidden = true;
	}

	function yearsLabel(years: number) {
		return `${years} ${years === 1 ? strings.work.year : strings.work.years}`;
	}

	function startYear(period: string) {
		return period.match(/\d{4}/)?.[0] ?? '';
	}
</script>

<section id="work" class="section work-section" {@attach scrollScene()}>
	<SectionHead index={strings.work.index} kicker={strings.work.kicker} />
	<div class="chronology editorial-grid">
		<aside class="timeline" aria-label={strings.work.chronology}>
			<p class="meta"><PretextField text={strings.work.chronology} tag="span" orbs={false} /></p>
			<ol>
				{#each companies as company (company.id)}
					<li>
						<a href={`#work-${company.id}`}>
							<span>{startYear(loc(company.period, locale))}</span>
							<PretextField text={company.name} tag="span" orbs={false} />
						</a>
					</li>
				{/each}
			</ol>
		</aside>

		<div class="stages">
			{#each companies as company, index (company.id)}
				<article
					id={`work-${company.id}`}
					class="stage"
					{@attach scrollScene()}
				>
					<header class="stage-head">
						<p class="stage-index meta">{String(index + 1).padStart(2, '0')} / {String(companies.length).padStart(2, '0')}</p>
						<h2><PretextField text={company.name} tag="span" orbs={false} /></h2>
						<div class="stage-meta">
							<p class="meta"><PretextField text={loc(company.role, locale)} tag="span" orbs={false} /></p>
							<p class="meta period">
								<PretextField text={loc(company.period, locale)} tag="span" orbs={false} />
								<span>· {yearsLabel(company.years)}</span>
							</p>
						</div>
					</header>

					<div class="blurb">
						<PretextField text={loc(company.description, locale)} tag="p" orbs={false} />
					</div>

					{#if company.projects.length}
						<div class="selected">
							<h3 class="meta"><PretextField text={strings.work.projects} tag="span" orbs={false} /></h3>
							<ul class="project-plates">
								{#each company.projects as project (project.id)}
									<li>
										<a class="plate technical-frame" href={project.url} target="_blank" rel="noopener">
											<span class="media">
												{#if project.imageUrl}
													<img
														src={project.imageUrl}
														alt=""
														loading="lazy"
														decoding="async"
														referrerpolicy="no-referrer"
														onerror={hideImg}
													/>
												{/if}
											</span>
											<span class="plate-body">
												<strong><PretextField text={loc(project.name, locale)} tag="span" orbs={false} /></strong>
												<span class="desc">
													<PretextField text={loc(project.description, locale)} tag="span" orbs={false} />
												</span>
												<span class="url">{displayUrl(project.url)}</span>
											</span>
										</a>
									</li>
								{/each}
							</ul>
						</div>
					{/if}
				</article>
			{/each}
		</div>
	</div>
</section>

<style>
	.work-section {
		padding-bottom: var(--space-5);
	}

	.chronology {
		align-items: start;
	}

	.timeline {
		display: none;
	}

	.stages {
		grid-column: 1 / -1;
	}

	.stage {
		position: relative;
		padding: var(--space-5) 0 var(--space-7);
		border-top: 1px solid var(--line);
	}

	.stage::before {
		content: '';
		position: absolute;
		top: -1px;
		left: 0;
		width: clamp(3rem, 18vw, 12rem);
		height: 2px;
		background: var(--ink-1);
		transform: scaleX(0.16);
		transform-origin: left;
		transition: transform var(--motion-slow) var(--ease);
	}

	.stage:global([data-in-view])::before {
		transform: scaleX(1);
	}

	.stage-head h2 {
		font-size: clamp(2.5rem, 8vw, 7rem);
		font-weight: 500;
		letter-spacing: -0.065em;
		line-height: 0.86;
		margin: 0 0 var(--space-4);
		text-wrap: balance;
	}

	.stage-index {
		text-align: right;
	}

	.stage-meta {
		display: grid;
		gap: var(--space-2);
		padding: var(--space-3) 0;
		border-block: 1px solid var(--line);
	}

	.period > span {
		color: var(--ink-4);
	}

	.blurb {
		margin: var(--space-5) 0 var(--space-6);
		max-width: var(--measure);
		color: var(--ink-2);
		font-family: var(--font-serif);
		font-size: clamp(1.05rem, 1.8vw, 1.4rem);
		line-height: 1.45;
		text-wrap: pretty;
		hyphens: none;
	}

	.selected > h3 {
		margin-bottom: var(--space-3);
	}

	.project-plates {
		list-style: none;
		display: grid;
		gap: var(--space-4);
	}

	.plate {
		display: grid;
		overflow: clip;
		text-decoration: none;
		color: inherit;
		min-height: 44px;
	}

	.media {
		display: block;
		overflow: hidden;
		aspect-ratio: 16 / 8;
		border-bottom: 1px solid var(--line);
		background-color: color-mix(in srgb, var(--ink-1) 4%, var(--paper));
		background-image:
			repeating-linear-gradient(
				135deg,
				transparent 0,
				transparent 0.7rem,
				var(--line) 0.7rem,
				var(--line) calc(0.7rem + 1px)
			),
			linear-gradient(var(--line) 1px, transparent 1px),
			linear-gradient(90deg, var(--line) 1px, transparent 1px);
		background-size: auto, 2rem 2rem, 2rem 2rem;
	}

	.plate img {
		width: 100%;
		height: 100%;
		aspect-ratio: 16 / 8;
		object-fit: cover;
		background: color-mix(in srgb, var(--ink-1) 6%, transparent);
		filter: grayscale(1) contrast(1.05);
		transition: transform var(--motion-slow) var(--ease), filter var(--motion-medium) var(--ease);
	}

	.plate:hover img {
		transform: scale(1.02);
		filter: grayscale(0.3);
	}

	.plate-body {
		display: grid;
		gap: var(--space-2);
		padding: var(--space-4);
	}

	.plate-body strong {
		font-weight: 500;
		font-size: clamp(1.15rem, 2vw, 1.6rem);
	}

	.desc {
		color: var(--ink-2);
		line-height: 1.45;
		font-size: 0.95rem;
	}

	.url {
		font-family: var(--font-mono);
		font-size: 0.68rem;
		letter-spacing: 0.06em;
		color: var(--ink-4);
	}

	@media (min-width: 700px) {
		.project-plates {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
	}

	@media (min-width: 900px) and (pointer: fine) and (prefers-reduced-motion: no-preference) {
		.timeline {
			position: sticky;
			top: var(--nav-h);
			grid-column: 1 / 4;
			display: block;
			min-height: calc(100vh - var(--nav-h) - var(--space-7));
			padding-right: var(--space-4);
			padding-top: var(--space-3);
			border-right: 1px solid var(--line);
			background: var(--paper);
		}

		.timeline ol {
			list-style: none;
			margin-top: var(--space-5);
		}

		.timeline a {
			display: grid;
			grid-template-columns: 3.25rem 1fr;
			gap: var(--space-2);
			align-items: center;
			min-height: 3.25rem;
			border-top: 1px solid var(--line);
			color: var(--ink-3);
			font-family: var(--font-mono);
			font-size: 0.68rem;
			letter-spacing: 0.08em;
			text-transform: uppercase;
			text-decoration: none;
		}

		.timeline a:hover {
			color: var(--ink-1);
		}

		.stages {
			grid-column: 4 / 13;
		}

		.stage {
			min-height: 105vh;
			padding: 0 0 var(--space-8) var(--space-5);
			opacity: 0.45;
			transition: opacity var(--motion-medium) var(--ease);
		}

		.stage:global([data-in-view]),
		.stage:global([data-static-scene]) {
			opacity: 1;
		}

		.stage-head {
			position: sticky;
			top: var(--nav-h);
			z-index: 3;
			margin: 0 0 0 calc(var(--space-5) * -1);
			padding: var(--space-3) var(--space-4) var(--space-3) var(--space-5);
			background: var(--paper);
		}

		.stage-head::before {
			content: '';
			position: absolute;
			left: 0;
			right: 0;
			bottom: 0;
			top: calc(var(--nav-h) * -1);
			background: var(--paper);
			z-index: -1;
		}

		.work-section:global([data-static-scene]) .timeline,
		.work-section:global([data-static-scene]) .stage-head {
			position: static;
		}
	}
</style>
