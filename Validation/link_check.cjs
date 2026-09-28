#!/usr/bin/env node
/* link_check.cjs — Agentic SecOps suite URL sweep (read-only).
 *   node Validation/link_check.cjs                 collect + network sweep
 *   node Validation/link_check.cjs --collect-only  collect + report counts, no network
 *   options: --currency-json <file> writes the currency sweep (P03), --redirects-json <file> the
 *   redirects (P12), and --pass-date YYYY-MM-DD sets the sweep's pass date (default: today)
 *
 * Zero npm dependencies: Node 18+ built-ins only (global fetch,
 * AbortSignal.timeout) plus the system `unzip` via child_process for the
 * zip-container sources (.pptx / .docx) — the same pattern battery.cjs uses.
 * Nothing is installed and node_modules / the manifests are never touched.
 *
 * Sources (authored only): the Playbook JSX, README.txt, the text Documents,
 * the concept-brief .docx, the Diagram HTMLs, and the deck's slide XML + slide
 * rels (where a .pptx stores hyperlink targets). Generated artifacts are
 * skipped so URLs aren't double-counted: Playbook/index.html, the deck PDF,
 * and the export-only Documents PDFs.
 *
 * For every unique http/https URL: HEAD first, fall back to GET if HEAD throws
 * or the server rejects the method; 12s timeout; at most 24 requests in flight.
 * Classify OK (2xx) / REDIRECT (3xx, final destination captured) / BROKEN
 * (4xx-5xx, DNS/connection failure, or timeout). Prints only REDIRECT and
 * BROKEN with the source file(s) for each, then a summary line.
 *
 * Read-only: reads files and makes network requests; never edits the suite. The two JSON options write
 * only to the paths they are given.
 * Round I adds the currency sweep (P03), which runs offline with --collect-only too, and the redirect
 * list (P12), which the next pass applies as same-document moves after a human check.
 * PUBLIC EDITION MODE: a `.public-edition` marker file at the tree root switches on public mode, which
 * skips checks for files that exist only in the private working repo. Without the marker every check
 * runs exactly as before. Here: README.txt, CLAUDE-CODE-ONBOARDING.md, HARNESS-AUDIT.md and
 * Documents/Improvement-Roadmap.md are skipped and README.md is read instead.
 */
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const SUITE = path.resolve(__dirname, '..');
const UA = 'Mozilla/5.0 (compatible; AgenticSecOps-LinkCheck/1.0)';
const TIMEOUT_MS = 12000;
const MAX_INFLIGHT = 24;
const COLLECT_ONLY = process.argv.includes('--collect-only');

/* ---- source set ---- */
const PUBLIC = fs.existsSync(path.join(SUITE, '.public-edition'));
const PRIVATE_ONLY = ['README.txt', 'CLAUDE-CODE-ONBOARDING.md', 'HARNESS-AUDIT.md', 'Documents/Improvement-Roadmap.md'];
const textFilesAll = [
  'Playbook/agentic-secops-teaming.jsx',
  'README.txt',
  'Documents/Agentic-SecOps-Study-Guide.md',
  'Documents/Agentic-SecOps-Tradecraft-Field-Card.md',
  'Documents/Improvement-Roadmap.md',
  ...fs.readdirSync(path.join(SUITE, 'Diagrams'))
    .filter((f) => f.endsWith('.html')).sort().map((f) => 'Diagrams/' + f),
];
const textFiles = PUBLIC
  ? textFilesAll.map((f) => (f === 'README.txt' ? 'README.md' : f)).filter((f) => !PRIVATE_ONLY.includes(f))
  : textFilesAll;
const zipFiles = [
  { rel: 'Documents/Adversary-Emulation-Concept-Brief.docx',
    member: /^word\/(document\.xml|_rels\/document\.xml\.rels)$/ },
  { rel: 'Deck/Agentic-SecOps-Master-Deck.pptx',
    member: /^ppt\/slides\/(slide\d+\.xml|_rels\/slide\d+\.xml\.rels)$/ },
];

/* ---- url extraction ----
 * OOXML containers (.pptx/.docx) carry XML-namespace URIs (xmlns="http://
 * schemas.openxmlformats.org/...", "http://schemas.microsoft.com/...") that are
 * format scaffolding, not authored citations. They are excluded by host so the
 * sweep reflects real references only. */
const NAMESPACE_HOSTS = /^(schemas\.openxmlformats\.org|schemas\.microsoft\.com|www\.w3\.org\/XML|purl\.org\/dc)/i;
function isNamespaceUri(u) {
  return NAMESPACE_HOSTS.test(u.replace(/^https?:\/\//i, ''));
}
function decodeEntities(s) {
  return s
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(+n))
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCharCode(parseInt(h, 16)));
}
function extractUrls(raw) {
  const text = decodeEntities(raw);
  const re = /https?:\/\/[^\s"'`<>)\]}\\]+/g; // ` terminates markdown inline-code spans
  const out = [];
  let m;
  while ((m = re.exec(text))) {
    let u = m[0].replace(/[.,;:!?]+$/, ''); // strip trailing sentence punctuation
    if (u.length > 'https://'.length && !isNamespaceUri(u)) out.push(u);
  }
  return out;
}

/* ---- zip member read via system unzip ---- */
function listZip(abs) {
  return execFileSync('unzip', ['-Z1', abs], { encoding: 'utf-8', maxBuffer: 64 * 1024 * 1024 })
    .split('\n').filter(Boolean);
}
function readZipMember(abs, member) {
  return execFileSync('unzip', ['-p', abs, member], { encoding: 'utf-8', maxBuffer: 64 * 1024 * 1024 });
}

/* ---- collect ---- */
const urlMap = new Map();   // url -> Set(sourceFile)
const perFile = [];         // [rel, refCount]
const record = (url, file) => {
  if (!urlMap.has(url)) urlMap.set(url, new Set());
  urlMap.get(url).add(file);
};

for (const rel of textFiles) {
  const urls = extractUrls(fs.readFileSync(path.join(SUITE, rel), 'utf-8'));
  perFile.push([rel, urls.length]);
  for (const u of urls) record(u, rel);
}
/* Round K: in public mode the PPTX and the DOCX do not ship; their URLs are read from the matching PDFs' text and link
 * annotations (the /URI strings, with PDF string escapes undone) */
const PDF_FOR = { 'Documents/Adversary-Emulation-Concept-Brief.docx': 'Documents/Adversary-Emulation-Concept-Brief.pdf', 'Deck/Agentic-SecOps-Master-Deck.pptx': 'Deck/Agentic-SecOps-Master-Deck.pdf' };
for (const z of zipFiles) {
  if (PUBLIC && !fs.existsSync(path.join(SUITE, z.rel))) {
    const pdf = PDF_FOR[z.rel], pabs = path.join(SUITE, pdf);
    let raw = '';
    try { raw = execFileSync('pdftotext', ['-enc', 'UTF-8', pabs, '-'], { encoding: 'utf-8', maxBuffer: 64 * 1024 * 1024 }); } catch (e) { /* no pdftotext: the annotations still count */ }
    for (const m of fs.readFileSync(pabs, 'latin1').matchAll(/\/URI\s*\(((?:[^()\\]|\\.)*)\)/g)) raw += '\n' + m[1].replace(/\\(.)/g, '$1');
    const urls = extractUrls(raw);
    perFile.push([pdf, urls.length]);
    for (const u of urls) record(u, pdf);
    continue;
  }
  const abs = path.join(SUITE, z.rel);
  const members = listZip(abs).filter((mm) => z.member.test(mm));
  let raw = '';
  for (const mm of members) raw += '\n' + readZipMember(abs, mm);
  const urls = extractUrls(raw);
  perFile.push([z.rel, urls.length]);
  for (const u of urls) record(u, z.rel);
}

const uniqueUrls = [...urlMap.keys()].sort();

/* ---- collection report ---- */
console.log('================ URL COLLECTION ================');
let totalRefs = 0;
for (const [rel, n] of perFile) {
  totalRefs += n;
  console.log(`  ${rel.padEnd(48)} ${String(n).padStart(4)} refs`);
}
console.log(`  ${''.padEnd(48)} ${'----'.padStart(4)}`);
console.log(`  ${'total references'.padEnd(48)} ${String(totalRefs).padStart(4)}`);
console.log(`  ${'UNIQUE URLs'.padEnd(48)} ${String(uniqueUrls.length).padStart(4)}`);

/* ---- currency sweep (P03, Round I; offline, so it runs with --collect-only too) ----
 * Every status phrase in the shipped text (registry.json "currency.status": pending, upcoming, expected in, in
 * preview, beta, draft, presale and the like, lowercase, so a capitalized product name ending in Preview is not one) with the
 * dates in its sentence. A phrase is flagged when its sentence holds a date and every date there is before the pass
 * date (today, or --pass-date YYYY-MM-DD): a status that may have gone stale. A month or year counts as its last day.
 * Flags are resolved in Validation/registry.json like the offline checks (allowlist, or a baseline for the owner);
 * --currency-json <file> writes the whole sweep. */
function currencySweep() {
  const TU = require('./text_units.cjs');
  const REG = TU.loadRegistry(SUITE);
  const argAt = (k) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : null; };
  const passArg = argAt('--pass-date');
  const PASS = passArg ? new Date(passArg + 'T00:00:00Z') : new Date(new Date().toISOString().slice(0, 10) + 'T00:00:00Z');
  const MON = { jan: 0, feb: 1, mar: 2, apr: 3, may: 4, jun: 5, jul: 6, aug: 7, sep: 8, sept: 8, oct: 9, nov: 10, dec: 11 };
  const M3 = '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\\.?';
  const DATE = new RegExp(`\\b(?:${M3}\\s+(\\d{1,2}),\\s+(20\\d\\d)|(\\d{1,2})\\s+${M3}\\s+(20\\d\\d)|${M3}\\s+(20\\d\\d)|Q([1-4])\\s+(20\\d\\d)|(20\\d\\d)-(\\d\\d)-(\\d\\d)|(?<![\\d/.-])(20\\d\\d)(?![\\d/-]))\\b`, 'g');
  const last = (y, mo, d) => new Date(Date.UTC(y, mo, d || new Date(Date.UTC(y, mo + 1, 0)).getUTCDate()));
  const dates = (t) => [...t.matchAll(DATE)].map((m) => ({ text: m[0], d: m[1] ? last(+m[3], MON[m[1].toLowerCase()], +m[2]) : m[5] ? last(+m[6], MON[m[5].toLowerCase()], +m[4])
    : m[7] ? last(+m[8], MON[m[7].toLowerCase()]) : m[9] ? last(+m[10], +m[9] * 3 - 1) : m[11] ? last(+m[11], +m[12] - 1, +m[13]) : last(+m[14], 11) }));
  const { units } = TU.textUnits(SUITE);
  const rows = [], flagged = [];
  for (const h of TU.findHits('P03', units, new RegExp(REG.currency.status, 'g'))) {
    const a = Math.max(h.ctx.lastIndexOf('. ', h.index) + 1, h.ctx.lastIndexOf('\n', h.index) + 1, 0);
    const ends = [h.ctx.indexOf('. ', h.index), h.ctx.indexOf('\n', h.index)].filter((x) => x >= 0);
    const sent = h.ctx.slice(a, ends.length ? Math.min(...ends) + 1 : h.ctx.length);
    const ds = dates(sent);
    const stale = ds.length > 0 && ds.every((x) => x.d < PASS);
    rows.push({ file: h.file, line: h.line, unit: h.unit, phrase: h.text, dates: ds.map((x) => x.text), flagged: stale, deck: h.deck, sentence: sent.trim().slice(0, 400), hit: h });
    if (stale) flagged.push(h);
  }
  const res = TU.resolveHits('P03', flagged, REG);
  const state = (h) => (res.allowed.includes(h) ? 'allowlisted' : res.baselined.includes(h) ? 'baselined' : res.deferred.includes(h) ? 'deferred to the deck' : 'open');
  for (const r of rows) { r.state = r.flagged ? state(r.hit) : 'not flagged'; delete r.hit; }
  console.log('\n================ CURRENCY SWEEP (P03) ================');
  console.log(`  pass date ${PASS.toISOString().slice(0, 10)}; ${rows.length} status phrase(s), ${flagged.length} dated before the pass, ${rows.filter((r) => !r.dates.length).length} undated`);
  for (const l of TU.warnSummary('P03 status phrases dated before the pass', res)) console.log(l);
  const out = argAt('--currency-json');
  if (out) {
    fs.writeFileSync(out, JSON.stringify({ pass_date: PASS.toISOString().slice(0, 10), phrases: rows.length, flagged: flagged.length,
      open: res.open.length, allowlisted: res.allowed.length, baselined: res.baselined.length, deferred_to_deck: res.deferred.length,
      stale_baseline: res.stale.map((b) => b.id), rows }, null, 1));
    console.log(`  wrote ${out}`);
  }
}
currencySweep();

if (COLLECT_ONLY) process.exit(0);

/* ---- network sweep ---- */
function errStr(e) {
  if (e && e.name === 'TimeoutError') return 'timeout (12s)';
  if (e && e.cause && e.cause.code) return e.cause.code;
  return (e && e.message) ? e.message.slice(0, 120) : String(e);
}
async function doFetch(url, method) {
  const res = await fetch(url, {
    method, redirect: 'follow', signal: AbortSignal.timeout(TIMEOUT_MS),
    headers: { 'user-agent': UA, accept: '*/*' },
  });
  const info = { status: res.status, redirected: res.redirected, finalUrl: res.url,
    location: res.headers.get('location') };
  try { if (res.body) await res.body.cancel(); } catch (e) { /* ignore */ }
  return info;
}
/* Known-noise allowlist (HARNESS-AUDIT P5): URLs whose non-OK result is
 * understood and accepted, so a sweep labels them KNOWN instead of re-flagging
 * them every pass. Prefix match, so a host entry covers its paths. Extend only
 * with a ratified reason. NOT a substitute for triage of genuinely new noise. */
const KNOWN_NOISE = [
  ['https://openai.com/', 'WAF 403 to automated fetch; live in-browser'],
  ['https://medium.com/', 'WAF 403 to automated fetch; live in-browser'],
  ['https://www.dcsa.mil/portals/', 'DCSA WAF 403 on document PDFs; live in-browser'],
  ['https://www.linkedin.com/', 'LinkedIn 999/403 to automated fetch; live in-browser'],
  ['https://link.springer.com/', 'cookie-wall redirect (?error=cookies_not_supported), not a real move'],
  ['https://samate.nist.gov/SARD', 'transient 500 under checker burst; re-run to confirm'],
  ['https://danielmiessler.com/podcast/', 'convention-ratified redirect to the show host; do not re-fold'],
  ['https://www.iso.org/', 'ISO WAF 403 to automated fetch; live in-browser'],
  ['https://www.dcsa.mil/', 'Akamai edge 403 (Access Denied / errors.edgesuite.net reference page) to automated fetch; live in-browser'],
  ['http://www.w3.org/2000/svg', 'XML namespace identifier (xmlns) — the scheme is part of the namespace name; never repoint'],
  ['https://www.infosecuriosity.co.uk/posts/2026-06-28-Most-SOCs-Are-Thinking-About-AI-the-Wrong-Way/', 'site-wide 403 to automated fetch; the post loads in a reader fetch (Sep 27, 2026), and its title, author and date match the entry'],
  ['https://sublime.security/resources/trust-then-autonomy-a-new-framework-for-evaluating-security-ai/', '429 to automated reads; reader fetch, September 27, 2026: loads and matches the entry'],
  ['https://www.armis.com/blog/nation-state-attacks-hit-machine-speed-key-takeaways-of-the-2026-armis-cyberwarfare-report-and-what-it-means-for-security-teams/', '403 to automated reads; reader fetch, September 27, 2026: loads and matches the entry'],
  ['https://www.sciencedirect.com/science/article/abs/pii/S0167739X26001482', '403 to automated reads; reader fetch, September 27, 2026: loads and matches the entry'],
];
const knownNoise = (url) => {
  const hit = KNOWN_NOISE.find(([p]) => url.startsWith(p));
  return hit ? hit[1] : null;
};

function classify(url, info) {
  if (info.status >= 400) return { url, kind: 'BROKEN', detail: `HTTP ${info.status}` };
  if (info.redirected) return { url, kind: 'REDIRECT', detail: `-> ${info.finalUrl}` };
  if (info.status >= 300) return { url, kind: 'REDIRECT', detail: `-> ${info.location || info.finalUrl}` };
  return { url, kind: 'OK', detail: '' };
}
async function probe(url) {
  try {
    const head = await doFetch(url, 'HEAD');
    if (head.status >= 400) {                 // method maybe rejected — try GET
      try { return classify(url, await doFetch(url, 'GET')); }
      catch (e) { return classify(url, head); }
    }
    return classify(url, head);
  } catch (e) {
    try { return classify(url, await doFetch(url, 'GET')); }
    catch (e2) { return { url, kind: 'BROKEN', detail: errStr(e2) }; }
  }
}
async function runPool(items, limit, worker) {
  const results = new Array(items.length);
  let i = 0, done = 0;
  const runners = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (i < items.length) {
      const idx = i++;
      results[idx] = await worker(items[idx]);
      done++;
      if (done % 25 === 0 || done === items.length) {
        process.stderr.write(`\r  ...checked ${done}/${items.length}`);
      }
    }
  });
  await Promise.all(runners);
  process.stderr.write('\n');
  return results;
}

(async () => {
  const srcs = (u) => [...urlMap.get(u)].sort().join(', ');
  const results = await runPool(uniqueUrls, MAX_INFLIGHT, probe);
  for (const r of results) { const why = r.kind !== 'OK' && knownNoise(r.url); if (why) { r.known = why; } }
  const redirects = results.filter((r) => r.kind === 'REDIRECT' && !r.known).sort((a, b) => a.url.localeCompare(b.url));
  const broken = results.filter((r) => r.kind === 'BROKEN' && !r.known).sort((a, b) => a.url.localeCompare(b.url));
  const known = results.filter((r) => r.known).sort((a, b) => a.url.localeCompare(b.url));
  const okCount = results.filter((r) => r.kind === 'OK').length;

  console.log('\n================ REDIRECTS ================');
  if (!redirects.length) console.log('  (none)');
  for (const r of redirects) {
    console.log(`  ${r.url}`);
    console.log(`      ${r.detail}`);
    console.log(`      src: ${srcs(r.url)}`);
  }

  console.log('\n================ BROKEN ================');
  if (!broken.length) console.log('  (none)');
  for (const r of broken) {
    console.log(`  ${r.url}`);
    console.log(`      ${r.detail}`);
    console.log(`      src: ${srcs(r.url)}`);
  }

  console.log('\n================ KNOWN NOISE (accepted) ================');
  if (!known.length) console.log('  (none)');
  for (const r of known) {
    console.log(`  ${r.url}`);
    console.log(`      ${r.detail}  [${r.kind}]  KNOWN: ${r.known}`);
    console.log(`      src: ${srcs(r.url)}`);
  }

  console.log('\n================ SUMMARY ================');
  console.log(`  checked ${results.length}  /  OK ${okCount}  /  redirects ${redirects.length}  /  broken ${broken.length}  /  known-noise ${known.length}`);
  /* P12 (Round I): --redirects-json <file> writes every redirect for the next pass to apply as a same-document move
   * after a human check: the URL, where it lands, the files citing it, and whether the move stays on the same host.
   * Nothing is applied here; the sweep stays read-only. */
  {
    const i = process.argv.indexOf('--redirects-json');
    if (i > 0 && process.argv[i + 1]) {
      const host = (u) => { try { return new URL(u).host.replace(/^www\./, ''); } catch (e) { return null; } };
      const moves = redirects.map((r) => {
        const to = r.detail.replace(/^->\s*/, '');
        return { url: r.url, to, same_host: host(r.url) === host(to), sources: [...urlMap.get(r.url)].sort(),
          proposal: 'same-document move after a human check: confirm the destination is the same document, then replace the URL in every source' };
      });
      fs.writeFileSync(process.argv[i + 1], JSON.stringify({ checked: results.length, redirects: moves.length, known_noise: known.length, moves }, null, 1));
      console.log(`  wrote ${process.argv[i + 1]} (${moves.length} redirect(s))`);
    }
  }
  process.exit(0);
})().catch((e) => { console.error('RUNNER FAILURE:', e); process.exit(1); });
