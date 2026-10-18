/* text_units.cjs: the shipped text as located units, and the matching rules for Validation/registry.json.
 * A library (nothing runs on require), used by the checks the critic gauntlet proposed: statics_check (P01 P02 P04 P07
 * P10 P11), sync_check (P08), battery (P06), render_check (P14), link_check (P03) and build_exec_summary (P13), and by
 * statics_check's license checks (Round J).
 * Read-only; Node built-ins, the system `unzip` for the brief and the deck (as ripple_check uses it), and typescript,
 * when it resolves, for the app's interface text.
 *
 * A unit is { file, unit, line, text, kind, deck }:
 *   - the JSX: every string in the content model (the `sections`, `navGroups` and `content` objects, evaluated as the
 *     app evaluates them), unit = its path (content.cases.categories[0].summary); a stat ({ value, label, source }) and
 *     a list item ({ name, use }) are one unit each; keys that hold no prose (url, icon, color, id, tier and the like)
 *     are left out. Plus the text nodes and the title, aria-label, placeholder and alt strings of the interface code
 *     (unit = "ui"), when typescript resolves;
 *   - Markdown (the study guide, the field card, README.md, CLAUDE.md): one unit per paragraph. The study guide's
 *     dated-addenda section (private tree) and its "About this edition" section (public edition) are left out: the
 *     first is frozen history that does not ship, the second is written by the export;
 *   - HTML (the executive summary, the landing page, Diagrams/): one unit per line of the text view (style and script
 *     removed, tags removed, entities decoded, line numbers kept);
 *   - the concept brief DOCX and the deck PPTX: one unit per paragraph; deck units carry deck: true. In public mode,
 *     where they do not ship, the units come from their PDFs (one per paragraph of each page), under the same names.
 * File names are the private tree's (Public/README.md, Public/CLAUDE.md, Public/index.html). In public mode (the
 * .public-edition marker) the same units are read from the root copies and keep their private names, so one registry
 * entry matches in both trees.
 *
 * Registry matching (Validation/registry.json). A hit is { check, file, unit, line, index, text, ctx }: ctx is the
 * unit's text and index the hit's offset in it.
 *   - allow entries { check, phrase | regex, reason, file? } cover every hit whose unit holds the phrase (or a regex
 *     match) at a span covering the hit: a cited title, a proper name, a quoted source. One entry may cover many hits.
 *   - baseline entries { id, check, file, hit, context, status, note } cover the hit in their file whose text is `hit`
 *     and whose unit holds `context` at a span covering it. An entry must cover exactly one hit, so a new occurrence
 *     still fires; one that covers none is stale and one that covers several is ambiguous, and both count as open.
 *     status "judgment" is a decision for the owner; "DEFERRED-DECK" waits for the deck round. */
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const JSX_REL = 'Playbook/agentic-secops-teaming.jsx';
const GUIDE_REL = 'Documents/Agentic-SecOps-Study-Guide.md';
const FROZEN_HEAD = '## June 2026 refresh \u2014 what changed in this revision';
const EDITION_HEAD = '## About this edition';
const PART0 = '\n-----\n\n## Part 0 \u2014 Foundations';
const PUBLIC_NAMES = { 'Public/README.md': 'README.md', 'Public/CLAUDE.md': 'CLAUDE.md', 'Public/index.html': 'index.html',
  'Public/THIRD_PARTY_NOTICES.md': 'THIRD_PARTY_NOTICES.md', 'Public/LICENSE': 'LICENSE', 'Public/_package.json': 'package.json' };
const NO_PROSE_KEYS = new Set(['id', 'ids', 'icon', 'color', 'dim', 'url', 'tier', 'phase', 'owner', 'severity', 'viz', 'mitTabs', 'kind']);

const isPublic = (suite) => fs.existsSync(path.join(suite, '.public-edition'));
/* the path a private-tree file has in this tree */
const onDisk = (suite, rel) => (isPublic(suite) && PUBLIC_NAMES[rel] ? PUBLIC_NAMES[rel] : rel);
const readRel = (suite, rel) => fs.readFileSync(path.join(suite, onDisk(suite, rel)), 'utf-8');

/* the app's data, evaluated from the JSX source the way the app evaluates it */
function loadModel(suite) {
  const jsx = fs.readFileSync(path.join(suite, JSX_REL), 'utf-8');
  const a = jsx.indexOf('const palette = {'), b = jsx.indexOf('const severityColor');
  const c = jsx.indexOf('const actionSourceLinks = {'), d = jsx.indexOf('const renderSourceLabel');
  if (a < 0 || b < a || c < 0 || d < c) throw new Error('text_units: the JSX data blocks were not found');
  const m = new Function(jsx.slice(a, b) + '\n' + jsx.slice(c, d) + '\nreturn { palette, sections, navGroups, content, actionSourceLinks };')();
  m.jsx = jsx;
  return m;
}

/* the line where a string's text first appears in the source (by its first 40 characters, escapes aside); 0 if not found */
function lineOf(src, text, from) {
  const probe = text.slice(0, 40);
  let i = src.indexOf(probe, from || 0);
  if (i < 0) i = src.indexOf(JSON.stringify(probe).slice(1, -1), from || 0);
  return i < 0 ? 0 : src.slice(0, i).split('\n').length;
}

let tsCache;
function typescript() {
  if (tsCache !== undefined) return tsCache;
  try { tsCache = require('typescript'); } catch (e) {
    try { tsCache = require(path.join(execFileSync('npm', ['root', '-g'], { encoding: 'utf-8', stdio: ['ignore', 'pipe', 'ignore'] }).trim(), 'typescript')); } catch (e2) { tsCache = null; }
  }
  return tsCache;
}

function jsxUnits(suite) {
  const m = loadModel(suite);
  const out = [];
  const cStart = m.jsx.indexOf('const content = {');
  const push = (p, text, probe) => out.push({ file: JSX_REL, unit: p, text, kind: 'jsx',
    line: lineOf(m.jsx, probe || text, p.startsWith('content') ? cStart : 0) });
  const walk = (v, p, key) => {
    if (NO_PROSE_KEYS.has(key)) return;
    if (typeof v === 'string') { push(p, v); return; }
    if (Array.isArray(v)) { v.forEach((x, i) => walk(x, p + '[' + i + ']', key)); return; }
    if (!v || typeof v !== 'object') return;
    const ks = Object.keys(v).filter((k) => typeof v[k] === 'string' && !NO_PROSE_KEYS.has(k));
    const onlyStrings = Object.keys(v).every((k) => typeof v[k] === 'string');
    if (onlyStrings && ks.length && ks.every((k) => ['value', 'label', 'source'].includes(k)) && 'value' in v && 'label' in v) {
      push(p, ks.map((k) => v[k]).join(' · '), v.value.length >= 3 ? v.value : v.label); return;
    }
    if (onlyStrings && 'name' in v && 'use' in v && ks.every((k) => ['name', 'use'].includes(k))) { push(p, `${v.name}: ${v.use}`, v.name); return; }
    for (const [k, x] of Object.entries(v)) walk(x, p + '.' + k, k);
  };
  walk(m.sections, 'sections'); walk(m.navGroups, 'navGroups'); walk(m.content, 'content');
  const ts = typescript();
  if (ts) {
    const appAt = m.jsx.indexOf('export default function App()');
    const sf = ts.createSourceFile('app.tsx', m.jsx, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
    const ATTRS = new Set(['title', 'aria-label', 'placeholder', 'alt']);
    const at = (n) => sf.getLineAndCharacterOfPosition(n.getStart(sf)).line + 1;
    const visit = (n) => {
      if (n.pos >= appAt) {
        if (n.kind === ts.SyntaxKind.JsxText) {
          const t = n.getText(sf).replace(/\s+/g, ' ').trim();
          if (/[A-Za-z]{2}/.test(t)) out.push({ file: JSX_REL, unit: 'ui', text: t, kind: 'jsx', line: at(n) });
        } else if (n.kind === ts.SyntaxKind.JsxAttribute && ATTRS.has(n.name.getText(sf)) && n.initializer && n.initializer.kind === ts.SyntaxKind.StringLiteral) {
          out.push({ file: JSX_REL, unit: 'ui', text: n.initializer.text, kind: 'jsx', line: at(n) });
        }
      }
      ts.forEachChild(n, visit);
    };
    visit(sf);
  }
  return { units: out, uiParsed: !!ts };
}

/* Markdown paragraphs with their first line; the study guide's frozen or generated section is blanked, lines kept */
function mdUnits(suite, rel) {
  let t = readRel(suite, rel);
  if (rel === GUIDE_REL) {
    const head = t.includes(FROZEN_HEAD) ? FROZEN_HEAD : t.includes(EDITION_HEAD) ? EDITION_HEAD : null;
    const a = head ? t.indexOf(head) : -1, b = t.indexOf(PART0);
    if (a >= 0 && b > a) t = t.slice(0, a) + '\n'.repeat(t.slice(a, b + 1).split('\n').length - 1) + t.slice(b + 1);
  }
  const out = []; let buf = [], start = 0;
  const flush = () => { if (buf.length) out.push({ file: rel, unit: 'L' + start, line: start, text: buf.join('\n'), kind: 'md' }); buf = []; };
  t.split('\n').forEach((l, i) => { if (l.trim()) { if (!buf.length) start = i + 1; buf.push(l); } else flush(); });
  flush();
  return out;
}

/* the text view of an HTML file: style and script blocks, comments and tags removed (their newlines kept), entities decoded */
function htmlText(t) {
  const keepNl = (s) => '\n'.repeat((s.match(/\n/g) || []).length);
  t = t.replace(/<(style|script)\b[\s\S]*?<\/\1>/gi, keepNl).replace(/<!--[\s\S]*?-->/g, keepNl).replace(/<[^>]*>/g, keepNl);
  const ent = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', mdash: '\u2014', ndash: '\u2013', rsquo: '’',
    lsquo: '‘', rdquo: '”', ldquo: '“', hellip: '…', middot: '·', rarr: '→', larr: '←',
    le: '≤', ge: '≥', times: '×', copy: '©' };
  return t.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m0, e) => {
    if (e[0] === '#') { const cp = e[1] === 'x' || e[1] === 'X' ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10); return cp <= 0x10ffff ? String.fromCodePoint(cp) : m0; }
    return ent[e.toLowerCase()] || m0;
  });
}
function htmlUnits(suite, rel) {
  const out = [];
  htmlText(readRel(suite, rel)).split('\n').forEach((l, i) => {
    const t = l.replace(/\s+/g, ' ').trim();
    if (/[A-Za-z]/.test(t)) out.push({ file: rel, unit: 'L' + (i + 1), line: i + 1, text: t, kind: 'html' });
  });
  return out;
}

/* OOXML paragraphs (the brief's w:p, the deck's slide and notes a:p), text runs joined */
function ooxmlUnits(suite, rel, members, ptag, ttag, deck) {
  const abs = path.join(suite, rel);
  const names = execFileSync('unzip', ['-Z1', abs], { encoding: 'utf-8', maxBuffer: 1 << 26 }).split('\n').filter((n) => members.test(n));
  names.sort((x, y) => x.localeCompare(y, 'en', { numeric: true }));
  const dec = (s) => s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (m0, n) => String.fromCodePoint(+n)).replace(/&#x([0-9a-f]+);/gi, (m0, h) => String.fromCodePoint(parseInt(h, 16))).replace(/&amp;/g, '&');
  const out = [];
  for (const n of names) {
    const x = execFileSync('unzip', ['-p', abs, n], { encoding: 'utf-8', maxBuffer: 1 << 26 });
    const pr = new RegExp(`<${ptag}\\b[^>]*>([\\s\\S]*?)</${ptag}>`, 'g'), tr = new RegExp(`<${ttag}(?:\\s[^>]*)?>([^<]*)</${ttag}>`, 'g');
    let k = 0;
    for (const p of x.matchAll(pr)) {
      k++;
      const s = dec([...p[1].matchAll(tr)].map((r) => r[1]).join(''));
      if (/[A-Za-z]/.test(s)) out.push({ file: rel, unit: `${n}#p${k}`, line: 0, text: s, kind: deck ? 'pptx' : 'docx', deck: !!deck });
    }
  }
  return out;
}

const MD_FILES = [GUIDE_REL, 'Documents/Agentic-SecOps-Tradecraft-Field-Card.md', 'Public/README.md', 'Public/CLAUDE.md'];
const BRIEF_REL = 'Documents/Adversary-Emulation-Concept-Brief.docx';
const DECK_REL = 'Deck/Agentic-SecOps-Master-Deck.pptx';
/* Round K: the public edition ships the deck and the brief as PDFs, and their PPTX and DOCX stay private. In public mode
 * (or wherever the OOXML is absent) their units come from the PDF's text: one unit per paragraph of each page, lines
 * joined, still filed under the private names so one registry entry matches in both trees. */
const PDF_OF = { [BRIEF_REL]: 'Documents/Adversary-Emulation-Concept-Brief.pdf', [DECK_REL]: 'Deck/Agentic-SecOps-Master-Deck.pdf' };
const fromPdf = (suite, rel) => isPublic(suite) && !fs.existsSync(path.join(suite, rel)) && !!PDF_OF[rel];
function pdfText(suite, rel) {
  return execFileSync('pdftotext', ['-enc', 'UTF-8', path.join(suite, PDF_OF[rel]), '-'], { encoding: 'utf-8', maxBuffer: 1 << 26 });
}
function pdfUnits(suite, rel, deck) {
  const out = [];
  pdfText(suite, rel).split('\f').forEach((page, pi) => page.split(/\n\s*\n/).forEach((para, k) => {
    const s = para.replace(/\s*\n\s*/g, ' ').trim();
    if (/[A-Za-z]/.test(s)) out.push({ file: rel, unit: `pdf page ${pi + 1}#p${k + 1}`, line: 0, text: s, kind: 'pdf', deck: !!deck });
  }));
  return out;
}
const htmlFiles = (suite) => ['Documents/Agentic-SecOps-Executive-Summary.html', 'Public/index.html',
  ...fs.readdirSync(path.join(suite, 'Diagrams')).filter((f) => f.endsWith('.html')).sort().map((f) => 'Diagrams/' + f)];
/* every shipped unit; opts.files limits the set to the listed private-tree names. Returns { units, uiParsed }. */
function textUnits(suite, opts) {
  const want = (rel) => !opts || !opts.files || opts.files.includes(rel);
  let units = [], uiParsed = null;
  if (want(JSX_REL)) { const j = jsxUnits(suite); units = units.concat(j.units); uiParsed = j.uiParsed; }
  for (const rel of MD_FILES) if (want(rel)) units = units.concat(mdUnits(suite, rel));
  for (const rel of htmlFiles(suite)) if (want(rel)) units = units.concat(htmlUnits(suite, rel));
  if (want(BRIEF_REL)) units = units.concat(fromPdf(suite, BRIEF_REL) ? pdfUnits(suite, BRIEF_REL, false) : ooxmlUnits(suite, BRIEF_REL, /^word\/document\.xml$/, 'w:p', 'w:t', false));
  if (want(DECK_REL)) units = units.concat(fromPdf(suite, DECK_REL) ? pdfUnits(suite, DECK_REL, true) : ooxmlUnits(suite, DECK_REL, /^ppt\/(slides\/slide|notesSlides\/notesSlide)\d+\.xml$/, 'a:p', 'a:t', true));
  return { units, uiParsed };
}

/* spans of URLs in a unit's text (bare URLs and Markdown link targets), so prose checks can skip them */
function urlSpans(t) {
  const out = [];
  for (const m of t.matchAll(/https?:\/\/[^\s)"'<>\]]+/g)) out.push([m.index, m.index + m[0].length]);
  return out;
}
const inSpans = (spans, i) => spans.some(([a, b]) => i >= a && i < b);
/* every match of `re` (global) in the units, URLs skipped, as hits */
function findHits(check, units, re, keep) {
  const hits = [];
  for (const u of units) {
    const spans = urlSpans(u.text);
    for (const m of u.text.matchAll(re)) {
      if (inSpans(spans, m.index)) continue;
      const h = { check, file: u.file, unit: u.unit, line: u.line, index: m.index, text: m[0], ctx: u.text, deck: !!u.deck, m };
      if (!keep || keep(h)) hits.push(h);
    }
  }
  return hits;
}

/* ---- the registry ---- */
function loadRegistry(suite) { return JSON.parse(fs.readFileSync(path.join(suite, 'Validation', 'registry.json'), 'utf-8')); }
function covers(ctx, phrase, index, len) {
  for (let i = ctx.indexOf(phrase); i >= 0; i = ctx.indexOf(phrase, i + 1)) if (i <= index && index + len <= i + phrase.length) return true;
  return false;
}
function coversRe(ctx, re, index, len) {
  for (const m of ctx.matchAll(new RegExp(re, 'g'))) if (m.index <= index && index + len <= m.index + m[0].length) return true;
  return false;
}
function allowedBy(reg, check, h) {
  return (reg.allow || []).find((a) => a.check === check && (!a.file || a.file === h.file) &&
    (a.phrase !== undefined ? covers(h.ctx, a.phrase, h.index, h.text.length) : a.regex !== undefined ? coversRe(h.ctx, a.regex, h.index, h.text.length) : false));
}
/* sort the hits into open, allowed, baselined, deferred to the deck, and the stale and ambiguous baseline entries */
function resolveHits(check, hits, reg) {
  const res = { open: [], allowed: [], baselined: [], deferred: [], stale: [], ambiguous: [] };
  const coveredBy = new Map();
  for (const b of (reg.baseline || []).filter((x) => x.check === check)) {
    const hs = hits.filter((h) => h.file === b.file && h.text === b.hit && covers(h.ctx, b.context, h.index, h.text.length));
    if (hs.length === 0) res.stale.push(b);
    else if (hs.length > 1) res.ambiguous.push(b);
    else coveredBy.set(hs[0], b);
  }
  for (const h of hits) {
    if (allowedBy(reg, check, h)) res.allowed.push(h);
    else if (coveredBy.has(h)) (coveredBy.get(h).status === 'DEFERRED-DECK' ? res.deferred : res.baselined).push(h);
    else res.open.push(h);
  }
  return res;
}
const openCount = (res) => res.open.length + res.stale.length + res.ambiguous.length;
const where = (h) => `${h.file}${h.line ? ':' + h.line : ''}${h.unit && !/^L\d+$/.test(h.unit) ? ' [' + h.unit + ']' : ''}`;
function snippet(h, n) {
  const k = n || 60;
  const a = Math.max(0, h.index - k), b = Math.min(h.ctx.length, h.index + h.text.length + k);
  return (a > 0 ? '…' : '') + h.ctx.slice(a, b).replace(/\s+/g, ' ') + (b < h.ctx.length ? '…' : '');
}
const tally = (res) => `open ${res.open.length} · allowlisted ${res.allowed.length} · baselined ${res.baselined.length} · deferred to the deck ${res.deferred.length}` +
  (res.stale.length ? ` · stale baseline ${res.stale.length}` : '') + (res.ambiguous.length ? ` · ambiguous baseline ${res.ambiguous.length}` : '');
function detailLines(res, max) {
  const lines = [];
  for (const h of res.open.slice(0, max || 40)) lines.push(`      open: ${where(h)} "${h.text}" in: ${snippet(h)}`);
  if (res.open.length > (max || 40)) lines.push(`      ... ${res.open.length - (max || 40)} more open`);
  for (const b of res.stale) lines.push(`      stale baseline ${b.id}: "${b.hit}" (${b.file}) matches no current occurrence`);
  for (const b of res.ambiguous) lines.push(`      ambiguous baseline ${b.id}: "${b.hit}" (${b.file}) matches more than one occurrence`);
  return lines;
}
/* the one summary line a warning check prints: a check mark when nothing is open, else a WARN line and the open items */
function warnSummary(label, res, extra) {
  const counts = tally(res) + (extra ? ` · ${extra}` : '');
  return openCount(res) ? [`  ! WARN (non-fatal): ${label}: ${counts}`, ...detailLines(res)] : [`  ✓ ${label} (warning check): ${counts}`];
}

module.exports = { JSX_REL, GUIDE_REL, BRIEF_REL, DECK_REL, PDF_OF, fromPdf, pdfText, pdfUnits, FROZEN_HEAD, EDITION_HEAD, PART0, PUBLIC_NAMES, isPublic, onDisk, readRel,
  loadModel, jsxUnits, mdUnits, htmlText, htmlUnits, ooxmlUnits, textUnits, urlSpans, inSpans, findHits, loadRegistry, covers,
  allowedBy, resolveHits, openCount, where, snippet, tally, detailLines, warnSummary };
