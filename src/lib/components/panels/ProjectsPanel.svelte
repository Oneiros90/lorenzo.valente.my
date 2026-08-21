<script lang="ts">
  import type { ProjectConfig } from '$lib/webgl/types';
  import type { LocaleData } from '$lib/i18n';
  import ProjectIcon from '$lib/components/ProjectIcon.svelte';

  interface Props {
    open: boolean;
    strings: LocaleData;
    projects: ProjectConfig[];
    error?: boolean;
    onclose: () => void;
  }

  let { open, strings, projects, error = false, onclose }: Props = $props();
  const p = $derived(strings.panels.projects);
</script>

<div class="panel panel--center" class:open>
  <button class="close" onclick={onclose}>{strings.panels.close}</button>
  <h2>{p.title}</h2>
  <div class="sub">{p.subtitle}</div>
  {#if error}
    <div class="panel-status">{p.error}</div>
  {:else if projects.length === 0}
    <div class="panel-status">{p.empty}</div>
  {:else}
    <div class="project-list">
      {#each projects as project (project.id)}
        <article class="project-card">
          <ProjectIcon src={project.imageUrl} name={project.name} />
          <div class="project-body">
            <h3>
              <a href={project.url} target="_blank" rel="noopener">◈ {project.name}</a>
            </h3>
            <div class="desc">{project.description || p.noDescription}</div>
            <div class="meta">
              <span>{p.stars} <b>{project.stars}</b></span>
              <span>{p.lang} <b>{project.lang}</b></span>
            </div>
            {#if project.tags.length}
              <div class="tags">
                {#each project.tags as tag (tag)}
                  <span>{tag}</span>
                {/each}
              </div>
            {/if}
          </div>
        </article>
      {/each}
    </div>
  {/if}
  <div class="note">{p.note}</div>
</div>
