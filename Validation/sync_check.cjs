#!/usr/bin/env node
/* sync_check.cjs — Agentic SecOps suite structural validation.
 * Pure Node, zero dependencies required. Run from anywhere:
 *   node Validation/sync_check.cjs
 *
 * Checks:
 *   1. JSX nav parity (content tabs <-> nav entries, both 35)
 *   2. Canonical counts: 87 actions (40/37/10), 243 resources / 13 groups,
 *      88 glossary terms / 5 groups, 34 tools / 6 categories
 *   3. index.html zero external loads (script src / link href / remote img /
 *      @import / remote url() / fetch(http)
 *   4. All 16 diagram posters: zero external loads, balanced <html> tags;
 *      twin mirror: each of the 14 JSX srcDoc figures equals its Diagrams/ file
 *      (full text for all 14 since C1; a twin listed in TWIN_CONTENT_DRIFT would
 *      instead be held to an identical :root block and zero retired-identity
 *      literals)
 *   5. JSX <-> HTML sync:
 *        - FULL mode if the `typescript` package resolves: transpile the JSX
 *          through the canonical pipeline and byte-compare with the payload
 *          embedded in index.html
 *        - TRIPWIRE mode otherwise: every sampled string literal from the JSX
 *          must appear verbatim in the embedded payload
 *   6. P08 (Round I): each linked action source label's title words appear in the name of the Resource
 *      Index entry its link points to (text_units.cjs and Validation/registry.json)
 * Exit code 0 = all green; 1 = failures.
 */
const fs = require('fs');
const path = require('path');

const SUITE = path.resolve(__dirname, '..');
const JSX = path.join(SUITE, 'Playbook', 'agentic-secops-teaming.jsx');
const HTML = path.join(SUITE, 'Playbook', 'index.html');
const DIAGRAMS = path.join(SUITE, 'Diagrams');

const results = [];
let failures = 0;
const check = (name, ok, detail) => {
  results.push([name, ok ? 'PASS' : 'FAIL', detail || '']);
  if (!ok) failures++;
};

const jsx = fs.readFileSync(JSX, 'utf-8');
const html = fs.readFileSync(HTML, 'utf-8');

/* ---- 1. nav parity ---- */
const contentTabs = [...jsx.matchAll(/^  (\w+): \{/gm)].map((m) => m[1]);
const navEntries = [...jsx.matchAll(/\{\s*id:\s*"([^"]+)",\s*label:/g)].map((m) => m[1]);
const ct = new Set(contentTabs), nv = new Set(navEntries);
const missingNav = [...ct].filter((x) => !nv.has(x));
const missingTab = [...nv].filter((x) => !ct.has(x));
check('nav parity 35<->35',
  contentTabs.length === 35 && navEntries.length === 35 && !missingNav.length && !missingTab.length,
  `tabs=${contentTabs.length} nav=${navEntries.length}` +
  (missingNav.length ? ` missingNav=${missingNav}` : '') +
  (missingTab.length ? ` missingTab=${missingTab}` : ''));

/* ---- 2. canonical counts ---- */
const phase = (p) => (jsx.match(new RegExp(`phase:\\s*"${p}"`, 'g')) || []).length;
const now = phase('Now'), next = phase('Next'), later = phase('Later');
check('actions 87 (40/37/10)', now === 40 && next === 37 && later === 10,
  `Now=${now} Next=${next} Later=${later}`);

const resourceGroups = ['Frameworks & Standards', 'Community & Collective Resources', 'The Offense\u2013Defense Balance',
  'Threat Intelligence & Industry Reports', 'Zero Trust & Agentic Insider Risk',
  'Vendor & Platform Security', 'Federal & DoD Standards', 'Regulatory & Compliance',
  'Human-Centric AI Adoption', 'Practitioner & Industry Insights',
  'Voices to Follow',
  'Frontier Labs & National-Security Research', 'Research & Reference'];
const gpos = resourceGroups
  .map((g) => ({ g, i: jsx.search(new RegExp(`group:\\s*"${g.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}"`)) }))
  .filter((x) => x.i >= 0)
  .sort((a, b) => a.i - b.i);
let resTotal = 0;
gpos.forEach((x, k) => {
  const end = k + 1 < gpos.length ? gpos[k + 1].i : x.i + 80000;
  const block = jsx.slice(x.i, end);
  resTotal += (block.match(/\{\s*(?:sub:\s*"[^"]*",\s*)?name:\s*"/g) || []).length;
});
check('resources 243 / 13 groups', gpos.length === 13 && resTotal === 243,
  `groups=${gpos.length} items=${resTotal}`);

/* ---- tier integrity (TIERING round): every RI entry carries a tier; split pinned ---- */
const riSlice = jsx.slice(gpos[0].i, gpos[gpos.length - 1].i + 80000);
const tierSpine = (riSlice.match(/tier: "spine"/g) || []).length;
const tierAppx = (riSlice.match(/tier: "appendix"/g) || []).length;
check('tier integrity 187 spine / 56 appendix', tierSpine === 187 && tierAppx === 56 && tierSpine + tierAppx === resTotal,
  `spine=${tierSpine} appendix=${tierAppx} total=${resTotal}`);

/* ---- impl integrity (ACTIONABILITY): armed and empty until exemplar payloads land ---- */
const riNames = new Set([...riSlice.matchAll(/name: "((?:[^"\\]|\\.)*)", url:/g)].map((m) => m[1]));
const implBlocks = [...jsx.matchAll(/impl: \{([^{}]*)\}/g)];
let implOk = true, implNote = '';
for (const m of implBlocks) {
  /* hundred-and-ninth pass: a "]" inside a quoted step or ref (the [un]prompted 2026 talk names) does not end the array */
  const stepsM = m[1].match(/steps: \[((?:"(?:[^"\\]|\\.)*"|[^\]"])*)\]/);
  const nSteps = stepsM ? ((stepsM[1].match(/"/g) || []).length / 2) : 0;
  if (nSteps < 1) { implOk = false; implNote = 'impl without steps'; break; }
  const refsM = m[1].match(/refs: \[((?:"(?:[^"\\]|\\.)*"|[^\]"])*)\]/);
  if (refsM) for (const rm of [...refsM[1].matchAll(/"((?:[^"\\]|\\.)*)"/g)]) {
    if (!riNames.has(rm[1])) { implOk = false; implNote = 'unresolved ref: ' + rm[1].slice(0, 48); break; }
  }
  if (!implOk) break;
}
check(`impl integrity (armed; payloads=${implBlocks.length})`, implOk, implNote || 'all payloads valid');

const fluencyStart = jsx.search(/^  fluency: \{/m);
const fluencyEnd = jsx.indexOf('\n  learningpath: {', fluencyStart);
const fluencyBlock = jsx.slice(fluencyStart, fluencyEnd > 0 ? fluencyEnd : fluencyStart + 60000);
const terms = (fluencyBlock.match(/\{\s*term:\s*"/g) || []).length;
check('glossary 88 terms', terms === 88, `terms=${terms}`);

const toolsStart = jsx.search(/^  tools: \{/m);
const toolsEnd = jsx.indexOf('\n  risks: {', toolsStart);
const toolsBlock = jsx.slice(toolsStart, toolsEnd > 0 ? toolsEnd : toolsStart + 60000);
const toolCats = (toolsBlock.match(/\{\s*name:\s*"[^"]+",\s*icon:/g) || []).length;
const toolTiles = (toolsBlock.match(/\{\s*name:\s*"[^"]+",\s*url:/g) || []).length;
check('tools 34 / 6 categories', toolCats === 6 && toolTiles === 34,
  `categories=${toolCats} tools=${toolTiles}`);

/* ---- 3. index.html zero external loads ---- */
const extPatterns = [
  [/<script[^>]*\bsrc\s*=/g, 'script src'],
  [/<link[^>]*\bhref\s*=(?!\s*["']?data:)/g, 'link href'],
  [/<img[^>]*\bsrc\s*=\s*["']http/g, 'remote img'],
  [/@import\s/g, '@import'],
  [/url\(\s*["']?(?:https?:)?\/\//g, 'remote url()'],
  [/\bfetch\s*\(\s*["']http/g, 'fetch(http)'],
];
const extHits = extPatterns.flatMap(([re, label]) =>
  (html.match(re) || []).map(() => label));
check('index.html zero external loads', extHits.length === 0, extHits.join(',') || 'clean');

/* ---- 4. diagrams ---- */
const diagFiles = fs.readdirSync(DIAGRAMS).filter((f) => f.endsWith('.html')).sort();
let diagBad = [];
for (const f of diagFiles) {
  const d = fs.readFileSync(path.join(DIAGRAMS, f), 'utf-8');
  const hits = extPatterns.flatMap(([re]) => d.match(re) || []);
  const open = (d.match(/<html/g) || []).length;
  const close = (d.match(/<\/html>/g) || []).length;
  if (hits.length || open !== 1 || close !== 1) diagBad.push(f);
}
check('diagrams 16x clean', diagFiles.length === 16 && diagBad.length === 0,
  `files=${diagFiles.length}` + (diagBad.length ? ` bad=${diagBad}` : ''));

/* twin mirror (B2): the 14 srcDoc templates in the JSX, matched to Diagrams/ files by
 * <title>. FULL: template text == file text (only the file's trailing newline is
 * ignored). TWIN_CONTENT_DRIFT lists twins whose content drifted before B2 and was
 * not reconciled (empty since C1 synced maturity-ladder): those must carry the identical :root block and zero retired-
 * identity literals (list mirrors statics_check.cjs section 8). SYNC_TWIN_JSX /
 * SYNC_TWIN_DIAGRAMS override the sources for canary runs. */
{
  const TWIN_COUNT = 14;
  const TWIN_CONTENT_DRIFT = [];
  const OLD_IDENTITY = /#(?:A100FF|C2A3FF|7500C0|C966FF|E2B4FF|F0ABFC|7000B0|7A3AD9|16082B|1E0A3A|0D0018|241147|1A0030|120022|160A2E|12061F|1B1330|EDE9F5|F3EFFA|FF50A0|05F2DB|224BFF)\b|rgba?\(\s*(?:161,\s*0,\s*255|201,\s*102,\s*255|194,\s*163,\s*255|255,\s*80,\s*160|5,\s*242,\s*219|34,\s*75,\s*255)|graphik/i;
  const twinJsx = fs.readFileSync(process.env.SYNC_TWIN_JSX || JSX, 'utf-8');
  const twinDir = process.env.SYNC_TWIN_DIAGRAMS || DIAGRAMS;
  const byTitle = {};
  for (const f of fs.readdirSync(twinDir).filter((x) => x.endsWith('.html'))) {
    const t = fs.readFileSync(path.join(twinDir, f), 'utf-8');
    const m = t.match(/<title>([\s\S]*?)<\/title>/);
    if (m) byTitle[m[1]] = { f, t };
  }
  const unesc = (x) => x.replace(/\\([`$\\])/g, '$1');
  const rootOf = (x) => (x.match(/:root\s*\{[^}]*\}/) || [''])[0];
  let twins = 0, full = 0, rooted = 0;
  const drift = [];
  for (const m of twinJsx.matchAll(/srcDoc=\{`([\s\S]*?)`\}/g)) {
    twins++;
    const tw = unesc(m[1]);
    const title = (tw.match(/<title>([\s\S]*?)<\/title>/) || [])[1];
    const file = byTitle[title];
    if (!file) { drift.push(`no Diagrams file titled "${title}"`); continue; }
    if (TWIN_CONTENT_DRIFT.includes(file.f)) {
      if (rootOf(tw) && rootOf(tw) === rootOf(file.t) && !OLD_IDENTITY.test(tw)) rooted++;
      else drift.push(`${file.f} (:root or retired identity)`);
    } else if (tw === file.t || tw + '\n' === file.t) full++;
    else drift.push(file.f);
  }
  check(`twin mirror ${TWIN_COUNT}x (${full} full-text, ${rooted} :root+clean)`,
    twins === TWIN_COUNT && drift.length === 0, drift.length ? `drift: ${drift.join(', ')}` : `twins=${twins}`);
}

/* ---- 5. JSX <-> HTML sync ---- */
const markRe = /\/\* ===== Agentic SecOps playbook component[^*]*\*\/\s*\n?/;
const mark = html.match(markRe);
let payload = null;
if (mark) {
  const start = mark.index + mark[0].length;
  const end = html.indexOf('</script>', start);
  payload = html.slice(start, end);
}
check('embedded payload located', !!payload, payload ? `${payload.length} chars` : 'marker missing');

let ts = null;
try { ts = require('typescript'); } catch (e) {
  try {
    const root = require('child_process').execSync('npm root -g', { encoding: 'utf-8' }).trim();
    ts = require(require('path').join(root, 'typescript'));
  } catch (e2) { /* tripwire mode */ }
}
if (ts && payload) {
  let src = jsx
    .replace('import { useState, Fragment } from "react";', 'const { useState, Fragment } = React;')
    .replace('export default function App() {', 'function App() {');
  const out = ts.transpileModule(src, {
    compilerOptions: { jsx: ts.JsxEmit.React, target: ts.ScriptTarget.ES2019, module: ts.ModuleKind.None },
  }).outputText;
  check('JSX<->HTML byte-sync (FULL)', out === payload,
    out === payload ? 'byte-identical' : `built=${out.length} embedded=${payload.length}`);
} else if (payload) {
  const samples = [...jsx.matchAll(/"((?:[^"\\]|\\.){40,90})"/g)]
    .map((m) => m[1]).filter((x) => !x.includes('\\')).slice(0, 60);
  const missing = samples.filter((x) => !payload.includes(x));
  check('JSX<->HTML sync (TRIPWIRE — install `typescript` for byte-proof)',
    samples.length >= 30 && missing.length === 0,
    `sampled=${samples.length} missing=${missing.length}`);
}

/* ---- 6. source labels match their sources (P08, Round I) ----
 * Each action source label that actionSourceLinks links: the words of its title (after "Publisher · " when the label
 * has one, without a trailing ", Mon YYYY") must appear in the name of the Resource Index entry whose URL the label
 * links to (an all-capitals word may match the initials of consecutive words there). A label whose URL is in no
 * Resource Index entry has no name to compare and is counted, not failed. Legitimate words (a genre such as "Note", a
 * team, an item number) are allowed per label in Validation/registry.json; judgment items are baselined there. */
{
  const TU = require('./text_units.cjs');
  const REG = TU.loadRegistry(SUITE);
  const M = TU.loadModel(SUITE);
  const nurl = (u) => u.trim().replace(/^http:/, 'https:').replace(/\/+$/, '').toLowerCase();
  const byUrl = new Map();
  for (const g of M.content.resources.groups) for (const it of g.items) { const k = nurl(it.url); if (!byUrl.has(k)) byUrl.set(k, []); byUrl.get(k).push(it.name); }
  const fold = (s) => s.normalize('NFKD').replace(/[\u0300-\u036f]/g, '').replace(/[’']/g, "'").toLowerCase();
  const STOP = new Set(['the', 'a', 'an', 'of', 'and', 'for', 'to', 'in', 'on', 'as', 'by', 'with']);
  const words = (s) => fold(s).split(/[^a-z0-9.\/]+/).map((w) => w.replace(/^[.\/]+|[.\/]+$/g, '')).filter((w) => w && !STOP.has(w));
  const initials = (n) => { const ws = fold(n).split(/[^a-z0-9]+/).filter(Boolean); const o = new Set(); for (let i = 0; i < ws.length; i++) for (let j = i + 2; j <= Math.min(ws.length, i + 6); j++) o.add(ws.slice(i, j).map((w) => w[0]).join('')); return o; };
  const hits = []; let linked = 0, outside = 0, allowedLabels = 0;
  for (const [label, url] of Object.entries(M.actionSourceLinks)) {
    const names = byUrl.get(nurl(url));
    if (!names) { outside++; continue; }
    linked++;
    const noDate = label.replace(/,\s*(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.? \d{4}$/, '');
    const title = noDate.includes(' · ') ? noDate.split(' · ').slice(1).join(' · ') : noDate;
    const allowed = new Set((REG.allow || []).filter((a) => a.check === 'P08' && a.label === label).flatMap((a) => a.words));
    const raw = names.map((n) => { const nw = new Set(words(n)); const ini = initials(n); return words(title).filter((w) => !nw.has(w) && !ini.has(w)); })
      .sort((a, b) => a.length - b.length)[0];
    const missing = raw.filter((w) => !allowed.has(w));
    if (raw.length && !missing.length) allowedLabels++;
    if (missing.length) hits.push({ check: 'P08', file: 'Playbook/agentic-secops-teaming.jsx', unit: 'actionSourceLinks', line: 0, index: 0, text: label, ctx: label, missing });
  }
  const res = TU.resolveHits('P08', hits, REG);
  const n = TU.openCount(res);
  check(`P08 source labels match their resources (${linked} linked)`, n === 0,
    (n ? res.open.map((h) => `"${h.text}" lacks ${h.missing.join(', ')}`).concat(res.stale.map((b) => `stale ${b.id}`), res.ambiguous.map((b) => `ambiguous ${b.id}`)).slice(0, 3).join(' | ') + ' | ' : '') +
    `${TU.tally(res).replace('allowlisted 0', 'allowlisted ' + allowedLabels)} · ${outside} label(s) link outside the Resource Index, not compared`);
}

/* ---- report ---- */
console.log('================ SYNC CHECK ================');
for (const [name, status, detail] of results) {
  console.log(`  ${status === 'PASS' ? '\u2713' : '\u2717'} ${name.padEnd(52)} ${status}  ${detail}`);
}
console.log(failures ? `\n${failures} FAILURE(S)` : '\nALL GREEN');
process.exit(failures ? 1 : 0);
