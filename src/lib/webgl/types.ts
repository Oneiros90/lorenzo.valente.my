export type Vec3 = [number, number, number];

export interface CompanyConfig {
  id: string;
  years: number;
  colorA: Vec3;
  colorB: Vec3;
}

export interface ProjectConfig {
  id: string;
  url: string;
  stars: number;
  lang: string;
  tags: string[];
}

export interface BioConfig {
  archiveId: string;
  status: string;
}

export interface ChessConfig {
  rapid: number;
  blitz: number;
  bullet: number;
  lastGame: string;
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
