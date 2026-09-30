#!/usr/bin/env node
/* battery.cjs — Agentic SecOps full validation battery (orchestrator).
 *   node Validation/battery.cjs
 *
 * Layers (each degrades gracefully if tooling is absent):
 *   1. sync_check.cjs        — structural / counts / zero-external / byte-sync
 *   2. deck + documents      — PPTX slide count (unzip), PDF page counts
 *                              (python3+pypdf, else pdfinfo, else best-effort),
 *                              study-guide Part 8 mirror = 226 links,
 *                              Part 8 sub-group labels = the app's (P06),
 *                              executive summary HTML zero external loads,
 *                              landing page zero external loads,
 *                              README consistency tripwires
 *   3. render_check.cjs      — headless browser battery (SKIPPED if no Chrome)
 *   4. anchor_check.cjs      — deep-link anchor + gated-figure DOM-presence
 *                              resolution, the sixth layer (SKIPPED if no Chrome)
 * PUBLIC EDITION MODE: a `.public-edition` marker file at the tree root switches on public mode, which
 * skips checks for files that exist only in the private working repo. Without the marker every check
 * runs exactly as before. Here: the three README.txt tripwires report SKIPPED (public edition: not shipped).
 * Private-only PDF page checks live in Export/private_pages.json, which the export never ships; the battery
 * reads it only when present (Round L2).
 * Exit 0 = no failures (SKIPPED layers reported, not failed).
 */
const { execFileSync, spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const SUITE = path.resolve(__dirname, '..');
const PUBLIC = fs.existsSync(path.join(SUITE, '.public-edition'));
const NOT_SHIPPED = 'public edition: not shipped';
const rows = [];
let failures = 0;
const add = (layer, name, status, detail) => {
  rows.push([layer, name, status, detail || '']);
  if (status === 'FAIL') failures++;
};
const have = (cmd) => spawnSync('which', [cmd]).status === 0;

/* ---- layer 1: sync check ---- */
{
  const r = spawnSync(process.execPath, [path.join(__dirname, 'sync_check.cjs')], { encoding: 'utf-8' });
  const green = r.status === 0;
  add('sync', 'structural / counts / external-loads / byte-sync', green ? 'PASS' : 'FAIL',
    green ? 'see sync_check for detail' : (r.stdout.split('\n').find((l) => l.includes('\u2717')) || '').trim());
  process.stdout.write(r.stdout);
}

/* ---- layer 1b: count-ripple lockstep ---- */
{
  const r = spawnSync(process.execPath, [path.join(__dirname, 'ripple_check.cjs')], { encoding: 'utf-8' });
  const green = r.status === 0;
  add('ripple', 'counts lockstep across all ripple locations', green ? 'PASS' : 'FAIL',
    green ? 'see ripple_check for detail' : (r.stdout.split('\n').find((l) => l.includes('✗')) || '').trim());
  process.stdout.write(r.stdout);
}

/* ---- layer 1c: encoding + ordering statics ---- */
{
  const r = spawnSync(process.execPath, [path.join(__dirname, 'statics_check.cjs')], { encoding: 'utf-8' });
  const green = r.status === 0;
  add('static', 'encoding + alpha-ordering statics', green ? 'PASS' : 'FAIL',
    green ? 'see statics_check for detail' : (r.stdout.split('\n').find((l) => l.includes('✗')) || '').trim());
  process.stdout.write(r.stdout);
}

/* ---- layer 2: deck + documents ---- */
const pdfPages = (p) => {
  if (have('python3')) {
    const r = spawnSync('python3', ['-c',
      `from pypdf import PdfReader;print(len(PdfReader(r'''${p}''').pages))`], { encoding: 'utf-8' });
    if (r.status === 0) return parseInt(r.stdout.trim(), 10);
  }
  if (have('pdfinfo')) {
    const r = spawnSync('pdfinfo', [p], { encoding: 'utf-8' });
    const m = (r.stdout || '').match(/Pages:\s+(\d+)/);
    if (m) return parseInt(m[1], 10);
  }
  const raw = fs.readFileSync(p, 'latin1');
  const m = raw.match(/\/Type\s*\/Pages[^>]*\/Count\s+(\d+)/);
  return m ? parseInt(m[1], 10) : -1;
};
{
  const deck = path.join(SUITE, 'Deck', 'Agentic-SecOps-Master-Deck.pptx');
  if (PUBLIC) {  // Round K: the PPTX stays in the private repo; the public edition's deck is its PDF
    const n = pdfPages(path.join(SUITE, 'Deck', 'Agentic-SecOps-Master-Deck.pdf'));
    add('deck', 'deck PDF 31 pages (the PPTX stays private)', n === 31 ? 'PASS' : 'FAIL', `pages=${n}`);
  } else if (have('unzip')) {
    const out = execFileSync('unzip', ['-l', deck], { encoding: 'utf-8' });
    const slides = (out.match(/ppt\/slides\/slide\d+\.xml/g) || []).length;
    add('deck', 'PPTX 31 slides', slides === 31 ? 'PASS' : 'FAIL', `slides=${slides}`);
  } else {
    add('deck', 'PPTX 31 slides', 'SKIPPED', 'unzip not available');
  }
  const checks = [
    ['Deck/Agentic-SecOps-Master-Deck.pdf', 31],
    ['Documents/Agentic-SecOps-Executive-Summary.pdf', 7],
    ['Documents/Adversary-Emulation-Concept-Brief.pdf', 3],
  ];
  /* Round L2: private-only PDF page checks live in Export/private_pages.json, which the export never ships.
   * Read only when present, and spliced in after the summary, so private mode prints the same rows in the same
   * order; public mode has no such file and prints no row for them. */
  const privatePages = path.join(SUITE, 'Export', 'private_pages.json');
  if (fs.existsSync(privatePages)) checks.splice(2, 0, ...JSON.parse(fs.readFileSync(privatePages, 'utf-8')).pages);
  for (const [rel, want] of checks) {
    const got = pdfPages(path.join(SUITE, rel));
    add('docs', `${path.basename(rel)} = ${want}pp`,
      got === want ? 'PASS' : got === -1 ? 'SKIPPED' : 'FAIL', `pages=${got}`);
  }
  /* executive summary HTML source (C4): zero external loads, the same six patterns
   * sync_check.cjs applies to index.html (its section 3) */
  const esHtml = fs.readFileSync(path.join(SUITE, 'Documents', 'Agentic-SecOps-Executive-Summary.html'), 'utf-8');
  const EXT = [/<script[^>]*\bsrc\s*=/g, /<link[^>]*\bhref\s*=(?!\s*["']?data:)/g, /<img[^>]*\bsrc\s*=\s*["']http/g, /@import\s/g,
    /url\(\s*["']?(?:https?:)?\/\//g, /\bfetch\s*\(\s*["']http/g];
  const esExt = EXT.reduce((n, re) => n + (esHtml.match(re) || []).length, 0);
  add('docs', 'exec summary HTML zero external loads', esExt === 0 ? 'PASS' : 'FAIL', esExt ? `hits=${esExt}` : 'clean');
  /* landing page (C5): the same patterns; Public/index.html privately, index.html in public mode */
  const landingRel = PUBLIC ? 'index.html' : path.join('Public', 'index.html');
  if (fs.existsSync(path.join(SUITE, landingRel))) {
    const landing = fs.readFileSync(path.join(SUITE, landingRel), 'utf-8');
    const lpExt = EXT.reduce((n, re) => n + (landing.match(re) || []).length, 0);
    add('docs', 'landing page zero external loads', lpExt === 0 ? 'PASS' : 'FAIL', lpExt ? `hits=${lpExt}` : 'clean');
  } else {
    add('docs', 'landing page zero external loads', 'FAIL', `${landingRel} missing`);
  }
  const guide = fs.readFileSync(path.join(SUITE, 'Documents', 'Agentic-SecOps-Study-Guide.md'), 'utf-8');
  const p8 = guide.indexOf('## Part 8'); const p9 = guide.indexOf('## Part 9');
  const links = (guide.slice(p8, p9).match(/\[[^\]]+\]\(https?:\/\/[^)]+\)/g) || []).length;
  add('docs', 'study guide Part 8 mirror = 226 links', links === 226 ? 'PASS' : 'FAIL', `links=${links}`);
  /* P06 (Round I): the Part 8 mirror's sub-group labels equal the app's sub-groups, group by group and in order, and
   * each label is a paragraph of its own (a blank line before and after), so none renders inside a bullet */
  {
    const TU = require('./text_units.cjs');
    const M = TU.loadModel(SUITE);
    const body = guide.slice(p8, p9).slice(guide.slice(p8, p9).indexOf('### The full Resource Index'));
    const lines = body.split('\n'); const mirror = []; const glued = [];
    lines.forEach((l, i) => {
      const g = l.match(/^\*\*\d+\. (.+)\*\*$/);
      if (g) { mirror.push({ group: g[1], subs: [] }); return; }
      const s = l.match(/^\*([^*].*?)\*$/);
      if (s && mirror.length) {
        mirror[mirror.length - 1].subs.push(s[1]);
        if ((lines[i - 1] || '').trim() !== '' || (lines[i + 1] || '').trim() !== '') glued.push(s[1]);
      } else if (/\S\s*\*[^*\s][^*]*\*\s*$/.test(l) && /^- \[/.test(l)) glued.push(l.slice(0, 60));
    });
    const app = M.content.resources.groups.map((g) => { const subs = []; for (const it of g.items) if (it.sub && subs[subs.length - 1] !== it.sub) subs.push(it.sub); return { group: g.group, subs }; });
    const diffs = [];
    app.forEach((g, k) => {
      const mg = mirror[k];
      if (!mg || mg.group !== g.group) diffs.push(`group ${k + 1}: app ${g.group}, mirror ${mg ? mg.group : 'none'}`);
      else if (JSON.stringify(g.subs) !== JSON.stringify(mg.subs)) diffs.push(`${g.group}: app ${g.subs.join(' / ') || 'none'}, mirror ${mg.subs.join(' / ') || 'none'}`);
    });
    if (mirror.length !== app.length) diffs.push(`groups: app ${app.length}, mirror ${mirror.length}`);
    const nSubs = app.reduce((n, g) => n + g.subs.length, 0);
    add('docs', 'Part 8 sub-group labels = app (P06)', !diffs.length && !glued.length ? 'PASS' : 'FAIL',
      diffs.length || glued.length ? [...diffs, ...glued.map((x) => `not a paragraph of its own: ${x}`)].slice(0, 3).join(' | ') : `${nSubs} labels in ${app.length} groups`);
  }
  const fcPath = path.join(SUITE, 'Documents', 'Agentic-SecOps-Tradecraft-Field-Card.md');
  if (fs.existsSync(fcPath)) {
    const fc = fs.readFileSync(fcPath, 'utf-8');
    const fcSec = (fc.match(/^## /gm) || []).length;
    // the canon phasing is derived from the JSX, as ripple_check does, never hardcoded
    const jsxSrc = fs.readFileSync(path.join(SUITE, 'Playbook', 'agentic-secops-teaming.jsx'), 'utf-8');
    const ph = (p) => (jsxSrc.match(new RegExp(`phase:\\s*"${p}"`, 'g')) || []).length;
    const fcPhase = fc.includes(`${ph('Now') + ph('Next') + ph('Later')} actions across **Now (${ph('Now')}) / Next (${ph('Next')}) / Later (${ph('Later')})**`);
    add('docs', 'field card (9 sections + canon phasing)', fcSec === 9 && fcPhase ? 'PASS' : 'FAIL', `sections=${fcSec} phasing=${fcPhase}`);
  } else {
    add('docs', 'field card (9 sections + canon phasing)', 'FAIL', 'file missing');
  }
  if (PUBLIC) {
    for (const name of ['README canonical 31/31 consistent', 'README deck-count headers read 31',
      'README carries 226 (no stale 119-162 stat)']) add('docs', name, 'SKIPPED', NOT_SHIPPED);
  } else {
    const readme = fs.readFileSync(path.join(SUITE, 'README.txt'), 'utf-8');
    const ok38 = readme.includes('Verified: 31 .pptx slides and\n31 PDF pages') ||
      /Verified: 31 \.pptx slides and\s*\n?31 PDF pages/.test(readme);
    add('docs', 'README canonical 31/31 consistent', ok38 && !readme.includes('36 is authoritative') && !readme.includes('37 is authoritative') && !readme.includes('38 is authoritative') && !readme.includes('32 is authoritative') ? 'PASS' : 'FAIL');
    add('docs', 'README deck-count headers read 31', readme.includes('CANONICAL DECK COUNT: 31 SLIDES') && readme.includes('SLIDE INVENTORY (31)') ? 'PASS' : 'FAIL');
    add('docs', 'README carries 226 (no stale 119-162 stat)',
      readme.includes('86/226/87') && !readme.includes('63/119/64') && !readme.includes('63/122/64') && !readme.includes('63/123/64') && !readme.includes('63/124/64') && !readme.includes('63/125/64') && !readme.includes('64/128/66') && !readme.includes('65/131/66') && !readme.includes('66/132/66') && !readme.includes('68/136/67') && !readme.includes('69/138/67') && !readme.includes('71/141/67') && !readme.includes('74/151/67') && !readme.includes('77/154/72') ? 'PASS' : 'FAIL');
  }
}

/* ---- layer 2b: embed-presence static assert (srcDoc gates, both directions) ---- */
{
  const py = spawnSync('python3', [path.join(__dirname, 'embed_check.py')], { encoding: 'utf-8' });
  process.stdout.write(py.stdout || '');
  if (py.error || py.status === null) add('embed', 'srcDoc embed-presence static assert', 'SKIPPED', 'python3 not available');
  else add('embed', 'srcDoc embed-presence static assert', py.status === 0 ? 'PASS' : 'FAIL');
}

/* ---- layer 3: render battery ---- */
{
  const r = spawnSync(process.execPath, [path.join(__dirname, 'render_check.cjs')], { encoding: 'utf-8' });
  process.stdout.write(r.stdout);
  if (r.status === 2) add('render', 'headless browser battery', 'SKIPPED', 'no Chrome / puppeteer');
  else add('render', 'headless browser battery', r.status === 0 ? 'PASS' : 'FAIL');
}

/* ---- layer 4: anchor-resolution battery (deep-link anchors + gated figures) ---- */
{
  const r = spawnSync(process.execPath, [path.join(__dirname, 'anchor_check.cjs')], { encoding: 'utf-8' });
  process.stdout.write(r.stdout);
  if (r.status === 2) add('anchor', 'anchor + gated-figure resolution', 'SKIPPED', 'no Chrome / puppeteer');
  else add('anchor', 'anchor + gated-figure resolution', r.status === 0 ? 'PASS' : 'FAIL');
}

/* ---- consolidated table ---- */
console.log('\n================ FULL BATTERY — CONSOLIDATED ================');
for (const [layer, name, status, detail] of rows) {
  const mark = status === 'PASS' ? '\u2713' : status === 'SKIPPED' ? '\u25cb' : '\u2717';
  console.log(`  ${mark} [${layer.padEnd(6)}] ${name.padEnd(46)} ${status}${detail ? '  ' + detail : ''}`);
}
console.log(failures ? `\n${failures} FAILURE(S)` : '\nALL GREEN (skipped layers reported above, not failed)');
process.exit(failures ? 1 : 0);
