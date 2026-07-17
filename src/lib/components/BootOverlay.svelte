<script lang="ts">
  import type { LocaleData } from '$lib/i18n';

  interface Props {
    strings: LocaleData;
    done: boolean;
  }

  let { strings, done }: Props = $props();
</script>

<div class="boot" class:done>
  <div>{strings.boot.message}</div>
  <div class="boot__bar"><i></i></div>
</div>
