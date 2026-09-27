#!/usr/bin/env node
/* statics_check.cjs - encoding + ordering statics.
 *   node Validation/statics_check.cjs
 *
 * Fatal checks (exit 1):
 *   1. Every authored text file decodes as strict UTF-8 and carries no
 *      mojibake markers (double-encoded sequences, BOM debris, U+FFFD).
 *   2. No \u escapes inside Resource Index desc strings or glossary defs
 *      (typographic characters are typed literally in content).
 *   3. Flat Resource Index groups are case-insensitive alphabetical with the
 *      ratified digit rule (a leading "0DIN" sorts as "ODIN").
 *   4. Voices to Follow sorts by surname.
 *   5. actionSourceLinks has no orphan keys: every source-link map entry is
 *      referenced by some action's source label (renderSourceLabel looks up
 *      the full label; a dead key is a stale link with nothing to render).
 * Warning-only (reported, exit unaffected):
 *   5. Within-sub alphabetical order for sub-clustered groups, excluding the
 *      deliberate lead clusters (Frameworks / Evaluation Corpora & Testbeds;
 *      Practitioner / Context Graph). The Cisco/Splunk reorder rides in a
 *      content pass, so violations here do not fail the battery.
 *   6. Prose-voice dash: the ratified house voice is the em dash; a spaced
 *      en dash " - " (U+2013 with surrounding spaces) in authored text should
 *      be an em dash. Warning-only this pass; promote to fatal after the
 *      planned dash sweep (HARNESS-AUDIT Q1).
 * Fatal (R37):
 *   7. WCAG AA contrast floors on the two-mode token pair table:
 *      text-primary/surface >= 4.5:1 (AA normal text), accent/surface >= 3.0:1
 *      (accent is display/eyebrow-scale bold text - AA large-text floor),
 *      text-secondary/surface >= 4.5:1 and team-purple/surface >= 4.5:1 (both
 *      are set as body-size text), both modes. STATICS_HTML env overrides the
 *      target for canary runs.
 * Fatal (B2, hardened C1):
 *   8. Identity guard: the retired identity (22 hex values, 6 rgb triples, 2 font /
 *      design-system names) has zero hits in Playbook/index.html (shell and
 *      payload), the JSX, Diagrams/*.html, the executive summary HTML and the landing
 *      page (Public/index.html; index.html in public mode), in any
 *      of its encodings: #RRGGBB,
 *      #RRGGBBAA, %23-encoded, and comma- or space-separated rgb()/rgba(). A
 *      violet-band scan then fails any 6- or 8-digit hex or rgb()/rgba() color
 *      with HSL hue 253-303 and saturation above 0.35 unless it is in the plum
 *      allowlist (the team-purple family). Hits are printed as file:line.
 *      STATICS_IDENTITY_FILES (comma-separated paths) overrides the file list
 *      for canary runs.
 * Fatal (Round I, the critic gauntlet's checks, through text_units.cjs and Validation/registry.json):
 *   9. P01: every registered figure carries its label (a snapshot date, a scope, a metric) nearby.
 *  10. P02: every registered claim appears only in its canonical form.
 *  11. P07: every cross-reference names an existing tab, section, card or glossary term exactly.
 * Warning-only (Round I; each prints one summary line, and an open item turns that line into a WARN):
 *  12. P04: UK spellings in shipped prose (cited titles, proper names and quotations allowlisted).
 *  13. P10: a figure in a tab body block or card with no source link and no named source.
 *  14. P11: absolutes and vendor claims stated as fact, in a sentence that attributes nothing.
 * Fatal (Round J, through Validation/registry.json's "license" entry, which the export gate reads too):
 *  15. LICENSE is the pinned notice: in private mode Public/LICENSE's sha256 is the pin; in public mode LICENSE is the
 *      pinned template with one date ("Month D, YYYY") in the ship-date token's place.
 *  16. No license terms outside the allowances: the registry's patterns (the name, the identifiers and the web
 *      address of the license earlier versions carried) have zero hits in the shipped text units, the raw text of
 *      their sources (every XML part of the brief and the deck), Playbook/index.html, THIRD_PARTY_NOTICES.md,
 *      package.json and LICENSE, except inside an allowance (the study guide's dated addenda are left out, as
 *      text_units leaves them out). Each allowance is pinned to its files and exact text and must be present exactly
 *      as pinned, so a stale allowance fails too.
 *  17. The short notice, exactly, at its four sites: the landing page's first footer paragraph, the executive
 *      summary's credit paragraph, the app footer (the JSX, without the final period) and the deck's closing slide
 *      (slide38.xml, two paragraphs).
 *  17b (Round K). The copyright line, the short notice's first two sentences, exactly as its own line at 19 sites: the
 *      study guide and the field card (the paragraph under the title), each diagram poster (one <div class="copy"> in
 *      its footer), and the concept brief (its DOCX's last paragraph in private mode, its PDF's last page in both).
 * Fatal (Round K, the deck's C2 identity):
 *  18. Deck identity guard: the retired identity and the violet band have zero hits in the deck's theme, master,
 *      layout and slide XML (private mode; the PPTX does not ship).
 *  19. Deck palette: every color in every deck XML part is one of registry.json's deck_palette tokens, and no part
 *      uses a system, preset, scRGB or HSL color (private mode).
 *  20. Deck fonts: the deck PDF embeds only IBM Plex faces, read from its own font dictionaries with
 *      build_exec_summary's font guard, pdffonts as a cross-check (both modes; the PDF ships).
 * PUBLIC EDITION MODE: a `.public-edition` marker file at the tree root switches on public mode, which
 * skips checks for files that exist only in the private working repo. Without the marker every check
 * runs exactly as before. Here: README.txt, CLAUDE-CODE-ONBOARDING.md, HARNESS-AUDIT.md and
 * Documents/Improvement-Roadmap.md are skipped and README.md is checked instead. A missing file still
 * fails in private mode.
 */
const fs = require('fs');
const path = require('path');

const SUITE = path.resolve(__dirname, '..');
const results = [];
let failures = 0;
const check = (name, ok, detail) => {
  results.push([name, ok ? 'PASS' : 'FAIL', detail || '']);
  if (!ok) failures++;
};
const warns = [];

/* ---- 1. encoding ---- */
const PUBLIC = fs.existsSync(path.join(SUITE, '.public-edition'));
const PRIVATE_ONLY = ['README.txt', 'CLAUDE-CODE-ONBOARDING.md', 'HARNESS-AUDIT.md', 'Documents/Improvement-Roadmap.md'];
const FILES_PRIVATE = ['Playbook/agentic-secops-teaming.jsx', 'README.txt', 'CLAUDE.md',
  'CLAUDE-CODE-ONBOARDING.md', 'HARNESS-AUDIT.md',
  'Documents/Agentic-SecOps-Study-Guide.md', 'Documents/Agentic-SecOps-Tradecraft-Field-Card.md',
  'Documents/Improvement-Roadmap.md', 'Documents/Agentic-SecOps-Executive-Summary.html', 'Public/index.html'];
const FILES = PUBLIC
  ? FILES_PRIVATE.map((f) => (f === 'README.txt' ? 'README.md' : f === 'Public/index.html' ? 'index.html' : f)).filter((f) => !PRIVATE_ONLY.includes(f))
  : FILES_PRIVATE;
const MOJIBAKE = ['â€', 'Ã©', 'Ã¨', 'Ã¼', 'Ã¶', 'Ã¤', 'Ã‚', 'ï»¿', '�'];
for (const rel of FILES) {
  const buf = fs.readFileSync(path.join(SUITE, rel));
  let txt = null, valid = true;
  try { txt = new TextDecoder('utf-8', { fatal: true }).decode(buf); } catch (e) { valid = false; }
  const hits = valid ? MOJIBAKE.filter((m) => txt.includes(m)) : [];
  check(`utf-8 clean: ${((r) => (/^(\.\.([\\/]|$)|[\\/]|[A-Za-z]:)/.test(r) ? rel : r.split(path.sep).join('/')))(path.relative(SUITE, path.resolve(SUITE, rel)))}`, valid && hits.length === 0,
    !valid ? 'invalid UTF-8' : hits.join(',') || '');
}

/* ---- 6. prose-voice dash (warning-only) ---- */
for (const rel of FILES) {
  const txt = fs.readFileSync(path.join(SUITE, rel), 'utf-8');
  const n = (txt.match(/ – /g) || []).length;
  if (n) warns.push(`${((r) => (/^(\.\.([\\/]|$)|[\\/]|[A-Za-z]:)/.test(r) ? rel : r.split(path.sep).join('/')))(path.relative(SUITE, path.resolve(SUITE, rel)))}: ${n} spaced en dash(es) - house prose voice is the em dash`);
}

/* ---- parse the Resource Index ---- */
const jsx = fs.readFileSync(path.join(SUITE, 'Playbook', 'agentic-secops-teaming.jsx'), 'utf-8');
const rStart = jsx.indexOf('\n  resources: {');
const rEnd = jsx.indexOf('\n    ],\n  },', rStart);
const region = jsx.slice(rStart, rEnd);
const gRe = /group: "((?:[^"\\]|\\.)*)",\n        items: \[\n([\s\S]*?)\n        \],/g;
const fld = (s, k) => { const m = s.match(new RegExp(k + ':\\s*"((?:[^"\\\\]|\\\\.)*)"')); return m ? m[1] : null; };
const groups = [];
let m;
while ((m = gRe.exec(region))) {
  const items = m[2].split('\n').filter((l) => l.trim()).map((l) => ({
    sub: fld(l, 'sub'), name: fld(l, 'name'), desc: fld(l, 'desc'), line: l,
  }));
  groups.push({ name: m[1], items });
}
check('RI parse (13 groups)', groups.length === 13, `groups=${groups.length}`);

/* ---- 2. no \u escapes in content strings ---- */
const badU = [];
for (const g of groups) for (const it of g.items) if (/\\u[0-9a-fA-F]{4}/.test(it.line)) badU.push(it.name);
const fStart = jsx.search(/^  fluency: \{/m);
const fEnd = jsx.indexOf('\n  learningpath: {', fStart);
const gloss = jsx.slice(fStart, fEnd);
const glossBad = (gloss.match(/\\u[0-9a-fA-F]{4}/g) || []).length;
check('no \\u escapes in RI entries', badU.length === 0, badU.slice(0, 3).join(','));
check('no \\u escapes in glossary', glossBad === 0, glossBad ? `${glossBad} found` : '');

/* ---- 3/4. ordering ---- */
/* Ratified collation (one rule, applied wherever digits occur): the brand
 * token "0DIN" reads as "ODIN"; every other standalone digit sorts by its
 * spelled-out word. Multi-digit runs (NIST SP numbers, years, versions) are
 * left as-is so numeric identifiers keep their natural order. */
const DIGITWORD = { 0: 'zero', 1: 'one', 2: 'two', 3: 'three', 4: 'four', 5: 'five', 6: 'six', 7: 'seven', 8: 'eight', 9: 'nine' };
const collate = (name) => name
  .replace(/0DIN/g, 'ODIN')
  .replace(/\b\d\b/g, (d) => DIGITWORD[d])
  .toLowerCase();
const surname = (name) => name.split(' — ')[0].trim().split(/\s+/).pop().toLowerCase();
const FLAT = ['The Offense–Defense Balance', 'Threat Intelligence & Industry Reports',
  'Zero Trust & Agentic Insider Risk', 'Regulatory & Compliance',
  'Human-Centric AI Adoption', 'Research & Reference',
  'Community & Collective Resources'];
const byName = Object.fromEntries(groups.map((g) => [g.name, g]));
for (const gn of FLAT) {
  const names = (byName[gn] || { items: [] }).items.map((i) => i.name);
  const sorted = [...names].sort((a, b) => collate(a) < collate(b) ? -1 : 1);
  const bad = names.findIndex((n, i) => n !== sorted[i]);
  check(`alpha: ${gn}`, byName[gn] && bad === -1, bad >= 0 ? `first out of place: ${names[bad]}` : `${names.length} entries`);
}
{
  const names = (byName['Voices to Follow'] || { items: [] }).items.map((i) => i.name);
  const sorted = [...names].sort((a, b) => surname(a) < surname(b) ? -1 : 1);
  check('surname order: Voices to Follow', names.join('|') === sorted.join('|'), `${names.length} entries`);
}

/* ---- 5. within-sub order (warnings only) ---- */
const EXEMPT = { 'Frameworks & Standards': ['Evaluation Corpora & Testbeds'],
  'Practitioner & Industry Insights': ['Context Graph'] };
for (const g of groups) {
  if (!g.items.some((i) => i.sub)) continue;
  const subs = [];
  for (const it of g.items) {
    if (!subs.length || subs[subs.length - 1].sub !== it.sub) subs.push({ sub: it.sub, names: [] });
    subs[subs.length - 1].names.push(it.name);
  }
  const seen = new Set();
  for (const s of subs) {
    if (seen.has(s.sub)) warns.push(`${g.name}: sub "${s.sub}" not contiguous`);
    seen.add(s.sub);
    if ((EXEMPT[g.name] || []).includes(s.sub)) continue;
    const sorted = [...s.names].sort((a, b) => collate(a) < collate(b) ? -1 : 1);
    const bad = s.names.findIndex((n, i) => n !== sorted[i]);
    if (bad >= 0) warns.push(`${g.name} / ${s.sub}: "${s.names[bad]}" out of alpha order`);
  }
}

/* ---- 5. source-label wiring: no orphan actionSourceLinks keys ---- */
const msIdx = jsx.indexOf('const actionSourceLinks = {');
const meIdx = jsx.indexOf('\n};', msIdx);
const mapKeys = [...jsx.slice(msIdx, meIdx).matchAll(/^  "((?:[^"\\]|\\.)*)":/gm)].map((x) => x[1]);
const sourceLabels = new Set([...jsx.matchAll(/source:\s*"((?:[^"\\]|\\.)*)"/g)].map((x) => x[1]));
const orphans = mapKeys.filter((k) => !sourceLabels.has(k));
check('actionSourceLinks: no orphan keys', msIdx >= 0 && orphans.length === 0,
  orphans.length ? orphans.slice(0, 3).join(' | ') : `${mapKeys.length} keys all referenced`);

/* ---- 7. WCAG AA contrast floors on the two-mode token pair table (R37) ----
 * Pairs per kickoff: text-primary on surface, accent on surface, both modes.
 * Floors: 4.5:1 for text-primary (AA normal text); 3.0:1 for accent (accent
 * renders as display/eyebrow-scale bold text and UI accents - the AA
 * large-text/non-text floor). STATICS_HTML env overrides the index.html
 * target for canary runs. */
{
  const HTML_PATH = process.env.STATICS_HTML || path.join(SUITE, 'Playbook', 'index.html');
  const html = fs.readFileSync(HTML_PATH, 'utf-8');
  const blocks = {
    dark: (html.match(/:root, :root\[data-theme="dark"\] \{([\s\S]*?)\n  \}/) || [])[1],
    light: (html.match(/:root\[data-theme="light"\] \{([\s\S]*?)\n  \}/) || [])[1],
  };
  const tokenOf = (block, name) => ((block || '').match(new RegExp('--' + name + ':\\s*([^;]+);')) || [])[1];
  const lum = (hex) => {
    const c = hex.replace('#', '');
    const f = (i) => {
      const v = parseInt(c.slice(i, i + 2), 16) / 255;
      return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    };
    return 0.2126 * f(0) + 0.7152 * f(2) + 0.0722 * f(4);
  };
  const ratio = (fg, bg) => {
    const a = lum(fg), b = lum(bg);
    return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
  };
  const PAIRS = [['text-primary', 'surface', 4.5], ['accent', 'surface', 3.0],
    ['text-secondary', 'surface', 4.5], ['team-purple', 'surface', 4.5]];
  for (const mode of ['dark', 'light']) {
    for (const [fg, bg, floor] of PAIRS) {
      const fv = (tokenOf(blocks[mode], fg) || '').trim();
      const bv = (tokenOf(blocks[mode], bg) || '').trim();
      const hexish = /^#[0-9a-fA-F]{6}$/.test(fv) && /^#[0-9a-fA-F]{6}$/.test(bv);
      const r = hexish ? ratio(fv, bv) : 0;
      check(`contrast AA (${mode}): ${fg}/${bg} >= ${floor}:1`, hexish && r >= floor,
        hexish ? `${r.toFixed(2)}:1` : `non-hex token (${fv} on ${bv})`);
    }
  }
}

/* the retired font names, filled by check 8 from its own list, so the deck identity guard (18) needs no copy of them */
const RETIRED_FONT_NAMES = [];

/* ---- 8. identity guard (B2, hardened C1): the retired identity must not come back ----
 * The list is the Round B2 Phase 1a inventory; sync_check.cjs's twin-mirror regex
 * carries the same base list. C1 hardening: each listed hex is also caught as
 * #RRGGBBAA and %23-encoded (data URIs), each listed triple also space-separated
 * (rgb(161 0 255 / 0.5)), and a violet-band scan fails any other purple: a 6- or
 * 8-digit hex (# or %23) or rgb()/rgba() color with HSL hue 253-303 and saturation
 * above 0.35 that is not in the plum allowlist. */
{
  const OLD_HEX = ['A100FF', 'C2A3FF', '7500C0', 'C966FF', 'E2B4FF', 'F0ABFC', '7000B0', '7A3AD9',
    '16082B', '1E0A3A', '0D0018', '241147', '1A0030', '120022', '160A2E', '12061F', '1B1330',
    'EDE9F5', 'F3EFFA', 'FF50A0', '05F2DB', '224BFF'];
  const OLD_RGB = [[161, 0, 255], [201, 102, 255], [194, 163, 255], [255, 80, 160], [5, 242, 219], [34, 75, 255]];
  const OLD_NAMES = ['graphik'];
  RETIRED_FONT_NAMES.push(...OLD_NAMES);
  const SEP = '(?:\\s*,\\s*|\\s+)';
  const re = new RegExp(`(?:#|%23)(?:${OLD_HEX.join('|')})(?:[0-9a-f]{2})?\\b|rgba?\\(\\s*(?:${OLD_RGB.map((t) => t.join(SEP)).join('|')})(?!\\d)|${OLD_NAMES.join('|')}`, 'gi');
  /* violet band: hue 253-303, saturation > 0.35; plum (team-purple family) allowed */
  const PLUM_HEX = ['B273B5', '5E2868', 'DCC0DE'];
  const PLUM_RGB = ['178,115,181', '94,40,104', '220,192,222'];
  const hsl = (r, g, b) => {
    const [R, G, B] = [r / 255, g / 255, b / 255];
    const max = Math.max(R, G, B), min = Math.min(R, G, B), d = max - min, l = (max + min) / 2;
    if (d === 0) return [0, 0, l];
    const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    let h = max === R ? ((G - B) / d) % 6 : max === G ? (B - R) / d + 2 : (R - G) / d + 4;
    h *= 60;
    if (h < 0) h += 360;
    return [h, s, l];
  };
  const colorRe = /(?:#|%23)([0-9a-f]{6})(?:[0-9a-f]{2})?\b|rgba?\(\s*(\d{1,3})(?:\s*,\s*|\s+)(\d{1,3})(?:\s*,\s*|\s+)(\d{1,3})(?!\d)/gi;
  const files = process.env.STATICS_IDENTITY_FILES
    ? process.env.STATICS_IDENTITY_FILES.split(',').filter(Boolean)
    : ['Playbook/index.html', 'Playbook/agentic-secops-teaming.jsx', 'Documents/Agentic-SecOps-Executive-Summary.html',
      PUBLIC ? 'index.html' : 'Public/index.html',
      ...fs.readdirSync(path.join(SUITE, 'Diagrams')).filter((f) => f.endsWith('.html')).sort().map((f) => 'Diagrams/' + f)];
  const hits = [], violet = [];
  for (const rel of files) {
    const abs = path.isAbsolute(rel) ? rel : path.join(SUITE, rel);
    const txt = fs.readFileSync(abs, 'utf-8');
    const at = (i) => `${((r) => (/^(\.\.([\\/]|$)|[\\/]|[A-Za-z]:)/.test(r) ? rel : r.split(path.sep).join('/')))(path.relative(SUITE, path.resolve(SUITE, rel)))}:${txt.slice(0, i).split('\n').length}`;
    for (const m of txt.matchAll(re)) hits.push(`${at(m.index)} ${m[0]}`);
    for (const m of txt.matchAll(colorRe)) {
      const rgb = m[1] ? [0, 2, 4].map((k) => parseInt(m[1].slice(k, k + 2), 16)) : [m[2], m[3], m[4]].map(Number);
      const allowed = m[1] ? PLUM_HEX.includes(m[1].toUpperCase()) : PLUM_RGB.includes(rgb.join(','));
      const [h, s] = hsl(...rgb);
      if (h >= 253 && h <= 303 && s > 0.35 && !allowed) violet.push(`${at(m.index)} ${m[0]} (h${Math.round(h)} s${s.toFixed(2)})`);
    }
  }
  check(`identity guard: retired identity absent (${files.length} files)`, hits.length === 0,
    hits.length ? `${hits.length} hit(s): ${hits.slice(0, 8).join(' | ')}${hits.length > 8 ? ' | ...' : ''}` : 'clean');
  check(`identity guard: violet band plum-only (${files.length} files)`, violet.length === 0,
    violet.length ? `${violet.length} hit(s): ${violet.slice(0, 8).join(' | ')}${violet.length > 8 ? ' | ...' : ''}` : 'clean');
}

/* ---- 9 to 14. the critic gauntlet's checks (Round I) ----
 * The shipped text comes from text_units.cjs; every registry, allowlist and baseline from Validation/registry.json.
 * Fatal: P01 (a registered figure carries its label nearby), P02 (a registered claim appears only in its canonical
 * form), P07 (a cross-reference names an existing tab, section, card or glossary term exactly). Warnings, one summary
 * line each: P04 (UK spellings), P10 (a figure in a tab body block or card with no source link or named source), P11
 * (absolutes and vendor claims stated as fact). An open item turns a warning's summary line into a WARN line. */
const TU = require('./text_units.cjs');
const REG = TU.loadRegistry(SUITE);
const { units: UNITS, uiParsed } = TU.textUnits(SUITE);
const MODEL = TU.loadModel(SUITE);
const gauntletDetail = [], gauntletWarn = [];
const fatalGauntlet = (name, res, extra) => {
  const n = TU.openCount(res);
  check(name, n === 0, (n ? `${n} open: ` + [...res.open.map((h) => `${TU.where(h)} "${h.text}"`), ...res.stale.map((b) => `stale ${b.id}`), ...res.ambiguous.map((b) => `ambiguous ${b.id}`)].slice(0, 3).join(' | ') + ' | ' : '') + TU.tally(res) + (extra ? ` · ${extra}` : ''));
  if (n) gauntletDetail.push(`  ${name}:`, ...TU.detailLines(res));
};
const win = (h, w) => h.ctx.slice(Math.max(0, h.index - w), h.index + h.text.length + w);
/* P01: a figure registered in registry.json's "figures" carries its label within `window` characters in its unit */
{
  const hits = [];
  for (const f of REG.figures) {
    const when = f.when ? new RegExp(f.when) : null, label = new RegExp(f.label);
    for (const h of TU.findHits('P01', UNITS, new RegExp(f.match, 'g'))) {
      const w = win(h, f.window || 250);
      if (when && !when.test(w)) continue;
      if (!label.test(w)) { h.figure = f.id; hits.push(h); }
    }
  }
  fatalGauntlet(`P01 figures carry their labels (${REG.figures.length} registered)`, TU.resolveHits('P01', hits, REG));
}
/* P02: every detection of a registered claim lies inside a match of one of its canonical forms */
{
  const hits = [];
  for (const c of REG.claims) {
    const canon = (c.canonical || []).map((x) => new RegExp(x, 'g'));
    for (const h of TU.findHits('P02', UNITS, new RegExp(c.detect, 'g' + (c.flags || '')))) {
      const ok = canon.some((re) => [...h.ctx.matchAll(re)].some((m) => m.index <= h.index && h.index + h.text.length <= m.index + m[0].length));
      if (!ok) { h.claim = c.id; hits.push(h); }
    }
  }
  fatalGauntlet(`P02 registered claims in canonical form (${REG.claims.length} registered)`, TU.resolveHits('P02', hits, REG));
}
/* P07: "the X tab" names a nav label; "the X section" and "(see X)" name a nav label, a nav group, a tab title, a body
 * heading, a card, a Resource Index group, a metrics or glossary group or a glossary term. A list ("X and Y", "X, Y and
 * Z", "X in the Resource Index") is split and each name checked. A "(see X)" whose names share no first word with any
 * target is a pointer to something else (a document or a Part) and is not checked. */
{
  const labels = new Set(MODEL.sections.map((s) => s.label));
  const targets = new Set([...labels, ...MODEL.navGroups.map((g) => g.label)]);
  for (const v of Object.values(MODEL.content)) {
    if (v.title) targets.add(v.title);
    for (const b of v.body || []) if (b.heading) targets.add(b.heading.replace(/─/g, '').trim());
    for (const c of v.categories || []) if (c.name) targets.add(c.name);
    for (const g of v.groups || []) { for (const k of ['group', 'name', 'label']) if (g[k]) targets.add(g[k]); for (const it of g.items || []) if (it.term) targets.add(it.term); }
  }
  const firsts = new Set([...targets].map((t) => t.split(/\s/)[0]));
  const CAP = "[A-Z0-9](?:[\\w&'’/()+-]|\\.(?=\\w))*";
  const PHR = `${CAP}(?:\\s(?:&|and|of|for|to|in|the|on|vs\\.?|${CAP}))*`;
  const FORMS = [['tab', new RegExp(`\\b(?:[Tt]he|this playbook['’]s|see|on|in)\\s(${PHR})\\s(?:tabs?)\\b`, 'g')],
    ['section', new RegExp(`\\b[Tt]he\\s(${PHR})\\ssection\\b`, 'g')], ['see', new RegExp(`\\([Ss]ee (?:the )?(${PHR})\\)`, 'g')]];
  const hits = []; let refs = 0;
  for (const [kind, re] of FORMS) {
    for (const h of TU.findHits('P07', UNITS, re)) {
      const X = h.m[1];
      const parts = X.split(/,\s(?:and\s)?|\sand\s|\sin\sthe\s/).map((s) => s.replace(/^the\s/i, '').trim()).filter(Boolean);
      if (kind === 'see' && !parts.some((p) => firsts.has(p.split(/\s/)[0]))) continue;
      refs++;
      if (parts.every((p) => (kind === 'tab' ? labels.has(p) : targets.has(p)))) continue;
      h.index += h.m[0].indexOf(X); h.text = X; hits.push(h);
    }
  }
  fatalGauntlet('P07 cross-references name what exists', TU.resolveHits('P07', hits, REG), `${refs} references checked`);
}
/* P04: UK spellings (registry.json "uk_spellings") in shipped prose; cited titles, proper names and quotations go in the allowlist */
{
  const re = new RegExp('\\b(?:' + REG.uk_spellings.join('|') + ')\\b', 'gi');
  gauntletWarn.push(...TU.warnSummary('P04 UK spellings', TU.resolveHits('P04', TU.findHits('P04', UNITS, re), REG)));
}
/* P10: a percentage, multiplier or large count in a tab body block or a card that carries no source link and names no
 * source; a named source is a Resource Index publisher (the part of an entry's name before its em dash), an action source
 * label's publisher, a Research Library paper, or a name in registry.json's "unsourced.named_sources" */
{
  const pubs = new Set(REG.unsourced.named_sources);
  for (const g of MODEL.content.resources.groups) for (const it of g.items) { const p = it.name.split(' \u2014 ')[0].replace(/\s*\([^)]*\)\s*/g, ' ').trim(); if (p.length >= 2) pubs.add(p); }
  for (const s of Object.keys(MODEL.actionSourceLinks)) pubs.add(s.split(' · ')[0].trim());
  for (const p of (MODEL.content.academic && MODEL.content.academic.papers) || []) if (p.name) pubs.add(p.name.split(':')[0].trim());
  const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const NAMED = new RegExp('(?:^|[^\\w])(?:' + [...pubs].sort((a, b) => b.length - a.length).map(esc).join('|') + ')(?!\\w)');
  const FIG = new RegExp(REG.unsourced.figure, 'g');
  const jsx = MODEL.jsx, hits = [];
  const unit = (id, text, sourced, probe) => {
    if (sourced || NAMED.test(text)) return;
    const m = FIG.exec(text); FIG.lastIndex = 0;
    if (!m) return;
    const at = jsx.indexOf(probe.slice(0, 40));
    hits.push({ check: 'P10', file: TU.JSX_REL, unit: id, line: at < 0 ? 0 : jsx.slice(0, at).split('\n').length, index: m.index, text: m[0], ctx: text });
  };
  for (const [tab, v] of Object.entries(MODEL.content)) {
    (v.body || []).forEach((b, i) => { if (!b.divider && b.text) unit(`TAB:${tab}:B${i + 1}`, `${b.heading || ''}. ${b.text}`, !!(b.links && b.links.length), b.text); });
    (v.categories || []).forEach((c, i) => unit(`CAT:${tab}:${i + 1}`, [c.name, c.summary || '', ...(c.items || []).map((it) => `${it.name}: ${it.use || it.desc || ''}`)].join(' | '), !!c.url, c.name));
  }
  gauntletWarn.push(...TU.warnSummary('P10 figures without a source', TU.resolveHits('P10', hits, REG)));
}
/* P11: absolutes and vendor claims stated as fact (registry.json "absolutes"), in a sentence that attributes nothing */
{
  const ATTR = /\b(?:reports?|reported|says|said|claims?|claimed|describes|described|calls|called|according to|by [A-Z][\w&.’' -]{0,40}?['’]s (?:own )?account|markets|positions|bills|touts|the vendor|vendor[- ]reported|self-reported|announced|announces|framed|frames|argues|argued|asserts|proposes|presents|introduces)\b/i;
  const re = new RegExp(REG.absolutes.join('|'), 'gi');
  const hits = TU.findHits('P11', UNITS, re, (h) => {
    const a = Math.max(h.ctx.lastIndexOf('. ', h.index), h.ctx.lastIndexOf('; ', h.index), 0);
    const e = [h.ctx.indexOf('. ', h.index), h.ctx.indexOf('; ', h.index)].filter((x) => x >= 0);
    return !ATTR.test(h.ctx.slice(a, e.length ? Math.min(...e) : h.ctx.length));
  });
  gauntletWarn.push(...TU.warnSummary('P11 absolutes and vendor claims as fact', TU.resolveHits('P11', hits, REG), uiParsed ? '' : 'interface text not read (typescript not found)'));
}

/* ---- 15 to 17. the license (Round J), fatal ----
 * registry.json's "license" entry holds the pin, the ship-date token with the words around it, the patterns, the
 * allowances and the short notice; the export gate's LICENSE_TERMS group reads the same entry. Its patterns and its
 * allowed texts are written so that they do not match themselves (a character class in each pattern, a JSON unicode
 * escape in each allowed text), because the gate scans registry.json as well. */
{
  const crypto = require('crypto');
  const { execFileSync } = require('child_process');
  const L = REG.license || {};
  const sha = (b) => crypto.createHash('sha256').update(b).digest('hex');
  const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  /* 15. private mode: Public/LICENSE's sha256 is the pin; public mode: LICENSE is the pinned template with one
   * "Month D, YYYY" date in the token's place */
  {
    const rel = TU.onDisk(SUITE, 'Public/LICENSE');
    const buf = fs.readFileSync(path.join(SUITE, rel));
    let ok = false, detail = '';
    if (!PUBLIC) {
      const h = sha(buf); ok = !!L.sha256 && h === L.sha256;
      detail = `sha256 ${h.slice(0, 16)}… ${ok ? '= the pin' : '!= the pin ' + String(L.sha256).slice(0, 16) + '…'}`;
    } else {
      const t = buf.toString('utf-8');
      const MONTH = '(?:January|February|March|April|May|June|July|August|September|October|November|December)';
      const [pre, post] = L.date_context || ['', ''];
      const ms = pre && post ? [...t.matchAll(new RegExp(`(?<=${esc(pre)})${MONTH} (?:[1-9]|[12]\\d|3[01]), \\d{4}(?=${esc(post)})`, 'g'))] : [];
      if (ms.length === 1 && L.token) {
        const tmpl = t.slice(0, ms[0].index) + L.token + t.slice(ms[0].index + ms[0][0].length);
        ok = !!L.sha256 && sha(Buffer.from(tmpl, 'utf-8')) === L.sha256;
        detail = `ship date ${ms[0][0]}; with the token back it is ${ok ? 'the pinned template' : 'not the pinned template'}`;
      } else detail = `${ms.length} ship date(s) in the token's place (expected 1)`;
    }
    check(`license: ${rel} is the pinned notice`, ok, detail);
  }
  /* 16. no license terms outside the allowances: the text units, the raw text of their sources (every XML part of the
   * brief and the deck), Playbook/index.html, THIRD_PARTY_NOTICES.md, package.json and LICENSE */
  {
    const pats = (L.patterns || []).map((p) => new RegExp(p, 'gi'));
    const allow = L.allow || [];
    /* the study guide's dated-addenda section (private tree) or its edition note (public edition) is left out, as
     * text_units leaves it out: the first is frozen history that does not ship, the second is written by the export */
    const leaveOut = (t) => {
      const head = t.includes(TU.FROZEN_HEAD) ? TU.FROZEN_HEAD : t.includes(TU.EDITION_HEAD) ? TU.EDITION_HEAD : null;
      const a = head ? t.indexOf(head) : -1, b = t.indexOf(TU.PART0);
      return a >= 0 && b > a ? t.slice(0, a) + '\n'.repeat(t.slice(a, b + 1).split('\n').length - 1) + t.slice(b + 1) : t;
    };
    const rawOf = new Map();
    const readRaw = (rel) => {
      if (!rawOf.has(rel)) {
        const abs = path.join(SUITE, TU.onDisk(SUITE, rel));
        let t = null;
        try {
          t = TU.fromPdf(SUITE, rel) ? TU.pdfText(SUITE, rel)
            : /\.(?:pptx|docx)$/i.test(rel) ? execFileSync('unzip', ['-p', abs, '*.xml', '*.rels'], { encoding: 'utf-8', maxBuffer: 1 << 28 })
            : rel === TU.GUIDE_REL ? leaveOut(fs.readFileSync(abs, 'utf-8')) : fs.readFileSync(abs, 'utf-8');
        } catch (e) { t = null; }
        rawOf.set(rel, t);
      }
      return rawOf.get(rel);
    };
    const texts = UNITS.map((u) => ({ file: u.file, at: () => TU.where(u), text: u.text }));
    const unread = [];
    for (const rel of new Set([...UNITS.map((u) => u.file), 'Playbook/index.html', 'Public/THIRD_PARTY_NOTICES.md', 'Public/_package.json', 'Public/LICENSE'])) {
      const t = readRaw(rel);
      if (t === null) unread.push(rel);
      else texts.push({ file: rel, at: (i) => `${TU.onDisk(SUITE, rel)}:${t.slice(0, i).split('\n').length} (raw)`, text: t });
    }
    const open = []; let allowed = 0;
    for (const x of texts) for (const re of pats) for (const m of x.text.matchAll(re)) {
      if (allow.some((a) => (a.files || []).includes(x.file) && TU.covers(x.text, a.text, m.index, m[0].length))) { allowed++; continue; }
      open.push(`${x.at(m.index)} "${m[0]}"`);
    }
    const stale = [];
    for (const a of allow) {
      if (!pats.some((re) => new RegExp(re.source, 'i').test(a.text || ''))) stale.push(`${a.id} holds no license term`);
      for (const f of a.files || []) {
        const t = readRaw(f), n = t === null ? 0 : t.split(a.text).length - 1;
        if (n !== (a.count || 1)) stale.push(`${a.id} found ${n}x in ${TU.onDisk(SUITE, f)}`);
      }
    }
    const ok = pats.length > 0 && open.length === 0 && stale.length === 0 && unread.length === 0;
    check('license: no license terms outside the allowances', ok,
      (open.length ? `${open.length} open: ${open.slice(0, 3).join(' | ')} | ` : '') + (stale.length ? `stale allowance: ${stale.join(' | ')} | ` : '') +
      (unread.length ? `unread: ${unread.join(', ')} | ` : '') + (pats.length ? '' : 'no patterns | ') +
      `open ${open.length} · allowed hits ${allowed} · allowances ${allow.map((a) => a.id).join(', ')}${stale.length ? '' : ' present as pinned'} · ${texts.length} texts`);
    if (open.length > 3) gauntletDetail.push('  license terms:', ...open.map((o) => `      open: ${o}`));
  }
  /* 17. the short notice, exactly: the landing page's first footer paragraph, the summary's credit paragraph, the app
   * footer (the JSX, without the final period) and the deck's closing slide (slide38.xml, two paragraphs) */
  {
    const N = L.notice || '';
    const one = (t, re) => { const ms = [...t.matchAll(re)]; return ms.length === 1 ? ms[0][1] : null; };
    const landing = TU.readRel(SUITE, 'Public/index.html');
    const summary = fs.readFileSync(path.join(SUITE, 'Documents/Agentic-SecOps-Executive-Summary.html'), 'utf-8');
    /* the closing slide's two paragraphs: slide38.xml in private mode, the deck PDF's last page in public mode (Round K) */
    const deck = TU.fromPdf(SUITE, TU.DECK_REL)
      ? TU.pdfText(SUITE, TU.DECK_REL).split('\f').filter((p) => p.trim()).pop().split('\n').map((l) => ({ text: l.trim() })).filter((u) => u.text)
      : TU.ooxmlUnits(SUITE, TU.DECK_REL, /^ppt\/slides\/slide38\.xml$/, 'a:p', 'a:t', true);
    const sites = [
      ['the landing footer', one(landing, /<footer>\s*<p>([^<]*)<\/p>/g) === N],
      ['the summary credit', one(summary, /<p class="credit">([^<]*)<\/p>/g) === N],
      ['the app footer', jsx.split(`>${N.replace(/\.$/, '')}</span>`).length === 2],
      ['the deck closing slide', deck.some((u, i) => i + 1 < deck.length && `${u.text} ${deck[i + 1].text}` === N)],
    ];
    const bad = sites.filter((s) => !s[1]).map((s) => s[0]);
    check(`license: the short notice at its ${sites.length} sites`, N !== '' && bad.length === 0,
      bad.length ? `missing or changed at ${bad.join(', ')}` : `exact at ${sites.map((s) => s[0].replace(/^the /, '')).join(', ')}`);
  }
  /* 17b (Round K). The copyright line (the short notice's first two sentences), exactly, as its own line at 19 sites:
   * the study guide and the field card (the paragraph directly under the title), each of the 16 diagram posters (one
   * <div class="copy"> in its footer; the srcDoc twins follow through the twin mirror), and the concept brief (the last
   * paragraph of its DOCX in private mode, and a line of its PDF's last page in both modes, when pdftotext is available). */
  {
    const N = L.notice || '';
    const LINE = N.replace(/ Built with .*$/, '');
    const bad = [], seen = [];
    const under = (rel) => { const u = TU.mdUnits(SUITE, rel); return u.length > 1 && u[0].text.startsWith('# ') && u[1].text === LINE; };
    for (const rel of [TU.GUIDE_REL, 'Documents/Agentic-SecOps-Tradecraft-Field-Card.md']) (under(rel) ? seen : bad).push(rel.split('/').pop());
    const posters = fs.readdirSync(path.join(SUITE, 'Diagrams')).filter((f) => f.endsWith('.html')).sort();
    for (const f of posters) {
      const t = fs.readFileSync(path.join(SUITE, 'Diagrams', f), 'utf-8');
      (t.split(`<div class="copy">${LINE}</div>`).length === 2 ? seen : bad).push(f);
    }
    let brief = 0, pdfNote = '';
    if (!PUBLIC) {
      const u = TU.ooxmlUnits(SUITE, TU.BRIEF_REL, /^word\/document\.xml$/, 'w:p', 'w:t', false);
      if (u.length && u[u.length - 1].text === LINE) brief++; else bad.push('the brief DOCX');
    }
    try {
      const pdf = path.join(SUITE, 'Documents', 'Adversary-Emulation-Concept-Brief.pdf');
      const pages = Number((execFileSync('pdfinfo', [pdf], { encoding: 'utf-8' }).match(/^Pages:\s+(\d+)/m) || [])[1]);
      const last = execFileSync('pdftotext', ['-f', String(pages), '-l', String(pages), '-enc', 'UTF-8', pdf, '-'], { encoding: 'utf-8' });
      if (last.split('\n').some((l) => l.trim() === LINE)) brief++; else bad.push('the brief PDF');
    } catch (e) { pdfNote = '; the brief PDF not read (pdfinfo or pdftotext not available)'; }
    if (brief) seen.push('the brief');
    const sites = 2 + posters.length + 1;
    const need = sites - (PUBLIC && pdfNote ? 1 : 0);
    check(`license: the copyright line at its ${sites} sites`, LINE.endsWith('All rights reserved.') && posters.length === 16 && bad.length === 0 && seen.length === need,
      bad.length ? `missing or changed at ${bad.join(', ')}` : `exact under the study guide's and the field card's titles, in ${posters.length} poster footers, and closing the brief (${PUBLIC ? 'PDF' : 'DOCX and PDF'})${pdfNote}`);
  }
}

/* ---- 18 to 20. the deck's C2 identity (Round K), fatal ----
 * 18. Identity guard over the deck: the retired identity and the violet band (the same patterns as check 8) have zero hits
 *     in the deck's XML parts (theme, masters, layouts, slides). Private mode: the PPTX does not ship.
 * 19. Deck palette: every color in every deck XML part is one of registry.json's "deck_palette" (the C2 tokens), and no
 *     part uses a system, preset, scRGB or HSL color. Private mode, for the same reason.
 * 20. Deck fonts: the deck PDF embeds only IBM Plex faces, read from the PDF's own font dictionaries (build_exec_summary's
 *     font guard), with pdffonts as a cross-check when it is available. Both modes: the PDF ships. */
{
  const { execFileSync } = require('child_process');
  const deckRel = 'Deck/Agentic-SecOps-Master-Deck.pptx', pdfRel = 'Deck/Agentic-SecOps-Master-Deck.pdf';
  const deck = path.join(SUITE, deckRel);
  if (!PUBLIC) {
    let names = [];
    try { names = execFileSync('unzip', ['-Z1', deck], { encoding: 'utf-8' }).split('\n').filter((n) => /\.xml$/.test(n)); } catch (e) { names = null; }
    if (!names) { check('deck identity guard (theme, masters, layouts, slides)', false, 'the deck could not be read (unzip)'); check('deck palette (C2 tokens only)', false, 'the deck could not be read (unzip)'); }
    else {
      const OLD_HEX = ['A100FF', 'C2A3FF', '7500C0', 'C966FF', 'E2B4FF', 'F0ABFC', '7000B0', '7A3AD9', '16082B', '1E0A3A', '0D0018', '241147', '1A0030', '120022',
        '160A2E', '12061F', '1B1330', 'EDE9F5', 'F3EFFA', 'FF50A0', '05F2DB', '224BFF'];
      const idHits = [], violet = [], off = [], forms = [];
      const pal = new Set(((REG.deck_palette || {}).colors || []).map((c) => c.toUpperCase()));
      const PLUM = new Set(['B273B5', '5E2868', 'DCC0DE']);
      const hslOf = (hex) => {
        const [r, g, b] = [0, 2, 4].map((k) => parseInt(hex.slice(k, k + 2), 16) / 255);
        const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn, l = (mx + mn) / 2;
        if (!d) return [0, 0];
        const s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
        let h = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4; h *= 60; if (h < 0) h += 360;
        return [h, s];
      };
      for (const n of names) {
        const x = execFileSync('unzip', ['-p', deck, n.replace(/[[\]*?\\]/g, '\\$&')], { encoding: 'utf-8', maxBuffer: 1 << 26 });  // unzip reads [ ] * ? as wildcards
        const idPart = /^ppt\/(theme|slideMasters|slideLayouts|slides)\//.test(n);
        for (const m of x.matchAll(/<a:srgbClr val="([0-9A-Fa-f]{6})"/g)) {
          const c = m[1].toUpperCase();
          if (!pal.has(c)) off.push(`${n}: ${c}`);
          if (idPart) {
            if (OLD_HEX.includes(c)) idHits.push(`${n}: ${c}`);
            const [h, s] = hslOf(c);
            if (h >= 253 && h <= 303 && s > 0.35 && !PLUM.has(c)) violet.push(`${n}: ${c}`);
          }
        }
        if (idPart && RETIRED_FONT_NAMES.some((nm) => new RegExp(nm, 'i').test(x))) idHits.push(`${n}: a retired font name`);
        for (const f of ['sysClr', 'prstClr', 'scrgbClr', 'hslClr']) if (x.includes('<a:' + f)) forms.push(`${n}: ${f}`);
      }
      const nId = names.filter((n) => /^ppt\/(theme|slideMasters|slideLayouts|slides)\//.test(n)).length;
      check(`deck identity guard (${nId} theme, master, layout and slide parts)`, idHits.length === 0 && violet.length === 0,
        idHits.length || violet.length ? `${[...idHits, ...violet.map((v) => 'violet ' + v)].slice(0, 6).join(' | ')}` : 'retired identity absent; violet band plum-only');
      check(`deck palette (C2 tokens only, ${names.length} XML parts)`, pal.size > 0 && off.length === 0 && forms.length === 0,
        off.length || forms.length ? [...new Set([...off, ...forms])].slice(0, 6).join(' | ') : `${pal.size} tokens; every color is one of them`);
    }
  }
  {
    const pdf = path.join(SUITE, pdfRel);
    let ok = false, detail = '';
    try {
      const { fontGuard, pdffontsRows, pdffontsDisagreements } = require('./build_exec_summary.cjs');
      const g = fontGuard(pdf);
      const fails = [...g.fails];
      let cross = 'pdffonts not available';
      try {
        const rows = pdffontsRows(execFileSync('pdffonts', [pdf], { encoding: 'utf-8' }));
        fails.push(...pdffontsDisagreements(rows, g.fonts), ...rows.filter((r) => !/^(?:[A-Z]{6}\+)?IBMPlex(?:Sans|Mono)(?:-[A-Za-z0-9]+)?$/.test(r.name)).map((r) => `pdffonts: ${r.name}`));
        cross = `pdffonts agrees (${rows.length} rows)`;
      } catch (e) { if (!/ENOENT/.test(String(e))) fails.push('pdffonts: ' + String(e.message || e).slice(0, 80)); }
      ok = fails.length === 0;
      detail = ok ? `${g.fonts.filter((f) => f.top).length} fonts, all IBM Plex; ${cross}` : fails.slice(0, 4).join(' | ');
    } catch (e) { detail = 'unreadable: ' + String(e.message || e).slice(0, 120); }
    check('deck fonts (the deck PDF embeds only IBM Plex)', ok, detail);
  }
}

/* ---- report ---- */
console.log('================ STATICS CHECK ================');
for (const [name, status, detail] of results) {
  console.log(`  ${status === 'PASS' ? '✓' : '✗'} ${name.padEnd(46)} ${status}  ${detail}`);
}
for (const l of gauntletDetail) console.log(l);
for (const l of gauntletWarn) console.log(l);
for (const w of warns) console.log(`  ! WARN (non-fatal): ${w}`);
const nWarn = warns.length + gauntletWarn.filter((l) => l.startsWith('  ! WARN')).length;
console.log(failures ? `\n${failures} FAILURE(S)` : `\nALL GREEN${nWarn ? ` (${nWarn} warning(s) above)` : ''}`);
process.exit(failures ? 1 : 0);
