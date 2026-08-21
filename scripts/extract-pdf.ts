import { pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';
import { getDocument, GlobalWorkerOptions } from 'pdfjs-dist/legacy/build/pdf.mjs';
import type { PdfTextItem } from './parse-cv.ts';

const require = createRequire(import.meta.url);

function setupWorker(): void {
  if (GlobalWorkerOptions.workerSrc) return;
  const workerPath = require.resolve('pdfjs-dist/legacy/build/pdf.worker.mjs');
  GlobalWorkerOptions.workerSrc = pathToFileURL(workerPath).href;
}

export async function extractPdfItems(data: Uint8Array): Promise<PdfTextItem[]> {
  setupWorker();
  const doc = await getDocument({
    data: data.slice(),
    verbosity: 0,
    useSystemFonts: true
  }).promise;

  const items: PdfTextItem[] = [];
  try {
    for (let p = 1; p <= doc.numPages; p++) {
      const page = await doc.getPage(p);
      const content = await page.getTextContent();
      for (const item of content.items) {
        if (!('str' in item) || !item.str) continue;
        const t = item.transform;
        items.push({ str: item.str, x: t[4], y: t[5] });
      }
    }
  } finally {
    await doc.cleanup?.();
  }
  return items;
}
