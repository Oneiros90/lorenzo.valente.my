<script lang="ts">
  import type { LocaleData } from '$lib/i18n';

  interface Props {
    strings: LocaleData;
    clock: string;
    hidden?: boolean;
  }

  let { strings, clock, hidden = false }: Props = $props();
</script>

<div class="hud-top">
  <div class="hud hud--tl" class:hud--hidden={hidden}>
    <b>{strings.hud.title}</b>
    <span>{strings.hud.subtitle}</span>
  </div>
  <div class="hud hud--tr" class:hud--hidden={hidden}>
    <span>{strings.hud.coords}</span>
    <span>{clock}</span>
  </div>
</div>
<div class="hud hud--br" class:hud--hidden={hidden}>{strings.hud.atmosphere}</div>
