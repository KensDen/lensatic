// The playbook's figures for the app (27 October 2026): every diagram the website shows inside a play, rendered to a PNG
// the iOS app can bundle, with a manifest that says where each one goes. The website's diagrams are the inline
// <svg role="img" aria-label> drawings and the <iframe title> posters in playbook/Playbook/agentic-secops-teaming.jsx;
// the app's plays (playbook/app/plays.json, from tools/build_library.py) leave them out.
//
// The published page, docs/playbook/Playbook/index.html, is served from 127.0.0.1 and opened in the system Chrome driven
// by playwright-core (npm install --no-package-lock --ignore-scripts at the repository root), 390px wide at device scale
// 3, in the dark theme (the dark colour scheme, and the umbrella bar's stored choice, lensatic-theme, set to dark), with
// reduced motion so the posters' reveal animations are already done. Each play is opened by its hash (#id), the page's
// own deep link. In it, a figure is an svg[role=img] with an aria-label or an iframe with a title, outside the page's
// chrome (header, nav, buttons, links) and at least 120px wide, so icons, logos and decoration are not figures. Each is
// captured as its own element, at its rendered size, on the page's own background; a poster is captured whole after its
// frame has fitted its height, with the page's fixed and sticky chrome hidden so it cannot cover one. Every PNG is
// re-encoded losslessly with the row filtering that packs it smallest; a capture still over 1.5 MB is taken again at
// device scale 2.
//
// A figure must be captured whole. One that overflows sideways at 390 (a poster whose document is wider than its frame,
// or has an element running past the frame's right edge, as an inner scroller's hidden content does; a drawing wider
// than its container, or drawn past its own viewBox) is captured instead at the narrowest of 430, 600, 768 and 1024
// where it fits, at device scale 3 (2 over 1.5 MB); if none fits, at 1024, with a warning. A figure that fits at 390
// is captured there. The manifest gives each figure's viewport.
//
// Out: playbook/app/figures/<id>.png and playbook/app/figures/figures.json, {"figures": [{id, play, after, alt, width,
// height, viewport}]}, in play order and then in page order. "after" is the heading of the block in that play's blocks (plays.json)
// that the figure follows: the nearest text above the figure on the page that is one of those headings, or null when no
// block heading is above it. A PNG left from an earlier run that no figure names is removed.
// Native figures (R4): the six small inline drawings (the autonomy dial, the three faces, the trifecta, the purple loop,
// the blast radius and the patching deficit) are drawn by the app itself, in its own type and colours, so they read at
// a phone's width and follow its theme. Each keeps its place in the manifest, marked "native": true, with no PNG.
//
// Light (R4): with --light, the same figures are captured in the light theme (the light colour scheme, lensatic-theme
// set to light) into playbook/app/figures/light/, at the viewport the manifest gives each, and each must come out the
// size its dark capture is; the manifest is not rewritten. Run the dark pass first.
// Usage: node tools/build_figures.mjs [--light]
import { createServer } from 'node:http';
import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, unlinkSync, writeFileSync } from 'node:fs';
import { dirname, extname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync, inflateSync } from 'node:zlib';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const DOCS = join(ROOT, 'docs');
const PAGE = 'playbook/Playbook/index.html';
const PLAYS = join(ROOT, 'playbook', 'app', 'plays.json');
const OUT = join(ROOT, 'playbook', 'app', 'figures');
const WIDTH = 390, HEIGHT = 900, SCALE = 3, FALLBACK_SCALE = 2;
const WIDER = [430, 600, 768, 1024];  // the viewports, narrowest first, for a figure that overflows at 390
const MAX_BYTES = 1.5 * 1024 * 1024;
const MIN_WIDTH = 120;
const SCHEME = process.argv.includes('--light') ? 'light' : 'dark';
const DIR = SCHEME === 'light' ? join(OUT, 'light') : OUT;
// the figures the app draws itself (Views/NativeFigures.swift)
const NATIVE = new Set(['autonomy-spectrum', 'three-faces', 'lethal-trifecta', 'purple-loop', 'blast-radius', 'patching-deficit']);

// the figures' ids, by their accessible names; a figure not listed here takes a slug of its name (and is reported)
const IDS = {
  'Same Horsepower, Two Outcomes': 'same-horsepower',
  'The autonomy spectrum': 'autonomy-spectrum',
  'Three jobs: automation, AI, people': 'three-jobs',
  'One capability, three faces': 'three-faces',
  'The lethal trifecta': 'lethal-trifecta',
  'The continuous purple loop': 'purple-loop',
  'SecOps AI maturity ladder': 'maturity-ladder',
  'Security org chart: today vs future': 'org-chart',
  'Agentic SecOps reference architecture': 'reference-architecture',
  'Identity-first enforcement architecture': 'identity-enforcement',
  'Continuous purple teaming loop': 'purple-teaming-loop',
  'Value stream map: lead time per TTP': 'value-stream-map',
  'Zero Trust for Operational Technology': 'zero-trust-ot',
  'MAESTRO seven-layer reference model': 'maestro-layers',
  'Cyber Jailbreak Severity spectrum': 'jailbreak-severity',
  'One Operator, a Cast of Agents': 'cast-of-agents',
  'Schematic of containment bounding a compromised agent blast radius': 'blast-radius',
  'The patching deficit, drawn to scale': 'patching-deficit',
  'Zero Trust capability matrix': 'zero-trust-matrix',
  'AI security framework crosswalk': 'framework-crosswalk',
};
const slugOf = (s) => String(s).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 48);

let chromium;
try { ({ chromium } = await import('playwright-core')); } catch {
  console.log('FAIL  build_figures: playwright-core is missing; run npm install --no-package-lock --ignore-scripts at the repository root');
  process.exit(1);
}
const CHROMES = [process.env.LENSATIC_CHROME, process.env.CHROME_PATH,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium', '/usr/bin/chromium-browser'].filter(Boolean);
const chrome = CHROMES.find((p) => existsSync(p));
if (!chrome) { console.log('FAIL  build_figures: no Chrome or Chromium found; set LENSATIC_CHROME'); process.exit(1); }
if (!existsSync(join(DOCS, PAGE))) { console.log(`FAIL  build_figures: docs/${PAGE} is missing`); process.exit(1); }

const plays = JSON.parse(readFileSync(PLAYS, 'utf8')).plays;
const playOrder = new Map(plays.map((p, i) => [p.id, i]));

// docs/ served at /lensatic/ and at /, as the layout guard serves it, so every address resolves as it does live
const TYPES = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json',
  '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.woff2': 'font/woff2', '.pdf': 'application/pdf', '.ico': 'image/x-icon' };
const server = createServer((req, res) => {
  let p = decodeURIComponent(new URL(req.url, 'http://x').pathname).replace(/^\/lensatic(?=\/|$)/, '');
  if (p.endsWith('/')) p += 'index.html';
  const f = join(DOCS, p);
  if (!f.startsWith(DOCS) || !existsSync(f) || statSync(f).isDirectory()) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'content-type': TYPES[extname(f)] || 'application/octet-stream' }); res.end(readFileSync(f));
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const URL_ = `http://127.0.0.1:${server.address().port}/lensatic/${PAGE}`;

const browser = await chromium.launch({ executablePath: chrome, headless: true });
const stop = async () => { await browser.close().catch(() => {}); await new Promise((r) => server.close(r)); };
const fail = async (msg) => { console.log(`FAIL  build_figures: ${msg}`); await stop(); process.exit(1); };

// a page at a device scale, in the theme asked for
async function openPage(scale, width = WIDTH) {
  const ctx = await browser.newContext({ viewport: { width, height: HEIGHT }, deviceScaleFactor: scale, colorScheme: SCHEME, reducedMotion: 'reduce' });
  await ctx.addInitScript((scheme) => { try { localStorage.setItem('lensatic-theme', scheme); } catch (e) {} }, SCHEME);
  const page = await ctx.newPage();
  await page.goto(URL_, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  const theme = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
  if (theme !== SCHEME) await fail(`the page rendered with data-theme ${theme}, not ${SCHEME}`);
  return { ctx, page, play: null };
}
const pages = new Map();
async function pageFor(width, scale) {
  const k = `${width}@${scale}`;
  if (!pages.has(k)) pages.set(k, await openPage(scale, width));
  return pages.get(k);
}

// opens a play by its hash and waits until it shows, every poster has fitted its height and every animation is done
async function openPlay(page, play) {
  const id = play.id;
  await page.evaluate((id) => { location.hash = id; }, id);
  try {
    await page.waitForFunction((title) => { const n = (t) => String(t || '').toLowerCase().replace(/[^a-z0-9]+/g, ''); return [...document.querySelectorAll('h1')].some((h) => n(h.textContent) === n(title)); }, play.title, { timeout: 10000 });
  } catch { await fail(`the ${id} play did not open (no h1 reads "${play.title}")`); }
  await page.waitForTimeout(300);
  let last = '', same = 0;
  for (let i = 0; i < 60 && same < 3; i++) {
    const sig = await page.evaluate(async () => {
      const frames = [...document.querySelectorAll('iframe[title]')];
      for (const f of frames) {
        const d = f.contentDocument;
        if (!d || d.readyState !== 'complete') return 'loading';
        await d.fonts.ready;
        d.getAnimations().forEach((a) => { try { a.finish(); } catch (e) {} });
      }
      document.getAnimations().forEach((a) => { try { a.finish(); } catch (e) {} });
      return frames.map((f) => f.getBoundingClientRect().height).join(',') + '|' + document.documentElement.getAttribute('data-theme')
        + '|' + frames.map((f) => f.contentDocument.documentElement.getAttribute('data-theme')).join(',');
    });
    if (sig === last && sig !== 'loading') same++; else { same = 0; last = sig; }
    await page.waitForTimeout(150);
  }
  if (same < 3) await fail(`the ${id} play's figures did not settle`);
}
async function showPlay(p, play) { if (p.play !== play.id) { await openPlay(p.page, play); p.play = play.id; } }

// runs in the page: the play's figures in page order, each marked for capture, with the block heading above it
function findFigures({ heads, MIN_WIDTH }) {
  const norm = (t) => String(t || '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
  const wanted = new Map(heads.map((h) => [norm(h), h]));
  const CHROME = 'header, nav, button, a, [role="banner"], [role="navigation"], [role="button"]';
  const vis = (e) => { const r = e.getBoundingClientRect(), cs = getComputedStyle(e); return r.width >= 2 && r.height >= 2 && cs.visibility !== 'hidden' && cs.display !== 'none'; };
  document.querySelectorAll('[data-figure-capture]').forEach((e) => e.removeAttribute('data-figure-capture'));
  const figs = [...document.querySelectorAll('svg[role="img"][aria-label], iframe[title]')]
    .filter((f) => vis(f) && !f.closest(CHROME) && f.getBoundingClientRect().width >= MIN_WIDTH);
  // text elements that hold only their own text (a heading's words, perhaps in spans), outside the page's chrome
  const texts = [...document.body.querySelectorAll('*')].filter((e) => !e.closest(CHROME) && !e.closest('svg') && e.tagName !== 'IFRAME'
    && [...e.childNodes].every((n) => n.nodeType === 3 || (n.nodeType === 1 && /^(SPAN|B|STRONG|EM|I)$/.test(n.tagName))) && e.textContent.trim()
    && wanted.has(norm(e.textContent)));
  // the page's fixed and sticky chrome (the umbrella bar, the play menu) would cover a figure scrolled under it: hidden
  for (const e of document.body.querySelectorAll('*')) {
    const pos = getComputedStyle(e).position;
    if ((pos === 'fixed' || pos === 'sticky') && !figs.some((f) => e.contains(f))) e.style.setProperty('visibility', 'hidden', 'important');
  }
  // why a figure is not whole at this width, or null: a poster's document wider than its frame, or an element in it
  // running past the frame's right edge (clipped or in an inner scroller); a drawing past its container's content box,
  // or drawn past its own viewBox
  const overflowOf = (f) => {
    if (f.tagName === 'IFRAME') {
      const d = f.contentDocument, de = d.documentElement, cw = de.clientWidth;
      const sw = Math.max(de.scrollWidth, d.body ? d.body.scrollWidth : 0);
      if (sw > cw + 1) return `its document is ${sw}px wide in a ${cw}px frame`;
      for (const e of d.body.querySelectorAll('*')) {
        const q = e.getBoundingClientRect();
        if (q.width > 0 && q.height > 0 && q.right > cw + 1 && d.defaultView.getComputedStyle(e).visibility !== 'hidden')
          return `${e.tagName.toLowerCase()}${typeof e.className === 'string' && e.className.trim() ? '.' + e.className.trim().split(/\s+/).join('.') : ''} runs to ${q.right.toFixed(0)}px in a ${cw}px frame`;
      }
      return null;
    }
    const r = f.getBoundingClientRect(), c = f.parentElement, q = c.getBoundingClientRect(), cs = getComputedStyle(c);
    const left = q.left + parseFloat(cs.borderLeftWidth) + parseFloat(cs.paddingLeft), right = q.right - parseFloat(cs.borderRightWidth) - parseFloat(cs.paddingRight);
    if (r.left < left - 1 || r.right > right + 1) return `it spans ${r.left.toFixed(0)} to ${r.right.toFixed(0)}px in a container of ${left.toFixed(0)} to ${right.toFixed(0)}px`;
    const vb = f.viewBox && f.viewBox.baseVal, bb = f.getBBox();
    if (vb && vb.width && (bb.x < vb.x - 1 || bb.x + bb.width > vb.x + vb.width + 1)) return `it is drawn from ${bb.x.toFixed(0)} to ${(bb.x + bb.width).toFixed(0)} in a viewBox ${vb.width} wide`;
    return null;
  };
  return figs.map((f, i) => {
    f.setAttribute('data-figure-capture', String(i));
    const above = texts.filter((t) => t.compareDocumentPosition(f) & Node.DOCUMENT_POSITION_FOLLOWING);
    const h = above.length ? wanted.get(norm(above[above.length - 1].textContent)) : null;
    const r = f.getBoundingClientRect();
    return { index: i, alt: (f.getAttribute('aria-label') || f.getAttribute('title')).trim(), after: h, w: r.width, h: r.height, overflow: overflowOf(f) };
  });
}

const pngSize = (buf) => ({ width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) });

// re-encodes a PNG losslessly, in one IDAT chunk deflated at the highest level, with whichever row filtering makes it
// smallest: Chrome's own adaptive filters, no filter, or the Sub filter on every row (a flat dark diagram often packs
// far tighter unfiltered)
const CRC = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
const crc32 = (b) => { let c = -1; for (const x of b) c = CRC[(c ^ x) & 0xff] ^ (c >>> 8); return (c ^ -1) >>> 0; };
const chunk = (type, data) => { const t = Buffer.from(type, 'latin1'), len = Buffer.alloc(4), crc = Buffer.alloc(4);
  len.writeUInt32BE(data.length); crc.writeUInt32BE(crc32(Buffer.concat([t, data]))); return Buffer.concat([len, t, data, crc]); };
const predict = (f, a, u, c) => { if (f === 0) return 0; if (f === 1) return a; if (f === 2) return u; if (f === 3) return (a + u) >> 1;
  const p = a + u - c, pa = Math.abs(p - a), pb = Math.abs(p - u), pc = Math.abs(p - c); return pa <= pb && pa <= pc ? a : pb <= pc ? u : c; };
function refilter(raw, w, h, bpp) {
  const L = w * bpp, st = L + 1, none = Buffer.alloc(st * h), sub = Buffer.alloc(st * h);
  let prev = Buffer.alloc(L);
  for (let y = 0; y < h; y++) {
    const f = raw[y * st], cur = none.subarray(y * st + 1, (y + 1) * st);
    for (let i = 0; i < L; i++) cur[i] = (raw[y * st + 1 + i] + predict(f, i >= bpp ? cur[i - bpp] : 0, prev[i], i >= bpp ? prev[i - bpp] : 0)) & 255;
    sub[y * st] = 1;
    for (let i = 0; i < L; i++) sub[y * st + 1 + i] = (cur[i] - (i >= bpp ? cur[i - bpp] : 0)) & 255;
    prev = cur;
  }
  return [none, sub];
}
function recompress(buf) {
  const parts = [buf.subarray(0, 8)], idat = [];
  let at = 8, placed = false;
  while (at < buf.length) {
    const len = buf.readUInt32BE(at), type = buf.toString('latin1', at + 4, at + 8), data = buf.subarray(at + 8, at + 8 + len);
    if (type === 'IDAT') { idat.push(data); if (!placed) { parts.push(null); placed = true; } } else parts.push(buf.subarray(at, at + 12 + len));
    at += 12 + len;
  }
  const raw = inflateSync(Buffer.concat(idat));
  const w = buf.readUInt32BE(16), h = buf.readUInt32BE(20), depth = buf[24], type = buf[25], interlace = buf[28];
  const bpp = { 2: 3, 6: 4 }[type];
  const rows = [raw].concat(depth === 8 && bpp && !interlace ? refilter(raw, w, h, bpp) : []);
  const z = rows.map((r) => deflateSync(r, { level: 9, memLevel: 9 })).reduce((m, x) => (x.length < m.length ? x : m));
  const out = Buffer.concat(parts.map((p) => p || chunk('IDAT', z)));
  return out.length < buf.length ? out : buf;
}

const main = await pageFor(WIDTH, SCALE);
const ids = await main.page.evaluate(() => [...new Set([...document.querySelectorAll('[data-tab]')].map((e) => e.dataset.tab))]);
const missing = plays.filter((p) => !ids.includes(p.id)).map((p) => p.id);
if (missing.length) await fail(`the page has no tab for ${missing.join(', ')}`);

// captures one figure (by its accessible name) at a width: at device scale 3, or 2 when that is over 1.5 MB
async function capture(play, heads, alt, width) {
  let buf, scale;
  for (scale of [SCALE, FALLBACK_SCALE]) {
    const p = await pageFor(width, scale);
    await showPlay(p, play);
    const f = (await p.page.evaluate(findFigures, { heads, MIN_WIDTH })).find((x) => x.alt === alt);
    if (!f) await fail(`"${alt}" is not in the ${play.id} play at ${width}px`);
    const el = p.page.locator(`[data-figure-capture="${f.index}"]`);
    buf = recompress(await el.screenshot({ animations: 'disabled', scale: 'device' }));
    if (buf.length <= MAX_BYTES) break;
  }
  return { buf, scale };
}

mkdirSync(DIR, { recursive: true });
const figures = [], notes = [], seen = new Set();
if (SCHEME === 'light') {
  // each figure the manifest has a PNG for, at its viewport, the size of its dark capture
  const manifest = JSON.parse(readFileSync(join(OUT, 'figures.json'), 'utf8')).figures;
  for (const m of manifest.filter((x) => !x.native)) {
    const play = plays.find((p) => p.id === m.play);
    const heads = play.blocks.map((b) => (b.type === 'heading' ? b.text : b.heading)).filter(Boolean);
    const { buf, scale } = await capture(play, heads, m.alt, m.viewport);
    const { width, height } = pngSize(buf);
    if (Math.abs(width - m.width) > 3 || Math.abs(height - m.height) > Math.max(6, m.height * 0.01))
      await fail(`${m.id} is ${width} x ${height} in light and ${m.width} x ${m.height} in dark`);
    writeFileSync(join(DIR, `${m.id}.png`), buf);
    seen.add(m.id);
    figures.push({ ...m, width, height, _bytes: buf.length, _scale: scale });
  }
  await stop();
  for (const n of readdirSync(DIR)) if (n.endsWith('.png') && !seen.has(n.slice(0, -4))) { unlinkSync(join(DIR, n)); notes.push(`removed light/${n}, which no figure names`); }
  let total = 0;
  for (const f of figures) { total += f._bytes; console.log(`${f.id.padEnd(24)} ${String(f.width).padStart(5)} x ${String(f.height).padEnd(6)} ${(f._bytes / 1024).toFixed(0).padStart(5)} KB  @${f._scale}x`); }
  for (const n of notes) console.log(`NOTE  ${n}`);
  console.log(`build_figures --light: ${figures.length} figures, ${(total / 1024 / 1024).toFixed(2)} MB in playbook/app/figures/light/`);
  process.exit(0);
}
for (const play of plays) {
  await showPlay(main, play);
  const heads = play.blocks.map((b) => (b.type === 'heading' ? b.text : b.heading)).filter(Boolean);
  const found = await main.page.evaluate(findFigures, { heads, MIN_WIDTH });
  for (const f of found) {
    let id = IDS[f.alt];
    if (!id) { id = slugOf(f.alt); notes.push(`${id}: no id listed for "${f.alt}"; named by its slug`); }
    if (seen.has(id)) await fail(`two figures take the id ${id}`);
    seen.add(id);
    if (NATIVE.has(id)) {
      figures.push({ id, play: play.id, after: f.after, alt: f.alt, native: true, _order: [playOrder.get(play.id), f.index], _bytes: 0, _scale: 0 });
      continue;
    }
    // the narrowest viewport at which the figure is whole
    let viewport = WIDTH;
    if (f.overflow) {
      const why = [`at ${WIDTH}: ${f.overflow}`];
      viewport = null;
      for (const w of WIDER) {
        const p = await pageFor(w, SCALE);
        await showPlay(p, play);
        const g = (await p.page.evaluate(findFigures, { heads, MIN_WIDTH })).find((x) => x.alt === f.alt);
        if (!g) await fail(`"${f.alt}" is not in the ${play.id} play at ${w}px`);
        if (!g.overflow) { viewport = w; break; }
        why.push(`at ${w}: ${g.overflow}`);
      }
      if (viewport === null) { viewport = WIDER[WIDER.length - 1]; notes.push(`WARN ${id} overflows at every width; captured at ${viewport} (${why.join('; ')})`); }
      else notes.push(`${id} overflows at ${WIDTH} (${why.join('; ')}); captured at ${viewport}`);
    }
    const { buf, scale } = await capture(play, heads, f.alt, viewport);
    writeFileSync(join(OUT, `${id}.png`), buf);
    const { width, height } = pngSize(buf);
    figures.push({ id, play: play.id, after: f.after, alt: f.alt, width, height, viewport, _order: [playOrder.get(play.id), f.index], _bytes: buf.length, _scale: scale });
  }
}
await stop();

figures.sort((a, b) => a._order[0] - b._order[0] || a._order[1] - b._order[1]);
for (const n of readdirSync(OUT)) if (n.endsWith('.png') && (!seen.has(n.slice(0, -4)) || NATIVE.has(n.slice(0, -4)))) { unlinkSync(join(OUT, n)); notes.push(`removed ${n}, ${NATIVE.has(n.slice(0, -4)) ? "drawn by the app" : "which no figure names"}`); }
writeFileSync(join(OUT, 'figures.json'), JSON.stringify({ figures: figures.map(({ id, play, after, alt, width, height, viewport, native }) => (native ? { id, play, after, alt, native } : { id, play, after, alt, width, height, viewport })) }, null, 2) + '\n');

let total = 0;
for (const f of figures) {
  total += f._bytes;
  if (f.native) { console.log(`${f.id.padEnd(24)} ${f.play.padEnd(13)} native, drawn by the app  after ${JSON.stringify(f.after)}`); continue; }
  console.log(`${f.id.padEnd(24)} ${f.play.padEnd(13)} ${String(f.width).padStart(5)} x ${String(f.height).padEnd(6)} ${(f._bytes / 1024).toFixed(0).padStart(5)} KB  @${f._scale}x  ${String(f.viewport).padStart(4)}px  after ${f.after === null ? 'null' : JSON.stringify(f.after)}`);
}
for (const n of notes) console.log(`NOTE  ${n}`);
console.log(`build_figures: ${figures.length} figures in ${new Set(figures.map((f) => f.play)).size} plays, ${(total / 1024 / 1024).toFixed(2)} MB in playbook/app/figures/`);
