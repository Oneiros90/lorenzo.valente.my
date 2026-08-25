<script lang="ts">
  import type { BioConfig } from '$lib/webgl/types';
  import { loc, t, type Locale, type LocaleData } from '$lib/i18n';

  interface Props {
    open: boolean;
    strings: LocaleData;
    bio: BioConfig;
    cvUrl: string;
    onclose: () => void;
  }

  let { open, strings, bio, cvUrl, onclose }: Props = $props();
  const p = $derived(strings.panels.bio);
  const locale = $derived(strings.meta.lang as Locale);
</script>

<div class="panel panel--bio" class:open>
  <button class="close" onclick={onclose}>{strings.panels.close}</button>
  <h2>{p.title}</h2>
  <div class="sub">{t(p.subtitle, { id: bio.archiveId })}</div>
  <div class="row"><span class="k">{p.name}</span><span class="v">{bio.name}</span></div>
  <div class="row"><span class="k">{p.specialization}</span><span class="v">{loc(bio.specialization, locale)}</span></div>
  <div class="row"><span class="k">{p.base}</span><span class="v">{strings.bio.base}</span></div>
  <div class="row">
    <span class="k">{p.status}</span>
    <span class="v status-active">{p.statusActive}</span>
  </div>
  <p>{loc(bio.description, locale)}</p>
  <a class="cv-link" href={cvUrl} target="_blank" rel="noopener">{p.downloadCv}</a>
  <div class="note">{p.note}</div>
</div>
