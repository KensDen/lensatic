// Makes a 1200 x 630 link-preview card, once, for one Lensatic page: the hub (web/src/social-card.png, which the hub and
// the map share), the Zero Trust guide (guides/zero-trust/social-card.png) or the Agentic SecOps playbook
// (playbook/social-card.png). Lensatic 2.0 (18 October 2026) made them one family in the Lensatic field system: the
// page's own mark, eyebrow, title and lede on the dark ground with the faint grid, and the same lower band on every card
// (the compass, Lensatic, the three section names, the address, over a rule in the three section colours). The text is
// hub/site.json's cards entry; the colours are hub/lensatic.css's dark tokens. Each card is a small HTML page with the
// embedded IBM Plex faces, rendered by a headless Chrome over the DevTools Protocol. No packages, no network: Node's
// child_process and built-in WebSocket, as tools/layout_check.mjs does. The PNG is a committed source asset; the builds
// copy it and never rebuild it, so they stay deterministic.
// Usage: node tools/make_social_card.mjs --card hub|zero-trust|playbook [--out PATH]
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const arg = (k, dflt) => (args.indexOf(k) >= 0 ? args[args.indexOf(k) + 1] : dflt);
const CARD = arg('--card', 'hub');
const DEFAULT_OUT = { hub: 'web/src/social-card.png', 'zero-trust': 'guides/zero-trust/social-card.png', playbook: 'playbook/social-card.png' };
if (!DEFAULT_OUT[CARD]) { console.error(`unknown card ${CARD}`); process.exit(2); }
const OUT = resolve(ROOT, arg('--out', DEFAULT_OUT[CARD]));
const W = 1200, H = 630;

const site = JSON.parse(readFileSync(join(ROOT, 'hub', 'site.json'), 'utf8'));
const card = site.cards[CARD];
const css = readFileSync(join(ROOT, 'hub', 'lensatic.css'), 'utf8');
// the dark theme: the chosen-dark block of the shared file
const block = css.slice(css.indexOf(':root[data-theme="dark"] {'), css.indexOf('}', css.indexOf(':root[data-theme="dark"] {')));
const tok = (name) => { const m = new RegExp(`--${name}:\\s*(#[0-9A-Fa-f]{6})`).exec(block); if (!m) throw new Error(`token --${name} missing`); return m[1]; };
const svg = readFileSync(join(ROOT, 'web', 'src', 'mark.svg'), 'utf8');
const viewBox = /viewBox="([^"]+)"/.exec(svg)[1];
const paths = (svg.match(/<path\b[^>]*\/>/g) || []).join('');
const compass = (cls) => `<div class="${cls}"><svg viewBox="${viewBox}" aria-hidden="true">${paths}</svg></div>`;
const dataUri = (file, mime) => `data:${mime};base64,${readFileSync(join(ROOT, file)).toString('base64')}`;
const MARKS = {
  compass: () => compass('tile'),
  zero: () => `<img class="mark" src="${dataUri('guides/zero-trust/icon.svg', 'image/svg+xml')}" alt="">`,
  emblem: () => `<img class="mark" src="${dataUri('hub/marks/apt-unicorn-emblem.webp', 'image/webp')}" alt="">`,
};
const face = (family, weight, file) => `@font-face { font-family: '${family}'; font-weight: ${weight}; font-style: normal; src: url(data:font/woff2;base64,${readFileSync(join(ROOT, 'web', 'src', 'fonts', file)).toString('base64')}) format('woff2'); }`;
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const sec = { maps: tok('sec-maps'), guides: tok('sec-guides'), playbook: tok('sec-playbook') };
const eyebrowColour = card.accent ? sec[card.accent] : tok('fg-2');   // the hub names all three sections, so its eyebrow is neutral

const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><style>
${face('IBM Plex Sans', 400, 'IBMPlexSans-Regular-Latin1.woff2')}
${face('IBM Plex Sans', 700, 'IBMPlexSans-Bold-Latin1.woff2')}
${face('IBM Plex Mono', 700, 'IBMPlexMono-Bold-Latin1.woff2')}
html, body { margin: 0; width: ${W}px; height: ${H}px; }
body { box-sizing: border-box; position: relative; font-family: 'IBM Plex Sans', sans-serif; color: ${tok('fg')}; background-color: ${tok('bg')};
  background-image: linear-gradient(rgba(69,196,244,0.05) 1px, transparent 1px), linear-gradient(90deg, rgba(69,196,244,0.05) 1px, transparent 1px);
  background-size: 60px 60px; }
.main { position: absolute; left: 88px; right: 88px; top: 64px; }
.tile { width: 108px; height: 108px; border-radius: 24px; background: ${tok('tile-bg')}; box-shadow: inset 0 0 0 1px ${tok('line-strong')};
  display: grid; place-items: center; color: ${tok('tile-fg')}; margin-bottom: 30px; }
.tile svg { width: 76px; height: 76px; }
.mark { display: block; width: 108px; height: 108px; margin-bottom: 30px; }
.eyebrow { font-family: 'IBM Plex Mono', monospace; font-weight: 700; font-size: 22px; letter-spacing: 0.14em; text-transform: uppercase;
  color: ${eyebrowColour}; margin: 0 0 14px; }
h1 { font-size: 78px; line-height: 1; margin: 0 0 20px; letter-spacing: -0.015em; }
p.lede { font-size: 26px; line-height: 1.38; color: ${tok('fg-2')}; margin: 0; max-width: 1024px; }
.band { position: absolute; left: 0; right: 0; bottom: 0; height: 92px; background: ${tok('bg-2')}; display: flex; align-items: center; gap: 18px;
  padding: 0 88px; box-sizing: border-box; }
.band::before { content: ""; position: absolute; left: 0; right: 0; top: 0; height: 5px;
  background: linear-gradient(90deg, ${sec.maps} 0 33.34%, ${sec.guides} 33.34% 66.67%, ${sec.playbook} 66.67% 100%); }
.band .btile { width: 44px; height: 44px; border-radius: 10px; background: ${tok('tile-bg')}; display: grid; place-items: center; color: ${tok('tile-fg')}; }
.band .btile svg { width: 31px; height: 31px; }
.band .name { font-weight: 700; font-size: 28px; }
.band .line { font-size: 22px; color: ${tok('fg-2')}; }
.band .addr { margin-left: auto; font-family: 'IBM Plex Mono', monospace; font-weight: 700; font-size: 20px; color: ${tok('accent')}; }
</style></head><body>
<div class="main">${MARKS[card.mark]()}<p class="eyebrow">${esc(card.eyebrow)}</p><h1>${esc(card.title)}</h1><p class="lede">${esc(card.lede)}</p></div>
<div class="band">${compass('btile')}<span class="name">${esc(site.name)}</span><span class="line">${esc(site.cardBand.line)}</span><span class="addr">${esc(site.cardBand.address)}</span></div>
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
