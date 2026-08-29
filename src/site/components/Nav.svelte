<script lang="ts">
	import type { Attachment } from 'svelte/attachments';
	import type { Locale, SiteLocaleData } from '$lib/i18n';
	import { navigationProgress } from '../lib/scroll';
	import type { Theme } from '../lib/theme';

	interface Props {
		strings: SiteLocaleData;
		locale: Locale;
		theme: Theme;
		name: string;
		onlocale: (locale: Locale) => void;
		ontheme: (theme: Theme) => void;
	}

	let { strings, locale, theme, name, onlocale, ontheme }: Props = $props();

	let open = $state(false);
	let active = $state('bio');
	const chapterIds = ['bio', 'work', 'projects', 'chess', 'contact'];

	const links = $derived([
		{ href: '#bio', label: strings.nav.bio },
		{ href: '#work', label: strings.nav.work },
		{ href: '#projects', label: strings.nav.projects },
		{ href: '#chess', label: strings.nav.chess },
		{ href: '#contact', label: strings.nav.contact }
	]);

	const themeLabel = $derived(theme === 'dark' ? strings.nav.themeLight : strings.nav.themeDark);

	function close(restoreFocus = false) {
		open = false;
		if (restoreFocus) {
			requestAnimationFrame(() =>
				document.querySelector<HTMLButtonElement>('[aria-controls="nav-panel"]')?.focus()
			);
		}
	}

	function toggle() {
		open = !open;
	}

	function onkeydown(event: KeyboardEvent) {
		if (!open) return;
		if (event.key === 'Escape') {
			close(true);
			return;
		}
		const panel = document.getElementById('nav-panel');
		if (event.key !== 'Tab' || !panel) return;
		const focusable = [...panel.querySelectorAll<HTMLElement>('a[href], button:not([disabled])')];
		const first = focusable.at(0);
		const last = focusable.at(-1);
		if (event.shiftKey && document.activeElement === first) {
			event.preventDefault();
			last?.focus();
		} else if (!event.shiftKey && document.activeElement === last) {
			event.preventDefault();
			first?.focus();
		}
	}

	function setActive(id: string) {
		active = id;
	}

	function mobileMenu(isOpen: boolean): Attachment<HTMLElement> {
		return (element) => {
			if (!isOpen) return;
			const prev = document.body.style.overflow;
			const main = document.querySelector<HTMLElement>('.site > main');
			const footer = document.querySelector<HTMLElement>('.site > footer');
			document.body.style.overflow = 'hidden';
			if (main) main.inert = true;
			if (footer) footer.inert = true;
			const raf = requestAnimationFrame(() => element.querySelector<HTMLElement>('a[href]')?.focus());
			return () => {
				cancelAnimationFrame(raf);
				document.body.style.overflow = prev;
				if (main) main.inert = false;
				if (footer) footer.inert = false;
			};
		};
	}
</script>

<svelte:window {onkeydown} />

<nav
	class="nav"
	aria-label={strings.nav.index}
	{@attach navigationProgress(chapterIds, setActive)}
>
	<div class="reading-progress" aria-hidden="true"><span></span></div>
	<a class="brand" href="#bio">{name}</a>

	<div class="links">
		{#each links as link (link.href)}
			<a href={link.href} aria-current={active === link.href.slice(1) ? 'location' : undefined}>
				{link.label}
			</a>
		{/each}
	</div>

	<div class="tools">
		<div class="langs" role="group" aria-label={strings.nav.langIt + ' / ' + strings.nav.langEn}>
			<button
				type="button"
				class={['lang', { on: locale === 'it' }]}
				aria-pressed={locale === 'it'}
				onclick={() => onlocale('it')}
			>
				{strings.nav.langIt}
			</button>
			<button
				type="button"
				class={['lang', { on: locale === 'en' }]}
				aria-pressed={locale === 'en'}
				onclick={() => onlocale('en')}
			>
				{strings.nav.langEn}
			</button>
		</div>
		<button class="tool" type="button" onclick={() => ontheme(theme === 'dark' ? 'light' : 'dark')}>
			{themeLabel}
		</button>
		<button
			class="burger"
			type="button"
			aria-expanded={open}
			aria-controls="nav-panel"
			aria-label={open ? strings.nav.close : strings.nav.menu}
			onclick={toggle}
		>
			<span class={['bars', { open }]} aria-hidden="true"></span>
		</button>
	</div>
</nav>

<div
	id="nav-panel"
	class="panel"
	role="dialog"
	aria-modal="true"
	aria-label={strings.nav.index}
	hidden={!open}
	{@attach mobileMenu(open)}
>
	{#each links as link (link.href)}
		<a href={link.href} aria-current={active === link.href.slice(1) ? 'location' : undefined} onclick={() => close()}>
			<span>{link.label}</span>
			<small>{link.href.slice(1).padStart(2, '0')}</small>
		</a>
	{/each}
</div>

<style>
	.nav {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		z-index: 40;
		display: grid;
		grid-template-columns: auto 1fr auto;
		align-items: center;
		height: var(--nav-h);
		padding: 0 var(--gutter);
		border-bottom: 1px solid var(--line);
		background: var(--paper);
		backdrop-filter: none;
		--page-progress: 0;
	}

	.reading-progress {
		position: absolute;
		right: 0;
		bottom: -1px;
		left: 0;
		height: 2px;
		overflow: hidden;
	}

	.reading-progress span {
		display: block;
		width: 100%;
		height: 100%;
		background: var(--ink-1);
		transform: scaleX(var(--page-progress));
		transform-origin: left;
		will-change: transform;
	}

	.brand {
		font-weight: 500;
		letter-spacing: -0.02em;
		text-decoration: none;
		white-space: nowrap;
	}

	.links {
		display: none;
		justify-content: center;
		gap: var(--space-4);
		font-family: var(--font-mono);
		font-size: 0.72rem;
		letter-spacing: 0.12em;
		text-transform: uppercase;
	}

	.links a {
		text-decoration: none;
		color: var(--ink-2);
		min-height: 44px;
		display: inline-flex;
		align-items: center;
	}

	.links a:hover {
		color: var(--ink-1);
	}

	.links a[aria-current='location'] {
		color: var(--ink-1);
	}

	.links a[aria-current='location']::before {
		content: '•';
		margin-right: var(--space-1);
	}

	.tools {
		display: flex;
		align-items: center;
		justify-content: flex-end;
		gap: var(--space-1);
	}

	.langs {
		display: flex;
	}

	.lang,
	.tool,
	.burger {
		min-width: 44px;
		min-height: 44px;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		font-family: var(--font-mono);
		font-size: 0.68rem;
		letter-spacing: 0.12em;
		text-transform: uppercase;
		color: var(--ink-3);
		text-decoration: none;
	}

	.lang.on,
	.tool:hover,
	.lang:hover {
		color: var(--ink-1);
	}

	.burger {
		position: relative;
	}

	.bars,
	.bars::before,
	.bars::after {
		display: block;
		width: 16px;
		height: 1px;
		background: var(--ink-1);
	}

	.bars::before,
	.bars::after {
		content: '';
		position: relative;
	}

	.bars::before {
		top: -5px;
	}

	.bars::after {
		top: 4px;
	}

	.bars.open {
		background: transparent;
	}

	.bars.open::before {
		top: 0;
		transform: rotate(45deg);
	}

	.bars.open::after {
		top: -1px;
		transform: rotate(-45deg);
	}

	.panel {
		position: fixed;
		top: var(--nav-h);
		left: 0;
		right: 0;
		bottom: 0;
		z-index: 39;
		display: flex;
		flex-direction: column;
		padding: var(--space-5) var(--gutter);
		background: var(--paper);
		border-top: 1px solid var(--line);
	}

	.panel[hidden] {
		display: none;
	}

	.panel a {
		display: flex;
		align-items: center;
		min-height: 44px;
		font-family: var(--font-mono);
		font-size: 0.82rem;
		letter-spacing: 0.14em;
		text-transform: uppercase;
		text-decoration: none;
		border-bottom: 1px solid var(--line);
		color: var(--ink-1);
		justify-content: space-between;
		font-size: clamp(1.35rem, 7vw, 2.5rem);
		letter-spacing: -0.02em;
	}

	.panel a small {
		font-size: 0.62rem;
		letter-spacing: 0.12em;
		color: var(--ink-4);
	}

	@media (min-width: 1100px) {
		.links {
			display: flex;
		}

		.burger,
		.panel {
			display: none;
		}
	}
</style>
