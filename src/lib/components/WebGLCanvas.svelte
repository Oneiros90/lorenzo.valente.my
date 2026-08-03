<script lang="ts">
  import { onMount } from 'svelte';
  import {
    cameraConfig,
    getDeskPose,
    getFocusPose,
    lerp,
    lerpVec3,
    mouseLookBasis,
    type CameraPose
  } from '$lib/webgl/camera';
  import { pick } from '$lib/webgl/picking';
  import { EnceladusRenderer } from '$lib/webgl/renderer';
  import type { CompanyConfig, PickId, SceneConfig, SocialConfig, Vec3 } from '$lib/webgl/types';
  import type { LocaleData } from '$lib/i18n';
  import WorldLabels from '$lib/components/WorldLabels.svelte';

  interface Props {
    companies: CompanyConfig[];
    socials: SocialConfig[];
    scene: SceneConfig;
    strings: LocaleData;
    hover: PickId;
    active: PickId;
    focusCamera: boolean;
    onpick: (id: PickId) => void;
    onerror: (type: 'webgl' | 'shader', detail?: string) => void;
  }

  let {
    companies,
    socials,
    scene,
    strings,
    hover = $bindable(0),
    active,
    focusCamera,
    onpick,
    onerror
  }: Props = $props();

  let canvas: HTMLCanvasElement;
  let renderer: EnceladusRenderer | null = null;
  let mouseX = 0.5;
  let mouseY = 0.5;
  let smX = 0.5;
  let smY = 0.5;
  let timeNow = 0;
  let lastPx = -1;
  let lastPy = -1;
  let raf = 0;
  let viewBias = 0;
  let mouseDirty = false;
  let pickPx = -1;
  let pickPy = -1;
  let pickRo: Vec3 = [0, 0, 0];
  let pickTarget: Vec3 = [0, 0, 0];
  let pickFocal = 0;
  let pickBias = -1;
  const start = performance.now();

  let currentRo: Vec3 = [...cameraConfig.desk.ro] as Vec3;
  let currentTarget: Vec3 = [...cameraConfig.desk.target] as Vec3;
  let currentFocal = cameraConfig.desk.focal;
  let labelPose: CameraPose = $state.raw({
    ro: [...cameraConfig.desk.ro] as Vec3,
    target: [...cameraConfig.desk.target] as Vec3,
    focal: cameraConfig.desk.focal
  });
  let labelBias = $state(0);
  let labelTime = $state(0);
  let labelCanvasW = $state(1);
  let labelCanvasH = $state(1);

  function deskPoseFromMouse(time: number): CameraPose {
    const desk = getDeskPose(time);
    const { fw } = mouseLookBasis(smX, smY, innerWidth, innerHeight);
    const dist = cameraConfig.look.lookDistance;
    const target: Vec3 = [
      desk.ro[0] + fw[0] * dist,
      desk.ro[1] + fw[1] * dist,
      desk.ro[2] + fw[2] * dist
    ];
    return { ro: desk.ro, target, focal: desk.focal };
  }

  function currentPose(): CameraPose {
    return { ro: currentRo, target: currentTarget, focal: currentFocal };
  }

  function cameraChanged(): boolean {
    const eps = 1e-4;
    return (
      Math.abs(currentRo[0] - pickRo[0]) > eps ||
      Math.abs(currentRo[1] - pickRo[1]) > eps ||
      Math.abs(currentRo[2] - pickRo[2]) > eps ||
      Math.abs(currentTarget[0] - pickTarget[0]) > eps ||
      Math.abs(currentTarget[1] - pickTarget[1]) > eps ||
      Math.abs(currentTarget[2] - pickTarget[2]) > eps ||
      Math.abs(currentFocal - pickFocal) > eps ||
      Math.abs(viewBias - pickBias) > eps
    );
  }

  function updateHover(force = false) {
    if (!renderer) return;
    if (focusCamera || active !== 0) {
      if (hover !== 0) hover = 0;
      document.body.style.cursor = 'default';
      mouseDirty = false;
      return;
    }
    if (lastPx < 0) return;
    const moved = mouseDirty || lastPx !== pickPx || lastPy !== pickPy;
    if (!force && !moved && !cameraChanged()) return;

    const id = pick(lastPx, lastPy, timeNow, canvas, companies, scene, currentPose(), viewBias, socials);
    if (id !== hover) hover = id;
    document.body.style.cursor = id ? 'pointer' : 'default';

    mouseDirty = false;
    pickPx = lastPx;
    pickPy = lastPy;
    pickRo = [...currentRo] as Vec3;
    pickTarget = [...currentTarget] as Vec3;
    pickFocal = currentFocal;
    pickBias = viewBias;
  }

  function onPointerMove(e: PointerEvent) {
    if (focusCamera) return;
    if (e.pointerType === 'touch' && !e.isPrimary) return;
    mouseX = e.clientX / innerWidth;
    mouseY = 1.0 - e.clientY / innerHeight;
    lastPx = e.clientX;
    lastPy = e.clientY;
    mouseDirty = true;
    updateHover();
  }

  function onClick(e: MouseEvent) {
    if ((e.target as Element).closest('.panel')) return;
    if (!renderer) return;
    if (focusCamera) {
      if (e.clientX >= innerWidth * 0.5) onpick(0);
      return;
    }
    const id = pick(e.clientX, e.clientY, timeNow, canvas, companies, scene, currentPose(), viewBias, socials);
    onpick(id);
  }

  function loop(now: number) {
    if (!renderer) return;
    if (document.visibilityState === 'hidden') {
      raf = 0;
      return;
    }

    timeNow = (now - start) / 1000;
    const lookSmooth = cameraConfig.look.smooth;
    smX += (mouseX - smX) * lookSmooth;
    smY += (mouseY - smY) * lookSmooth;

    const idle = deskPoseFromMouse(timeNow);
    const focus = focusCamera ? getFocusPose(active, timeNow, companies, scene) : null;
    const desired = focus ?? idle;
    const speed = cameraConfig.lerpSpeed;
    currentRo = lerpVec3(currentRo, desired.ro, speed);
    currentTarget = lerpVec3(currentTarget, desired.target, speed);
    currentFocal = lerp(currentFocal, desired.focal, speed);
    viewBias = lerp(viewBias, focusCamera ? 1 : 0, speed);

    updateHover();
    renderer.draw(
      canvas,
      timeNow,
      smX,
      smY,
      focusCamera || active !== 0 ? 0 : hover,
      active,
      scene,
      currentRo,
      currentTarget,
      currentFocal,
      viewBias
    );
    labelPose = { ro: currentRo, target: currentTarget, focal: currentFocal };
    labelBias = viewBias;
    labelTime = timeNow;
    labelCanvasW = canvas.width;
    labelCanvasH = canvas.height;
    raf = requestAnimationFrame(loop);
  }

  function startLoop() {
    if (raf || !renderer || document.visibilityState === 'hidden') return;
    raf = requestAnimationFrame(loop);
  }

  onMount(() => {
    try {
      renderer = new EnceladusRenderer(canvas, companies, scene, (detail) => {
        onerror('shader', detail);
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg === 'no webgl2') onerror('webgl');
      else onerror('shader', msg);
      return;
    }

    const onResize = () => renderer?.resize(canvas, scene);
    const onVisibility = () => {
      if (document.visibilityState === 'hidden') {
        if (raf) cancelAnimationFrame(raf);
        raf = 0;
      } else {
        startLoop();
      }
    };

    window.addEventListener('resize', onResize);
    window.addEventListener('pointermove', onPointerMove, { passive: true });
    window.addEventListener('click', onClick);
    document.addEventListener('visibilitychange', onVisibility);
    startLoop();

    return () => {
      if (raf) cancelAnimationFrame(raf);
      window.removeEventListener('resize', onResize);
      window.removeEventListener('pointermove', onPointerMove);
      window.removeEventListener('click', onClick);
      document.removeEventListener('visibilitychange', onVisibility);
      renderer?.destroy();
    };
  });
</script>

<canvas bind:this={canvas}></canvas>
<WorldLabels
  {strings}
  {companies}
  {socials}
  {scene}
  pose={labelPose}
  viewBias={labelBias}
  time={labelTime}
  canvasWidth={labelCanvasW}
  canvasHeight={labelCanvasH}
  hidden={focusCamera}
/>
