<script lang="ts">
	import type { SiteLocaleData } from '$lib/i18n';
	import { sparkPaths } from '$lib/chess';
	import type { ChessConfig, ChessTimeControl } from '$lib/webgl/types';
	import { scrollScene } from '../lib/scroll';
	import ChessMark from './ChessMark.svelte';
	import PretextField from './PretextField.svelte';
	import SectionHead from './SectionHead.svelte';

	interface Props {
		strings: SiteLocaleData;
		chess: ChessConfig;
		error: boolean;
	}

	let { strings, chess, error }: Props = $props();

	const pending = $derived(!error && chess.timeControls.length === 0);

	const resultLabel = $derived(
		chess.lastGameResult === 'win'
			? strings.chess.win
			: chess.lastGameResult === 'draw'
				? strings.chess.draw
				: chess.lastGameResult === 'loss'
					? strings.chess.loss
					: ''
	);

	const lastGame = $derived(
		[resultLabel, chess.lastGameOpening].filter(Boolean).join(' · ')
	);

	function gamesPlayed(tc: ChessTimeControl) {
		return tc.wins + tc.losses + tc.draws;
	}

	function winRate(tc: ChessTimeControl) {
		const total = gamesPlayed(tc);
		return total ? Math.round((tc.wins / total) * 100) : 0;
	}

	function titleFor(id: ChessTimeControl['id']) {
		return strings.chess[id];
	}

	function elo(value: number | null) {
		return value == null ? '—' : String(value);
	}
</script>

<section id="chess" class="section chess-section" {@attach scrollScene()}>
	<SectionHead index={strings.chess.index} kicker={strings.chess.kicker} />

	<div class="poster technical-frame">
		<div class="poster-head meta">
			<PretextField text={strings.chess.poster} tag="span" orbs={false} />
			<span>@{chess.username}</span>
		</div>
		<div class="mark-wrap">
			<ChessMark />
		</div>
		<div class="body" aria-live="polite" aria-busy={pending}>
			{#if error}
				<p class="status">{strings.chess.error}</p>
			{:else if pending}
				<div class="ratings">
					{#each ['rapid', 'blitz', 'bullet'] as id (id)}
						<article class="rating technical-frame">
							<span class="meta">{strings.chess[id as 'rapid' | 'blitz' | 'bullet']}</span>
							<b class="elo skeleton">2400</b>
							<div class="facts meta">
								<span class="skeleton">{strings.chess.best}</span>
								<span class="skeleton">{strings.chess.games}</span>
								<span class="skeleton">{strings.chess.winRate}</span>
							</div>
						</article>
					{/each}
				</div>
			{:else}
				<div class="ratings">
					{#each chess.timeControls as tc (tc.id)}
						{@const spark = sparkPaths(tc.spark)}
						<article class="rating technical-frame">
							<div class="rating-head">
								<span class="meta">{titleFor(tc.id)}</span>
								<span class="meta">{tc.id.toUpperCase()}</span>
							</div>
							<b class="elo">{elo(tc.rating)}</b>
							{#if spark.line}
								<svg class="spark" viewBox="0 0 300 56" preserveAspectRatio="none" aria-hidden="true">
									<path class="spark-area" d={spark.area} />
									<path class="spark-line" d={spark.line} />
								</svg>
							{/if}
							<div class="facts meta">
								<span>{strings.chess.best} {elo(tc.best)}</span>
								<span>{strings.chess.games} {gamesPlayed(tc)}</span>
								<span>{strings.chess.winRate} {winRate(tc)}%</span>
							</div>
						</article>
					{/each}
				</div>

				<div class="record">
					<div class="last">
						<span class="meta">{strings.chess.lastGame}</span>
						{#if chess.lastGameUrl && lastGame}
							<a href={chess.lastGameUrl} target="_blank" rel="noopener">{lastGame}</a>
						{:else}
							<span>{lastGame || strings.chess.empty}</span>
						{/if}
					</div>
					<dl class="profile-data meta">
						{#if chess.followers != null}
							<div><dt>{strings.chess.followers}</dt><dd>{chess.followers}</dd></div>
						{/if}
						{#if chess.league}
							<div><dt>{strings.chess.league}</dt><dd>{chess.league}</dd></div>
						{/if}
						{#if chess.location}
							<div><dt>{strings.chess.location}</dt><dd>{chess.location}</dd></div>
						{/if}
					</dl>
				</div>
			{/if}

			{#if chess.url}
				<a class="profile-link" href={chess.url} target="_blank" rel="noopener">
					{strings.chess.profile}
					<span aria-hidden="true">↗</span>
				</a>
			{/if}
		</div>
	</div>
</section>

<style>
	.chess-section {
		min-height: 110vh;
		overflow: clip;
	}

	.poster {
		position: relative;
		min-height: 70vh;
		padding: var(--space-4);
		overflow: hidden;
	}

	.poster-head {
		position: relative;
		z-index: 3;
		display: flex;
		justify-content: space-between;
		gap: var(--space-3);
		padding-bottom: var(--space-3);
		border-bottom: 1px solid var(--line);
	}

	.mark-wrap {
		position: absolute;
		top: 10%;
		right: -18%;
		z-index: 0;
		width: min(85vw, 62rem);
		opacity: 0.2;
		transform: translate3d(0, var(--scene-y-reverse), 0) rotate(-4deg);
		will-change: transform;
	}

	.mark-wrap :global(.mark) {
		width: 100%;
		max-width: none;
	}

	.body {
		position: relative;
		z-index: 2;
		min-width: 0;
		padding-top: var(--space-6);
	}

	.ratings {
		display: grid;
		gap: var(--space-3);
		margin-bottom: var(--space-6);
	}

	.rating {
		display: grid;
		grid-template-rows: auto 1fr auto auto;
		gap: var(--space-3);
		min-height: 18rem;
		padding: var(--space-4);
		background: color-mix(in srgb, var(--paper) 88%, transparent);
	}

	.rating-head {
		display: flex;
		justify-content: space-between;
		gap: var(--space-3);
	}

	.elo {
		align-self: center;
		font-size: clamp(4rem, 15vw, 9rem);
		font-weight: 500;
		letter-spacing: -0.075em;
		line-height: 0.72;
		font-variant-numeric: tabular-nums;
	}

	.facts {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-3);
	}

	.spark {
		width: 100%;
		height: 3.5rem;
		overflow: visible;
	}

	.spark-area {
		fill: color-mix(in srgb, var(--ink-1) 6%, transparent);
		stroke: none;
	}

	.spark-line {
		fill: none;
		stroke: var(--ink-1);
		stroke-width: 1;
		vector-effect: non-scaling-stroke;
	}

	.record,
	.last {
		display: grid;
		gap: var(--space-3);
	}

	.record {
		margin-bottom: var(--space-5);
		padding-top: var(--space-4);
		border-top: 1px solid var(--line);
	}

	.last a,
	.last span:last-child {
		font-size: 1.1rem;
	}

	.status {
		color: var(--ink-3);
		font-family: var(--font-serif);
		margin-bottom: var(--space-4);
	}

	.profile-data {
		display: grid;
		gap: var(--space-2);
	}

	.profile-data div {
		display: grid;
		grid-template-columns: 1fr auto;
		gap: var(--space-3);
		padding-bottom: var(--space-2);
		border-bottom: 1px solid var(--line);
	}

	.profile-data dd {
		color: var(--ink-1);
	}

	.profile-link {
		display: flex;
		justify-content: space-between;
		align-items: center;
		min-height: 3.5rem;
		padding-top: var(--space-3);
		border-top: 1px solid var(--ink-1);
		font-family: var(--font-mono);
		font-size: 0.72rem;
		letter-spacing: 0.1em;
		text-transform: uppercase;
		text-decoration: none;
	}

	@media (min-width: 800px) {
		.ratings {
			grid-template-columns: repeat(3, 1fr);
			gap: var(--grid-gap);
		}
	}

	@media (min-width: 900px) {
		.poster {
			padding: var(--space-5);
		}

		.body {
			padding-top: clamp(var(--space-6), 10vh, var(--space-8));
		}

		.rating:nth-child(2) {
			transform: translateY(var(--space-5));
		}

		.record {
			grid-template-columns: 1.5fr 1fr;
			gap: var(--space-6);
		}

		.mark-wrap {
			top: -5%;
			right: -8%;
			width: min(66vw, 72rem);
		}
	}

	@media (prefers-reduced-motion: reduce), (pointer: coarse) {
		.mark-wrap {
			transform: rotate(-4deg);
		}
	}
</style>
