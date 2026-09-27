#!/usr/bin/env node
/* anchor_check.cjs — Agentic SecOps anchor-resolution battery layer (layer 6).
 *   CHROME_PATH=/path/to/chrome node Validation/anchor_check.cjs [html-path]
 *   node Validation/anchor_check.cjs /tmp/scratch.html   (canary / ad-hoc target)
 *
 * Machine-checks the failure class render_check cannot see: render_check asserts
 * mount + tab-routing + zero console errors, but NOT PRESENCE — a mis-keyed gate
 * silently fails to render and still passes green. This layer closes that gap
 * for the deep-link anchor set and the tab-gated srcDoc figures (the ROUND-27
 * both-directions hand check, generalized to a cross-check matrix).
 *
 * Two exact-match constants, house count-assert pattern (sync_check style):
 *   ANCHOR_COUNT        — search-indexed deep-link anchors that must resolve.
 *   GATED_FIGURE_COUNT  — tab-gated srcDoc figures under a single-tab gate whose
 *                         presence/absence is cross-checked. Bounded to the three
 *                         fresh embeds (ROUND-25/26/27) — the at-risk set this
 *                         round was authored to guard. The tree carries more
 *                         iframes (older, long-stable embeds); the run reports the
 *                         total so coverage is transparent (no silent cap).
 *
 * MANIFEST DISCIPLINE: ANCHORS and FIGURES below ARE the canonical definitions
 * (no formal definition existed in the tree at authoring). Any round that adds or
 * removes a search-indexed anchor, or moves/adds/removes a gated figure, MUST
 * ripple the manifest AND its constant in the SAME commit — the length assert
 * below fails loudly otherwise.
 *
 * Exit 0 = pass; 1 = fail; 2 = SKIPPED (no browser), so battery.cjs degrades
 * gracefully exactly like render_check.
 */
const path = require('path');
const fs = require('fs');

const SUITE = path.resolve(__dirname, '..');
const HTML = process.argv[2] || process.env.ANCHOR_CHECK_HTML || path.join(SUITE, 'Playbook', 'index.html');

/* ---- exact-match constants + manifests (ripple in-commit when they move) ---- */
const ANCHOR_COUNT = 11;
const ANCHORS = [
  'MCP attack surface', 'test manual', 'clone this repo', 'BlueBench', 'worked example',
  'guardrails', 'Alberta', 'MOSAIC', 'mukul975', 'Boko Haram',
  'Oligo', /* TIERING: appendix-tier RI entry — asserts the Appendix expander auto-opens on deep-link (D3) */
];
const GATED_FIGURE_COUNT = 3;
const FIGURES = [
  { title: 'Same Horsepower, Two Outcomes', tab: 'overview' },
  { title: 'One Operator, a Cast of Agents', tab: 'threatmodel' },
  { title: 'Zero Trust for Operational Technology', tab: 'otics' },
];

function resolvePuppeteer() {
  const candidates = [
    'puppeteer', 'puppeteer-core',
  ];
  for (const c of candidates) { try { return require(c); } catch (e) {} }
  return null;
}
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

(async () => {
  console.log('================ ANCHOR-RESOLUTION CHECK ================');

  /* manifest integrity — fails before the browser even launches */
  if (ANCHORS.length !== ANCHOR_COUNT) {
    console.log(`  ✗ ANCHOR manifest length ${ANCHORS.length} != ANCHOR_COUNT ${ANCHOR_COUNT}`);
    process.exit(1);
  }
  if (FIGURES.length !== GATED_FIGURE_COUNT) {
    console.log(`  ✗ FIGURE manifest length ${FIGURES.length} != GATED_FIGURE_COUNT ${GATED_FIGURE_COUNT}`);
    process.exit(1);
  }

  const puppeteer = resolvePuppeteer();
  const chrome = resolveChrome() || await fallbackChrome(puppeteer);
  if (!puppeteer || !chrome) {
    console.log('ANCHOR CHECK SKIPPED: ' + (!puppeteer ? 'puppeteer not installed. ' : '') +
      (!chrome ? 'no Chrome binary found (set CHROME_PATH).' : ''));
    process.exit(2);
  }
  if (!fs.existsSync(HTML)) { console.log('ANCHOR CHECK FAIL: html not found: ' + HTML); process.exit(1); }

  const consoleErrors = [], pageErrors = [];
  const browser = await puppeteer.launch({
    executablePath: chrome, headless: 'shell',
    args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1400, height: 900 });
  page.on('console', (m) => { if (m.type() === 'error') consoleErrors.push(m.text().slice(0, 180)); });
  page.on('pageerror', (e) => pageErrors.push(String(e).slice(0, 180)));

  const results = [];
  let failures = 0;
  const check = (name, ok, detail) => { results.push([name, ok, detail || '']); if (!ok) failures++; };
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  /* ---- R37: the anchor + figure passes execute under BOTH themes ---- */
  for (const THEME of ['dark', 'light']) {
  const setTheme = () => page.evaluate((t) => document.documentElement.setAttribute('data-theme', t), THEME);

  /* ---- 1. ANCHOR PASS: every manifest term resolves to a scrolled+flashed block ---- */
  let resolved = 0;
  const anchorFails = [];
  for (const term of ANCHORS) {
    await page.goto('file://' + HTML, { waitUntil: 'load', timeout: 60000 });
    await page.waitForFunction(() => {
      const r = document.getElementById('root'); return r && r.innerText.length > 200;
    }, { timeout: 30000 });
    await setTheme();
    await sleep(150);
    await page.evaluate((q) => {
      const input = document.querySelector('input[placeholder]');
      const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
      setter.call(input, q);
      input.dispatchEvent(new Event('input', { bubbles: true }));
    }, term);
    await sleep(340);
    const clicked = await page.evaluate(() => {
      const input = document.querySelector('input[placeholder]');
      const wrap = input.closest('div').parentElement;
      const bs = [...wrap.querySelectorAll('button')].filter((b) => b.offsetParent !== null && b.textContent.trim().length > 3);
      if (!bs.length) return false;
      bs[0].click();
      return true;
    });
    await sleep(1050);
    /* coupled to the seek() flash in the JSX: el.style.background = "color-mix(in srgb, var(--accent) 14%, transparent)" */
    const ok = clicked && await page.evaluate(() => {
      const f = [...document.querySelectorAll('[id^="b-"]')].find((e) => e.style.background && e.style.background.includes('var(--accent) 14%'));
      return !!f && window.scrollY > 0;
    });
    if (ok) resolved++; else anchorFails.push(term);
  }
  check(`anchors resolve [${THEME}] (${resolved}/${ANCHOR_COUNT})`, resolved === ANCHOR_COUNT,
    anchorFails.length ? `unresolved=${JSON.stringify(anchorFails)}` : '');

  /* ---- 2. FIGURE PASS: present on home tab, absent on every other figure's home tab ---- */
  await page.goto('file://' + HTML, { waitUntil: 'load', timeout: 60000 });
  await page.waitForFunction(() => {
    const r = document.getElementById('root'); return r && r.innerText.length > 200;
  }, { timeout: 30000 });
  await setTheme();
  const totalIframes = await page.evaluate(() => document.querySelectorAll('iframe').length);

  let figuresOk = 0;
  const figureFails = [];
  const homeTabs = FIGURES.map((f) => f.tab);
  for (const fig of FIGURES) {
    // present on its home tab
    const present = await page.evaluate(async (t) => {
      const s = (ms) => new Promise((r) => setTimeout(r, ms));
      location.hash = '#' + t.tab; await s(500);
      const el = document.querySelector(`iframe[title="${t.title}"]`);
      return !!el && el.offsetParent !== null;
    }, fig);
    // absent on every OTHER figure's home tab (cross-check matrix)
    let absentEverywhereElse = true;
    for (const other of homeTabs) {
      if (other === fig.tab) continue;
      const absent = await page.evaluate(async (arg) => {
        const s = (ms) => new Promise((r) => setTimeout(r, ms));
        location.hash = '#' + arg.tab; await s(400);
        return document.querySelector(`iframe[title="${arg.title}"]`) === null;
      }, { tab: other, title: fig.title });
      if (!absent) { absentEverywhereElse = false; break; }
    }
    if (present && absentEverywhereElse) figuresOk++;
    else figureFails.push(`${fig.title} [present=${present} absentElsewhere=${absentEverywhereElse}]`);
  }
  check(`gated figures present-and-isolated [${THEME}] (${figuresOk}/${GATED_FIGURE_COUNT})`, figuresOk === GATED_FIGURE_COUNT,
    (figureFails.length ? `fails=${JSON.stringify(figureFails)}; ` : '') + `totalIframes=${totalIframes} (bounded set=${GATED_FIGURE_COUNT})`);
  } /* end THEME loop (R37) */

  /* ---- 3. zero new console/page errors across the run ---- */
  check('zero console errors', consoleErrors.length === 0, consoleErrors.slice(0, 3).join(' | '));
  check('zero page errors', pageErrors.length === 0, pageErrors.slice(0, 3).join(' | '));

  await browser.close();

  for (const [name, ok, detail] of results) {
    console.log(`  ${ok ? '✓' : '✗'} ${name.padEnd(46)} ${ok ? 'PASS' : 'FAIL'}${detail ? '  ' + detail : ''}`);
  }
  console.log(failures ? `\n${failures} FAILURE(S)` : '\nALL GREEN');
  process.exit(failures ? 1 : 0);
})().catch((e) => { console.log('ANCHOR CHECK ERROR: ' + e); process.exit(1); });
