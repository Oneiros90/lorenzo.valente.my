<script lang="ts">
  import { sparkPaths } from '$lib/chess';

  interface Props {
    values: number[];
    colorId: string;
  }

  let { values, colorId }: Props = $props();
  const paths = $derived(sparkPaths(values));
  const gid = $derived(`spark-${colorId}`);
</script>

{#if paths.line}
  <svg class="spark" viewBox="0 0 300 56" preserveAspectRatio="none">
    <defs>
      <linearGradient id={gid} x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="currentColor" stop-opacity=".45" />
        <stop offset="1" stop-color="currentColor" stop-opacity="0" />
      </linearGradient>
    </defs>
    <path d={paths.line} fill="none" stroke="currentColor" stroke-width="2" />
    <path d={paths.area} fill={`url(#${gid})`} stroke="none" />
  </svg>
{/if}
