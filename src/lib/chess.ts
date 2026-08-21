import chessConfig from '$lib/config/chess.json';
import type { ChessConfig, ChessResult, ChessTimeClassId, ChessTimeControl } from '$lib/webgl/types';

const FETCH_TIMEOUT_MS = 8000;
const USER = chessConfig.username;
const PROFILE_URL = `https://api.chess.com/pub/player/${USER}`;
const STATS_URL = `https://api.chess.com/pub/player/${USER}/stats`;
const ARCHIVES_URL = `https://api.chess.com/pub/player/${USER}/games/archives`;
const SPARK_POINTS = 12;
const DRAW_RESULTS = new Set([
  'draw',
  'stalemate',
  'repetition',
  'agreed',
  'timevsinsufficient',
  'insufficient',
  '50move'
]);

interface ChessStatsBlock {
  last?: { rating?: number };
  best?: { rating?: number };
  record?: { win?: number; loss?: number; draw?: number };
}

interface ChessStats {
  chess_rapid?: ChessStatsBlock;
  chess_blitz?: ChessStatsBlock;
  chess_bullet?: ChessStatsBlock;
}

interface ChessProfile {
  name?: string;
  username?: string;
  avatar?: string;
  url?: string;
  location?: string;
  league?: string;
  followers?: number;
  joined?: number;
  status?: string;
}

interface ChessPlayer {
  username: string;
  rating: number;
  result: string;
}

interface ChessGame {
  url: string;
  eco?: string;
  time_class?: string;
  white: ChessPlayer;
  black: ChessPlayer;
}

const TIME_CLASSES: { id: ChessTimeClassId; statsKey: keyof ChessStats }[] = [
  { id: 'rapid', statsKey: 'chess_rapid' },
  { id: 'blitz', statsKey: 'chess_blitz' },
  { id: 'bullet', statsKey: 'chess_bullet' }
];

export const EMPTY_CHESS: ChessConfig = {
  name: '',
  username: USER,
  avatar: null,
  url: `https://www.chess.com/member/${USER}`,
  location: '',
  league: '',
  followers: null,
  joined: null,
  premium: false,
  timeControls: [],
  lastGameResult: null,
  lastGameOpening: '',
  lastGameUrl: null
};

function combineSignals(parent?: AbortSignal): { signal: AbortSignal; cleanup: () => void } {
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), FETCH_TIMEOUT_MS);
  const onAbort = () => ac.abort();
  parent?.addEventListener('abort', onAbort);
  return {
    signal: ac.signal,
    cleanup: () => {
      clearTimeout(timer);
      parent?.removeEventListener('abort', onAbort);
    }
  };
}

function mergeSignals(parent: AbortSignal | undefined, timeoutMs: number): AbortSignal {
  const timeout = AbortSignal.timeout(timeoutMs);
  if (!parent) return timeout;
  if (typeof AbortSignal.any === 'function') return AbortSignal.any([parent, timeout]);
  return timeout;
}

function resultKind(result: string): ChessResult {
  if (result === 'win') return 'win';
  if (DRAW_RESULTS.has(result)) return 'draw';
  return 'loss';
}

function openingName(eco?: string): string {
  if (!eco) return '';
  const slug = eco.split('/').pop() ?? '';
  return slug.split('-').filter(Boolean).slice(0, 2).join(' ');
}

function sideFor(game: ChessGame): ChessPlayer {
  return game.white.username.toLowerCase() === USER.toLowerCase() ? game.white : game.black;
}

function ratingsForClass(games: ChessGame[], timeClass: string): number[] {
  return games.filter((game) => game.time_class === timeClass).map((game) => sideFor(game).rating);
}

export function sparkPaths(values: number[], w = 300, h = 56): { line: string; area: string } {
  if (values.length < 2) return { line: '', area: '' };
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min || 1;
  const padY = 6;
  const innerH = h - padY * 2;
  const pts = values.map((value, i) => {
    const x = (i / (values.length - 1)) * w;
    const y = padY + (1 - (value - min) / span) * innerH;
    return [x, y] as const;
  });
  const line = pts.map(([x, y], i) => `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${y.toFixed(1)}`).join(' ');
  return { line, area: `${line} L${w},${h} L0,${h} Z` };
}

async function fetchJson<T>(url: string, signal?: AbortSignal): Promise<T> {
  const res = await fetch(url, { signal });
  if (!res.ok) throw new Error(`Chess.com ${res.status}`);
  return (await res.json()) as T;
}

async function fetchRecentGames(signal?: AbortSignal): Promise<ChessGame[]> {
  const { archives } = await fetchJson<{ archives: string[] }>(
    ARCHIVES_URL,
    mergeSignals(signal, FETCH_TIMEOUT_MS)
  );
  const latest = archives.at(-1);
  if (!latest) return [];
  const { games } = await fetchJson<{ games: ChessGame[] }>(
    latest,
    mergeSignals(signal, FETCH_TIMEOUT_MS)
  );
  return games ?? [];
}

function timeControl(id: ChessTimeClassId, block: ChessStatsBlock | undefined, games: ChessGame[]): ChessTimeControl {
  return {
    id,
    rating: typeof block?.last?.rating === 'number' ? block.last.rating : null,
    best: typeof block?.best?.rating === 'number' ? block.best.rating : null,
    wins: block?.record?.win ?? 0,
    losses: block?.record?.loss ?? 0,
    draws: block?.record?.draw ?? 0,
    spark: ratingsForClass(games, id).slice(-SPARK_POINTS)
  };
}

function lastGameFrom(games: ChessGame[]): Pick<ChessConfig, 'lastGameResult' | 'lastGameOpening' | 'lastGameUrl'> {
  const last = games.at(-1);
  return {
    lastGameResult: last ? resultKind(sideFor(last).result) : null,
    lastGameOpening: last ? openingName(last.eco) : '',
    lastGameUrl: last?.url ?? null
  };
}

export async function fetchChessStats(signal?: AbortSignal): Promise<ChessConfig> {
  const { signal: combined, cleanup } = combineSignals(signal);
  try {
    const [profile, stats, games] = await Promise.all([
      fetchJson<ChessProfile>(PROFILE_URL, combined).catch(() => null),
      fetchJson<ChessStats>(STATS_URL, combined),
      fetchRecentGames(signal).catch(() => [] as ChessGame[])
    ]);
    return {
      name: profile?.name ?? '',
      username: profile?.username ?? USER,
      avatar: profile?.avatar ?? null,
      url: profile?.url ?? `https://www.chess.com/member/${USER}`,
      location: profile?.location ?? '',
      league: profile?.league ?? '',
      followers: typeof profile?.followers === 'number' ? profile.followers : null,
      joined: typeof profile?.joined === 'number' ? profile.joined : null,
      premium: profile?.status === 'premium',
      timeControls: TIME_CLASSES.map(({ id, statsKey }) => timeControl(id, stats[statsKey], games)),
      ...lastGameFrom(games)
    };
  } finally {
    cleanup();
  }
}
