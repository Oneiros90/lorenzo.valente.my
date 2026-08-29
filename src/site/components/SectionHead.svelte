<script lang="ts">
	import PretextField from './PretextField.svelte';

	interface Props {
		index: string;
		kicker: string;
	}

	let { index, kicker }: Props = $props();
	const label = $derived(`${index} // ${kicker}`);
</script>

<header class="section-head">
	<PretextField class="kicker" text={label} tag="p" orbs={false} />
</header>
