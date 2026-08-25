<script lang="ts">
  import type { GithubProfile, ProjectConfig } from '$lib/webgl/types';
  import type { LocaleData } from '$lib/i18n';
  import { displayUrl, formatMonthYear } from '$lib/format';
  import ProfileHero from '$lib/components/ProfileHero.svelte';
  import WorkProjectCard from '$lib/components/WorkProjectCard.svelte';

  interface Props {
    open: boolean;
    strings: LocaleData;
    profile: GithubProfile;
    projects: ProjectConfig[];
    error?: boolean;
    onclose: () => void;
  }

  let { open, strings, profile, projects, error = false, onclose }: Props = $props();
  const p = $derived(strings.panels.projects);
  const localeTag = $derived(strings.meta.lang === 'it' ? 'it-IT' : 'en-US');
  const displayName = $derived(profile.name || profile.username || '—');
  const chips = $derived(
    [
      profile.company,
      profile.location,
      profile.publicRepos != null ? `${profile.publicRepos} ${p.repos}` : ''
    ].filter((chip): chip is string => Boolean(chip))
  );
  const meta = $derived([
    { label: p.followers, value: profile.followers == null ? '—' : String(profile.followers) },
    { label: p.joined, value: formatJoined(profile.joined) }
  ]);
  const noteHref = $derived(profile.url);
  const noteHost = $derived(noteHref ? displayUrl(noteHref) : '');
  const hasProfile = $derived(Boolean(profile.username || profile.name));

  function formatJoined(iso: string | null): string {
    if (!iso) return '—';
    const date = new Date(iso);
    return Number.isNaN(date.getTime()) ? '—' : formatMonthYear(date, localeTag);
  }
</script>

<div class="panel panel--center" class:open>
  <button class="close" onclick={onclose}>{strings.panels.close}</button>
  <h2>{p.title}</h2>
  <div class="sub">{p.subtitle}</div>
  {#if error}
    <div class="panel-status">{p.error}</div>
  {:else}
    {#if hasProfile}
      <ProfileHero
        name={displayName}
        username={profile.username}
        avatar={profile.avatar}
        url={profile.url}
        {chips}
        {meta}
      />
    {/if}
    {#if projects.length === 0}
      <div class="panel-status">{p.empty}</div>
    {:else}
      <div class="project-list">
        {#each projects as project (project.id)}
          <WorkProjectCard
            name={project.name}
            url={project.url}
            description={project.description}
            imageUrl={project.imageUrl}
            noDescription={p.noDescription}
            stars={project.stars}
            lang={project.lang}
            tags={project.tags}
            starsLabel={p.stars}
            langLabel={p.lang}
          />
        {/each}
      </div>
    {/if}
  {/if}
  <div class="note">
    {p.note}{#if noteHref && noteHost}
      · <a href={noteHref} target="_blank" rel="noopener">{noteHost}</a>
    {/if}
  </div>
</div>
