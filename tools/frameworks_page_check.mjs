// Measurements of the frameworks page (Lensatic 2.0, Round 3) in a real browser engine, for tools/check_web.py, which
// judges them. playwright-core driving the system's Chrome, as tools/layout_guard.mjs does; nothing is downloaded and
// nothing leaves the repository: the page is opened from its file, with the network closed.
// Usage: node tools/frameworks_page_check.mjs docs/maps/frameworks/index.html
// Prints one JSON object: for 375 and 1280 wide, whether the page scrolls sideways, what is clipped past the right edge,
// the links under 44 px in the jump row and the text a reader sees; and for print, the text that prints and the pages.
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const file = process.argv[2];
if (!file) { console.error('usage: node tools/frameworks_page_check.mjs <page.html>'); process.exit(2); }
let chromium;
try { ({ chromium } = await import('playwright-core')); } catch {
  console.log(JSON.stringify({ error: 'playwright-core is missing; run npm install --no-package-lock --ignore-scripts at the repository root' }));
  process.exit(2);
}
const CHROMES = [process.env.LENSATIC_CHROME, process.env.CHROME_PATH,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium', '/usr/bin/chromium-browser'].filter(Boolean);
const chrome = CHROMES.find((p) => existsSync(p));
if (!chrome) { console.log(JSON.stringify({ error: 'no Chrome or Chromium found; set LENSATIC_CHROME' })); process.exit(2); }

const url = pathToFileURL(resolve(file)).href;
const browser = await chromium.launch({ executablePath: chrome, headless: true });
const out = { widths: {}, requests: [] };
try {
  for (const width of [375, 1280]) {
    const ctx = await browser.newContext({ viewport: { width, height: 900 }, hasTouch: width < 600, colorScheme: 'light' });
    const page = await ctx.newPage();
    // the page loads nothing: any request but the page itself is recorded, and refused
    await page.route('**/*', (route) => { if (route.request().url() === url) route.continue(); else { out.requests.push(route.request().url()); route.abort(); } });
    await page.goto(url, { waitUntil: 'load' });
    out.widths[width] = await page.evaluate(() => {
      const vw = document.documentElement.clientWidth;
      const clipped = [];
      for (const e of document.querySelectorAll('main *')) {
        if (e.closest('.fw-scroll')) continue;  // a comparison's table scrolls inside its own box on a phone
        const r = e.getBoundingClientRect();
        if (r.width > 0 && r.right > vw + 1) clipped.push(`${e.tagName.toLowerCase()}.${e.className} ${Math.round(r.right)}`);
      }
      const small = [...document.querySelectorAll('.fw-jump a')].filter((a) => a.getBoundingClientRect().height < 44).map((a) => a.textContent);
      const layout = { vw, scrollWidth: document.documentElement.scrollWidth, clipped: clipped.slice(0, 5), small,
                       cards: document.querySelectorAll('article.fw').length };
      // the text a reader sees, less what the build adds beside the folder's words (an abbreviation's spell-out, the PDF
      // tags), so each of the folder's texts can be looked for whole
      const quiet = document.createElement('style');
      quiet.textContent = '.xp, .gloss, .pdf-tag { display: none !important; }';
      document.head.appendChild(quiet);
      return { ...layout, text: document.querySelector('main').innerText };
    });
    await ctx.close();
  }
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  const page = await ctx.newPage();
  await page.goto(url, { waitUntil: 'load' });
  await page.emulateMedia({ media: 'print' });
  // Letter with the margins Chrome's own print uses by default (about 1 cm), as the map's printout is measured. The pages
  // are counted first, from the page as it prints; then the text that prints, less the build's additions
  const pdf = await page.pdf({ format: 'Letter', printBackground: false, margin: { top: '0.4in', bottom: '0.4in', left: '0.4in', right: '0.4in' } });
  const text = await page.evaluate(() => {
    const quiet = document.createElement('style');
    quiet.textContent = '.xp, .gloss, .pdf-tag { display: none !important; }';
    document.head.appendChild(quiet);
    return document.querySelector('main').innerText;
  });
  out.print = { text, pages: (pdf.toString('latin1').match(/\/Type\s*\/Page[^s]/g) || []).length };
  await ctx.close();
} catch (e) {
  out.error = String(e).split('\n')[0];
}
await browser.close();
process.stdout.write(JSON.stringify(out) + '\n');
