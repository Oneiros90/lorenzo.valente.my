<script lang="ts">
  import type { LocaleData } from '$lib/i18n';
  import type { CameraPose } from '$lib/webgl/camera';
  import { orbPosJS, orbRadius } from '$lib/webgl/orbs';
  import { projectWorldToScreen } from '$lib/webgl/project';
  import { socialPosJS } from '$lib/webgl/socials';
  import type { CompanyConfig, SceneConfig, SocialConfig, Vec3 } from '$lib/webgl/types';

  interface Props {
    strings: LocaleData;
    companies: CompanyConfig[];
    socials: SocialConfig[];
    scene: SceneConfig;
    pose: CameraPose;
    viewBias: number;
    time: number;
    canvasWidth: number;
    canvasHeight: number;
    hidden?: boolean;
  }

  let {
    strings,
    companies,
    socials,
    scene,
    pose,
    viewBias,
    time,
    canvasWidth,
    canvasHeight,
    hidden = false
  }: Props = $props();

  const TAB_C: Vec3 = [-0.7, 0.83, 0.8];
  const BRD_C: Vec3 = [0.58, 0.805, 0.82];
  const OCT_C: Vec3 = [1.12, 0.8, 1.1];

  interface LabelItem {
    id: string;
    text: string;
    x: number;
    y: number;
    depth: number;
    visible: boolean;
  }

  function above(p: Vec3, dy: number): Vec3 {
    return [p[0], p[1] + dy, p[2]];
  }

  const labels = $derived.by(() => {
    if (hidden || canvasWidth < 1 || canvasHeight < 1) return [] as LabelItem[];

    const out: LabelItem[] = [];
    const push = (id: string, text: string, world: Vec3) => {
      const s = projectWorldToScreen(world, pose, viewBias, canvasWidth, canvasHeight);
      out.push({ id, text, x: s.x, y: s.y, depth: s.depth, visible: s.visible });
    };

    push('bio', strings.labels.bio, above(TAB_C, 0.14));
    push('chess', strings.labels.chess, above(BRD_C, 0.12));
    push('github', strings.labels.github, above(OCT_C, 0.2));

    for (let i = 0; i < companies.length; i++) {
      const c = companies[i];
      const r = orbRadius(c.years, scene);
      const name = c.name;
      push(`company-${c.id}`, name, above(orbPosJS(i, time, r, companies.length), r + 0.06));
    }

    for (let i = 0; i < socials.length; i++) {
      const s = socials[i];
      const name = strings.labels.socials[s.id as keyof typeof strings.labels.socials] ?? s.id;
      push(`social-${s.id}`, name, above(socialPosJS(i, time), 0.12));
    }

    return out.sort((a, b) => b.depth - a.depth);
  });
</script>

{#if !hidden}
  <div class="world-labels" aria-hidden="true">
    {#each labels as label (label.id)}
      {#if label.visible}
        <span
          class="world-label"
          style:left="{label.x}px"
          style:top="{label.y}px"
          style:--depth={label.depth}
        >
          {label.text}
        </span>
      {/if}
    {/each}
  </div>
{/if}

<style>
  .world-labels {
    position: fixed;
    inset: 0;
    pointer-events: none;
    z-index: 4;
    overflow: hidden;
  }

  .world-label {
    position: absolute;
    transform: translate(-50%, -120%);
    white-space: nowrap;
    font-family: Rajdhani, 'Segoe UI', system-ui, sans-serif;
    font-size: clamp(10px, 1.05vw, 13px);
    font-weight: 600;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: #d7e9ff;
    text-shadow:
      0 0 6px rgba(56, 189, 248, 0.85),
      0 0 14px rgba(10, 20, 40, 0.9);
    opacity: clamp(0.35, calc(1.15 - (var(--depth) - 1.2) * 0.12), 0.95);
    border-bottom: 1px solid rgba(120, 200, 255, 0.35);
    padding: 0 2px 1px;
  }
</style>
