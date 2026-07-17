<script lang="ts">
  import type { ProjectConfig } from '$lib/webgl/types';
  import type { LocaleData } from '$lib/i18n';

  interface Props {
    open: boolean;
    strings: LocaleData;
    projects: ProjectConfig[];
    onclose: () => void;
  }

  let { open, strings, projects, onclose }: Props = $props();
  const p = $derived(strings.panels.projects);
  let idx = $state(0);

  function go(i: number) {
    idx = (i + projects.length) % projects.length;
  }

  $effect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'ArrowLeft') go(idx - 1);
      if (e.key === 'ArrowRight') go(idx + 1);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });
</script>

<div class="panel panel--center" class:open>
  <button class="close" onclick={onclose}>{strings.panels.close}</button>
  <h2>{p.title}</h2>
  <div class="sub">{p.subtitle}</div>
  <div class="carousel">
    {#each projects as project, i (project.id)}
      {@const copy = strings.projects[project.id as keyof typeof strings.projects]}
      <div class="slide" class:on={i === idx}>
        <h3>
          <a href={project.url} target="_blank" rel="noopener">◈ {copy.name}</a>
        </h3>
        <div class="desc">{copy.description}</div>
        <div class="meta">
          <span>{p.stars} <b>{project.stars}</b></span>
          <span>{p.lang} <b>{project.lang}</b></span>
        </div>
        <div class="tags">
          {#each project.tags as tag}
            <span>{tag}</span>
          {/each}
        </div>
      </div>
    {/each}
  </div>
  <div class="car-nav">
    <button aria-label={p.prev} onclick={() => go(idx - 1)}>‹</button>
    <div class="dots">
      {#each projects as _, i}
        <button type="button" class:on={i === idx} onclick={() => go(i)} aria-label={`${i + 1}`}></button>
      {/each}
    </div>
    <button aria-label={p.next} onclick={() => go(idx + 1)}>›</button>
  </div>
  <div class="note">{p.note}</div>
</div>
