import { readFileSync } from 'node:fs';
import { extractPdfItems } from './extract-pdf.ts';
import { parseCvItems, type CvFetchConfig } from './parse-cv.ts';

const path = process.argv[2];
if (!path) {
  console.error('usage: node --experimental-strip-types scripts/dump-cv.ts <pdf>');
  process.exit(1);
}

const cv = JSON.parse(
  readFileSync(new URL('../src/lib/config/cv.json', import.meta.url), 'utf8')
) as CvFetchConfig;

const data = new Uint8Array(readFileSync(path));
const items = await extractPdfItems(data);
const profile = parseCvItems(items, cv);
console.log('--- PROFILE ---');
console.log(JSON.stringify(profile, null, 2));
