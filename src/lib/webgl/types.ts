export type Vec3 = [number, number, number];

export interface CompanyConfig {
  id: string;
  years: number;
  colorA: Vec3;
  colorB: Vec3;
}

export interface ProjectConfig {
  id: string;
  name: string;
  description: string;
  url: string;
  stars: number;
  lang: string;
  tags: string[];
  imageUrl: string | null;
}

export interface GithubProfile {
  name: string;
  username: string;
  avatar: string | null;
  url: string;
  location: string;
  company: string;
  followers: number | null;
  joined: string | null;
  publicRepos: number | null;
}

export interface BioConfig {
  archiveId: string;
  status: string;
}

export type ChessResult = 'win' | 'draw' | 'loss';

export type ChessTimeClassId = 'rapid' | 'blitz' | 'bullet';

export interface ChessTimeControl {
  id: ChessTimeClassId;
  rating: number | null;
  best: number | null;
  wins: number;
  losses: number;
  draws: number;
  spark: number[];
}

export interface ChessConfig {
  name: string;
  username: string;
  avatar: string | null;
  url: string;
  location: string;
  league: string;
  followers: number | null;
  joined: number | null;
  premium: boolean;
  timeControls: ChessTimeControl[];
  lastGameResult: ChessResult | null;
  lastGameOpening: string;
  lastGameUrl: string | null;
}

export interface SceneConfig {
  defaultLocale: string;
  renderScale: number;
  aaRenderScale: number;
  maxDpr: number;
  bootDurationMs: number;
  fadeInSeconds: number;
  fadeDelaySeconds: number;
  clockIntervalMs: number;
  cycleId: string;
  orbRadiusBase: number;
  orbRadiusPerYear: number;
}

export interface SocialConfig {
  id: string;
  url: string;
  colorA: Vec3;
  colorB: Vec3;
}

export type PickId = number;

export interface RenderTarget {
  tex: WebGLTexture;
  fb: WebGLFramebuffer;
  w: number;
  h: number;
}

export interface RendererState {
  hover: PickId;
  active: PickId;
  mouseX: number;
  mouseY: number;
  smX: number;
  smY: number;
  time: number;
}

export interface OrbUniforms {
  colorsA: Float32Array;
  colorsB: Float32Array;
  radii: Float32Array;
}
