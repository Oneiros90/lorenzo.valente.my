<script lang="ts">
  import type { CompanyConfig } from '$lib/webgl/types';
  import { colorToHex, t, type LocaleData } from '$lib/i18n';

  interface Props {
    open: boolean;
    companyIndex: number;
    strings: LocaleData;
    companies: CompanyConfig[];
    onclose: () => void;
  }

  let { open, companyIndex, strings, companies, onclose }: Props = $props();
  const p = $derived(strings.panels.company);
  const company = $derived(companies[companyIndex]);
  const durationLabel = $derived(
    company && company.years === 1 ? p.year : p.years
  );
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
    <div class="row"><span class="k">{p.role}</span><span class="v">{company.role}</span></div>
    <div class="row"><span class="k">{p.period}</span><span class="v">{company.period}</span></div>
    <div class="row">
      <span class="k">{p.duration}</span>
      <span class="v">{company.years} {durationLabel}</span>
    </div>
    <p>{company.description}</p>
    <div class="note">{p.note}</div>
  </div>
{/if}
