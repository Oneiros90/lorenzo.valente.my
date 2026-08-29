<script lang="ts">
	import type { Attachment } from 'svelte/attachments';
	import profile from '$lib/config/profile.json';
	import socials from '$lib/config/socials.json';
	import { EMPTY_CHESS, fetchChessStats } from '$lib/chess';
	import { EMPTY_GITHUB_PROFILE, fetchGithubProjects } from '$lib/github';
	import { getDefaultLocale, getSiteStrings, loc, type Locale } from '$lib/i18n';
	import type { ChessConfig, GithubProfile, ProjectConfig } from '$lib/webgl/types';
	import { applyTheme, getInitialTheme, type Theme } from './lib/theme';
	import Chess from './components/Chess.svelte';
	import Contact from './components/Contact.svelte';
	import Footer from './components/Footer.svelte';
	import Hero from './components/Hero.svelte';
	import Nav from './components/Nav.svelte';
	import Projects from './components/Projects.svelte';
	import Work from './components/Work.svelte';

	let locale = $state<Locale>(getDefaultLocale());
	let theme = $state<Theme>(getInitialTheme());
	const strings = $derived(getSiteStrings(locale));
	const year = new Date().getFullYear();

	let githubProfile = $state.raw<GithubProfile>(EMPTY_GITHUB_PROFILE);
	let projects = $state.raw<ProjectConfig[]>([]);
	let githubError = $state(false);
	let chess = $state.raw<ChessConfig>(EMPTY_CHESS);
	let chessError = $state(false);

	function documentSettings(nextTheme: Theme, nextLocale: Locale, title: string): Attachment<HTMLElement> {
		return () => {
			applyTheme(nextTheme);
			document.documentElement.lang = nextLocale;
			document.title = title;
		};
	}

	const loadData: Attachment<HTMLElement> = () => {
		const ac = new AbortController();
		void fetchGithubProjects(ac.signal)
			.then((payload) => {
				githubProfile = payload.profile;
				projects = payload.projects;
				githubError = false;
			})
			.catch(() => {
				githubError = true;
			});
		void fetchChessStats(ac.signal)
			.then((data) => {
				chess = data;
				chessError = false;
			})
			.catch(() => {
				chessError = true;
			});
		return () => ac.abort();
	};

	function onlocale(next: Locale) {
		locale = next;
		const url = new URL(location.href);
		url.searchParams.set('lang', next);
		history.replaceState({}, '', url);
	}

	function ontheme(next: Theme) {
		theme = next;
	}
</script>

<svelte:head>
	<title>{strings.meta.title}</title>
	<meta name="description" content={strings.meta.description} />
</svelte:head>

<div class="grain" aria-hidden="true"></div>

<div
	class="site"
	{@attach documentSettings(theme, locale, strings.meta.title)}
	{@attach loadData}
>
	<a class="skip-link" href="#main-content">{strings.nav.skip}</a>
	<Nav {strings} {locale} {theme} name={profile.bio.name} {onlocale} {ontheme} />
	<main id="main-content" tabindex="-1">
		<Hero
			{strings}
			name={profile.bio.name}
			role={loc(profile.bio.specialization, locale)}
			description={loc(profile.bio.description, locale)}
			cvUrl={profile.cvUrl}
			born={loc(profile.bio.born, locale)}
			place={loc(profile.bio.place, locale)}
			workplace={loc(profile.bio.workplace, locale)}
			{theme}
		/>
		<Work {strings} companies={profile.companies} {locale} />
		<Projects {strings} profile={githubProfile} {projects} error={githubError} {locale} />
		<Chess {strings} {chess} error={chessError} />
		<Contact {strings} {socials} />
	</main>
	<Footer {strings} {year} />
</div>
