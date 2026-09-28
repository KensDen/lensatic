#!/usr/bin/env node
/* ripple_check.cjs - count-ripple lockstep verification.
 *   node Validation/ripple_check.cjs
 *
 * Derives the canonical counts from the JSX source alone (actions by phase,
 * resources, glossary terms, tool tiles), then asserts every location that
 * STATES a count agrees:
 *   - sync_check.cjs: header comment + check labels + numeric asserts
 *   - battery.cjs: header comment + Part-8 expectation + README positive triple
 *   - README.txt: counts line + stat-callout line
 *   - study guide: Part-8 mirror link count + the LATEST dated addendum triple
 *     (older addenda are frozen history and deliberately not checked)
 *   - deck slide37.xml: the three <a:t> stat runs (SKIPPED if unzip absent)
 *   - Improvement-Roadmap.md: must not carry a non-current triple
 *   - P05 (Round I): the field card's phasing line; sync_check's action header, label and assert;
 *     render_check's Action Plan label and asserts; Public/CLAUDE.md carries no literal canon count;
 *     and no stray canon literal (a triple, a count with its noun, a phase run) in Validation/ or Public/ (in
 *     public mode, Validation/ or the top-level README.md, CLAUDE.md, index.html, THIRD_PARTY_NOTICES.md and
 *     package.json, since the public tree has no Public/ folder)
 * Frozen-history diagnostics:
 *   - the current triple must NOT be in battery's exclusion list
 *   - every excluded triple must be absent from README; if present, the
 *     exclusion was premature (or history was scrubbed) - the fix is to
 *     remove the triple from the exclusion list, never to edit frozen text
 * This script derives everything and never needs editing between passes.
 * PUBLIC EDITION MODE: a `.public-edition` marker file at the tree root switches on public mode, which
 * skips checks for files that exist only in the private working repo. Without the marker every check
 * runs exactly as before. Here: the README counts line is checked in README.md (FAIL if
 * it is missing); the stat-callout line, the Roadmap check and the two README frozen-history
 * diagnostics report SKIP.
 * Exit 0 = all green; 1 = failures.
 */
const fs = require('fs');
const path = require('path');
const { execFileSync, spawnSync } = require('child_process');

const SUITE = path.resolve(__dirname, '..');
const read = (rel) => fs.readFileSync(path.join(SUITE, rel), 'utf-8');
const PUBLIC = fs.existsSync(path.join(SUITE, '.public-edition'));
const NOT_SHIPPED = 'public edition: not shipped';
const jsx = read('Playbook/agentic-secops-teaming.jsx');

const results = [];
let failures = 0;
const check = (name, ok, detail) => {
  results.push([name, ok ? 'PASS' : ok === null ? 'SKIP' : 'FAIL', detail || '']);
  if (ok === false) failures++;
};

/* ---- derive canon from the JSX (independent parse) ---- */
const phase = (p) => (jsx.match(new RegExp(`phase:\\s*"${p}"`, 'g')) || []).length;
const A = phase('Now') + phase('Next') + phase('Later');
const rStart = jsx.indexOf('\n  resources: {');
const rEnd = jsx.indexOf('\n    ],\n  },', rStart);
const R = (jsx.slice(rStart, rEnd).match(/^\s*\{\s*(?:sub:\s*"[^"]*",\s*)?name:\s*"/gm) || []).length;
const fStart = jsx.search(/^  fluency: \{/m);
const fEnd = jsx.indexOf('\n  learningpath: {', fStart);
const G = (jsx.slice(fStart, fEnd > 0 ? fEnd : fStart + 60000).match(/\{\s*term:\s*"/g) || []).length;
const tStart = jsx.search(/^  tools: \{/m);
const tEnd = jsx.indexOf('\n  risks: {', tStart);
const T = (jsx.slice(tStart, tEnd > 0 ? tEnd : tStart + 60000).match(/\{\s*name:\s*"[^"]+",\s*url:/g) || []).length;
const TRIPLE = `${A}/${R}/${G}`;
console.log(`ripple_check: derived canon ${TRIPLE} (tools ${T})`);

/* ---- sync_check.cjs ---- */
const sc = read('Validation/sync_check.cjs');
check('sync_check header comment', sc.includes(`${R} resources / 13 groups`) && sc.includes(`${G} glossary terms`) && sc.includes(`${T} tools / 6 categories`));
check('sync_check resource assert', sc.includes(`'resources ${R} / 13 groups'`) && sc.includes(`resTotal === ${R}`));
check('sync_check glossary assert', sc.includes(`'glossary ${G} terms'`) && sc.includes(`terms === ${G}`));
check('sync_check tools assert', sc.includes(`'tools ${T} / 6 categories'`) && sc.includes(`toolTiles === ${T}`));

/* ---- battery.cjs ---- */
const bat = read('Validation/battery.cjs');
check('battery header comment', bat.includes(`Part 8 mirror = ${R} links`));
check('battery Part-8 expectation', bat.includes(`'study guide Part 8 mirror = ${R} links'`) && bat.includes(`links === ${R}`));
check('battery positive triple', bat.includes(`readme.includes('${TRIPLE}')`) && bat.includes(`'README carries ${R} `));

/* ---- README ---- */
const readme = PUBLIC ? null : read('README.txt');
if (PUBLIC) {
  const md = fs.existsSync(path.join(SUITE, 'README.md')) ? read('README.md') : null;
  check('README counts line', !!md && md.includes(`${A} sourced actions, ${R} indexed resources, ${G} glossary terms`),
    md ? 'README.md' : 'README.md missing');
  check('README stat-callout line', null, NOT_SHIPPED);
} else {
  check('README counts line', readme.includes(`${A} sourced actions, ${R} indexed resources, ${G} glossary terms`));
  check('README stat-callout line', readme.includes(`refresh summary + ${TRIPLE} stat callouts`));
}

/* ---- study guide ---- */
const guide = read('Documents/Agentic-SecOps-Study-Guide.md');
const p8 = guide.slice(guide.indexOf('## Part 8'), guide.indexOf('## Part 9'));
const links = (p8.match(/\[[^\]]+\]\(https?:\/\/[^)]+\)/g) || []).length;
check(`study guide Part-8 mirror = ${R}`, links === R, `links=${links}`);
const addenda = guide.split('\n').filter((l) => /\*\*.*addendum \(/.test(l));
const latest = addenda[addenda.length - 1] || '';
check('latest addendum carries current canon',
  latest.includes(`${R} sources`) && latest.includes(`${G} glossary terms`) && latest.includes(`${A} actions`),
  latest ? latest.slice(2, 60) + '...' : 'no addendum found');

/* ---- stale guard (PASS-85): footer REFRESHED stamp == latest addendum date ---- */
const MONWORD = { JAN: 'January', FEB: 'February', MAR: 'March', APR: 'April', MAY: 'May', JUN: 'June',
  JUL: 'July', AUG: 'August', SEP: 'September', OCT: 'October', NOV: 'November', DEC: 'December' };
const fMatch = jsx.match(/REFRESHED ([A-Z]{3}) (\d{1,2}), (\d{4})/);
const aMatch = latest.match(/^\*\*(\w+) (\d{1,2}), (\d{4}) addendum/);
const footerDate = fMatch ? `${MONWORD[fMatch[1]]} ${Number(fMatch[2])}, ${fMatch[3]}` : 'none';
const addendumDate = aMatch ? `${aMatch[1]} ${Number(aMatch[2])}, ${aMatch[3]}` : 'none';
check('stale guard: footer REFRESHED == latest addendum date',
  !!fMatch && !!aMatch && footerDate === addendumDate,
  `footer=${footerDate} addendum=${addendumDate}`);

/* Part-8 mirror (name, url) pairs must equal the Resource Index pairs, not
 * just the count (P6). The 4 person cross-listings appear twice in both. */
const fld = (x, k) => { const mm = x.match(new RegExp(k + ':\\s*"((?:[^"\\\\]|\\\\.)*)"')); return mm ? mm[1] : null; };
const riPairs = jsx.slice(rStart, rEnd).split('\n')
  .filter((l) => /^\s*\{\s*(?:sub:\s*"[^"]*",\s*)?name:\s*"/.test(l))
  .map((l) => `${fld(l, 'name')}\u0000${fld(l, 'url')}`).sort();
const p8Body = p8.slice(p8.indexOf('### The full Resource Index'));
const p8Pairs = [...p8Body.matchAll(/- \[(.*)\]\((https?:\/\/[^)]+)\)/g)].map((mm) => `${mm[1]}\u0000${mm[2]}`).sort();
const pairsMatch = riPairs.length === p8Pairs.length && riPairs.every((v, i) => v === p8Pairs[i]);
let pairDetail = `RI=${riPairs.length} P8=${p8Pairs.length}`;
if (!pairsMatch) {
  const setP8 = new Set(p8Pairs), setRI = new Set(riPairs);
  const only = (arr, other) => arr.find((v) => !other.has(v));
  const showRI = only(riPairs, setP8), showP8 = only(p8Pairs, setRI);
  pairDetail += (showRI ? ` | RI-only: ${showRI.split('\u0000')[0]}` : '') + (showP8 ? ` | P8-only: ${showP8.split('\u0000')[0]}` : '');
}
check('Part-8 pairs == Resource Index pairs', pairsMatch, pairDetail);

/* ---- deck stat slide ---- */
const have = (cmd) => spawnSync('which', [cmd]).status === 0;
if (PUBLIC) {  // Round K: the PPTX stays private; read the HIGHLIGHTS page of the deck PDF (its stat lines and its stamp)
  if (have('pdftotext')) {
    const pages = execFileSync('pdftotext', ['-enc', 'UTF-8', path.join(SUITE, 'Deck', 'Agentic-SecOps-Master-Deck.pdf'), '-'], { encoding: 'utf-8', maxBuffer: 1 << 26 }).split('\f');
    const hp = pages.find((p) => /[A-Z]{3,9} \d{4} REFRESH/.test(p)) || '';
    const lines = hp.split('\n').map((l) => l.trim());
    const expect = {}; [A, R, G].forEach((v) => { expect[v] = (expect[v] || 0) + 1; });
    const statsOk = !!hp && Object.entries(expect).every(([v, n]) => lines.filter((l) => l === String(v)).length === n);
    check('deck slide37 stat runs', statsOk, `deck PDF HIGHLIGHTS page: expect lines ${A}|${R}|${G} (duplicate-aware)`);
    const stampM = hp.match(/([A-Z]{3,9}) (\d{4}) REFRESH/);
    const wantStamp = aMatch ? (aMatch[1].toUpperCase() + ' ' + aMatch[3]) : null;
    check('deck stamp == latest addendum month-year', !!stampM && !!wantStamp && stampM[1] + ' ' + stampM[2] === wantStamp,
      `stamp=${stampM ? stampM[1] + ' ' + stampM[2] : 'none'} want=${wantStamp || 'none'} (deck PDF)`);
  } else {
    check('deck slide37 stat runs', null, 'pdftotext not available');
  }
} else if (have('unzip')) {
  const s37 = execFileSync('unzip', ['-p', path.join(SUITE, 'Deck', 'Agentic-SecOps-Master-Deck.pptx'), 'ppt/slides/slide37.xml'], { encoding: 'utf-8' });
  const runCount = (v) => (s37.match(new RegExp(`<a:t>${v}</a:t>`, 'g')) || []).length;
  const expectRuns = {};
  [A, R, G].forEach((v) => { expectRuns[v] = (expectRuns[v] || 0) + 1; });
  const runsOk = Object.entries(expectRuns).every(([v, n]) => runCount(v) === n);
  check('deck slide37 stat runs', runsOk, `expect <a:t>${A}|${R}|${G}</a:t> (duplicate-aware)`);
  const stampM = s37.match(/([A-Z]{3,9}) (\d{4}) REFRESH/);
  const wantStamp = aMatch ? (aMatch[1].toUpperCase() + ' ' + aMatch[3]) : null;
  check('deck stamp == latest addendum month-year', !!stampM && !!wantStamp && stampM[1] + ' ' + stampM[2] === wantStamp,
    `stamp=${stampM ? stampM[1] + ' ' + stampM[2] : 'none'} want=${wantStamp || 'none'}`);
} else {
  check('deck slide37 stat runs', null, 'unzip not available');
}

/* ---- Improvement Roadmap ---- */
if (PUBLIC) {
  check('Roadmap carries no stale triple', null, NOT_SHIPPED);
} else {
  const roadmap = read('Documents/Improvement-Roadmap.md');
  const stray = (roadmap.match(/\b\d{2}\/1\d{2}\/\d{2}\b/g) || []).filter((t) => t !== TRIPLE);
  check('Roadmap carries no stale triple', stray.length === 0, stray.join(',') || 'none');
}

/* ---- frozen-history diagnostics ---- */
if (PUBLIC) {
  check('current triple not in exclusion list', null, NOT_SHIPPED);
  check('no excluded triple survives in README', null, NOT_SHIPPED);
} else {
  const excluded = [...bat.matchAll(/!readme\.includes\('(\d+\/\d+\/\d+)'\)/g)].map((m) => m[1]);
  check('current triple not in exclusion list', !excluded.includes(TRIPLE),
    excluded.includes(TRIPLE) ? `remove '${TRIPLE}' from battery's exclusion list` : `excluded: ${excluded.length}`);
  const premature = excluded.filter((t) => readme.includes(t));
  check('no excluded triple survives in README', premature.length === 0,
    premature.length ? `premature exclusion of ${premature.join(',')} - remove from the exclusion list; never edit frozen WHAT'S NEW text` : 'clean');
}

/* ---- the canon's other literal sites (P05, Round I) ----
 * The field card's phasing line; sync_check's action header, label and assert; render_check's Action Plan label and
 * asserts (chips, CSV lines, Markdown bullets): each must equal the derived canon. Public/CLAUDE.md (CLAUDE.md in
 * public mode) must carry no literal canon count, by its own rule. And no stray canon literal in Validation/ or
 * Public/ (public mode: Validation/ or the top-level README.md, CLAUDE.md, index.html, THIRD_PARTY_NOTICES.md and
 * package.json; Round M): an actions/resources/terms triple is allowed only as battery's positive triple or in its exclusion list,
 * and a count stated with its noun (actions, sources, resources, links, glossary terms, tools, bullets) or a phase
 * run (All-N / Now-N / Next-N / Later-N) must equal the canon. */
{
  const NOW = phase('Now'), NEXT = phase('Next'), LATER = phase('Later');
  const fc = read('Documents/Agentic-SecOps-Tradecraft-Field-Card.md');
  check('P05 field card phasing line', fc.includes(`${A} actions across **Now (${NOW}) / Next (${NEXT}) / Later (${LATER})**`),
    (fc.match(/\d+ actions across \*\*Now \(\d+\) \/ Next \(\d+\) \/ Later \(\d+\)\*\*/) || ['no phasing line'])[0]);
  check('P05 sync_check action header, label, assert', sc.includes(`${A} actions (${NOW}/${NEXT}/${LATER})`) && sc.includes(`'actions ${A} (${NOW}/${NEXT}/${LATER})'`) &&
    sc.includes(`now === ${NOW} && next === ${NEXT} && later === ${LATER}`));
  const rc = read('Validation/render_check.cjs');
  check('P05 render_check Action Plan label and asserts', rc.includes(`'Action Plan live counts ${A}/${NOW}/${NEXT}/${LATER}'`) &&
    rc.includes(`plan.all === ${A} && plan.now === ${NOW} && plan.next === ${NEXT} && plan.later === ${LATER}`) &&
    rc.includes(`lines.length === ${A + 1}`) && rc.includes(`'CSV export ${A + 1} lines (header+${A})'`) && rc.includes(`.length === ${A} });`) && rc.includes(`'Markdown export ${A} bullets'`));
  const cmRel = PUBLIC ? 'CLAUDE.md' : 'Public/CLAUDE.md';
  const cm = read(cmRel);
  const canonNums = [...new Set([A, R, G, T, NOW, NEXT, LATER])];
  const cmHits = [...cm.matchAll(new RegExp(`\\b(?:${canonNums.join('|')})\\b(?=\\s*(?:sourced |indexed )?(?:actions?|resources?|sources?|glossary|terms?|tools?|Now|Next|Later)\\b)|\\b\\d{2,3}\\/\\d{3}\\/\\d{2,3}\\b`, 'g'))].map((m) => m[0]);
  check(`P05 ${cmRel} carries no literal canon count`, cmHits.length === 0, cmHits.join(', ') || 'none');
  const excluded = [...bat.matchAll(/!readme\.includes\('(\d+\/\d+\/\d+)'\)/g)].map((m) => m[1]);
  const scan = [];
  const walkDir = (d) => fs.readdirSync(path.join(SUITE, d)).sort().forEach((f) => {
    const rel = d + '/' + f;
    if (fs.statSync(path.join(SUITE, rel)).isDirectory()) walkDir(rel);
    else if (/\.(?:cjs|js|py|json|md|html|txt)$/.test(f) || !f.includes('.')) scan.push(rel);
  });
  walkDir('Validation');
  if (PUBLIC) ['README.md', 'CLAUDE.md', 'index.html', 'THIRD_PARTY_NOTICES.md', 'package.json'].forEach((f) => { if (fs.existsSync(path.join(SUITE, f))) scan.push(f); });
  else walkDir('Public');
  const want = { action: A, actions: A, bullets: A, sources: R, resources: R, 'indexed resources': R, links: R, 'glossary terms': G, tools: T };
  const stray = [];
  for (const rel of scan) {
    const t = read(rel);
    const at = (i) => `${rel}:${t.slice(0, i).split('\n').length}`;
    for (const m of t.matchAll(/\b(\d{2,3})\/(\d{3})\/(\d{2,3})\b/g)) {
      const ok = rel === 'Validation/battery.cjs' && ((m[0] === TRIPLE && t.slice(m.index - 17, m.index) === "readme.includes('") || excluded.includes(m[0]));
      if (!ok) stray.push(`${at(m.index)} ${m[0]}`);
    }
    for (const m of t.matchAll(/\b(\d{2,3})\s(actions|bullets|sources|resources|indexed resources|links|glossary terms|tools)\b/g)) {
      if (Number(m[1]) !== want[m[2]] && !/\d\/\d+\/\d/.test(t.slice(m.index - 12, m.index))) stray.push(`${at(m.index)} "${m[0]}"`);
    }
    for (const m of t.matchAll(/\b(All|Now|Next|Later)-(\d+)\b/g)) {
      const w = { All: A, Now: NOW, Next: NEXT, Later: LATER }[m[1]];
      if (Number(m[2]) !== w) stray.push(`${at(m.index)} "${m[0]}"`);
    }
  }
  check(`P05 no stray canon literal in Validation/ or ${PUBLIC ? 'the top-level README.md, CLAUDE.md, index.html, THIRD_PARTY_NOTICES.md and package.json' : 'Public/'}`, stray.length === 0, stray.length ? stray.slice(0, 4).join(' | ') + (stray.length > 4 ? ` | ... ${stray.length - 4} more` : '') : `${scan.length} files scanned`);
}

/* ---- report ---- */
console.log('================ RIPPLE CHECK ================');
for (const [name, status, detail] of results) {
  const mark = status === 'PASS' ? '✓' : status === 'SKIP' ? '○' : '✗';
  console.log(`  ${mark} ${name.padEnd(44)} ${status}  ${detail}`);
}
console.log(failures ? `\n${failures} FAILURE(S)` : '\nALL GREEN');
process.exit(failures ? 1 : 0);
