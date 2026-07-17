/// <reference types="svelte" />
/// <reference types="vite/client" />

declare module '*.glsl?raw' {
  const content: string;
  export default content;
}

declare module '$lib/config/companies.json' {
  import type { CompanyConfig } from '$lib/webgl/types';
  const value: CompanyConfig[];
  export default value;
}

declare module '$lib/config/projects.json' {
  import type { ProjectConfig } from '$lib/webgl/types';
  const value: ProjectConfig[];
  export default value;
}

declare module '$lib/config/bio.json' {
  import type { BioConfig } from '$lib/webgl/types';
  const value: BioConfig;
  export default value;
}

declare module '$lib/config/chess.json' {
  import type { ChessConfig } from '$lib/webgl/types';
  const value: ChessConfig;
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
    desk: { ro: [number, number, number]; target: [number, number, number]; focal: number };
    presets: Record<string, { ro: [number, number, number]; target: [number, number, number]; focal: number }>;
    orb: { offset: [number, number, number]; focal: number };
  };
  export default value;
}

