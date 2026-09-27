// Static id check for the built wrapper. No packages: Node's fs and a regex over id attributes.
// Usage: node tools/dom_check.mjs web/lensatic.html < expected-ids.txt   (one id per line on stdin)
import { readFileSync } from 'node:fs';

const file = process.argv[2];
if (!file) { console.error('usage: node dom_check.mjs <built.html> < ids'); process.exit(2); }
const html = readFileSync(file, 'utf8');
const open = '<script type="application/json" id="stack">';
const i = html.indexOf(open);
const j = html.indexOf('</script>', i + open.length);
const outside = i < 0 ? html : html.slice(0, i) + html.slice(j);
const ids = new Set();
for (const m of outside.matchAll(/\sid="([^"]+)"/g)) ids.add(m[1]);
const expected = readFileSync(0, 'utf8').split('\n').map(s => s.trim()).filter(Boolean);
let missing = 0;
for (const id of expected) if (!ids.has(id)) { console.log('MISSING ' + id); missing += 1; }
const dupes = [...outside.matchAll(/\sid="([^"]+)"/g)].map(m => m[1]);
const seen = new Set(); let dup = 0;
for (const id of dupes) { if (seen.has(id)) { console.log('MISSING duplicate-id ' + id); dup += 1; } seen.add(id); }
console.log(`checked ${expected.length} ids, ${missing} missing, ${dup} duplicates, ${ids.size} ids in file`);
process.exit(missing || dup ? 1 : 0);
