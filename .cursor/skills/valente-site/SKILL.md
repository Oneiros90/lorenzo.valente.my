---
name: valente-site
description: Brand system and implementation rules for lorenzo.valente.my. Use when editing the homepage, Enceladus, design tokens, Pretext text, Canvas UI effects, or site copy.
---

# Valente site

Two surfaces, one content source.

- `/` is a 2D editorial homepage. Premium, factual, technological. No sci-fi, no atmosphere, no habitat, no O2.
- `/enceladus/` is the WebGL experience. Keep its sci-fi HUD copy.
- Shared facts live in `src/lib/config/` and the chess/github fetchers. Never duplicate bio, companies, projects, or socials.

## Tokens

Use CSS variables from `src/site/styles/tokens.css` only. Never raw hex in components.

Dark (default): paper `#000000`, ink ramp `#cdc4ba` → dimmer tiers still ≥ 4.6:1.
Light: paper bone `#e4ddd4`, ink `#0a0908`.
Grain 5.5%. Radius 2px. No box-shadow. No Inter. No neon, no gradient text.

Fonts: Space Grotesk (display), Fraunces (pull quotes), IBM Plex Mono (meta).

## Homepage sections

`00 //` numbered chapters: bio, work, projects, chess, contact. Biography is one section (name, portrait, role, status, clocks, lede, CV). One visible Enceladus link, in nav.

## Pretext

All homepage copy goes through `PretextField`. Semantic HTML first paint, hydrate after paint. Orbs punch gaps in a line; words flow on both sides via `layoutNextLineRange`. Canvas is `aria-hidden`. Skip orbs on reduced motion, coarse pointer, Save-Data.

## Canvas UI

Decrypt Reveal on the hero name, Particle Scroll on work, Displacement as cursor grain. Lazy-import. Skip on mobile / reduced motion. Detect html-in-canvas; fall back to HTML.

## Performance

Homepage must paint immediately. Never gate on images, chess, or GitHub. Skeletons for live data. `loading="lazy"` on images.
