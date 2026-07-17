<script lang="ts">
  import type { LocaleData } from '$lib/i18n';

  interface Props {
    strings: LocaleData;
    clock: string;
    hidden?: boolean;
  }

  let { strings, clock, hidden = false }: Props = $props();
</script>

<div class="hud hud--tl" class:hud--hidden={hidden}>
  <b>{strings.hud.title}</b>{strings.hud.subtitle}
</div>
<div class="hud hud--tr" class:hud--hidden={hidden}>
  {strings.hud.coords}<br /><span>{clock}</span>
</div>
<div class="hud hud--bl" class:hud--hidden={hidden}>
  {strings.hud.interact}&nbsp;→&nbsp;
  <span>[ {strings.hud.tablet} ]</span> ·
  <span>[ {strings.hud.chess} ]</span> ·
  <span>[ {strings.hud.octopus} ]</span> ·
  <span>[ {strings.hud.orbs} ]</span>
</div>
<div class="hud hud--br" class:hud--hidden={hidden}>{strings.hud.atmosphere}</div>
