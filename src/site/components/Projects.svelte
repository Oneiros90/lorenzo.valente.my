<script lang="ts">
	import { formatMonthYear } from '$lib/format';
	import type { Locale, SiteLocaleData } from '$lib/i18n';
	import type { GithubProfile, ProjectConfig } from '$lib/webgl/types';
	import { scrollScene } from '../lib/scroll';
	import PretextField from './PretextField.svelte';
	import SectionHead from './SectionHead.svelte';

	interface Props {
		strings: SiteLocaleData;
		profile: GithubProfile;
		projects: ProjectConfig[];
		error: boolean;
		locale: Locale;
	}

	let { strings, profile, projects, error, locale }: Props = $props();

	const localeTag = $derived(locale === 'it' ? 'it-IT' : 'en-US');
	const joined = $derived.by(() => {
		if (!profile.joined) return null;
		const date = new Date(profile.joined);
		return Number.isNaN(date.getTime()) ? null : formatMonthYear(date, localeTag);
	});
	const loading = $derived(!error && profile.followers == null && projects.length === 0);
	const curatedProjects = $derived(projects.slice(0, 8));
	const sequenceLength = $derived(Math.max(1, loading ? 5 : curatedProjects.length));
	const staticResult = $derived(error || (!loading && curatedProjects.length === 0));

	function hideImg(event: Event) {
		const img = event.currentTarget;
		if (img instanceof HTMLImageElement) img.hidden = true;
	}

	function repoMark(name: string) {
		const parts = name.split(/[-_.]+/).filter((part) => /[a-zA-Z0-9]/.test(part));
		if (parts.length >= 2) {
			return `${parts[0][0] ?? ''}${parts[1][0] ?? ''}`.toUpperCase();
		}
		const compact = name.replace(/[^a-zA-Z0-9]/g, '');
		return (compact.slice(0, 2) || 'GH').toUpperCase();
	}
</script>

<section
	id="projects"
	class={['section', 'projects-section', { 'static-result': staticResult }]}
	style:--scene-length={`${Math.max(2, sequenceLength) * 82}vh`}
	{@attach scrollScene({ track: '.project-track' })}
>
	<div class="projects-sticky">
		<SectionHead index={strings.projects.index} kicker={strings.projects.kicker} />

		<div class="project-console">
			<div class="stats">
				<div>
					<span class="meta">{strings.projects.followers}</span>
					<b class={['value', { skeleton: profile.followers == null && !error }]}>
						{profile.followers ?? '—'}
					</b>
				</div>
				<div>
					<span class="meta">{strings.projects.repos}</span>
					<b class={['value', { skeleton: profile.publicRepos == null && !error }]}>
						{profile.publicRepos ?? '—'}
					</b>
				</div>
				<div>
					<span class="meta">{strings.projects.joined}</span>
					<b class={['value', { skeleton: !joined && !error }]}>
						{joined ?? '—'}
					</b>
				</div>
			</div>
			{#if profile.url}
				<a class="profile-link meta" href={profile.url} target="_blank" rel="noopener">
					@{profile.username} ↗
				</a>
			{/if}
		</div>

		<div class="sequence-head meta">
			<PretextField text={strings.projects.sequence} tag="span" orbs={false} />
			<span>{String(sequenceLength).padStart(2, '0')} / GH</span>
		</div>

		<div class="sequence-viewport" aria-label={strings.projects.sequence}>
			<ul class="project-track">
			{#if loading}
				{#each { length: 5 }, index}
					<li class="project-item">
						<div class="repo technical-frame">
							<span class="project-number meta">0{index + 1}</span>
							<span class="thumb skeleton"></span>
							<span class="skeleton">{strings.projects.repos}</span>
						</div>
					</li>
				{/each}
			{:else}
				{#each curatedProjects as project, index (project.id)}
					<li class="project-item">
						<a
							class="repo technical-frame"
							href={project.url}
							target="_blank"
							rel="noopener"
							aria-label={`${strings.projects.open}: ${project.name}`}
						>
							<span class="project-number meta">
								{String(index + 1).padStart(2, '0')} / {String(curatedProjects.length).padStart(2, '0')}
							</span>
							<span class="image-frame media-fallback">
								<span class="monogram" aria-hidden="true">{repoMark(project.name)}</span>
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
							<span class="repo-head">
								<strong><PretextField text={project.name} tag="span" orbs={false} /></strong>
								<span aria-hidden="true">↗</span>
							</span>
							<span class="facts meta">
								<span>{project.lang}</span>
								<span>{strings.projects.stars} {project.stars}</span>
							</span>
							<span class="desc">
								<PretextField
									text={project.description || strings.projects.noDescription}
									tag="span"
									orbs={false}
								/>
							</span>
							{#if project.tags.length}
								<span class="tags">
									{#each project.tags as tag (tag)}
										<i>{tag}</i>
									{/each}
								</span>
							{/if}
						</a>
					</li>
				{/each}
			{/if}
			</ul>
		</div>

		<div class="status-wrap" aria-live="polite" aria-atomic="true">
			{#if error}
				<p class="status">{strings.projects.error}</p>
			{:else if !loading && projects.length === 0}
				<p class="status">{strings.projects.empty}</p>
			{/if}
		</div>
	</div>
</section>

<style>
	.projects-section {
		overflow: clip;
		--scene-x: 0px;
	}

	.projects-sticky {
		min-width: 0;
	}

	.project-console {
		display: grid;
		gap: var(--space-3);
		margin-bottom: var(--space-5);
		padding-bottom: var(--space-4);
		border-bottom: 1px solid var(--line);
	}

	.stats {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: var(--space-3);
	}

	.stats div {
		display: grid;
		gap: var(--space-1);
	}

	.value {
		font-size: clamp(1.35rem, 3vw, 2.4rem);
		font-weight: 500;
		letter-spacing: -0.045em;
	}

	.profile-link {
		width: fit-content;
		text-decoration: none;
	}

	.sequence-head {
		display: flex;
		justify-content: space-between;
		gap: var(--space-3);
		margin-bottom: var(--space-3);
	}

	.sequence-viewport {
		min-width: 0;
	}

	.project-track {
		list-style: none;
		display: grid;
		gap: var(--space-5);
	}

	.repo {
		position: relative;
		display: grid;
		gap: var(--space-3);
		min-height: 100%;
		padding: var(--space-4);
		text-decoration: none;
		color: inherit;
		overflow: clip;
	}

	.project-number {
		justify-self: end;
	}

	.repo img,
	.thumb {
		width: 100%;
		aspect-ratio: 16 / 9;
		object-fit: cover;
		background: color-mix(in srgb, var(--ink-1) 6%, transparent);
		filter: grayscale(1) contrast(1.08);
		transition: transform var(--motion-slow) var(--ease), filter var(--motion-medium) var(--ease);
	}

	.image-frame {
		position: relative;
		display: block;
		overflow: hidden;
		border: 1px solid var(--line);
		border-radius: var(--radius);
		aspect-ratio: 16 / 9;
	}

	.monogram {
		position: absolute;
		inset: 0;
		display: grid;
		place-items: center;
		font-family: var(--font-display);
		font-size: clamp(2.4rem, 7vw, 6rem);
		font-weight: 500;
		letter-spacing: -0.06em;
		line-height: 1;
		color: var(--ink-3);
		text-transform: uppercase;
		pointer-events: none;
	}

	.image-frame:has(img:not([hidden])) .monogram {
		opacity: 0;
	}

	.repo img {
		position: relative;
		z-index: 1;
	}

	.media-fallback {
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

	.repo:hover img {
		transform: scale(1.025);
		filter: grayscale(0.15);
	}

	.repo-head {
		display: grid;
		grid-template-columns: 1fr auto;
		gap: var(--space-3);
		align-items: start;
	}

	.repo strong {
		font-weight: 500;
		font-size: clamp(1.35rem, 2.5vw, 2.2rem);
		letter-spacing: -0.045em;
		line-height: 1;
	}

	.facts {
		display: flex;
		gap: var(--space-3);
		padding-top: var(--space-2);
		border-top: 1px solid var(--line);
	}

	.desc {
		color: var(--ink-2);
		font-family: var(--font-serif);
		line-height: 1.45;
	}

	.tags {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-1);
		align-self: end;
	}

	.tags i {
		font-style: normal;
		font-family: var(--font-mono);
		font-size: 0.62rem;
		letter-spacing: 0.08em;
		text-transform: uppercase;
		color: var(--ink-4);
		border: 1px solid var(--line);
		border-radius: var(--radius);
		padding: 0.15rem 0.4rem;
	}

	.status-wrap {
		min-height: 2rem;
	}

	.status {
		color: var(--ink-3);
		font-family: var(--font-serif);
		margin-top: var(--space-4);
	}

	@media (min-width: 720px) {
		.project-console {
			grid-template-columns: 1fr auto;
			align-items: end;
		}

		.project-track {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
	}

	@media (min-width: 900px) and (pointer: fine) and (prefers-reduced-motion: no-preference) {
		.projects-section {
			width: 100%;
			max-width: none;
			height: var(--scene-length);
			padding-inline: 0;
			padding-bottom: 0;
		}

		.projects-section::before {
			left: var(--gutter);
		}

		.projects-section::after {
			right: var(--gutter);
		}

		.projects-sticky {
			position: sticky;
			top: var(--nav-h);
			height: calc(100svh - var(--nav-h));
			padding: var(--space-4) var(--gutter);
			overflow: hidden;
		}

		.project-console {
			grid-template-columns: minmax(34rem, 0.55fr) auto;
			max-width: var(--grid-max);
			margin-inline: auto;
			margin-bottom: var(--space-3);
			padding-bottom: var(--space-3);
		}

		.sequence-head {
			max-width: var(--grid-max);
			margin-inline: auto;
			margin-bottom: var(--space-3);
		}

		.sequence-viewport {
			overflow: visible;
		}

		.project-track {
			display: flex;
			width: max-content;
			gap: var(--grid-gap);
			transform: translate3d(var(--scene-x), 0, 0);
			will-change: transform;
		}

		.project-item {
			width: clamp(32rem, 60vw, 68rem);
			min-height: calc(100svh - var(--nav-h) - 16rem);
		}

		.repo {
			grid-template-columns: minmax(0, 1.55fr) minmax(15rem, 0.75fr);
			grid-template-rows: auto auto 1fr auto;
			gap: var(--space-4) var(--space-5);
			padding: var(--space-5);
		}

		.project-number {
			grid-column: 2;
		}

		.image-frame,
		.thumb {
			grid-column: 1;
			grid-row: 1 / -1;
			align-self: stretch;
		}

		.repo img,
		.thumb {
			height: 100%;
			aspect-ratio: auto;
		}

		.repo-head,
		.facts,
		.desc,
		.tags {
			grid-column: 2;
		}

		.status-wrap {
			position: absolute;
			bottom: var(--space-3);
		}

		:global(.projects-section[data-static-scene]),
		.projects-section.static-result {
			width: min(100%, var(--grid-max));
			height: auto;
			min-height: auto;
			padding: clamp(var(--space-6), 10vw, var(--space-8)) var(--gutter);
		}

		:global(.projects-section[data-static-scene]) .projects-sticky,
		.projects-section.static-result .projects-sticky {
			position: static;
			height: auto;
			padding: 0;
			overflow: visible;
		}

		:global(.projects-section[data-static-scene]) .project-track,
		.projects-section.static-result .project-track {
			display: grid;
			grid-template-columns: repeat(2, minmax(0, 1fr));
			width: auto;
			transform: none;
		}

		:global(.projects-section[data-static-scene]) .project-item,
		.projects-section.static-result .project-item {
			width: auto;
			min-height: 0;
		}

		:global(.projects-section[data-static-scene]) .repo,
		.projects-section.static-result .repo {
			display: grid;
			grid-template-columns: 1fr;
			grid-template-rows: auto;
		}

		:global(.projects-section[data-static-scene]) .project-number,
		:global(.projects-section[data-static-scene]) .image-frame,
		:global(.projects-section[data-static-scene]) .thumb,
		:global(.projects-section[data-static-scene]) .repo-head,
		:global(.projects-section[data-static-scene]) .facts,
		:global(.projects-section[data-static-scene]) .desc,
		:global(.projects-section[data-static-scene]) .tags,
		.projects-section.static-result .project-number,
		.projects-section.static-result .image-frame,
		.projects-section.static-result .thumb,
		.projects-section.static-result .repo-head,
		.projects-section.static-result .facts,
		.projects-section.static-result .desc,
		.projects-section.static-result .tags {
			grid-column: 1;
			grid-row: auto;
		}

		:global(.projects-section[data-static-scene]) .repo img,
		:global(.projects-section[data-static-scene]) .thumb,
		.projects-section.static-result .repo img,
		.projects-section.static-result .thumb {
			height: auto;
			aspect-ratio: 16 / 9;
		}

		.projects-section.static-result .status-wrap {
			position: static;
		}
	}
</style>
