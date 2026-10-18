#!/usr/bin/env node
/* build_exec_summary.cjs: renders the executive summary PDF from its HTML source, offline.
 *   node Validation/build_exec_summary.cjs
 *   node Validation/build_exec_summary.cjs <in.html> <out.pdf>   (ad-hoc / canary target; both paths required)
 *
 * Source:  Documents/Agentic-SecOps-Executive-Summary.html (self-contained; edit this file)
 * Output:  Documents/Agentic-SecOps-Executive-Summary.pdf (never edit the PDF by hand)
 *
 * Finds puppeteer and Chrome the way render_check.cjs does, opens the HTML over file://,
 * allows only file: and data: requests (anything else is aborted and fails the build),
 * waits for document.fonts.ready and fails unless IBM Plex Sans 400 and 700 are loaded,
 * then prints US Letter with backgrounds (the @page rules in the HTML set the margins and
 * the running footer, which needs @page margin boxes: Chrome 131 or later) and reports the
 * page count. The font guard then reads the PDF's own font dictionaries, so it works with or
 * without pdffonts: every dictionary in every object, nested ones included, is read with the #xx
 * escapes in its keys and names decoded, and one with /Type /Font or a font /Subtype is a font.
 * The build fails on any font with /Subtype /Type3 (a system-font fallback), on a font whose
 * /BaseFont (an indirect one resolved) is missing or is not a name, and on any /BaseFont or
 * /FontName that is not an IBM Plex face (an optional six-letter subset tag and "+", then
 * IBMPlexSans or IBMPlexMono, optionally a hyphen and a style name of letters and digits).
 * A PDF with an object stream or an xref stream fails rather than being guessed at. When
 * pdffonts is available, its rows, parsed from the right so a long name cannot shift the
 * columns, must list the same fonts as the direct read. Once every check
 * passes, it sets the PDF's /Author to the HTML's <meta name="author"> by an incremental
 * update: a new Info object that keeps every existing entry, one xref section for it and a
 * trailer with /Prev that keeps /Root and /ID (Node built-ins only). A PDF whose
 * cross-reference is not a classic xref table fails the build rather than being guessed at;
 * with no meta author the PDF stays as printed. It prints to a temporary file and renames it
 * over the output only when every check passes, so a failed build leaves the last good PDF
 * in place; any failure, an unexpected one included, removes the temporary file.
 * Page budget (P13, Round I): after the rename it reports how full the last page is and warns above 90%,
 * never failing the build; Validation/registry.json may baseline a known fill for the summary PDF.
 * Exit 0 = PDF written; 1 = build failed (output untouched); 2 = no Chrome / puppeteer.
 */
const path = require('path');
const fs = require('fs');

const SUITE = path.resolve(__dirname, '..');
const ARGS = process.argv.slice(2);
if (require.main === module && ARGS.length !== 0 && ARGS.length !== 2) {
  console.log('usage: node Validation/build_exec_summary.cjs [<in.html> <out.pdf>]');
  process.exit(1);
}
const SRC = path.resolve(ARGS[0] || path.join(SUITE, 'Documents', 'Agentic-SecOps-Executive-Summary.html'));
const OUT = path.resolve(ARGS[1] || path.join(SUITE, 'Documents', 'Agentic-SecOps-Executive-Summary.pdf'));
const TMP = OUT + '.tmp';
const show = (p) => (p.startsWith(SUITE + path.sep) ? path.relative(SUITE, p) : p);

/* the same resolution order as render_check.cjs */
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
  const out = [];
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

/* page count from the written PDF: pdfinfo if present, else the page-tree /Count */
function pdfPages(p) {
  const { spawnSync } = require('child_process');
  const r = spawnSync('pdfinfo', [p], { encoding: 'utf-8' });
  const m = (r.stdout || '').match(/Pages:\s+(\d+)/);
  if (m) return parseInt(m[1], 10);
  const raw = fs.readFileSync(p, 'latin1');
  const c = raw.match(/\/Type\s*\/Pages[^>]*\/Count\s+(\d+)/);
  return c ? parseInt(c[1], 10) : -1;
}

/* Font guard: the PDF's own font dictionaries, read through its classic xref tables with Node built-ins, so it needs
 * no pdffonts. Skia writes PDF 1.4 without object streams; an object stream or an xref stream fails the build rather
 * than being guessed at. Every dictionary in every object is read, nested ones included (a font dictionary inline in a
 * Resources dictionary counts), with #xx escapes in keys and names decoded before any comparison. A dictionary with
 * /Type /Font or a font /Subtype is a font. Any font with /Subtype /Type3 (a system-font fallback) fails; so does a font
 * whose /BaseFont, an indirect one resolved, is missing or is not a name, and any /BaseFont or /FontName that is not an
 * IBM Plex face. */
const PLEX_FONT = /^(?:[A-Z]{6}\+)?IBMPlex(?:Sans|Mono)(?:-[A-Za-z0-9]+)?$/;
const FONT_SUBTYPES = ['/Type0', '/Type1', '/MMType1', '/Type3', '/TrueType', '/CIDFontType0', '/CIDFontType2'];
function pdfNameText(v) {
  return v && v[0] === '/' ? v.slice(1).replace(/#([0-9a-fA-F]{2})/g, (m, h) => String.fromCharCode(parseInt(h, 16))) : null;
}
/* a name value with its #xx escapes decoded ("/Type#33" reads "/Type3"); anything that is not a name gives null */
function pdfName(v) {
  const t = pdfNameText(v);
  return t === null ? null : '/' + t;
}
/* every object the classic xref tables list (the newest revision wins), with its dictionary when it has one and its
 * raw value otherwise (so an indirect /BaseFont can be resolved) */
function pdfObjects(s) {
  const sx = s.lastIndexOf('startxref');
  const m = sx < 0 ? null : /^startxref\s+(\d+)/.exec(s.slice(sx));
  if (!m) throw new Error('no startxref');
  const where = new Map(), seen = new Set();
  for (let off = parseInt(m[1], 10); ;) {
    if (seen.has(off)) throw new Error('xref /Prev loop');
    seen.add(off);
    const sec = pdfXrefSection(s, off);
    for (const [n, loc] of sec.offsets) if (!where.has(n)) where.set(n, loc);
    const t = (k) => { const e = sec.trailer.find(([key]) => pdfName(key) === k); return e ? e[1] : null; };
    if (t('/XRefStm') !== null) throw new Error('the PDF has an xref stream (a hybrid-reference trailer)');
    const p = t('/Prev');
    if (p === null) break;
    off = parseInt(p, 10);
  }
  const objs = new Map();
  for (const [n, loc] of where) {
    const head = new RegExp('^' + n + '\\s+' + loc.gen + '\\s+obj\\s*').exec(s.slice(loc.off, loc.off + 48));
    if (!head) throw new Error('object ' + n + ' not found at its xref offset');
    const i = loc.off + head[0].length;
    if (s.startsWith('<<', i)) objs.set(n, { gen: loc.gen, dict: pdfDict(s, i).entries, raw: null });
    else {
      let raw = null;
      try { raw = s.slice(i, pdfValueEnd(s, i)); } catch (e) { /* not a value this reader knows; resolves to null */ }
      objs.set(n, { gen: loc.gen, dict: null, raw });
    }
  }
  return objs;
}
/* the items of a PDF array's raw text */
function pdfArrayItems(v) {
  const out = [];
  for (let i = 1; ;) {
    i = pdfSkip(v, i);
    if (i >= v.length) throw new Error('unterminated array');
    if (v[i] === ']') return out;
    const j = pdfValueEnd(v, i);
    out.push(v.slice(i, j)); i = j;
  }
}
/* a dictionary's entries with #xx escapes in its keys decoded, and every dictionary nested in it, in arrays included */
function pdfDicts(entries, out) {
  const d = entries.map(([k, v]) => [pdfName(k), v]);
  out.push(d);
  const inner = (v) => {
    if (v.startsWith('<<')) pdfDicts(pdfDict(v, 0).entries, out);
    else if (v.startsWith('[')) for (const x of pdfArrayItems(v)) inner(x);
  };
  for (const [, v] of d) inner(v);
  return out;
}
/* the fonts the PDF holds, and every reason the guard fails */
function fontGuard(file) {
  const objs = pdfObjects(fs.readFileSync(file).toString('latin1'));
  const get = (d, k) => { const e = d ? d.find(([key]) => key === k) : null; return e ? e[1] : null; };
  /* a value, an indirect reference resolved to the object's raw value (a dictionary resolves to null) */
  const resolve = (v) => {
    const r = /^(\d+)\s+(\d+)\s+R$/.exec((v || '').trim());
    if (!r) return v;
    const o = objs.get(parseInt(r[1], 10));
    return o && o.gen === parseInt(r[2], 10) ? o.raw : null;
  };
  const dicts = [];
  for (const [n, o] of objs) {
    if (!o.dict) continue;
    const all = pdfDicts(o.dict, []);
    all.forEach((d, k) => dicts.push({ n, gen: o.gen, d, inline: k > 0 }));
  }
  const descendants = new Set();
  for (const { n, d, inline } of dicts) {
    const type = pdfName(get(d, '/Type'));
    if (!inline && type === '/ObjStm') throw new Error('the PDF has an object stream (object ' + n + ')');
    if (!inline && type === '/XRef') throw new Error('the PDF has an xref stream (object ' + n + ')');
    const df = resolve(get(d, '/DescendantFonts'));
    if (df) for (const r of df.matchAll(/(\d+)\s+\d+\s+R/g)) descendants.add(parseInt(r[1], 10));
  }
  const fonts = [], fails = [];
  for (const { n, gen, d, inline } of dicts) {
    const where = inline ? `a font dictionary inside object ${n}` : `font ${n}`;
    const type = pdfName(get(d, '/Type')), sub = pdfName(get(d, '/Subtype'));
    if (type === '/FontDescriptor') {
      const fn = pdfNameText(resolve(get(d, '/FontName')));
      if (!fn || !PLEX_FONT.test(fn)) fails.push(`font descriptor ${inline ? 'inside object ' + n : n}: /FontName ${fn || '(none, or not a name)'} is not IBM Plex`);
    }
    if (type !== '/Font' && !FONT_SUBTYPES.includes(sub)) continue;
    const bfRaw = get(d, '/BaseFont');
    const bf = bfRaw === null ? null : pdfNameText(resolve(bfRaw));
    fonts.push({ obj: n, gen, subtype: sub, name: bf, top: !inline && !descendants.has(n), inline });
    if (sub === '/Type3') fails.push(`${where}: /Subtype /Type3 (${bf || 'no name'}), a system-font fallback`);
    if (bfRaw === null) fails.push(`${where}: no /BaseFont`);
    else if (bf === null) fails.push(`${where}: /BaseFont ${bfRaw.trim().slice(0, 40)} is not a name`);
    else if (!PLEX_FONT.test(bf)) fails.push(`${where}: /BaseFont ${bf} is not IBM Plex`);
  }
  if (!fonts.length) fails.push('no font dictionaries found');
  return { fonts, fails };
}
/* pdffonts cross-check: each row parsed from the right (type, encoding, emb, sub, uni, object, generation), so a long
 * name cannot shift the columns; its fonts must be the direct read's top-level fonts, by object, name and Type 3-ness */
const PDFFONTS_TYPES = ['CID Type 0C (OT)', 'CID TrueType (OT)', 'Type 1C (OT)', 'TrueType (OT)', 'CID Type 0C', 'CID Type 0',
  'CID TrueType', 'Type 1C', 'Type 1', 'Type 3', 'TrueType', 'unknown'];
function pdffontsRows(out) {
  const lines = out.split('\n');
  const h = lines.findIndex((l) => /^name\s+type\s+encoding/.test(l));
  if (h < 0 || !/^-+/.test(lines[h + 1] || '')) throw new Error('unexpected pdffonts output');
  return lines.slice(h + 2).filter((l) => l.trim()).map((l) => {
    const m = /^(.*\S)\s+(\S+)\s+(yes|no)\s+(yes|no)\s+(yes|no)\s+(\d+)\s+(\d+)\s*$/.exec(l);
    if (!m) throw new Error('unreadable pdffonts row: ' + l.trim());
    const type = PDFFONTS_TYPES.find((t) => m[1] === t || m[1].endsWith(' ' + t));
    if (!type) throw new Error('unknown font type in pdffonts row: ' + l.trim());
    return { name: m[1].slice(0, m[1].length - type.length).trim() || '[none]', type, encoding: m[2], emb: m[3], sub: m[4], uni: m[5],
      obj: parseInt(m[6], 10), gen: parseInt(m[7], 10) };
  });
}
function pdffontsDisagreements(rows, fonts) {
  const key = (o, g) => o + ' ' + g;
  const rk = new Map(rows.map((r) => [key(r.obj, r.gen), r]));
  const fk = new Map(fonts.filter((f) => f.top).map((f) => [key(f.obj, f.gen), f]));
  const out = [];
  for (const [k, r] of rk) if (!fk.has(k)) out.push(`pdffonts lists font ${k} (${r.name}) and the direct read does not`);
  for (const [k, f] of fk) if (!rk.has(k)) out.push(`the direct read has font ${k} (${f.name || '[none]'}) and pdffonts does not list it`);
  for (const [k, r] of rk) {
    const f = fk.get(k);
    if (!f) continue;
    if ((r.type === 'Type 3') !== (f.subtype === '/Type3')) out.push(`font ${k}: pdffonts type ${r.type}, direct /Subtype ${f.subtype}`);
    if (r.name !== (f.name || '[none]')) out.push(`font ${k}: pdffonts name ${r.name}, direct name ${f.name || '[none]'}`);
  }
  return out;
}

/* the content of the HTML's <meta name="author">, or null when there is none. The tag's attributes are read in order
 * as whole attributes (quoted values consumed), so name="author" never matches inside data-name or inside another
 * attribute's value; attributes may come in either order. A numeric entity outside Unicode's range throws a plain
 * error, which the Author step turns into a clean build failure. */
function metaAuthor(html) {
  const ent = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" };
  for (const tag of html.match(/<meta\b[^>]*>/gi) || []) {
    const attrs = {};
    const re = /\s*([^\s=\/>"']+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>"']+)))?/y;
    re.lastIndex = 5;
    for (let m; (m = re.exec(tag)) !== null;) {
      const k = m[1].toLowerCase();
      if (!(k in attrs)) attrs[k] = m[2] !== undefined ? m[2] : m[3] !== undefined ? m[3] : m[4] !== undefined ? m[4] : '';
    }
    if ((attrs.name || '').toLowerCase() !== 'author') continue;
    const c = (attrs.content || '').replace(/&(#x[0-9a-f]+|#\d+|amp|lt|gt|quot|apos);/gi, (m0, e) => {
      if (e[0] !== '#') return ent[e.toLowerCase()];
      const cp = e[1] === 'x' || e[1] === 'X' ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
      if (!(cp >= 0 && cp <= 0x10ffff)) throw new Error(`meta author: the entity ${m0} is outside Unicode's range`);
      return String.fromCodePoint(cp);
    });
    return c.trim() ? c : null;
  }
  return null;
}

/* a PDF string: literal (backslash and parentheses escaped) when printable ASCII, else UTF-16BE hex with a BOM */
function pdfString(v) {
  if (/^[\x20-\x7e]*$/.test(v)) return '(' + v.replace(/[\\()]/g, (c) => '\\' + c) + ')';
  const u = Buffer.from(v, 'utf16le');
  for (let i = 0; i + 1 < u.length; i += 2) { const t = u[i]; u[i] = u[i + 1]; u[i + 1] = t; }
  return '<FEFF' + u.toString('hex').toUpperCase() + '>';
}

/* a minimal reader for the PDF objects the Author update touches: the trailer and the Info dictionary.
 * Values are kept as their raw text; anything it does not recognise throws, so the build fails rather than guesses. */
function pdfSkip(s, i) {
  for (;;) {
    if (i < s.length && /[\x00\t\n\f\r ]/.test(s[i])) i++;
    else if (s[i] === '%') { while (i < s.length && s[i] !== '\n' && s[i] !== '\r') i++; }
    else return i;
  }
}
function pdfValueEnd(s, i) {
  const c = s[i];
  if (c === '(') {
    let depth = 0;
    for (; i < s.length; i++) {
      if (s[i] === '\\') { i++; continue; }
      if (s[i] === '(') depth++;
      else if (s[i] === ')' && --depth === 0) return i + 1;
    }
    throw new Error('unterminated literal string');
  }
  if (s.startsWith('<<', i)) return pdfDict(s, i).end;
  if (c === '<') { const j = s.indexOf('>', i); if (j < 0) throw new Error('unterminated hex string'); return j + 1; }
  if (c === '[') {
    for (i++; ;) {
      i = pdfSkip(s, i);
      if (i >= s.length) throw new Error('unterminated array');
      if (s[i] === ']') return i + 1;
      i = pdfValueEnd(s, i);
    }
  }
  if (c === '/') { i++; while (i < s.length && !/[\x00\t\n\f\r ()<>[\]{}/%]/.test(s[i])) i++; return i; }
  const m = /^(?:[+-]?\d+\s+\d+\s+R\b|[+-]?(?:\d+\.?\d*|\.\d+)|true\b|false\b|null\b)/.exec(s.slice(i, i + 48));
  if (!m) throw new Error('unexpected PDF token at byte ' + i);
  return i + m[0].length;
}
function pdfDict(s, i) {
  if (!s.startsWith('<<', i)) throw new Error('dictionary expected at byte ' + i);
  const entries = [];
  for (i += 2; ;) {
    i = pdfSkip(s, i);
    if (s.startsWith('>>', i)) return { entries, end: i + 2 };
    if (s[i] !== '/') throw new Error('dictionary key expected at byte ' + i);
    const k0 = i; i = pdfValueEnd(s, i); const key = s.slice(k0, i);
    i = pdfSkip(s, i); const v0 = i; i = pdfValueEnd(s, i);
    entries.push([key, s.slice(v0, i)]);
  }
}
function pdfXrefSection(s, off) {
  if (!s.startsWith('xref', off)) throw new Error('the cross-reference at byte ' + off + ' is not a classic xref table');
  const offsets = new Map();
  let i = off + 4;
  for (;;) {
    i = pdfSkip(s, i);
    if (s.startsWith('trailer', i)) break;
    const h = /^(\d+)\s+(\d+)/.exec(s.slice(i, i + 40));
    if (!h) throw new Error('bad xref subsection header at byte ' + i);
    const start = parseInt(h[1], 10), count = parseInt(h[2], 10);
    i += h[0].length;
    for (let k = 0; k < count; k++) {
      i = pdfSkip(s, i);
      const e = /^(\d{10}) (\d{5}) ([nf])/.exec(s.slice(i, i + 18));
      if (!e) throw new Error('bad xref entry at byte ' + i);
      if (e[3] === 'n') offsets.set(start + k, { off: parseInt(e[1], 10), gen: parseInt(e[2], 10) });
      i += 18;
    }
  }
  return { offsets, trailer: pdfDict(s, pdfSkip(s, i + 7)).entries };
}

/* set /Author by an incremental update: append a new Info object (every existing entry kept), one xref section for
 * it and a trailer with /Prev that keeps /Root and /ID */
function setPdfAuthor(file, author) {
  const buf = fs.readFileSync(file);
  const s = buf.toString('latin1');
  const sx = s.lastIndexOf('startxref');
  const m = sx < 0 ? null : /^startxref\s+(\d+)/.exec(s.slice(sx));
  if (!m) throw new Error('no startxref');
  const prev = parseInt(m[1], 10);
  const newest = pdfXrefSection(s, prev);
  const get = (entries, k) => { const e = entries.find(([key]) => key === k); return e ? e[1] : null; };
  const size = parseInt(get(newest.trailer, '/Size'), 10);
  const root = get(newest.trailer, '/Root'), id = get(newest.trailer, '/ID'), info = get(newest.trailer, '/Info');
  if (!Number.isInteger(size) || !root) throw new Error('trailer without /Size or /Root');
  if (get(newest.trailer, '/Encrypt')) throw new Error('encrypted PDF');
  let infoEntries = [];
  if (info) {
    const r = /^(\d+)\s+(\d+)\s+R$/.exec(info.trim());
    if (!r) throw new Error('/Info is not an indirect reference');
    let sec = newest, loc = null;
    const seen = new Set([prev]);
    for (;;) {
      if (sec.offsets.has(parseInt(r[1], 10))) { loc = sec.offsets.get(parseInt(r[1], 10)); break; }
      const p = get(sec.trailer, '/Prev');
      if (!p) break;
      const po = parseInt(p, 10);
      if (seen.has(po)) throw new Error('xref /Prev loop');
      seen.add(po); sec = pdfXrefSection(s, po);
    }
    if (!loc) throw new Error('Info object ' + r[1] + ' is not in the xref');
    const head = new RegExp('^' + r[1] + '\\s+' + r[2] + '\\s+obj\\s*').exec(s.slice(loc.off, loc.off + 48));
    if (!head) throw new Error('Info object header not found at its xref offset');
    infoEntries = pdfDict(s, loc.off + head[0].length).entries;
  }
  const entries = infoEntries.filter(([k]) => k !== '/Author').concat([['/Author', pdfString(author)]]);
  const trailer = [['/Size', String(size + 1)], ['/Root', root], ['/Info', size + ' 0 R']];
  if (id) trailer.push(['/ID', id]);
  trailer.push(['/Prev', String(prev)]);
  const lead = /[\r\n]$/.test(s) ? '' : '\n';
  const obj = size + ' 0 obj\n<<' + entries.map(([k, v]) => k + ' ' + v).join('\n') + '>>\nendobj\n';
  const objOff = buf.length + lead.length;
  const xrefOff = objOff + Buffer.byteLength(obj, 'latin1');
  const tail = lead + obj + 'xref\n' + size + ' 1\n' + String(objOff).padStart(10, '0') + ' 00000 n \n' +
    'trailer\n<<' + trailer.map(([k, v]) => k + ' ' + v).join('\n') + '>>\nstartxref\n' + xrefOff + '\n%%EOF\n';
  fs.appendFileSync(file, Buffer.from(tail, 'latin1'));
  return { obj: size, xref: xrefOff, prev, kept: infoEntries.filter(([k]) => k !== '/Author').map(([k]) => k) };
}

/* the build runs only as a script; statics_check requires this file for its PDF font guard (Round K) */
if (require.main === module) (async () => {
  const puppeteer = resolvePuppeteer();
  const chrome = resolveChrome() || await fallbackChrome(puppeteer);
  if (!puppeteer || !chrome) {
    console.log('BUILD SKIPPED: ' + (!puppeteer ? 'puppeteer not installed. ' : '') +
      (!chrome ? 'no Chrome binary found (set CHROME_PATH).' : ''));
    process.exit(2);
  }
  if (!fs.existsSync(SRC)) { console.log('BUILD FAILED: source not found: ' + SRC); process.exit(1); }

  const browser = await puppeteer.launch({
    executablePath: chrome, headless: 'shell',
    args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage', '--no-first-run',
      '--disable-background-networking', '--disable-component-update', '--disable-default-apps',
      '--disable-sync', '--disable-domain-reliability'],
  });
  const fails = [];
  const requests = { file: 0, data: 0 };
  const blocked = [];
  const pageErrors = [];
  let printed = false;
  try {
    const major = parseInt(((await browser.version()).match(/\/(\d+)\./) || [])[1] || '0', 10);
    if (major < 131) fails.push(`Chrome ${major} is older than 131: @page margin boxes (the running footer) are unsupported`);
    const page = await browser.newPage();
    await page.setRequestInterception(true);
    page.on('request', (rq) => {
      const u = rq.url();
      const scheme = u.split(':', 1)[0].toLowerCase();
      if (scheme === 'file' || scheme === 'data') { requests[scheme]++; rq.continue(); }
      else { blocked.push(u.slice(0, 160)); rq.abort(); }
    });
    page.on('pageerror', (e) => pageErrors.push(String(e).slice(0, 180)));
    await page.goto('file://' + SRC, { waitUntil: 'load', timeout: 60000 });
    await page.evaluate(() => document.fonts.ready);
    const faces = await page.evaluate(() => [...document.fonts].map((f) => ({
      family: f.family.replace(/["']/g, ''), weight: String(f.weight), status: f.status })));
    const loaded = (fam, w) => faces.some((f) => f.family === fam && f.weight === w && f.status === 'loaded');
    for (const w of ['400', '700']) if (!loaded('IBM Plex Sans', w)) fails.push(`IBM Plex Sans ${w} not loaded`);
    console.log('fonts: ' + faces.map((f) => `${f.family} ${f.weight} ${f.status}`).join('; '));
    if (blocked.length) fails.push(`${blocked.length} non-file request(s) attempted: ${blocked.join(' | ')}`);
    if (!fails.length) {
      await page.pdf({ path: TMP, format: 'Letter', printBackground: true, preferCSSPageSize: true });
      printed = true;
    }
  } finally {
    await browser.close();
  }
  if (blocked.length && !fails.some((f) => f.includes('non-file request'))) fails.push(`${blocked.length} non-file request(s) attempted: ${blocked.join(' | ')}`);
  if (pageErrors.length) fails.push(`page errors: ${pageErrors.join(' | ')}`);
  console.log(`requests: file ${requests.file}, data ${requests.data}, other (blocked) ${blocked.length}`);
  /* the running footer lives in @page margin boxes: confirm it reached the PDF when pdftotext is available */
  if (printed && !fails.length) {
    const { spawnSync } = require('child_process');
    const t = spawnSync('pdftotext', ['-f', '1', '-l', '1', TMP, '-'], { encoding: 'utf-8' });
    if (t.status === 0 && !/Page 1 of \d+/.test(t.stdout || '')) fails.push('running footer ("Page 1 of N") missing from page 1');
  }
  /* Font guard: the PDF's own font dictionaries (no pdffonts needed), then pdffonts as a cross-check when available */
  if (printed && !fails.length) {
    try {
      const g = fontGuard(TMP);
      fails.push(...g.fails.map((x) => 'font guard: ' + x));
      const { spawnSync } = require('child_process');
      const f = spawnSync('pdffonts', [TMP], { encoding: 'utf-8' });
      let cross;
      if (f.error) cross = 'pdffonts not found, cross-check skipped';
      else if (f.status !== 0) { fails.push('pdffonts failed: ' + String(f.stderr || '').trim().slice(0, 160)); cross = 'pdffonts failed'; }
      else {
        const rows = pdffontsRows(f.stdout);
        const dis = pdffontsDisagreements(rows, g.fonts);
        fails.push(...dis.map((x) => 'font guard: ' + x));
        cross = dis.length ? `pdffonts disagrees (${dis.length})` : `pdffonts agrees (${rows.length} rows)`;
      }
      console.log(`font guard: ${g.fonts.length} font dictionaries (${g.fonts.filter((x) => x.top).length} fonts), ` +
        (g.fails.length ? `${g.fails.length} problem(s)` : 'all IBM Plex, no Type 3') + `; ${cross}`);
    } catch (e) { fails.push('font guard: ' + e.message); }
  }
  /* Author: the HTML's <meta name="author">, set by an incremental update; none leaves the PDF as printed */
  if (printed && !fails.length) {
    try {
      const author = metaAuthor(fs.readFileSync(SRC, 'utf-8'));
      if (author === null) console.log('author: no <meta name="author"> in the HTML; PDF left as printed');
      else {
        const r = setPdfAuthor(TMP, author);
        console.log(`author: /Author ${JSON.stringify(author)} set by an incremental update (Info object ${r.obj}, keeping ${r.kept.join(' ')}; xref at ${r.xref}, /Prev ${r.prev})`);
        const { spawnSync } = require('child_process');
        const i = spawnSync('pdfinfo', [TMP], { encoding: 'utf-8' });
        if (!i.error) {
          const a = (i.stdout || '').match(/^Author:\s*(.*)$/m);
          if (i.status !== 0 || !a || a[1].trim() !== author.trim()) fails.push('pdfinfo does not read the new Author (got ' + (a ? JSON.stringify(a[1]) : 'none') + ')');
        }
      }
    } catch (e) { fails.push('author: ' + e.message); }
  }
  if (fails.length) {
    try { fs.unlinkSync(TMP); } catch (e) {}
    console.log('BUILD FAILED (output left untouched): ' + fails.join('; '));
    process.exit(1);
  }
  fs.renameSync(TMP, OUT);
  console.log(`wrote ${show(OUT)}: ${pdfPages(OUT)} pages`);
  /* Page budget (P13, Round I): how full the last page is, measured on the written PDF with pdftotext -bbox (skipped
   * when pdftotext is absent): the lowest line of body text above the bottom margin, against the content box the HTML's
   * @page margins set. Above 90% the build warns, so a content round sees the budget before it runs out; the warning
   * never fails the build. Validation/registry.json may baseline a known fill for the summary PDF (check P13): the
   * baseline holds while the last page number is the same and the fill is no higher. */
  try {
    const { spawnSync } = require('child_process');
    const n = pdfPages(OUT);
    const bb = spawnSync('pdftotext', ['-f', String(n), '-l', String(n), '-bbox', OUT, '-'], { encoding: 'utf-8' });
    const pageM = /<page width="([\d.]+)" height="([\d.]+)"/.exec(bb.stdout || '');
    const pg = /@page\s*\{[^{}]*?margin:\s*([^;]+);/.exec(fs.readFileSync(SRC, 'utf-8'));
    const pt = (v) => { const m = /^([\d.]+)(in|pt|mm|cm|px)$/.exec(v.trim()); return m ? parseFloat(m[1]) * { in: 72, pt: 1, mm: 72 / 25.4, cm: 72 / 2.54, px: 0.75 }[m[2]] : NaN; };
    if (bb.error || bb.status !== 0 || !pageM || !pg) console.log('page budget: skipped (' + (bb.error ? 'pdftotext not found' : !pg ? 'no @page margin in the HTML' : 'pdftotext failed') + ')');
    else {
      const m4 = pg[1].trim().split(/\s+/).map(pt); const [top, , bottom] = m4.length === 1 ? [m4[0], 0, m4[0]] : m4.length === 2 ? [m4[0], 0, m4[0]] : [m4[0], 0, m4[2]];
      const H = parseFloat(pageM[2]), contentBottom = H - bottom;
      const ys = [...bb.stdout.matchAll(/<word xMin="[\d.]+" yMin="([\d.]+)" xMax="[\d.]+" yMax="([\d.]+)">/g)].map((w) => [parseFloat(w[1]), parseFloat(w[2])]).filter(([y0]) => y0 < contentBottom);
      if (!ys.length || !(top >= 0) || !(bottom >= 0)) console.log('page budget: skipped (no body text on the last page, or unreadable margins)');
      else {
        const fill = (Math.max(...ys.map(([, y1]) => y1)) - top) / (contentBottom - top);
        const pct = (100 * fill).toFixed(1);
        let base = null;
        try {
          const reg = JSON.parse(fs.readFileSync(path.join(SUITE, 'Validation', 'registry.json'), 'utf-8'));
          const rel = path.relative(SUITE, OUT).split(path.sep).join('/');
          base = (reg.baseline || []).find((b) => b.check === 'P13' && b.file === rel && b.hit === `page ${n} of ${n}` && fill <= Number(b.fill_max) + 1e-9);
        } catch (e) { /* no registry: no baseline */ }
        if (fill <= 0.9) console.log(`page budget: last page ${n} is ${pct}% full (a warning above 90%)`);
        else if (base) console.log(`page budget: last page ${n} is ${pct}% full, above 90% and baselined (${base.id}, at most ${(100 * base.fill_max).toFixed(1)}%)`);
        else console.log(`WARN page budget: last page ${n} is ${pct}% full, above 90%; the next addition may add a page`);
      }
    }
  } catch (e) { console.log('page budget: skipped (' + String(e.message || e).slice(0, 120) + ')'); }
})().catch((e) => {
  try { fs.unlinkSync(TMP); } catch (err) { /* no temporary file to remove */ }
  console.log('BUILD FAILED (output left untouched): ' + (e && e.stack || e)); process.exit(1);
});
module.exports = { fontGuard, pdffontsRows, pdffontsDisagreements, PLEX_FONT };
