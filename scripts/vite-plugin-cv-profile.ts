import { readFile } from 'node:fs/promises';
import path from 'node:path';
import type { Plugin } from 'vite';
import { extractPdfItems } from './extract-pdf.ts';
import { parseCvItems, type CvFetchConfig, type CvProfile } from './parse-cv.ts';

const VIRTUAL_ID = 'virtual:cv-profile';
const RESOLVED_ID = `\0${VIRTUAL_ID}`;

interface CvJson extends CvFetchConfig {
  url: string;
}

async function readJson<T>(file: string): Promise<T> {
  return JSON.parse(await readFile(file, 'utf8')) as T;
}

async function loadProfile(root: string): Promise<CvProfile> {
  const configPath = path.join(root, 'src/lib/config/cv.json');
  const fallbackPath = path.join(root, 'src/lib/config/generated-profile.fallback.json');
  const config = await readJson<CvJson>(configPath);

  try {
    let data: Uint8Array;
    const local = process.env.CV_PDF_PATH;
    if (local) {
      data = new Uint8Array(await readFile(local));
    } else {
      const res = await fetch(config.url);
      if (!res.ok) throw new Error(`CV fetch ${res.status} ${res.statusText}`);
      data = new Uint8Array(await res.arrayBuffer());
    }
    const items = await extractPdfItems(data);
    const parsed = parseCvItems(items, config);
    if (!parsed.companies.length || !parsed.bio.description) {
      throw new Error('CV parse produced empty bio or companies');
    }
    return parsed;
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.warn(`[cv-profile] ${message}; using ${path.relative(root, fallbackPath)}`);
    return readJson<CvProfile>(fallbackPath);
  }
}

export function cvProfilePlugin(): Plugin {
  let root = process.cwd();
  let profile: CvProfile | null = null;

  return {
    name: 'cv-profile',
    configResolved(config) {
      root = config.root;
    },
    async buildStart() {
      profile = await loadProfile(root);
    },
    resolveId(id) {
      if (id === VIRTUAL_ID) return RESOLVED_ID;
    },
    load(id) {
      if (id !== RESOLVED_ID) return;
      if (!profile) throw new Error('cv-profile: profile not loaded');
      return `export const bio = ${JSON.stringify(profile.bio)};
export const companies = ${JSON.stringify(profile.companies)};
export default { bio, companies };`;
    }
  };
}
