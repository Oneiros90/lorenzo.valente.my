<script lang="ts">
  import WorkProjectCard from '$lib/components/WorkProjectCard.svelte';
  import type { CompanyConfig } from '$lib/webgl/types';
  import { colorToHex, loc, t, type Locale, type LocaleData } from '$lib/i18n';

  interface Props {
    open: boolean;
    companyIndex: number;
    strings: LocaleData;
    companies: CompanyConfig[];
    onclose: () => void;
  }

  let { open, companyIndex, strings, companies, onclose }: Props = $props();
  const p = $derived(strings.panels.company);
  const locale = $derived(strings.meta.lang as Locale);
  const company = $derived(companies[companyIndex]);
  const durationLabel = $derived(company && company.years === 1 ? p.year : p.years);
</script>

{#if company}
  <div class="panel panel--center" class:open>
    <button class="close" onclick={onclose}>{strings.panels.close}</button>
    <h2>{company.name}</h2>
    <div class="sub">{t(p.subtitle, { id: companyIndex + 1 })}</div>
    <div class="company-colors">
      <i style="background:{colorToHex(company.colorA)};color:{colorToHex(company.colorA)}"></i>
      <i style="background:{colorToHex(company.colorB)};color:{colorToHex(company.colorB)}"></i>
    </div>
    <div class="row"><span class="k">{p.role}</span><span class="v">{loc(company.role, locale)}</span></div>
    <div class="row"><span class="k">{p.period}</span><span class="v">{loc(company.period, locale)}</span></div>
    <div class="row">
      <span class="k">{p.duration}</span>
      <span class="v">{company.years} {durationLabel}</span>
    </div>
    <p>{loc(company.description, locale)}</p>
    {#if company.projects.length}
      <h3 class="work-heading">{p.projects}</h3>
      <div class="project-list">
        {#each company.projects as project (project.id)}
          <WorkProjectCard
            name={loc(project.name, locale)}
            url={project.url}
            description={loc(project.description, locale)}
            imageUrl={project.imageUrl}
            noDescription={strings.panels.projects.noDescription}
          />
        {/each}
      </div>
    {/if}
    <div class="note">{p.note}</div>
  </div>
{/if}
