<script lang="ts">
  interface MetaItem {
    label: string;
    value: string;
  }

  interface Props {
    name: string;
    username: string;
    avatar: string | null;
    url: string;
    chips?: string[];
    meta?: MetaItem[];
  }

  let { name, username, avatar, url, chips = [], meta = [] }: Props = $props();
  const displayName = $derived(name || username || '—');
</script>

<div class="profile-hero">
  <a class="profile-avatar" href={url || undefined} target="_blank" rel="noopener">
    {#if avatar}
      <img src={avatar} alt={displayName} referrerpolicy="no-referrer" />
    {/if}
  </a>
  <div class="profile-identity">
    <a class="profile-name" href={url || undefined} target="_blank" rel="noopener">{displayName}</a>
    {#if username}
      <a class="profile-handle" href={url || undefined} target="_blank" rel="noopener">@{username}</a>
    {/if}
    {#if chips.length}
      <div class="profile-chips">
        {#each chips as chip (chip)}
          <span>{chip}</span>
        {/each}
      </div>
    {/if}
  </div>
  {#if meta.length}
    <div class="profile-aside">
      {#each meta as item (item.label)}
        <div>
          <span>{item.label}</span>
          <b>{item.value}</b>
        </div>
      {/each}
    </div>
  {/if}
</div>
