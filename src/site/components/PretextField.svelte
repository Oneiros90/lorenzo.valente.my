<script lang="ts">
	import { pretextAttach, type PretextLine } from '../lib/pretext-attach';

	interface Props {
		text: string;
		tag?: string;
		class?: string;
		orbs?: boolean;
	}

	let { text, tag = 'p', class: className = '', orbs = true }: Props = $props();

	let lines = $state<PretextLine[]>([]);
	let height = $state(0);
	let hydrated = $state(false);

	function setLines(next: PretextLine[], nextHeight: number, ready: boolean) {
		lines = next;
		height = nextHeight;
		hydrated = ready;
	}
</script>

<div
	class={['pretext', className, { hydrated }]}
	style:--pretext-h={hydrated ? `${height}px` : undefined}
>
	<svelte:element
		this={tag}
		class={['source', { 'visually-hidden': hydrated }]}
		{@attach pretextAttach(() => text, setLines, orbs)}
	>
		{text}
	</svelte:element>
	{#if hydrated}
		<div class="lines" aria-hidden="true">
			{#each lines as line (`${line.x}:${line.y}:${line.text}`)}
				<span class="line" style:left={`${line.x}px`} style:top={`${line.y}px`}>{line.text}</span>
			{/each}
		</div>
	{/if}
</div>

<style>
	.pretext {
		position: relative;
	}

	.pretext.hydrated {
		min-height: var(--pretext-h, 0px);
	}

	.source {
		margin: 0;
	}

	.visually-hidden {
		position: absolute;
		width: 1px;
		height: 1px;
		padding: 0;
		margin: -1px;
		overflow: hidden;
		clip: rect(0, 0, 0, 0);
		white-space: nowrap;
		border: 0;
	}

	/* Keep a full-width box so Pretext can still measure wrapping. */
	.source.visually-hidden {
		inset: 0 auto auto 0;
		width: 100%;
		height: auto;
		margin: 0;
		overflow: hidden;
		clip: auto;
		white-space: inherit;
		opacity: 0;
		pointer-events: none;
		user-select: none;
	}

	.lines {
		position: absolute;
		inset: 0;
		user-select: text;
	}

	.line {
		position: absolute;
		white-space: pre;
		user-select: text;
	}
</style>
