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
  import type { CompanyConfig, PickId, SceneConfig, Vec3 } from '$lib/webgl/types';

  interface Props {
    companies: CompanyConfig[];
    scene: SceneConfig;
    hover: PickId;
    active: PickId;
    focusCamera: boolean;
    onpick: (id: PickId) => void;
    onerror: (type: 'webgl' | 'shader', detail?: string) => void;
  }

  let {
    companies,
    scene,
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
  const start = performance.now();

  let currentRo: Vec3 = [...cameraConfig.desk.ro] as Vec3;
  let currentTarget: Vec3 = [...cameraConfig.desk.target] as Vec3;
  let currentFocal = cameraConfig.desk.focal;

  function deskPoseFromMouse(time: number): CameraPose {
    const desk = getDeskPose(time);
    const { fw } = mouseLookBasis(smX, smY);
    const target: Vec3 = [
      desk.ro[0] + fw[0] * 2.4,
      desk.ro[1] + fw[1] * 2.4,
      desk.ro[2] + fw[2] * 2.4
    ];
    return { ro: desk.ro, target, focal: desk.focal };
  }

  function currentPose(): CameraPose {
    return { ro: currentRo, target: currentTarget, focal: currentFocal };
  }

  function updateHover() {
    if (!renderer) return;
    if (focusCamera || active !== 0) {
      if (hover !== 0) hover = 0;
      document.body.style.cursor = 'default';
      return;
    }
    if (lastPx < 0) return;
    const id = pick(lastPx, lastPy, timeNow, canvas, companies, scene, currentPose(), viewBias);
    if (id !== hover) hover = id;
    document.body.style.cursor = id ? 'pointer' : 'default';
  }

  function onMove(e: MouseEvent) {
    if (focusCamera) return;
    mouseX = e.clientX / innerWidth;
    mouseY = 1.0 - e.clientY / innerHeight;
    lastPx = e.clientX;
    lastPy = e.clientY;
    updateHover();
  }

  function onClick(e: MouseEvent) {
    if ((e.target as Element).closest('.panel')) return;
    if (!renderer) return;
    if (focusCamera) {
      if (e.clientX >= innerWidth * 0.5) onpick(0);
      return;
    }
    const id = pick(e.clientX, e.clientY, timeNow, canvas, companies, scene, currentPose(), viewBias);
    onpick(id);
  }

  function loop(now: number) {
    if (!renderer) return;
    timeNow = (now - start) / 1000;
    smX += (mouseX - smX) * 0.04;
    smY += (mouseY - smY) * 0.04;

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
    window.addEventListener('resize', onResize);
    window.addEventListener('mousemove', onMove);
    window.addEventListener('click', onClick);
    raf = requestAnimationFrame(loop);

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('resize', onResize);
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('click', onClick);
      renderer?.destroy();
    };
  });
</script>

<canvas bind:this={canvas}></canvas>
