// Makes web/src/social-card.png, the 1200 x 630 link-preview image, once. The card is a small HTML page built from
// content (the tile, the name, the front door's eyebrow line, the tagline) in the dial theme, with the embedded
// IBM Plex faces, rendered by a headless Chrome over the DevTools Protocol. No packages, no network: Node's
// child_process and built-in WebSocket, as tools/layout_check.mjs does. The PNG is a committed source asset; the page
// build copies it to docs/ and never rebuilds it, so the build stays deterministic.
// Usage: node tools/make_social_card.mjs [--out web/src/social-card.png]
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const outArg = args.indexOf('--out') >= 0 ? args[args.indexOf('--out') + 1] : 'web/src/social-card.png';
const OUT = resolve(ROOT, outArg);
const W = 1200, H = 630;

const d = JSON.parse(readFileSync(join(ROOT, 'content', 'stack.json'), 'utf8'));
const css = readFileSync(join(ROOT, 'web', 'src', 'styles.css'), 'utf8');
// the dial theme: the tokens of the chosen-dark block at the top of styles.css
const block = css.slice(css.indexOf(':root[data-theme="dark"] {'), css.indexOf('}', css.indexOf(':root[data-theme="dark"] {')));
const tok = (name) => { const m = new RegExp(`--${name}:\\s*(#[0-9A-Fa-f]{6})`).exec(block); if (!m) throw new Error(`token --${name} missing`); return m[1]; };
const svg = readFileSync(join(ROOT, 'web', 'src', 'mark.svg'), 'utf8');
const viewBox = /viewBox="([^"]+)"/.exec(svg)[1];
const paths = (svg.match(/<path\b[^>]*\/>/g) || []).join('');
const face = (family, weight, file) => `@font-face { font-family: '${family}'; font-weight: ${weight}; font-style: normal; src: url(data:font/woff2;base64,${readFileSync(join(ROOT, 'web', 'src', 'fonts', file)).toString('base64')}) format('woff2'); }`;
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><style>
${face('IBM Plex Sans', 400, 'IBMPlexSans-Regular-Latin1.woff2')}
${face('IBM Plex Sans', 700, 'IBMPlexSans-Bold-Latin1.woff2')}
${face('IBM Plex Mono', 700, 'IBMPlexMono-Bold-Latin1.woff2')}
html, body { margin: 0; width: ${W}px; height: ${H}px; background: ${tok('bg')}; }
body { box-sizing: border-box; padding: 76px 88px; font-family: 'IBM Plex Sans', sans-serif; color: ${tok('fg')}; position: relative; }
body::after { content: ""; position: absolute; left: 88px; right: 88px; bottom: 64px; border-top: 1px solid ${tok('line-strong')}; }
.tile { width: 116px; height: 116px; border-radius: 26px; background: ${tok('tile-bg')}; box-shadow: inset 0 0 0 1px ${tok('line-strong')}; display: grid; place-items: center; color: ${tok('tile-fg')}; margin-bottom: 36px; }
.tile svg { width: 82px; height: 82px; }
.eyebrow { font-family: 'IBM Plex Mono', monospace; font-weight: 700; font-size: 22px; letter-spacing: 0.14em; text-transform: uppercase; color: ${tok('accent')}; margin: 0 0 14px; }
h1 { font-size: 84px; line-height: 1; margin: 0 0 22px; letter-spacing: -0.01em; }
p.lede { font-size: 29px; line-height: 1.4; color: ${tok('fg-2')}; margin: 0; max-width: 1000px; }
</style></head><body>
<div class="tile"><svg viewBox="${viewBox}" aria-hidden="true">${paths}</svg></div>
<p class="eyebrow">${esc(d.ui.labels.heroEyebrow)}</p>
<h1>${esc(d.meta.name)}</h1>
<p class="lede">${esc(d.meta.tagline)}</p>
</body></html>`;

const CANDIDATES = [process.env.LENSATIC_CHROME, '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium', '/usr/bin/google-chrome', '/usr/bin/chromium'].filter(Boolean);
const browserPath = CANDIDATES.find((p) => existsSync(p));
if (!browserPath) { console.error('no Chrome or Chromium found; set LENSATIC_CHROME'); process.exit(2); }
// the card page and the browser profile live in the repo's own .tmp/ (gitignored)
const repoTmp = join(ROOT, '.tmp');
mkdirSync(repoTmp, { recursive: true });
const work = mkdtempSync(join(repoTmp, 'lensatic-card-'));
const cardFile = join(work, 'card.html');
writeFileSync(cardFile, html);
const proc = spawn(browserPath, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${join(work, 'profile')}`, '--no-first-run',
  '--no-default-browser-check', '--disable-gpu', '--hide-scrollbars', 'about:blank'], { stdio: ['ignore', 'ignore', 'pipe'] });
const cleanup = () => { try { proc.kill('SIGKILL'); } catch { /* gone */ } try { rmSync(work, { recursive: true, force: true }); } catch { /* busy */ } };
const timer = setTimeout(() => { console.error('timed out'); cleanup(); process.exit(2); }, 60000);
const wsUrl = await new Promise((res, rej) => {
  let buf = '';
  proc.stderr.on('data', (c) => { buf += c; const m = /DevTools listening on (ws:\/\/\S+)/.exec(buf); if (m) res(m[1]); });
  proc.on('exit', () => rej(new Error('browser exited')));
});
const ws = new WebSocket(wsUrl);
await new Promise((res) => ws.addEventListener('open', res, { once: true }));
let nextId = 1;
const pending = new Map();
const listeners = [];
ws.addEventListener('message', (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) { const { res, rej } = pending.get(msg.id); pending.delete(msg.id); msg.error ? rej(new Error(msg.error.message)) : res(msg.result); }
  else if (msg.method) listeners.forEach((l) => l(msg));
});
const send = (method, params = {}, sessionId) => new Promise((res, rej) => {
  const id = nextId++; pending.set(id, { res, rej });
  ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
});
const once = (method, sessionId) => new Promise((res) => {
  const l = (m) => { if (m.method === method && m.sessionId === sessionId) { listeners.splice(listeners.indexOf(l), 1); res(m.params); } };
  listeners.push(l);
});
const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
await send('Page.enable', {}, sessionId);
await send('Emulation.setDeviceMetricsOverride', { width: W, height: H, deviceScaleFactor: 1, mobile: false }, sessionId);
const loaded = once('Page.loadEventFired', sessionId);
await send('Page.navigate', { url: pathToFileURL(cardFile).href }, sessionId);
await loaded;
const r = await send('Runtime.evaluate', { expression: 'document.fonts.ready.then(() => [...document.fonts].filter((f) => f.status === "loaded").length)', awaitPromise: true, returnByValue: true }, sessionId);
const shot = await send('Page.captureScreenshot', { format: 'png', clip: { x: 0, y: 0, width: W, height: H, scale: 1 } }, sessionId);
writeFileSync(OUT, Buffer.from(shot.data, 'base64'));
clearTimeout(timer);
console.log(`wrote ${OUT}: ${W} x ${H}, ${r.result.value} faces loaded`);
ws.close();
cleanup();
process.exit(0);
