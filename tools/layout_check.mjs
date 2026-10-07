// Layout measurements for the built wrapper in a real browser engine. No packages: Node's child_process,
// its built-in WebSocket, and the Chrome DevTools Protocol against a headless Chrome, Chromium or Edge.
// Usage: node tools/layout_check.mjs web/lensatic.html [--pdf out.pdf]
// Prints one JSON object. Exit 0 when measured (the caller judges), 2 when no browser could be driven.
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const args = process.argv.slice(2);
const file = args[0];
const opt = (name) => { const i = args.indexOf(name); return i > 0 ? args[i + 1] : null; };
if (!file) { console.error('usage: node layout_check.mjs <built.html> [--pdf out.pdf]'); process.exit(2); }

const CANDIDATES = [
  process.env.LENSATIC_CHROME,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
  '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/microsoft-edge',
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
].filter(Boolean);
const browserPath = CANDIDATES.find((p) => existsSync(p));
if (!browserPath) { console.log(JSON.stringify({ error: 'no Chrome, Chromium or Edge found; set LENSATIC_CHROME' })); process.exit(2); }
if (typeof WebSocket !== 'function') { console.log(JSON.stringify({ error: 'this Node has no built-in WebSocket (Node 22 or later needed)' })); process.exit(2); }

// the browser profile lives in the repo's own .tmp/ (gitignored), so nothing is written outside the repo
const repoTmp = join(dirname(fileURLToPath(import.meta.url)), '..', '.tmp');
mkdirSync(repoTmp, { recursive: true });
const profile = mkdtempSync(join(repoTmp, 'lensatic-cdp-'));
const proc = spawn(browserPath, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--no-first-run',
  '--no-default-browser-check', '--disable-gpu', '--hide-scrollbars=false', '--allow-file-access-from-files', 'about:blank'],
  { stdio: ['ignore', 'ignore', 'pipe'] });
const cleanup = () => { try { proc.kill('SIGKILL'); } catch { /* gone */ } try { rmSync(profile, { recursive: true, force: true }); } catch { /* busy */ } };
// stdout to a pipe is asynchronous in Node: exit only after the write has flushed
const emit = (obj, code) => process.stdout.write(JSON.stringify(obj) + '\n', () => { cleanup(); process.exit(code); });
const fail = (msg) => { emit({ error: msg }, 2); return new Promise(() => {}); };  // halts here; the write callback exits
const timer = setTimeout(() => fail('timed out driving the browser'), 150000);

const wsUrl = await new Promise((res, rej) => {
  let buf = '';
  proc.stderr.on('data', (c) => { buf += c; const m = /DevTools listening on (ws:\/\/\S+)/.exec(buf); if (m) res(m[1]); });
  proc.on('exit', () => rej(new Error('browser exited')));
}).catch((e) => fail(e.message));  // never resolves on failure

const ws = new WebSocket(wsUrl);
await new Promise((res) => ws.addEventListener('open', res, { once: true }));
let nextId = 1;
const pending = new Map();
const listeners = [];
ws.addEventListener('message', (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    const { res, rej } = pending.get(msg.id); pending.delete(msg.id);
    msg.error ? rej(new Error(msg.error.message)) : res(msg.result);
  } else if (msg.method) { listeners.forEach((l) => l(msg)); }
});
const send = (method, params = {}, sessionId) => new Promise((res, rej) => {
  const id = nextId++; pending.set(id, { res, rej });
  ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
});
const once = (method, sessionId) => new Promise((res) => {
  const l = (m) => { if (m.method === method && m.sessionId === sessionId) { listeners.splice(listeners.indexOf(l), 1); res(m.params); } };
  listeners.push(l);
});

const url = pathToFileURL(resolve(file)).href;
async function page({ width, height = 900, js = true, media = 'screen', mobile = false }) {
  const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
  await send('Page.enable', {}, sessionId);
  await send('Runtime.enable', {}, sessionId);
  await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile }, sessionId);
  // a phone is a touch screen: (pointer: coarse) matches, so the 44 px tap targets are what gets measured (Session 7)
  await send('Emulation.setTouchEmulationEnabled', mobile ? { enabled: true, maxTouchPoints: 5 } : { enabled: false }, sessionId);
  await send('Emulation.setScriptExecutionDisabled', { value: !js }, sessionId);
  await send('Emulation.setEmulatedMedia', { media: media === 'print' ? 'print' : '' }, sessionId);
  const loaded = once('Page.loadEventFired', sessionId);
  await send('Page.navigate', { url }, sessionId);
  await loaded;
  const evaluate = async (expression) => {
    const r = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true }, sessionId);
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
    return r.result.value;
  };
  return { targetId, sessionId, evaluate, close: () => send('Target.closeTarget', { targetId }) };
}

const MEASURE = `(() => {
  const r = (sel) => { const e = document.querySelector(sel); return e ? e.getBoundingClientRect() : null; };
  const wrap = document.querySelector('#matrix-dow .matrix-wrap');
  const table = r('#table-dow');
  const cisaWrap = document.querySelector('#matrix-cisa .matrix-wrap');
  return {
    viewport: document.documentElement.clientWidth,
    pageScrollWidth: document.documentElement.scrollWidth,
    scripted: document.documentElement.classList.contains('ready'),
    dowTableWidth: table ? Math.round(table.width * 10) / 10 : null,
    dowWrapClient: wrap ? wrap.clientWidth : null,
    dowWrapScroll: wrap ? wrap.scrollWidth : null,
    cisaHidden: document.querySelector('#matrix-cisa')?.hidden ?? null,
    cisaWrapClient: cisaWrap ? cisaWrap.clientWidth : null,
    cisaWrapScroll: cisaWrap ? cisaWrap.scrollWidth : null,
    openCells: document.querySelectorAll('#table-dow details.celld[open]').length,
    colnavHidden: document.querySelector('#matrix-dow .colnav')?.hidden ?? null,
    smallTargets: [...document.querySelectorAll('a, button, summary')].filter((e) => {
      const b = e.getBoundingClientRect(); if (!b.width || !b.height) return false;
      if (e.closest('p, li, dd, td > details .more, .small, small')) return false;
      return b.width < 44 || b.height < 44;
    }).map((e) => e.id || e.className || e.tagName).slice(0, 20),
  };
})()`;

// clipped content: with every disclosure open, nothing outside the matrix scroll box or the section-link strip may reach past
// the viewport's right edge (main clips sideways overflow, so the page's scroll width alone cannot see it)
const CLIPPED = `(() => {
  document.querySelectorAll('details').forEach((d) => { d.open = true; });
  const vw = document.documentElement.clientWidth;
  const out = [];
  for (const e of document.querySelectorAll('main *, header *')) {
    if (e.closest('.matrix-wrap, .nav, svg')) continue;
    const r = e.getBoundingClientRect();
    if (!r.width || !r.height) continue;
    if (r.right > vw + 1) out.push((e.closest('[id]') || {}).id + ' ' + e.tagName.toLowerCase() + ' ' + Math.round(r.right));
  }
  return out.slice(0, 10);
})()`;

// the header never scrolls or spills sideways: on narrow screens the section links are one menu button; where the
// strip of links shows, it must fit without scrolling
const HEADER = `(() => {
  const vw = document.documentElement.clientWidth;
  const h = document.getElementById('top');
  const menu = document.getElementById('navmenu');
  const nav = document.getElementById('nav');
  const bad = [];
  for (const e of h.querySelectorAll('*')) {
    if (menu && !menu.open && e.closest('.navmenu-list')) continue;
    if (e.closest('svg')) continue;
    const r = e.getBoundingClientRect();
    if (!r.width || !r.height) continue;
    if (r.right > vw + 1 || r.left < -1) bad.push((e.id || e.className || e.tagName) + ' ' + Math.round(r.left) + '..' + Math.round(r.right));
  }
  const navShown = getComputedStyle(nav).display !== 'none';
  return { vw, headerScroll: h.scrollWidth, headerClient: h.clientWidth, navShown, navOverflow: navShown ? nav.scrollWidth - nav.clientWidth : 0,
           menuShown: menu ? getComputedStyle(menu).display !== 'none' : false, bad: bad.slice(0, 5) };
})()`;

// tap targets (Session 7): chips at least 44 px tall on a coarse pointer, at least 36 px on a fine one; buttons and menu
// links at least 44 px
const TARGETS = `(() => {
  const coarse = matchMedia('(pointer: coarse)').matches;
  const floor = coarse ? 44 : 36;
  const small = [];
  let chips = 0;
  for (const e of document.querySelectorAll('.chip')) {
    const r = e.getBoundingClientRect(); if (!r.height) continue;
    chips++;
    if (r.height < floor - 0.5) small.push((e.textContent || '').trim() + ' ' + Math.round(r.height));
  }
  const menu = document.getElementById('navmenu');
  const wasOpen = menu ? menu.open : false;
  if (menu && getComputedStyle(menu).display !== 'none') menu.open = true;  // the menu's links are measured open
  const controls = [...document.querySelectorAll('.btn, .navmenu-list a, .foot-nav a, .colbtn')].filter((e) => { const r = e.getBoundingClientRect(); return r.width && (r.height < 43.5 || r.width < 43.5); })
    .map((e) => (e.id || e.className) + ' ' + Math.round(e.getBoundingClientRect().width) + 'x' + Math.round(e.getBoundingClientRect().height));
  const menuLinks = menu && menu.open ? [...menu.querySelectorAll('.navmenu-list a')].filter((e) => e.getBoundingClientRect().height).length : 0;
  if (menu) menu.open = wasOpen;
  return { coarse, floor, chips, menuLinks, small: small.slice(0, 5), controls: controls.slice(0, 5) };
})()`;

// visible text with every disclosure opened the way a reader would open it (clicks, not script-created text)
const VISIBLE_TEXT = `(() => { document.querySelectorAll('details').forEach((d) => { d.open = true; }); const st = document.createElement('style'); st.textContent = '.xp { display: none !important; }'; document.head.appendChild(st); const t = document.body.innerText; st.remove(); return t; })()`;

const out = { browser: browserPath, file: resolve(file) };
try {
  for (const w of [1280, 1440]) {
    const p = await page({ width: w });
    out[`js_${w}`] = await p.evaluate(MEASURE);
    await p.close();
  }
  {
    const p = await page({ width: 375, height: 812, mobile: true });
    out.js_375 = await p.evaluate(MEASURE);
    out.js_375.targets = await p.evaluate(TARGETS);
    out.js_375.afterNext = await p.evaluate(`(async () => { const w = document.querySelector('#matrix-dow .matrix-wrap'); document.querySelector('#matrix-dow .colbtn.next').click(); await new Promise(r => setTimeout(r, 700)); return { scrollLeft: w.scrollLeft, fadeLeft: document.querySelector('#matrix-dow .matrix-frame').classList.contains('clip-left') }; })()`);
    // arrow keys: real key events from the protocol while the scroll container has focus
    const before = await p.evaluate(`(() => { const w = document.querySelector('#matrix-dow .matrix-wrap'); w.scrollLeft = 0; w.focus(); return document.activeElement === w; })()`);
    await send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'ArrowRight', code: 'ArrowRight', windowsVirtualKeyCode: 39 }, p.sessionId);
    await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'ArrowRight', code: 'ArrowRight', windowsVirtualKeyCode: 39 }, p.sessionId);
    out.js_375.arrowKey = await p.evaluate(`(async () => { await new Promise(r => setTimeout(r, 700)); const w = document.querySelector('#matrix-dow .matrix-wrap'); const hs = [...document.querySelectorAll('#table-dow thead th')]; const stops = hs.slice(1).map((h) => h.offsetLeft - hs[0].offsetWidth); return { focused: ${before}, scrollLeft: w.scrollLeft, expectedStop: stops.find((x) => x > 2) }; })()`);
    // back to top appears after the first screenful
    out.js_375.backToTop = await p.evaluate(`(async () => { const t = document.getElementById('to-top'); window.scrollTo({ top: 0, behavior: 'instant' }); await new Promise(r => setTimeout(r, 400)); const atTop = getComputedStyle(t).visibility; window.scrollTo({ top: innerHeight * 3, behavior: 'instant' }); await new Promise(r => setTimeout(r, 400)); return { atTop, afterScroll: getComputedStyle(t).visibility, hiddenAttr: t.hidden }; })()`);
    await p.close();
  }
  out.header = {};
  for (const w of [360, 375, 390, 414, 480, 768, 1024, 1199, 1200, 1280, 1440]) {
    for (const js of [true, false]) {
      const p = await page({ width: w, height: 812, js, mobile: w < 768 });
      out.header[`${w}_${js ? 'js' : 'nojs'}`] = await p.evaluate(HEADER);
      if (js && (w === 360 || w === 1280)) { out.targets = out.targets || {}; out.targets[w] = await p.evaluate(TARGETS); }
      if (w === 375 || w === 768) {
        // matrix cells in every table a reader can see: is the pillar name shown, and does it match the column?
        out.pillars = out.pillars || {};
        out.pillars[`${w}_${js ? 'js' : 'nojs'}`] = await p.evaluate(`(() => {
          const res = { cells: 0, shown: 0, mismatch: [] };
          document.querySelectorAll('table td').forEach((td) => {
            const l = td.querySelector('.pillar-label'); const tb = td.closest('table');
            if (!l || !tb.getClientRects().length) return;
            res.cells++;
            if (getComputedStyle(l).display !== 'none' && l.getBoundingClientRect().height > 0) res.shown++;
            const th = tb.tHead && tb.tHead.rows[0].cells[td.cellIndex];
            if (!th || !th.textContent.replace(/\\s+/g, ' ').includes(l.textContent.trim())) res.mismatch.push(td.id);
          });
          return res;
        })()`);
      }
      if (js && (w === 360 || w === 375)) {
        // bring each section into the band the page watches and read the menu button: the section in view must be
        // named, in full (no ellipsis), inside the window
        out.header[`current${w}`] = await p.evaluate(`(async () => {
          const res = [];
          for (const a of document.querySelectorAll('#navmenu .navmenu-list a')) {
            const sec = document.getElementById('view-' + a.getAttribute('data-sec'));
            window.scrollTo({ top: sec.getBoundingClientRect().top + scrollY - innerHeight * 0.42 + 4, behavior: 'instant' });
            await new Promise(r => setTimeout(r, 250));
            const c = document.querySelector('#navmenu .navmenu-current');
            const s = document.querySelector('#navmenu > summary').getBoundingClientRect();
            const band = innerHeight * 0.425, sr = sec.getBoundingClientRect();
            res.push({ sec: a.getAttribute('data-sec'), inBand: sr.top <= band && sr.bottom >= band, hidden: c.hidden, text: c.textContent,
              expected: a.textContent, truncated: c.scrollWidth > c.clientWidth + 1, right: Math.round(Math.max(s.right, c.getBoundingClientRect().right)),
              vw: document.documentElement.clientWidth });
          }
          // back at the top, in the intro, no section is in view: the button must not keep naming the last one
          window.scrollTo({ top: 0, behavior: 'instant' });
          await new Promise(r => setTimeout(r, 250));
          const c = document.querySelector('#navmenu .navmenu-current');
          res.push({ sec: '(top)', top: true, hidden: c.hidden, text: c.textContent, marked: document.querySelectorAll('#navmenu a[aria-current], #nav a[aria-current]').length });
          return res;
        })()`);
      }
      await p.close();
    }
  }
  out.clipped = {};
  for (const w of [360, 375, 390, 414]) {
    for (const js of [true, false]) {
      const p = await page({ width: w, height: 812, js, mobile: true });
      out.clipped[`${w}_${js ? 'js' : 'nojs'}`] = await p.evaluate(CLIPPED);
      await p.close();
    }
  }
  for (const w of [375, 1280]) {
    const p = await page({ width: w, height: 900, js: false, mobile: w < 768 });
    out[`nojs_${w}`] = await p.evaluate(MEASURE);
    // opening disclosures from the protocol runs even with page scripts disabled
    out[`nojs_${w}`].visibleText = await p.evaluate(VISIBLE_TEXT);
    await p.close();
  }
  // print, with the behavior script and without it: the stylesheet alone must open every disclosure
  for (const js of [true, false]) {
    const p = await page({ width: 816, height: 1056, media: 'print', js });
    if (js) await p.evaluate(`(() => { window.dispatchEvent(new Event('beforeprint')); return 1; })()`);
    const m = await p.evaluate(MEASURE);
    m.closedDetails = await p.evaluate(`document.querySelectorAll('details:not([open])').length`);
    // text as printed, leaving out the expansions the build adds after abbreviations (they are checked separately)
    m.text = await p.evaluate(`(() => { const st = document.createElement('style'); st.textContent = '.xp { display: none !important; }'; document.head.appendChild(st); const t = document.body.innerText; st.remove(); return t; })()`);
    const { data } = await send('Page.printToPDF', { printBackground: false, paperWidth: 8.5, paperHeight: 11 }, p.sessionId);
    const pdf = Buffer.from(data, 'base64');
    m.pages = (pdf.toString('latin1').match(/\/Type\s*\/Page(?!s)/g) || []).length;
    const pdfPath = opt('--pdf');
    if (pdfPath) {
      writeFileSync(js ? pdfPath : pdfPath.replace(/\.pdf$/, '') + '-nojs.pdf', pdf);
      m.pdf = resolve(js ? pdfPath : pdfPath.replace(/\.pdf$/, '') + '-nojs.pdf');
    }
    out[js ? 'print' : 'print_nojs'] = m;
    await p.close();
  }
} catch (e) {
  await fail(`measurement failed: ${e.message}`);
}
clearTimeout(timer);
ws.close();
emit(out, 0);
