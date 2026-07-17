<script lang="ts">
  import type { ChessConfig } from '$lib/webgl/types';
  import type { LocaleData } from '$lib/i18n';

  interface Props {
    open: boolean;
    strings: LocaleData;
    chess: ChessConfig;
    onclose: () => void;
  }

  let { open, strings, chess, onclose }: Props = $props();
  const p = $derived(strings.panels.chess);
  const lastGame = $derived(
    strings.chess.lastGames[chess.lastGame as keyof typeof strings.chess.lastGames] ?? chess.lastGame
  );
</script>

<div class="panel panel--chess" class:open>
  <button class="close" onclick={onclose}>{strings.panels.close}</button>
  <h2>{p.title}</h2>
  <div class="sub">{p.subtitle}</div>
  <div class="elo"><b>{chess.rapid}</b><span>{p.eloRapid}</span></div>
  <svg class="spark" viewBox="0 0 300 56" preserveAspectRatio="none">
    <defs>
      <linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#38bdf8" stop-opacity=".5" />
        <stop offset="1" stop-color="#38bdf8" stop-opacity="0" />
      </linearGradient>
    </defs>
    <path
      d="M0,44 L25,40 L50,42 L75,34 L100,37 L125,28 L150,31 L175,22 L200,26 L225,18 L250,21 L275,12 L300,8"
      fill="none"
      stroke="#38bdf8"
      stroke-width="2"
      style="filter:drop-shadow(0 0 4px #38bdf8)"
    />
    <path
      d="M0,44 L25,40 L50,42 L75,34 L100,37 L125,28 L150,31 L175,22 L200,26 L225,18 L250,21 L275,12 L300,8 L300,56 L0,56 Z"
      fill="url(#g)"
      stroke="none"
    />
  </svg>
  <div class="row"><span class="k">{p.blitz}</span><span class="v">{chess.blitz}</span></div>
  <div class="row"><span class="k">{p.bullet}</span><span class="v">{chess.bullet}</span></div>
  <div class="row">
    <span class="k">{p.lastGame}</span>
    <span class="v status-active">{lastGame}</span>
  </div>
  <div class="note">{p.note}</div>
</div>
