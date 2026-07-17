<script lang="ts">
  import type { BioConfig } from '$lib/webgl/types';
  import { t, type LocaleData } from '$lib/i18n';

  interface Props {
    open: boolean;
    strings: LocaleData;
    bio: BioConfig;
    onclose: () => void;
  }

  let { open, strings, bio, onclose }: Props = $props();
  const p = $derived(strings.panels.bio);
</script>

<div class="panel panel--bio" class:open>
  <button class="close" onclick={onclose}>{strings.panels.close}</button>
  <h2>{p.title}</h2>
  <div class="sub">{t(p.subtitle, { id: bio.archiveId })}</div>
  <div class="row"><span class="k">{p.name}</span><span class="v">{strings.bio.name}</span></div>
  <div class="row"><span class="k">{p.specialization}</span><span class="v">{strings.bio.specialization}</span></div>
  <div class="row"><span class="k">{p.base}</span><span class="v">{strings.bio.base}</span></div>
  <div class="row">
    <span class="k">{p.status}</span>
    <span class="v status-active">{p.statusActive}</span>
  </div>
  <p>{strings.bio.description}</p>
  <div class="note">{p.note}</div>
</div>
