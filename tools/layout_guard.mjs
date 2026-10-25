// The layout guard (24 October 2026, the layout sweep): every published page under docs/, at 375, 390 and 1440 wide, in
// light and dark, in the system Chrome driven by playwright-core (npm install --no-package-lock --ignore-scripts at the
// repository root). It fails when a text block in a page's closing area, or a legend box under 520px, is more than 2px
// narrower than the page's main content column or offset from it; when a closing text block does not wrap with
// text-wrap: pretty or ends on a one-word line; when the page scrolls sideways; and when a page cannot be classified,
// which it lists by name instead of skipping.
//
// The main content column: the content box of the outermost element above the page's first visible h1 (below body)
// that has a max-width. The closing area: footers (footer, .footer, [role=contentinfo], .foot and classes with foot-,
// closing or copy in them; one inside a card or a side-by-side column belongs to that card or column), and the summary
// text beside the cards, not inside one: classed summary, closing or after-grid, or a note or caption that follows cards.
// In it, every block that holds text spans the column within 2px (a summary note spans the cards it follows), measured
// by its content box, or by its border box when it has its own border or background. Three exceptions: a footer's link
// list (a nav or list of links) only stays inside the column; a one-line block that shares its line with such a list
// counts with it, so the line spans the column; a badge or brand pill (a class with badge or brand in it) starts at the
// column's left edge. Legend boxes (aside and classes with legend, leg or callout in them) beside the cards, not inside
// one, span the column under 520px; a legend box inside an unboxed legend wrapper is checked as well as the wrapper.
// Usage: node tools/layout_guard.mjs [page.html ...]   (pages relative to docs/; default every page)
import { createServer } from 'node:http';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, extname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const DOCS = join(ROOT, 'docs');
const WIDTHS = [375, 390, 1440];
const SCHEMES = ['light', 'dark'];
const TOL = 2;

let chromium;
try { ({ chromium } = await import('playwright-core')); } catch {
  console.log('FAIL  layout guard: playwright-core is missing; run npm install --no-package-lock --ignore-scripts at the repository root');
  process.exit(1);
}
const CHROMES = [process.env.LENSATIC_CHROME, process.env.CHROME_PATH,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium', '/usr/bin/chromium-browser'].filter(Boolean);
const chrome = CHROMES.find((p) => existsSync(p));
if (!chrome) { console.log('FAIL  layout guard: no Chrome or Chromium found; set LENSATIC_CHROME'); process.exit(1); }

const walk = (d) => readdirSync(d).flatMap((n) => { const p = join(d, n); return statSync(p).isDirectory() ? walk(p) : [p]; });
const pages = (process.argv.slice(2).length ? process.argv.slice(2) : walk(DOCS).filter((p) => p.endsWith('.html')).map((p) => relative(DOCS, p)))
  .map((p) => p.split(sep).join('/')).sort();

// docs/ served at /lensatic/ (the 404 page's addresses are absolute) and at /, so every link resolves as it does live
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
const BASE = `http://127.0.0.1:${server.address().port}/lensatic/`;

// runs in the page: returns { unclassified } or { column, problems, blocks, legends }
function measure({ TOL, narrow }) {
  const vis = (e) => { const r = e.getBoundingClientRect(), cs = getComputedStyle(e); return r.width >= 2 && r.height >= 2 && cs.visibility !== 'hidden' && cs.display !== 'none' && parseFloat(cs.opacity) > 0.01; };
  const name = (e) => `${e.tagName.toLowerCase()}${e.id ? '#' + e.id : ''}${typeof e.className === 'string' && e.className.trim() ? '.' + e.className.trim().split(/\s+/).slice(0, 2).join('.') : ''}`;
  const text = (e) => (e.textContent || '').trim().replace(/\s+/g, ' ');
  const h1 = [...document.querySelectorAll('h1')].find(vis);
  if (!h1) return { unclassified: 'no visible h1' };
  let col = null;
  for (let e = h1.parentElement; e && e !== document.body && e !== document.documentElement; e = e.parentElement)
    if (getComputedStyle(e).maxWidth !== 'none') col = e;
  if (!col) return { unclassified: 'no element above the h1 sets a max-width' };
  const cr = col.getBoundingClientRect(), ccs = getComputedStyle(col);
  const C = { el: name(col), left: cr.left + parseFloat(ccs.paddingLeft) + parseFloat(ccs.borderLeftWidth),
    right: cr.right - parseFloat(ccs.paddingRight) - parseFloat(ccs.borderRightWidth) };
  const problems = [];
  const fmt = (r) => `${r.left.toFixed(1)} to ${r.right.toFixed(1)}`;
  const span = (r) => Math.abs(r.left - C.left) <= TOL && Math.abs(r.right - C.right) <= TOL;
  const blockOf = (n) => { let e = n.parentElement; while (e && getComputedStyle(e).display.startsWith('inline')) e = e.parentElement; return e; };
  const boxed = (e) => { const cs = getComputedStyle(e); return parseFloat(cs.borderTopWidth) + parseFloat(cs.borderLeftWidth) > 0 && cs.borderLeftStyle !== 'none' || (cs.backgroundColor !== 'rgba(0, 0, 0, 0)' && cs.backgroundColor !== 'transparent'); };

  // the closing area
  const FOOT = 'footer, .footer, [role="contentinfo"], .foot, [class*="foot-"], [class*="closing"], .copy, [class*="copyright"]';
  // beside the cards: no boxed ancestor between the element and the column (the column itself may be boxed)
  const beside = (e) => { for (let a = e.parentElement; a && a !== col && a !== document.body; a = a.parentElement) if (boxed(a)) return false; return col.contains(e); };
  // a footer inside a card (a boxed ancestor within the column) belongs to the card
  // footer text inside side-by-side columns (an ancestor with a sibling beside it) belongs to its column
  const inColumns = (e) => { for (let a = e.parentElement; a && a !== col; a = a.parentElement) { const r = a.getBoundingClientRect();
    if (a.parentElement && [...a.parentElement.children].some((s) => s !== a && vis(s) && (() => { const q = s.getBoundingClientRect(); return q.top < r.bottom - 1 && q.bottom > r.top + 1 && (q.right <= r.left + 1 || q.left >= r.right - 1); })())) return true; } return false; };
  let areas = [...document.querySelectorAll(FOOT)].filter((e) => vis(e) && (!col.contains(e) || (beside(e) && !inColumns(e))));
  // summary text: classed closing, summary or after-grid, or a note or caption that follows cards (a boxed sibling or a
  // grid of boxed children, 48px tall or more); headings and preformatted text are not summary paragraphs
  const tall = (e) => vis(e) && boxed(e) && e.getBoundingClientRect().height >= 48;
  const cardGrid = (e) => /grid|flex/.test(getComputedStyle(e).display) && [...e.children].filter(tall).length >= 2;
  const afterCards = (e) => { for (let s = e.previousElementSibling; s; s = s.previousElementSibling) if (vis(s) && (tall(s) || cardGrid(s))) return true; return false; };
  const NOTE = ':is([class*="note"], [class*="caption"], [class*="summary"], [class*="after-grid"]):not(summary, h1, h2, h3, h4, h5, h6, pre)';
  // a summary note lines up with the cards it follows (their union); footers line up with the page's column
  const ref = new Map();
  for (const e of [...document.querySelectorAll(NOTE)].filter((e) => vis(e) && e !== col && beside(e) && text(e))) {
    const cards = []; for (let q = e.previousElementSibling; q; q = q.previousElementSibling) if (vis(q) && (tall(q) || cardGrid(q))) cards.push(q.getBoundingClientRect());
    if (!cards.length && !/after-grid|closing|summary/.test(e.className)) continue;
    areas.push(e);
    if (cards.length) ref.set(e, { left: Math.min(...cards.map((r) => r.left)), right: Math.max(...cards.map((r) => r.right)), el: 'the cards above it' });
  }
  areas = areas.filter((a, i) => !areas.some((b, j) => j !== i && b.contains(a) && b !== a));
  if (!areas.length) return { unclassified: 'no closing area (no footer, closing or copyright block, and no summary text after cards)' };

  const blocks = new Map();
  for (const a of areas) {
    const tw = document.createTreeWalker(a, NodeFilter.SHOW_TEXT);
    for (let n; (n = tw.nextNode());) {
      if (!n.textContent.trim()) continue;
      const b = blockOf(n); if (!b || !vis(b)) continue;
      if (b.closest('style, script, template, [aria-hidden="true"]')) continue;
      blocks.set(b, a);
    }
  }
  const out = [];
  // a link list: a nav or list holding links, a flex or grid row of links only, or a link laid out as a block in one
  const isNav = (e) => (!!e.closest('nav, ul, ol') && [...e.querySelectorAll('*')].concat(e).some((x) => x.tagName === 'A'))
    || (/flex|grid/.test(getComputedStyle(e).display) && e.children.length > 0 && [...e.children].every((c) => c.tagName === 'A'))
    || (!!e.closest('a') && !!e.closest('a').parentElement && [...e.closest('a').parentElement.children].every((c) => c.tagName === 'A'));
  const lines = (e) => { const r = document.createRange(); r.selectNodeContents(e); const tops = [...new Set([...r.getClientRects()].filter((x) => x.width > 1).map((x) => Math.round(x.top)))]; return tops.length; };
  const lastLineWords = (e) => {
    const words = []; const tw = document.createTreeWalker(e, NodeFilter.SHOW_TEXT);
    for (let n; (n = tw.nextNode());) { const re = /\S+/g; let m; while ((m = re.exec(n.textContent))) { const r = document.createRange(); r.setStart(n, m.index); r.setEnd(n, m.index + m[0].length); const rc = [...r.getClientRects()].filter((x) => x.width > 0).pop(); if (rc) words.push({ w: m[0], top: Math.round(rc.top) }); } }
    if (!words.length) return { n: 0, line: '' };
    const lastTop = Math.max(...words.map((x) => x.top)); const tops = new Set(words.map((x) => x.top));
    const last = words.filter((x) => Math.abs(x.top - lastTop) <= 3);
    return { n: last.length, lines: tops.size, line: last.map((x) => x.w).join(' ') };
  };
  // a text block's text sits in its content box (inside its padding and border); a boxed block (its own border or
  // background), a badge and a legend box are measured by their visible border box
  const contentBox = (e) => { const q = e.getBoundingClientRect(), cs = getComputedStyle(e);
    return { left: q.left + parseFloat(cs.paddingLeft) + parseFloat(cs.borderLeftWidth), right: q.right - parseFloat(cs.paddingRight) - parseFloat(cs.borderRightWidth), top: q.top, bottom: q.bottom, width: q.width - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight) - parseFloat(cs.borderLeftWidth) - parseFloat(cs.borderRightWidth) }; };
  for (const [b, area] of blocks) {
    const r = boxed(b) ? b.getBoundingClientRect() : contentBox(b);
    const R = ref.get(area) || C;
    const span = (q) => Math.abs(q.left - R.left) <= TOL && Math.abs(q.right - R.right) <= TOL;
    const BADGE = '[class*="badge"], [class*="brand"]';
    const badges = [...b.querySelectorAll(BADGE)].concat(b.matches(BADGE) ? [b] : []);
    const badgeOnly = badges.length > 0 && badges.map((x) => x.textContent).join(' ').trim().replace(/\s+/g, ' ') === text(b);
    const kind = badgeOnly ? 'badge' : isNav(b) ? 'nav' : 'text';
    const row = { el: name(b), kind, box: fmt(r), text: text(b).slice(0, 48) };
    if (kind === 'badge') {
      const l = Math.min(...badges.filter(vis).map((x) => x.getBoundingClientRect().left));
      if (Math.abs(l - R.left) > TOL) problems.push(`badge ${row.el} "${row.text}" starts at ${l.toFixed(1)}, not at the column's left edge ${R.left.toFixed(1)}`);
    } else if (kind === 'nav') {
      if (r.left < C.left - TOL || r.right > C.right + TOL) problems.push(`link list ${row.el} ${fmt(r)} runs outside the column ${fmt(C)}`);
    } else {
      let ok = span(r), how = 'spans';
      if (!ok && lines(b) === 1 && b.parentElement) {
        // a one-line block that shares its line with a link list: the line spans the column
        const mates = [...b.parentElement.children].filter((s) => s !== b && vis(s) && isNav(s)).map((s) => s.getBoundingClientRect()).filter((s) => s.top < r.bottom && s.bottom > r.top);
        if (mates.length) { const u = { left: Math.min(r.left, ...mates.map((m) => m.left)), right: Math.max(r.right, ...mates.map((m) => m.right)) }; ok = span(u); how = `shares its line with a link list (line ${fmt(u)})`; }
      }
      if (!ok) problems.push(`text ${row.el} "${row.text}" ${fmt(r)}, not ${R === C ? 'the column' : R.el} ${fmt(R)} (${(R.right - R.left - r.width).toFixed(1)}px narrower, offset ${(r.left - R.left).toFixed(1)}px)`);
      const tw = getComputedStyle(b).textWrapStyle || getComputedStyle(b).textWrap;
      if (!/pretty/.test(tw)) problems.push(`text ${row.el} "${row.text}" wraps with text-wrap ${tw || 'auto'}, not pretty`);
      const ll = lastLineWords(b);
      if (ll.lines > 1 && ll.n === 1) problems.push(`text ${row.el} "${row.text}" ends on a one-word line ("${ll.line}")`);
      row.how = how; row.lines = ll.lines;
    }
    out.push(row);
  }

  // legend boxes under 520px: those beside the cards (no boxed ancestor between them and the column), not inside one
  const legends = [];
  if (narrow) {
    const LEG = 'aside, [class*="legend"], [class*="leg"], [class*="callout"]';
    const cands = [...document.querySelectorAll(LEG)].filter((e) => vis(e) && col.contains(e) && e !== col && !e.closest(FOOT) && beside(e));
    for (const e of cands) {
      if (getComputedStyle(e).display.startsWith('inline')) continue;
      const r = e.getBoundingClientRect();
      legends.push({ el: name(e), box: fmt(r) });
      if (!span(r)) problems.push(`legend ${name(e)} "${text(e).slice(0, 40)}" ${fmt(r)}, not the column ${fmt(C)} under 520px`);
    }
  }
  if (document.documentElement.scrollWidth > innerWidth + 1) problems.push(`the page scrolls sideways (${document.documentElement.scrollWidth}px in ${innerWidth}px)`);
  return { column: { el: C.el, box: fmt(C) }, blocks: out, legends, problems };
}

const browser = await chromium.launch({ executablePath: chrome, headless: true });
const results = [];
const verbose = !!process.env.LENSATIC_LAYOUT_VERBOSE;
await Promise.all(SCHEMES.flatMap((scheme) => WIDTHS.map(async (w) => {
  const ctx = await browser.newContext({ viewport: { width: w, height: 900 }, colorScheme: scheme, reducedMotion: 'reduce' });
  const page = await ctx.newPage();
  for (const pg of pages) {
    const errors = [];
    const onErr = (m) => { if (m.type() === 'error') errors.push(m.text()); };
    page.on('console', onErr);
    try {
      await page.goto(BASE + pg + `?guard=${scheme}${w}`, { waitUntil: 'load' });
      await page.evaluate(() => document.fonts.ready);
      await page.waitForTimeout(700);
      const r = await page.evaluate(measure, { TOL, narrow: w < 520 });
      results.push({ pg, scheme, w, ...r });
    } catch (e) { results.push({ pg, scheme, w, unclassified: `could not load: ${String(e).split('\n')[0]}` }); }
    page.off('console', onErr);
  }
  await ctx.close();
})));
await browser.close(); server.close();

let fails = 0, checked = 0;
const unclassified = new Map();
for (const pg of pages) {
  const rs = results.filter((r) => r.pg === pg).sort((a, b) => a.w - b.w || a.scheme.localeCompare(b.scheme));
  const un = rs.filter((r) => r.unclassified);
  if (un.length) { unclassified.set(pg, [...new Set(un.map((r) => `${r.unclassified} (${r.scheme} ${r.w})`))]); fails++; continue; }
  checked++;
  const bad = rs.filter((r) => r.problems.length);
  const nb = rs[0].blocks.length, nl = Math.max(...rs.map((r) => r.legends.length));
  if (bad.length) {
    fails++;
    console.log(`FAIL  ${pg}  (column ${rs[0].column.el})`);
    const seen = new Set();
    for (const r of bad) for (const p of r.problems) { const k = p.replace(/[\d.]+px|[\d.]+ to [\d.]+/g, '#'); if (!seen.has(k + r.w)) { seen.add(k + r.w); console.log(`      - ${r.scheme} ${r.w}: ${p}`); } }
  } else console.log(`PASS  ${pg}  (column ${rs[0].column.el}; ${nb} closing block${nb === 1 ? '' : 's'}, ${nl} legend box${nl === 1 ? '' : 'es'} under 520px; 3 widths x 2 themes)`);
  if (verbose) for (const r of rs) console.log(`      ${r.scheme} ${r.w} column ${r.column.box}: ` + r.blocks.map((b) => `${b.kind} ${b.el} ${b.box}`).join('; ') + (r.legends.length ? ' | legends ' + r.legends.map((l) => `${l.el} ${l.box}`).join('; ') : ''));
}
for (const [pg, why] of unclassified) console.log(`FAIL  ${pg}: could not classify: ${why.join('; ')}`);
console.log(`${fails ? 'LAYOUT GUARD RED' : 'LAYOUT GUARD GREEN'}: ${checked} of ${pages.length} pages classified and checked at ${WIDTHS.join(', ')} in light and dark${unclassified.size ? `; unclassified: ${[...unclassified.keys()].join(', ')}` : ''}`);
process.exit(fails ? 1 : 0);
