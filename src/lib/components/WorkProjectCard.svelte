<script lang="ts">
  import ProjectIcon from '$lib/components/ProjectIcon.svelte';

  interface Props {
    name: string;
    url: string;
    description: string;
    imageUrl: string | null;
    noDescription: string;
    stars?: number;
    lang?: string;
    tags?: string[];
    starsLabel?: string;
    langLabel?: string;
  }

  let {
    name,
    url,
    description,
    imageUrl,
    noDescription,
    stars,
    lang,
    tags = [],
    starsLabel,
    langLabel
  }: Props = $props();

  const showMeta = $derived(stars != null || lang);
</script>

<article class="project-card">
  {#key imageUrl}
    <ProjectIcon src={imageUrl} {name} />
  {/key}
  <div class="project-body">
    <h3>
      <a href={url} target="_blank" rel="noopener">◈ {name}</a>
    </h3>
    <div class="desc">{description || noDescription}</div>
    {#if showMeta}
      <div class="meta">
        {#if stars != null && starsLabel}
          <span>{starsLabel} <b>{stars}</b></span>
        {/if}
        {#if lang && langLabel}
          <span>{langLabel} <b>{lang}</b></span>
        {/if}
      </div>
    {/if}
    {#if tags.length}
      <div class="tags">
        {#each tags as tag (tag)}
          <span>{tag}</span>
        {/each}
      </div>
    {/if}
  </div>
</article>
