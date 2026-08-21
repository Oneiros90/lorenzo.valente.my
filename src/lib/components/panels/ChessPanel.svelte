<script lang="ts">
  import type { ChessConfig, ChessTimeControl } from '$lib/webgl/types';
  import type { LocaleData } from '$lib/i18n';
  import { displayUrl, formatMonthYear } from '$lib/format';
  import ChessSpark from '$lib/components/ChessSpark.svelte';
  import ProfileHero from '$lib/components/ProfileHero.svelte';

  interface Props {
    open: boolean;
    strings: LocaleData;
    chess: ChessConfig;
    error?: boolean;
    onclose: () => void;
  }

  let { open, strings, chess, error = false, onclose }: Props = $props();
  const p = $derived(strings.panels.chess);
  const localeTag = $derived(strings.meta.lang === 'it' ? 'it-IT' : 'en-US');
  const resultLabel = $derived(
    chess.lastGameResult === 'win'
      ? p.win
      : chess.lastGameResult === 'draw'
        ? p.draw
        : chess.lastGameResult === 'loss'
          ? p.loss
          : ''
  );
  const lastGame = $derived(
    resultLabel && chess.lastGameOpening
      ? `${resultLabel} · ${chess.lastGameOpening}`
      : resultLabel || chess.lastGameOpening
  );
  const hasStats = $derived(
    chess.timeControls.some((tc) => tc.rating != null) || chess.lastGameResult != null
  );
  const displayName = $derived(chess.name || chess.username || '—');
  const chips = $derived(
    [chess.premium ? p.premium : '', chess.league, chess.location].filter(
      (chip): chip is string => Boolean(chip)
    )
  );
  const meta = $derived([
    { label: p.followers, value: elo(chess.followers) },
    { label: p.joined, value: formatJoined(chess.joined) }
  ]);
  const noteHref = $derived(chess.url);
  const noteHost = $derived(noteHref ? displayUrl(noteHref) : '');

  function elo(value: number | null): string {
    return value == null ? '—' : String(value);
  }

  function gamesPlayed(tc: ChessTimeControl): number {
    return tc.wins + tc.losses + tc.draws;
  }

  function winRate(tc: ChessTimeControl): number {
    const total = gamesPlayed(tc);
    return total ? Math.round((tc.wins / total) * 100) : 0;
  }

  function titleFor(id: ChessTimeControl['id']): string {
    return p[id];
  }

  function formatJoined(ts: number | null): string {
    if (ts == null) return '—';
    return formatMonthYear(new Date(ts * 1000), localeTag);
  }
</script>

<div class="panel panel--chess" class:open>
  <button class="close" onclick={onclose}>{strings.panels.close}</button>
  <h2>{p.title}</h2>
  <div class="sub">{p.subtitle}</div>
  {#if error}
    <div class="panel-status">{p.error}</div>
  {:else if !hasStats}
    <div class="panel-status">{p.empty}</div>
  {:else}
    <ProfileHero
      name={displayName}
      username={chess.username}
      avatar={chess.avatar}
      url={chess.url}
      {chips}
      {meta}
    />

    <div class="time-list">
      {#each chess.timeControls as tc (tc.id)}
        {@const total = gamesPlayed(tc)}
        {@const wr = winRate(tc)}
        <article class="time-card" class:rapid={tc.id === 'rapid'} class:blitz={tc.id === 'blitz'} class:bullet={tc.id === 'bullet'}>
          <div class="time-card__head">
            <span class="time-card__label">{titleFor(tc.id)}</span>
            <b>{elo(tc.rating)}</b>
          </div>
          <ChessSpark values={tc.spark} colorId={tc.id} />
          <div class="time-card__meta">
            <span>{p.best} <b>{elo(tc.best)}</b></span>
            <span>{p.games} <b>{total}</b></span>
            <span>{p.winRate} <b>{wr}%</b></span>
          </div>
          <div class="wr" title={`${tc.wins}/${tc.losses}/${tc.draws}`}>
            <i style:width={`${wr}%`}></i>
          </div>
          <div class="time-card__record">
            {tc.wins}W · {tc.losses}L · {tc.draws}D
          </div>
        </article>
      {/each}
    </div>

    <div class="row">
      <span class="k">{p.lastGame}</span>
      <span class="v status-active">
        {#if chess.lastGameUrl && lastGame}
          <a href={chess.lastGameUrl} target="_blank" rel="noopener">{lastGame}</a>
        {:else}
          {lastGame || '—'}
        {/if}
      </span>
    </div>
  {/if}
  <div class="note">
    {p.note}{#if noteHref && noteHost}
      · <a href={noteHref} target="_blank" rel="noopener">{noteHost}</a>
    {/if}
  </div>
</div>
