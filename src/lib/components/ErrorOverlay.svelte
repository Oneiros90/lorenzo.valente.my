<script lang="ts">
  interface Props {
    message: string;
    detail?: string;
  }

  let { message, detail }: Props = $props();
</script>

<div class="error-overlay">
  {message}
  {#if detail}
    <br /><small>{detail}</small>
  {/if}
</div>
