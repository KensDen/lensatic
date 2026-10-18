#!/usr/bin/env node
/* Validation/build.cjs — rebuild Playbook/index.html from the JSX source.
 *
 * Mirrors the exact pipeline used in every maintenance pass:
 *   1. read Playbook/agentic-secops-teaming.jsx (the source of truth)
 *   2. swap the React import for a browser-global destructure; drop the export
 *   3. transpile JSX with TypeScript (jsx: React, target: ES2019, module: None)
 *   4. splice the output into index.html between the payload marker comment
 *      and the closing </script>
 *   5. run Validation/sync_check.cjs to verify the result byte-for-byte
 *
 * Requires the `typescript` package (local `npm install typescript` in the
 * suite root, or a global install). Never edit index.html by hand — edit the
 * JSX and run this.
 */
const fs = require('fs'), path = require('path'), cp = require('child_process');

const SUITE = path.resolve(__dirname, '..');
const JSX = path.join(SUITE, 'Playbook', 'agentic-secops-teaming.jsx');
const HTML = path.join(SUITE, 'Playbook', 'index.html');

function resolveTs() {
  try { return require('typescript'); } catch (e) {}
  try {
    const root = cp.execSync('npm root -g', { encoding: 'utf-8' }).trim();
    return require(path.join(root, 'typescript'));
  } catch (e) {}
  console.error('BUILD FAIL: typescript not found. Run `npm install typescript` in the suite root (or install globally).');
  process.exit(1);
}

const ts = resolveTs();
const jsx = fs.readFileSync(JSX, 'utf-8');
const src = jsx
  .replace('import { useState, Fragment } from "react";', 'const { useState, Fragment } = React;')
  .replace('export default function App() {', 'function App() {');
if (src === jsx) {
  console.error('BUILD FAIL: expected import/export anchors not found in the JSX.');
  process.exit(1);
}
const out = ts.transpileModule(src, { compilerOptions: {
  jsx: ts.JsxEmit.React, target: ts.ScriptTarget.ES2019, module: ts.ModuleKind.None,
} }).outputText;

const html = fs.readFileSync(HTML, 'utf-8');
const m = html.match(/\/\* ===== Agentic SecOps playbook component[^*]*\*\/\s*\n?/);
if (!m) { console.error('BUILD FAIL: payload marker comment not found in index.html.'); process.exit(1); }
const s = m.index + m[0].length;
const e = html.indexOf('</script>', s);
if (e < 0) { console.error('BUILD FAIL: closing </script> not found after payload marker.'); process.exit(1); }
fs.writeFileSync(HTML, html.slice(0, s) + out + html.slice(e));
console.log(`build: spliced ${out.length} chars into Playbook/index.html`);

const r = cp.spawnSync('node', [path.join(__dirname, 'sync_check.cjs')], { stdio: 'inherit' });
process.exit(r.status === null ? 1 : r.status);
