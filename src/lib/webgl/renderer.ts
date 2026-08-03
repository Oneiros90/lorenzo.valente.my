import vertSrc from '../shaders/vert.glsl?raw';
import sceneFragSrc from '../shaders/scene.frag.glsl?raw';
import blurFragSrc from '../shaders/blur.frag.glsl?raw';
import postFragSrc from '../shaders/post.frag.glsl?raw';
import type { CompanyConfig, RenderTarget, SceneConfig } from './types';
import { buildOrbUniforms } from './picking';

type UniformMap = Record<string, WebGLUniformLocation | null>;

function createWebGL2(canvas: HTMLCanvasElement): WebGL2RenderingContext {
  const tryOpts: WebGLContextAttributes[] = [
    { antialias: true, alpha: false, powerPreference: 'high-performance' },
    { antialias: true, alpha: false },
    { antialias: false, alpha: false }
  ];
  for (const opts of tryOpts) {
    const gl = canvas.getContext('webgl2', opts);
    if (gl) return gl;
  }
  throw new Error('no webgl2');
}

export class EnceladusRenderer {
  private gl: WebGL2RenderingContext;
  private vao: WebGLVertexArrayObject;
  private progScene: WebGLProgram;
  private progBlur: WebGLProgram;
  private progPost: WebGLProgram;
  private uS: UniformMap;
  private uB: UniformMap;
  private uP: UniformMap;
  private hasFloat: boolean;
  private useSupersample: boolean;
  private sceneRT!: RenderTarget;
  private bloomA!: RenderTarget;
  private bloomB!: RenderTarget;
  private W = 0;
  private H = 0;
  private orbUniforms;
  private onShaderError?: (message: string) => void;

  constructor(
    canvas: HTMLCanvasElement,
    companies: CompanyConfig[],
    scene: SceneConfig,
    onShaderError?: (message: string) => void
  ) {
    const gl = createWebGL2(canvas);
    this.gl = gl;
    this.onShaderError = onShaderError;
    this.hasFloat = !!gl.getExtension('EXT_color_buffer_float');
    this.useSupersample = false;
    this.orbUniforms = buildOrbUniforms(companies, scene);

    try {
      this.progScene = this.program(sceneFragSrc);
      this.progBlur = this.program(blurFragSrc);
      this.progPost = this.program(postFragSrc);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      onShaderError?.(msg);
      throw e;
    }

    this.vao = gl.createVertexArray()!;
    gl.bindVertexArray(this.vao);
    this.uS = this.cacheUniforms(this.progScene, [
      'iResolution',
      'iTime',
      'iMouse',
      'uHover',
      'uActive',
      'uCamRo',
      'uCamTarget',
      'uCamFocal',
      'uViewBias',
      'uOrbA',
      'uOrbB',
      'uOrbR'
    ]);
    this.uB = this.cacheUniforms(this.progBlur, ['uTex', 'uDir', 'uThreshold']);
    this.uP = this.cacheUniforms(this.progPost, [
      'uScene',
      'uBloom',
      'iResolution',
      'iTime',
      'uFade'
    ]);

    gl.useProgram(this.progScene);
    gl.uniform3fv(this.uS.uOrbA, this.orbUniforms.colorsA);
    gl.uniform3fv(this.uS.uOrbB, this.orbUniforms.colorsB);
    gl.uniform1fv(this.uS.uOrbR, this.orbUniforms.radii);

    this.resize(canvas, scene);
  }

  private compile(type: number, src: string): WebGLShader {
    const s = this.gl.createShader(type)!;
    this.gl.shaderSource(s, src);
    this.gl.compileShader(s);
    if (!this.gl.getShaderParameter(s, this.gl.COMPILE_STATUS)) {
      throw new Error(this.gl.getShaderInfoLog(s) ?? 'shader compile failed');
    }
    return s;
  }

  private program(fragSrc: string): WebGLProgram {
    const p = this.gl.createProgram()!;
    this.gl.attachShader(p, this.compile(this.gl.VERTEX_SHADER, vertSrc));
    this.gl.attachShader(p, this.compile(this.gl.FRAGMENT_SHADER, fragSrc));
    this.gl.linkProgram(p);
    if (!this.gl.getProgramParameter(p, this.gl.LINK_STATUS)) {
      throw new Error(this.gl.getProgramInfoLog(p) ?? 'program link failed');
    }
    return p;
  }

  private cacheUniforms(program: WebGLProgram, names: string[]): UniformMap {
    const map: UniformMap = {};
    for (const name of names) {
      map[name] = this.gl.getUniformLocation(program, name);
    }
    return map;
  }

  private makeTarget(w: number, h: number, preferFloat: boolean): RenderTarget {
    const gl = this.gl;
    const tex = gl.createTexture()!;
    gl.bindTexture(gl.TEXTURE_2D, tex);
    const useFloat = preferFloat && this.hasFloat;
    const ifmt = useFloat ? gl.RGBA16F : gl.RGBA8;
    const type = useFloat ? gl.HALF_FLOAT : gl.UNSIGNED_BYTE;
    gl.texImage2D(gl.TEXTURE_2D, 0, ifmt, w, h, 0, gl.RGBA, type, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    const fb = gl.createFramebuffer()!;
    gl.bindFramebuffer(gl.FRAMEBUFFER, fb);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    return { tex, fb, w, h };
  }

  private deleteTarget(rt: RenderTarget | undefined): void {
    if (!rt) return;
    const gl = this.gl;
    gl.deleteTexture(rt.tex);
    gl.deleteFramebuffer(rt.fb);
  }

  private resolveRenderScale(scene: SceneConfig): number {
    if (!this.useSupersample) return scene.renderScale;
    return Math.max(scene.renderScale, scene.aaRenderScale);
  }

  resize(canvas: HTMLCanvasElement, scene: SceneConfig): void {
    this.useSupersample = false;
    const dpr = Math.min(window.devicePixelRatio || 1, scene.maxDpr);
    const scale = this.resolveRenderScale(scene);
    const w = Math.floor(innerWidth * dpr * scale);
    const h = Math.floor(innerHeight * dpr * scale);
    if (w === this.W && h === this.H) return;
    this.W = w;
    this.H = h;
    canvas.width = Math.floor(innerWidth * dpr);
    canvas.height = Math.floor(innerHeight * dpr);
    this.deleteTarget(this.sceneRT);
    this.deleteTarget(this.bloomA);
    this.deleteTarget(this.bloomB);
    this.sceneRT = this.makeTarget(w, h, true);
    const bw = w >> 2 || 1;
    const bh = h >> 2 || 1;
    this.bloomA = this.makeTarget(bw, bh, false);
    this.bloomB = this.makeTarget(bw, bh, false);
  }

  draw(
    canvas: HTMLCanvasElement,
    t: number,
    smX: number,
    smY: number,
    hover: number,
    active: number,
    scene: SceneConfig,
    camRo: [number, number, number],
    camTarget: [number, number, number],
    camFocal: number,
    viewBias: number
  ): void {
    const gl = this.gl;
    gl.bindVertexArray(this.vao);

    gl.bindFramebuffer(gl.FRAMEBUFFER, this.sceneRT.fb);
    gl.viewport(0, 0, this.W, this.H);
    gl.useProgram(this.progScene);
    gl.uniform2f(this.uS.iResolution, this.W, this.H);
    gl.uniform1f(this.uS.iTime, t);
    gl.uniform2f(this.uS.iMouse, smX, smY);
    gl.uniform1f(this.uS.uHover, hover);
    gl.uniform1f(this.uS.uActive, active);
    gl.uniform3f(this.uS.uCamRo, camRo[0], camRo[1], camRo[2]);
    gl.uniform3f(this.uS.uCamTarget, camTarget[0], camTarget[1], camTarget[2]);
    gl.uniform1f(this.uS.uCamFocal, camFocal);
    gl.uniform1f(this.uS.uViewBias, viewBias);
    gl.drawArrays(gl.TRIANGLES, 0, 3);

    gl.useProgram(this.progBlur);
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.bloomA.fb);
    gl.viewport(0, 0, this.bloomA.w, this.bloomA.h);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.sceneRT.tex);
    gl.uniform1i(this.uB.uTex, 0);
    gl.uniform2f(this.uB.uDir, 1, 0);
    gl.uniform1f(this.uB.uThreshold, this.hasFloat ? 1.0 : 0.75);
    gl.drawArrays(gl.TRIANGLES, 0, 3);

    gl.bindFramebuffer(gl.FRAMEBUFFER, this.bloomB.fb);
    gl.viewport(0, 0, this.bloomB.w, this.bloomB.h);
    gl.bindTexture(gl.TEXTURE_2D, this.bloomA.tex);
    gl.uniform2f(this.uB.uDir, 0, 1);
    gl.uniform1f(this.uB.uThreshold, 0.0);
    gl.drawArrays(gl.TRIANGLES, 0, 3);

    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.viewport(0, 0, canvas.width, canvas.height);
    gl.useProgram(this.progPost);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.sceneRT.tex);
    gl.uniform1i(this.uP.uScene, 0);
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, this.bloomB.tex);
    gl.uniform1i(this.uP.uBloom, 1);
    gl.uniform2f(this.uP.iResolution, canvas.width, canvas.height);
    gl.uniform1f(this.uP.iTime, t);
    gl.uniform1f(
      this.uP.uFade,
      Math.min(1, Math.max(0, (t - scene.fadeDelaySeconds) / scene.fadeInSeconds))
    );
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  }

  destroy(): void {
    const gl = this.gl;
    this.deleteTarget(this.sceneRT);
    this.deleteTarget(this.bloomA);
    this.deleteTarget(this.bloomB);
    gl.deleteProgram(this.progScene);
    gl.deleteProgram(this.progBlur);
    gl.deleteProgram(this.progPost);
    gl.deleteVertexArray(this.vao);
  }
}
