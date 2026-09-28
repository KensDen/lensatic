#!/usr/bin/env node
/* render_check.cjs — Agentic SecOps headless render battery.
 * Requires a Chrome/Chromium binary and puppeteer (or puppeteer-core).
 *   CHROME_PATH=/path/to/chrome node Validation/render_check.cjs
 *   node Validation/render_check.cjs /tmp/scratch.html   (canary / ad-hoc target)
 * If neither resolves, exits with code 2 (SKIPPED) so battery.cjs can
 * report it without failing the run.
 *
 * Verifies in a real browser (file://):
 *   - app mounts; all 35 tabs route by hash with unique "NN / 35" counters
 *   - Action Plan chips compute All-85 / Now-40 / Next-35 / Later-10 live
 *   - CSV export = header + 85 rows; Markdown export = 85 bullets
 *   - search returns results; ArrowDown/Enter selects and navigates
 *   - every tab renders each of its body headings exactly once (P14, Round I)
 *   - every embedded poster fits its frame at 1280 px, after a resize to 390 px and after the resize back,
 *     with no reload, and the frames hold still (Round M)
 *   - zero console errors, zero page errors throughout
 */
const path = require('path');
const fs = require('fs');

const SUITE = path.resolve(__dirname, '..');
const HTML = process.argv[2] || process.env.RENDER_CHECK_HTML || path.join(SUITE, 'Playbook', 'index.html');

function resolvePuppeteer() {
  const candidates = [
    'puppeteer', 'puppeteer-core',
  ];
  for (const c of candidates) { try { return require(c); } catch (e) {} }
  return null;
}
/* scan puppeteer's managed-browser cache for a Chrome-for-Testing binary
 * (puppeteer.executablePath() is async in current puppeteer, so probe the
 * cache dir directly — cross-platform, no version coupling) */
function puppeteerCacheChrome() {
  const os = require('os');
  const root = path.join(process.env.PUPPETEER_CACHE_DIR || path.join(os.homedir(), '.cache', 'puppeteer'), 'chrome');
  const tails = [
    ['chrome-linux64', 'chrome'],
    ['chrome-mac-x64', 'Google Chrome for Testing.app', 'Contents', 'MacOS', 'Google Chrome for Testing'],
    ['chrome-mac-arm64', 'Google Chrome for Testing.app', 'Contents', 'MacOS', 'Google Chrome for Testing'],
    ['chrome-win64', 'chrome.exe'],
  ];
  let out = [];
  try {
    for (const dir of fs.readdirSync(root)) {
      for (const tail of tails) out.push(path.join(root, dir, ...tail));
    }
  } catch (e) { /* no cache dir */ }
  return out;
}
function resolveChrome() {
  const cands = [
    process.env.CHROME_PATH, process.env.PUPPETEER_EXECUTABLE_PATH,
    '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  ].filter(Boolean);
  for (const c of cands) { try { if (fs.existsSync(c)) return c; } catch (e) {} }
  return null;
}
/* no CHROME_PATH and no known system Chrome: use the browser puppeteer manages
 * (await puppeteer.executablePath(), only if that binary exists), then the cache scan */
async function fallbackChrome(puppeteer) {
  try {
    const p = puppeteer && typeof puppeteer.executablePath === 'function' ? await puppeteer.executablePath() : null;
    if (p && fs.existsSync(p)) return p;
  } catch (e) { /* puppeteer-core without a configured browser throws */ }
  for (const c of puppeteerCacheChrome()) { try { if (fs.existsSync(c)) return c; } catch (e) {} }
  return null;
}

const TABS = ['overview', 'dualuse', 'humancommand', 'aiessentials', 'foundations', 'red', 'blue',
  'purple', 'maturity', 'roadmap', 'program', 'architecture', 'usecase', 'infra', 'netsec',
  'otics', 'metrics', 'governance', 'compliance', 'threatmodel', 'federal', 'classified',
  'insiders', 'tradecraft', 'containment', 'agentir', 'vendor', 'cscrm', 'threats', 'cti',
  'hunting', 'frontier', 'frameworks', 'academic', 'cases', 'tools', 'risks', 'fluency',
  'learningpath', 'actionplan', 'resources'];

(async () => {
  const puppeteer = resolvePuppeteer();
  const chrome = resolveChrome() || await fallbackChrome(puppeteer);
  if (!puppeteer || !chrome) {
    console.log('RENDER CHECK SKIPPED: ' + (!puppeteer ? 'puppeteer not installed. ' : '') +
      (!chrome ? 'no Chrome binary found (set CHROME_PATH).' : ''));
    process.exit(2);
  }

  const consoleErrors = [], pageErrors = [];
  const browser = await puppeteer.launch({
    executablePath: chrome, headless: 'shell',
    args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 900 });
  page.on('console', (m) => { if (m.type() === 'error') consoleErrors.push(m.text().slice(0, 180)); });
  page.on('pageerror', (e) => pageErrors.push(String(e).slice(0, 180)));

  const results = [];
  let failures = 0;
  const check = (name, ok, detail) => { results.push([name, ok, detail || '']); if (!ok) failures++; };

  await page.goto('file://' + HTML, { waitUntil: 'load', timeout: 60000 });
  await page.waitForFunction(() => {
    const r = document.getElementById('root');
    return r && r.innerText.length > 200;
  }, { timeout: 30000 });
  check('app mounts', true);

  const tabResults = await page.evaluate(async (tabs) => {
    const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
    const out = [];
    for (const id of tabs) {
      location.hash = '#' + id;
      await sleep(90);
      const counter = (document.body.innerText.match(/(\d{2}) \/ (\d{2})/) || [])[0] || '';
      out.push({ id, counter, len: document.body.innerText.length });
    }
    return out;
  }, TABS);
  const uniq = new Set(tabResults.map((t) => t.counter)).size;
  const allOf35 = tabResults.every((t) => / \/ 35$/.test(' ' + t.counter));
  const dead = tabResults.filter((t) => !t.counter || t.len < 500).map((t) => t.id);
  check('35 tabs route with unique /35 counters', uniq === 35 && allOf35 && !dead.length,
    `unique=${uniq}` + (dead.length ? ` dead=${dead}` : ''));

  const plan = await page.evaluate(async () => {
    const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
    location.hash = '#actionplan';
    await sleep(300);
    const t = document.body.innerText;
    const chip = (n) => { const m = t.match(new RegExp(n + ' \u00b7 (\\d+)')); return m ? +m[1] : null; };
    return { all: chip('All'), now: chip('Now'), next: chip('Next'), later: chip('Later') };
  });
  check('Action Plan live counts 85/40/35/10',
    plan.all === 85 && plan.now === 40 && plan.next === 35 && plan.later === 10,
    JSON.stringify(plan));

  const csv = await page.evaluate(async () => new Promise((res) => {
    const orig = URL.createObjectURL.bind(URL); let captured = null;
    URL.createObjectURL = (b) => { captured = b; return orig(b); };
    const btn = Array.from(document.querySelectorAll('button')).find((b) => /CSV/.test(b.textContent));
    if (!btn) return res({ ok: false });
    btn.click();
    setTimeout(async () => {
      if (!captured) return res({ ok: false });
      const text = await captured.text();
      const lines = text.split('\r\n').filter(Boolean);
      res({ ok: lines.length === 86 && lines[0] === 'Phase,Owner,Action,Tab,Source,Frameworks,Implementation', lines: lines.length });
    }, 300);
  }));
  check('CSV export 86 lines (header+85)', csv.ok, `lines=${csv.lines}`);

  const md = await page.evaluate(async () => new Promise((res) => {
    const orig = URL.createObjectURL.bind(URL); let captured = null;
    URL.createObjectURL = (b) => { captured = b; return orig(b); };
    const btn = Array.from(document.querySelectorAll('button')).find((b) => /MD$/.test(b.textContent.trim()));
    if (!btn) return res({ ok: false });
    btn.click();
    setTimeout(async () => {
      if (!captured) return res({ ok: false });
      const text = await captured.text();
      res({ ok: (text.match(/^- \*\*/gm) || []).length === 85 });
    }, 300);
  }));
  check('Markdown export 85 bullets', md.ok);

  const kb = await page.evaluate(async () => {
    const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
    location.hash = '#overview'; await sleep(250);
    const input = document.querySelector('input[aria-label="Search the playbook"]');
    if (!input) return { ok: false };
    const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
    input.focus(); setter.call(input, 'containment');
    input.dispatchEvent(new Event('input', { bubbles: true }));
    await sleep(350);
    const results = document.querySelectorAll('div[style*="absolute"] button').length;
    const fire = (k) => input.dispatchEvent(new KeyboardEvent('keydown', { key: k, bubbles: true }));
    fire('ArrowDown'); await sleep(120);
    const selected = Array.from(document.querySelectorAll('div[style*="absolute"] button'))
      .filter((b) => b.getAttribute('style') && !/background:\s*transparent/.test(b.getAttribute('style'))).length;
    fire('Enter'); await sleep(300);
    return { ok: results > 0 && selected === 1 && input.value === '', results, selected, hash: location.hash };
  });
  check('search + keyboard nav', kb.ok, JSON.stringify(kb));

  /* ---- P14 (Round I): every tab renders each of its body headings exactly once. The headings come from the JSX's
   * content model (text_units.cjs), a divider without its box-drawing rules; each must be the whole text of exactly one
   * element under #root on its tab (the Reference Architecture gap, RR-2-057, passed every other layer). ---- */
  const headingsByTab = (() => {
    const out = {};
    try {
      const M = require('./text_units.cjs').loadModel(SUITE);
      for (const [id, v] of Object.entries(M.content)) if (Array.isArray(v.body) && v.body.length) out[id] = v.body.map((b) => (b.divider ? String(b.heading).replace(/─/g, '').trim() : b.heading)).filter(Boolean);
    } catch (e) { out.__error = String(e).slice(0, 160); }
    return out;
  })();
  if (headingsByTab.__error) check('every body heading renders exactly once (P14)', false, 'content model: ' + headingsByTab.__error);
  else {
    const seen = await page.evaluate(async (want) => {
      const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
      const res = {};
      for (const [id, heads] of Object.entries(want)) {
        location.hash = '#' + id; await sleep(150);
        const leaves = [...document.getElementById('root').querySelectorAll('*')].filter((e) => e.childElementCount === 0).map((e) => e.textContent.trim());
        res[id] = heads.map((h) => [h, leaves.filter((t) => t === h).length]);
      }
      return res;
    }, headingsByTab);
    const bad = Object.entries(seen).flatMap(([id, rows]) => rows.filter(([, n]) => n !== 1).map(([h, n]) => `${id}: "${h.slice(0, 40)}" x${n}`));
    const total = Object.values(seen).reduce((n, r) => n + r.length, 0);
    check(`every body heading renders exactly once (P14, ${total} in ${Object.keys(seen).length} tabs)`, bad.length === 0,
      bad.length ? `${bad.length} not once: ${bad.slice(0, 4).join(' | ')}${bad.length > 4 ? ' | ...' : ''}` : '');
  }


  /* ---- embedded posters follow window resizes (Round M): every srcDoc poster's frame must fit its poster on
   * load at 1280 px, after the window goes to 390 px and after it comes back, with no reload. The posters and their
   * home tabs come from the built HTML (each iframe title under the nearest tab gate before it, as embed_check reads
   * them, with the payload's \\u escapes decoded). A poster fits when its own content height (the root element's
   * box, or the body's scroll height plus its margins) is at most half a pixel over its frame's height (not clipped)
   * and at most a pixel and a half under it (not left tall after a shrink). Each width waits up to 4 s for every
   * poster to fit and then for two samples in a row to agree; the frames must then hold still over two more
   * samples, so a layout loop fails too. ---- */
  {
    const src = fs.readFileSync(HTML, 'utf-8');
    const gates = [...src.matchAll(/active === "(\w+)"/g)].map((m) => [m.index, m[1]]);
    const byTab = {};
    for (const m of src.matchAll(/title:\s*"([^"]+)",\s*scrolling/g)) {
      const g = gates.filter(([i]) => i < m.index).pop();
      if (g) (byTab[g[1]] = byTab[g[1]] || []).push(m[1].replace(/\\u([0-9a-fA-F]{4})/g, (x, h) => String.fromCharCode(parseInt(h, 16))));
    }
    const expected = Object.values(byTab).reduce((n, t) => n + t.length, 0);
    const fitAll = (titles) => page.evaluate(async (titles) => {
      const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
      const measure = () => titles.map((t) => {
        const f = [...document.querySelectorAll('iframe')].find((i) => i.title === t);
        const d = f && f.contentDocument;
        if (!d || !d.body) return { t, missing: true };
        const cs = d.defaultView.getComputedStyle(d.body);
        const content = Math.max(d.documentElement.getBoundingClientRect().height, d.body.scrollHeight + parseFloat(cs.marginTop) + parseFloat(cs.marginBottom));
        const frame = f.getBoundingClientRect().height;
        return { t, content: Math.round(content), frame: Math.round(frame), clipped: content > frame + 0.5, loose: frame - content > 1.5 };
      });
      const same = (a, b) => a.every((x, k) => !x.missing && !b[k].missing && x.frame === b[k].frame);
      let prev = measure(), m = prev;
      for (let i = 0; i < 40; i++) {
        await sleep(100); m = measure();
        if (m.every((x) => !x.missing && !x.clipped && !x.loose) && same(m, prev)) break;
        prev = m;
      }
      await sleep(150); const m2 = measure(); await sleep(150); const m3 = measure();
      return { rows: m3, still: same(m3, m2) && same(m2, m) };
    }, titles);
    const clipped = [], moving = [];
    let measured = 0;
    for (const [tab, titles] of Object.entries(byTab)) {
      await page.setViewport({ width: 1280, height: 900 });
      await page.goto('about:blank');
      await page.goto('file://' + HTML + '#' + tab, { waitUntil: 'load', timeout: 60000 });
      await page.waitForFunction((n) => {
        const f = [...document.querySelectorAll('iframe')];
        return f.length >= n && f.every((i) => i.contentDocument && i.contentDocument.readyState === 'complete' && i.contentDocument.body);
      }, { timeout: 30000 }, titles.length);
      for (const [w, h] of [[1280, 900], [390, 844], [1280, 900]]) {
        await page.setViewport({ width: w, height: h });
        const r = await fitAll(titles);
        measured += r.rows.filter((x) => !x.missing).length;
        for (const x of r.rows) if (x.missing || x.clipped || x.loose) clipped.push(`${x.t.slice(0, 32)} @${w}: ${x.missing ? 'missing' : `frame ${x.frame}, content ${x.content}`}`);
        if (!r.still) moving.push(`${tab} @${w}`);
      }
    }
    await page.setViewport({ width: 1280, height: 900 });
    check(`embedded posters fit after resizes (${expected} in ${Object.keys(byTab).length} tabs, 1280/390/1280)`,
      expected > 0 && measured === expected * 3 && clipped.length === 0 && moving.length === 0,
      clipped.length || moving.length ? [...clipped.slice(0, 3), ...moving.slice(0, 3).map((x) => 'still moving: ' + x)].join(' | ') : `${measured} fits measured, none clipped or left tall`);
  }

  /* ---- theme pass (R37): both themes execute; prefers-color-scheme honored; toggle round-trips ---- */
  await page.emulateMediaFeatures([{ name: 'prefers-color-scheme', value: 'dark' }]);
  await page.evaluate(() => { try { localStorage.removeItem('playbook-theme'); } catch (e) {} });
  await page.goto('file://' + HTML, { waitUntil: 'load', timeout: 60000 });
  await page.waitForFunction(() => { const r = document.getElementById('root'); return r && r.innerText.length > 200; }, { timeout: 30000 });
  const darkPass = await page.evaluate(() => ({
    attr: document.documentElement.getAttribute('data-theme'),
    bg: getComputedStyle(document.documentElement).getPropertyValue('--app-bg').trim(),
    mounted: document.getElementById('root').innerText.length > 200,
    counter: /\d{2} \/ \d{2}/.test(document.body.innerText),
  }));
  check('theme: dark honored on dark-pref first load', darkPass.attr === 'dark' && darkPass.mounted && darkPass.counter, JSON.stringify(darkPass));

  await page.emulateMediaFeatures([{ name: 'prefers-color-scheme', value: 'light' }]);
  await page.evaluate(() => { try { localStorage.removeItem('playbook-theme'); } catch (e) {} });
  await page.goto('file://' + HTML, { waitUntil: 'load', timeout: 60000 });
  await page.waitForFunction(() => { const r = document.getElementById('root'); return r && r.innerText.length > 200; }, { timeout: 30000 });
  const lightPass = await page.evaluate(() => ({
    attr: document.documentElement.getAttribute('data-theme'),
    bg: getComputedStyle(document.documentElement).getPropertyValue('--app-bg').trim(),
    mounted: document.getElementById('root').innerText.length > 200,
    counter: /\d{2} \/ \d{2}/.test(document.body.innerText),
  }));
  check('theme: light honored on light-pref first load', lightPass.attr === 'light' && lightPass.mounted && lightPass.counter, JSON.stringify(lightPass));
  check('theme: light tokens distinct from dark', !!darkPass.bg && !!lightPass.bg && darkPass.bg !== lightPass.bg, `dark=${darkPass.bg} light=${lightPass.bg}`);

  const toggle = await page.evaluate(async () => {
    const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
    const attr = () => document.documentElement.getAttribute('data-theme');
    const btn = Array.from(document.querySelectorAll('button')).find((b) => (b.getAttribute('aria-label') || '') === 'Toggle color theme');
    if (!btn) return { ok: false, why: 'toggle button not found' };
    const a0 = attr(); btn.click(); await sleep(120);
    const a1 = attr(); btn.click(); await sleep(120);
    const a2 = attr();
    let persisted = null;
    try { persisted = localStorage.getItem('playbook-theme'); } catch (e) { persisted = 'storage-denied'; }
    return { ok: a0 === 'light' && a1 === 'dark' && a2 === 'light', a0, a1, a2, persisted };
  });
  check('theme: toggle round-trips (persistence reported, not asserted)', toggle.ok, JSON.stringify(toggle));

  check('zero console errors', consoleErrors.length === 0, consoleErrors[0] || '');
  check('zero page errors', pageErrors.length === 0, pageErrors[0] || '');

  console.log('================ RENDER BATTERY ================');
  for (const [name, ok, detail] of results) {
    console.log(`  ${ok ? '\u2713' : '\u2717'} ${name.padEnd(44)} ${ok ? 'PASS' : 'FAIL'}  ${detail}`);
  }
  console.log(failures ? `\n${failures} FAILURE(S)` : '\nALL GREEN');
  await browser.close();
  process.exit(failures ? 1 : 0);
})().catch((e) => { console.error('RUNNER FAILURE:', e); process.exit(1); });
