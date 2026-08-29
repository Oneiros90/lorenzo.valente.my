<script lang="ts">
	import type { SiteLocaleData } from '$lib/i18n';
	import { scrollScene } from '../lib/scroll';
	import PretextField from './PretextField.svelte';
	import SectionHead from './SectionHead.svelte';

	interface Props {
		strings: SiteLocaleData;
		socials: { id: string; url: string }[];
	}

	let { strings, socials }: Props = $props();

	function label(id: string) {
		const labels = strings.contact as Record<string, string>;
		return labels[id] ?? id.charAt(0).toUpperCase() + id.slice(1);
	}
</script>

<section id="contact" class="section contact-section" {@attach scrollScene()}>
	<SectionHead index={strings.contact.index} kicker={strings.contact.kicker} />
	<div class="closing technical-frame">
		<div class="prompt">
			<h2><PretextField text={strings.contact.prompt} tag="span" orbs={false} /></h2>
		</div>
		<ul>
			{#each socials as social, index (social.id)}
				<li>
					<a
						href={social.url}
						target={social.url.startsWith('mailto:') ? undefined : '_blank'}
						rel={social.url.startsWith('mailto:') ? undefined : 'noopener'}
					>
						<span class="index meta">{String(index + 1).padStart(2, '0')}</span>
						<PretextField text={label(social.id)} tag="span" orbs={false} />
						<span class="arrow" aria-hidden="true">↗</span>
					</a>
				</li>
			{/each}
		</ul>
	</div>
</section>

<style>
	.contact-section {
		min-height: 100svh;
		padding-bottom: var(--space-4);
	}

	.closing {
		padding: var(--space-4);
		overflow: clip;
	}

	.prompt {
		display: grid;
		align-content: start;
		padding: var(--space-3) 0 var(--space-5);
	}

	h2 {
		font-size: clamp(3.2rem, 11vw, 9.5rem);
		font-weight: 500;
		letter-spacing: -0.07em;
		line-height: 0.82;
		text-transform: uppercase;
		white-space: nowrap;
	}

	h2 :global(.pretext),
	h2 :global(.source),
	h2 :global(.line) {
		white-space: nowrap;
	}

	ul {
		list-style: none;
		display: grid;
		border-top: 1px solid var(--line);
	}

	a {
		display: grid;
		grid-template-columns: 2.5rem 1fr auto;
		gap: var(--space-3);
		align-items: center;
		min-height: clamp(4.5rem, 9vw, 8rem);
		border-bottom: 1px solid var(--line);
		text-decoration: none;
		font-size: clamp(1.5rem, 4vw, 4rem);
		letter-spacing: -0.04em;
		transition: transform var(--motion-fast) var(--ease);
	}

	a:hover {
		color: var(--ink-1);
		transform: translateX(var(--space-2));
	}

	.index {
		letter-spacing: 0.08em;
	}

	.arrow {
		font-family: var(--font-mono);
		font-size: 0.9rem;
	}

	@media (min-width: 900px) {
		.closing {
			display: grid;
			grid-template-columns: 5fr 7fr;
			gap: var(--space-6);
			padding: var(--space-5);
		}

		.prompt {
			position: sticky;
			top: calc(var(--nav-h) + var(--space-5));
			align-self: start;
		}

		ul {
			align-self: start;
		}
	}
</style>
