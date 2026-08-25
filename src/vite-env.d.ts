/// <reference types="svelte" />
/// <reference types="vite/client" />

declare module '*.glsl?raw' {
  const content: string;
  export default content;
}

declare module '$lib/config/profile.json' {
  import type { ProfileConfig } from '$lib/webgl/types';
  const value: ProfileConfig;
  export default value;
}

declare module '$lib/config/github.json' {
  const value: { username: string };
  export default value;
}

declare module '$lib/config/socials.json' {
  import type { SocialConfig } from '$lib/webgl/types';
  const value: SocialConfig[];
  export default value;
}

declare module '$lib/config/chess.json' {
  const value: { username: string };
  export default value;
}

declare module '$lib/config/scene.json' {
  import type { SceneConfig } from '$lib/webgl/types';
  const value: SceneConfig;
  export default value;
}

declare module '$lib/config/camera.json' {
  const value: {
    desktopBreakpoint: number;
    lerpSpeed: number;
    panelTransitionMs: number;
    look: {
      smooth: number;
      lookDistance: number;
      desktop: { yawDeg: number; pitchDeg: number; pitchBiasDeg: number };
      mobile: { yawDeg: number; pitchDeg: number; pitchBiasDeg: number };
    };
    desk: { ro: [number, number, number]; target: [number, number, number]; focal: number };
    presets: Record<string, { ro: [number, number, number]; target: [number, number, number]; focal: number }>;
    orb: { offset: [number, number, number]; focal: number };
  };
  export default value;
}

