<script lang="ts">
  import WebGLCanvas from '$lib/components/WebGLCanvas.svelte';
  import BootOverlay from '$lib/components/BootOverlay.svelte';
  import Hud from '$lib/components/Hud.svelte';
  import ErrorOverlay from '$lib/components/ErrorOverlay.svelte';
  import BioPanel from '$lib/components/panels/BioPanel.svelte';
  import ChessPanel from '$lib/components/panels/ChessPanel.svelte';
  import ProjectsPanel from '$lib/components/panels/ProjectsPanel.svelte';
  import CompanyPanel from '$lib/components/panels/CompanyPanel.svelte';
  import companies from '$lib/config/companies.json';
  import bio from '$lib/config/bio.json';
  import scene from '$lib/config/scene.json';
  import socials from '$lib/config/socials.json';
  import { EMPTY_CHESS, fetchChessStats } from '$lib/chess';
  import { EMPTY_GITHUB_PROFILE, fetchGithubProjects } from '$lib/github';
  import { cameraConfig, isDesktopViewport } from '$lib/webgl/camera';
  import { getDefaultLocale, getLocaleData, type Locale, type LocaleData } from '$lib/i18n';
  import { isSocialPick, socialIndexFromPick } from '$lib/webgl/socials';
  import type { GithubProfile, PickId, ProjectConfig } from '$lib/webgl/types';

  let locale: Locale = $state(getDefaultLocale());
  let strings: LocaleData = $derived(getLocaleData(locale));
  let hover: PickId = $state(0);
  let active: PickId = $state(0);
  let projects = $state.raw<ProjectConfig[]>([]);
  let githubProfile = $state.raw<GithubProfile>(EMPTY_GITHUB_PROFILE);
  let projectsError = $state(false);
  let githubReady = $state(false);
  let chess = $state.raw(EMPTY_CHESS);
  let chessError = $state(false);
  let chessReady = $state(false);
  let bootMinElapsed = $state(false);
  let bootDone = $derived(githubReady && chessReady && bootMinElapsed);
  let errorType = $state<'webgl' | 'shader' | null>(null);
  let errorDetail = $state('');
  let clock = $state('');
  let desktop = $state(typeof window !== 'undefined' ? isDesktopViewport() : true);

  const companyIndex = $derived(active >= 4 && active <= 7 ? active - 4 : 0);
  const panelOpen = $derived(active !== 0 && !isSocialPick(active));
  const focusCamera = $derived(panelOpen && desktop);
  const focusMode = $derived(panelOpen && desktop);

  function formatClock() {
    const d = new Date();
    const time = d.toLocaleTimeString(locale === 'it' ? 'it-IT' : 'en-US');
    return `${strings.hud.clockPrefix} ${time} · ${strings.hud.cycle}`;
  }

  function togglePick(id: PickId) {
    if (id === 0) {
      active = 0;
      return;
    }
    active = active === id ? 0 : id;
  }

  function onPick(id: PickId) {
    if (isSocialPick(id)) {
      const url = socials[socialIndexFromPick(id)]?.url;
      if (url) window.open(url, '_blank', 'noopener,noreferrer');
      return;
    }
    togglePick(id);
  }

  function onClose() {
    active = 0;
  }

  function onError(type: 'webgl' | 'shader', detail?: string) {
    errorType = type;
    errorDetail = detail ?? '';
  }

  $effect(() => {
    document.documentElement.lang = strings.meta.lang;
    document.title = strings.meta.title;
  });

  $effect(() => {
    document.body.classList.toggle('focus-mode', focusMode);
    document.body.classList.toggle('panel-open', panelOpen);
    return () => {
      document.body.classList.remove('focus-mode', 'panel-open');
    };
  });

  $effect(() => {
    clock = formatClock();
    const id = window.setInterval(() => {
      clock = formatClock();
    }, scene.clockIntervalMs);
    return () => clearInterval(id);
  });

  $effect(() => {
    const ac = new AbortController();
    let cancelled = false;
    const minTimer = window.setTimeout(() => {
      if (!cancelled) bootMinElapsed = true;
    }, scene.bootDurationMs);

    Promise.allSettled([
      fetchGithubProjects(ac.signal).then((payload) => {
        if (!cancelled) {
          githubProfile = payload.profile;
          projects = payload.projects;
        }
      }),
      fetchChessStats(ac.signal).then((data) => {
        if (!cancelled) chess = data;
      })
    ]).then((results) => {
      if (cancelled) return;
      if (results[0].status === 'rejected') projectsError = true;
      if (results[1].status === 'rejected') chessError = true;
      githubReady = true;
      chessReady = true;
    });

    return () => {
      cancelled = true;
      ac.abort();
      clearTimeout(minTimer);
    };
  });

  $effect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') active = 0;
    };
    const mq = window.matchMedia(`(min-width: ${cameraConfig.desktopBreakpoint + 1}px)`);
    const onMq = () => {
      desktop = mq.matches;
    };
    onMq();
    mq.addEventListener('change', onMq);
    window.addEventListener('keydown', onKey);
    return () => {
      mq.removeEventListener('change', onMq);
      window.removeEventListener('keydown', onKey);
    };
  });
</script>

{#if errorType}
  <ErrorOverlay
    message={errorType === 'shader' ? strings.errors.shader : strings.errors.webgl}
    detail={errorDetail}
  />
{:else}
  <WebGLCanvas
    {companies}
    {socials}
    {scene}
    {strings}
    bind:hover
    {active}
    {focusCamera}
    onpick={onPick}
    onerror={onError}
  />
  <BootOverlay {strings} done={bootDone} />
  <Hud {strings} {clock} hidden={panelOpen} />
  <BioPanel open={active === 1} {strings} {bio} onclose={onClose} />
  <ChessPanel open={active === 2} {strings} {chess} error={chessError} onclose={onClose} />
  <ProjectsPanel
    open={active === 3}
    {strings}
    profile={githubProfile}
    {projects}
    error={projectsError}
    onclose={onClose}
  />
  <CompanyPanel
    open={active >= 4 && active <= 7}
    {companyIndex}
    {strings}
    {companies}
    onclose={onClose}
  />
{/if}
