/**
 * Dev-only visual check: drives the system Chrome against the vite dev server
 * and dumps a PNG so scene/shader changes can be eyeballed without a browser.
 *
 *   node scripts/shot.mjs out.png [--wait 6000] [--mx 0.5] [--my 0.5]
 *                                 [--w 1600] [--h 900] [--url http://...]
 */
import { launch } from 'puppeteer-core';
import { writeFileSync } from 'node:fs';

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const args = process.argv.slice(2);
const out = args[0] && !args[0].startsWith('--') ? args[0] : 'shot.png';
const flag = (name, def) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
};

const width = Number(flag('w', 1600));
const height = Number(flag('h', 900));
const wait = Number(flag('wait', 6500));
const mx = Number(flag('mx', 0.5));
const my = Number(flag('my', 0.5));
const url = flag('url', 'http://localhost:5173/');

const browser = await launch({
  executablePath: CHROME,
  headless: true,
  args: [
    '--no-sandbox',
    '--hide-scrollbars',
    '--use-gl=angle',
    '--use-angle=metal',
    '--enable-unsafe-swiftshader',
    `--window-size=${width},${height}`
  ]
});

const page = await browser.newPage();
await page.setViewport({ width, height, deviceScaleFactor: 1 });

const logs = [];
page.on('console', (m) => logs.push(`[${m.type()}] ${m.text()}`));
page.on('pageerror', (e) => logs.push(`[pageerror] ${e.message}`));

await page.goto(url, { waitUntil: 'networkidle2', timeout: 30000 });
await page.mouse.move(width * mx, height * my);
await new Promise((r) => setTimeout(r, wait));
await page.mouse.move(width * mx, height * my);
await new Promise((r) => setTimeout(r, 400));

const renderer = await page.evaluate(() => {
  const c = document.createElement('canvas');
  const gl = c.getContext('webgl2');
  if (!gl) return 'no-webgl2';
  const dbg = gl.getExtension('WEBGL_debug_renderer_info');
  return dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : 'unknown';
});

/* frame time medio: unica metrica utile per confrontare le versioni dello shader */
const perf = await page.evaluate(
  (ms) =>
    new Promise((resolve) => {
      const dt = [];
      let prev = performance.now();
      const tick = (now) => {
        dt.push(now - prev);
        prev = now;
        if (now - start < ms) requestAnimationFrame(tick);
        else {
          const s = dt.slice(2).sort((a, b) => a - b);
          resolve({
            n: s.length,
            med: s[(s.length / 2) | 0],
            p90: s[(s.length * 0.9) | 0]
          });
        }
      };
      const start = performance.now();
      requestAnimationFrame(tick);
    }),
  2500
);

const overlay = await page.evaluate(() => {
  const el = document.querySelector('.error-overlay, .boot-overlay');
  return el ? el.className + ': ' + el.textContent.trim().slice(0, 400) : null;
});

const png = await page.screenshot({ type: 'png' });
writeFileSync(out, png);
await browser.close();

console.log(`gpu: ${renderer}`);
console.log(`frame: med ${perf.med.toFixed(2)}ms  p90 ${perf.p90.toFixed(2)}ms  (${perf.n} frames)`);
if (overlay) console.log(`overlay: ${overlay}`);
if (logs.length) console.log(logs.join('\n'));
console.log(`wrote ${out}`);
