<script lang="ts">
	import type { SiteLocaleData } from '$lib/i18n';

	interface Props {
		strings: SiteLocaleData;
		year: number;
	}

	let { strings, year }: Props = $props();
</script>

<footer class="footer">
	<div class="footer-grid">
		<div class="cluster">
			<a class="enceladus" href="/enceladus/">{strings.nav.enceladus}</a>
			<p>{strings.meta.title} · {year}</p>
		</div>
		<div class="cluster end">
			<p class="rights">{strings.footer.rights}</p>
			<a href="#bio">{strings.footer.back} ↑</a>
		</div>
	</div>
</footer>

<style>
	.footer {
		padding: var(--space-4) var(--gutter) var(--space-5);
		border-top: 1px solid var(--line);
		font-family: var(--font-mono);
		font-size: 0.72rem;
		letter-spacing: 0.08em;
		color: var(--ink-3);
	}

	.footer-grid {
		display: grid;
		gap: var(--space-3);
		width: min(100%, calc(var(--grid-max) - (var(--gutter) * 2)));
		margin-inline: auto;
	}

	.cluster {
		display: grid;
		gap: var(--space-1);
		align-content: start;
	}

	a {
		width: fit-content;
		color: var(--ink-1);
		text-decoration: none;
	}

	.enceladus {
		text-transform: uppercase;
		letter-spacing: 0.12em;
	}

	@media (min-width: 900px) {
		.footer-grid {
			grid-template-columns: 1fr 1fr;
			align-items: start;
		}

		.cluster.end {
			justify-items: end;
			text-align: right;
		}
	}
</style>
