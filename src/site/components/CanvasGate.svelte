<script lang="ts">
	import type { Component, Snippet } from 'svelte';
	import { idle, shouldUseEffects } from '../lib/capabilities';

	type Kind = 'decrypt' | 'displace' | 'particles';

	interface Props {
		kind: Kind;
		class?: string;
		children: Snippet;
		[key: string]: unknown;
	}

	let { kind, class: className = '', children, ...options }: Props = $props();

	let Cmp = $state<Component<Record<string, unknown>> | null>(null);

	$effect(() => {
		if (!shouldUseEffects()) return;
		const target = kind;
		return idle(() => {
			void load(target);
		});
	});

	async function load(target: Kind) {
		if (target === 'decrypt') {
			Cmp = (await import('$lib/components/canvasui/DecryptReveal.svelte')).default;
		} else if (target === 'displace') {
			Cmp = (await import('$lib/components/canvasui/Displacement.svelte')).default;
		} else {
			Cmp = (await import('$lib/components/canvasui/ParticleScroll.svelte')).default;
		}
	}
</script>

{#if Cmp}
	<Cmp class={className} {...options}>
		{@render children()}
	</Cmp>
{:else}
	{@render children()}
{/if}
