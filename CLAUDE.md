# Agentic SecOps Tradecraft Playbook: notes for Claude Code

This is the public edition of the Agentic SecOps Tradecraft Playbook, built by Ken Connell with Claude and Claude Code. The source of truth for the app is `Playbook/agentic-secops-teaming.jsx`. The script payload in `Playbook/index.html` is generated and never hand-edited; the shell around it (head, tokens, fonts) is edited directly. Regenerate the payload with `node Validation/build.cjs`.

## Ship gate

`node Validation/battery.cjs` must be ALL GREEN before any commit. Seven layers:

1. sync_check: canon counts, nav parity, zero external loads, diagram hygiene (each embedded figure equals its file in Diagrams/), JSX to HTML byte-sync, and that each linked action source label matches the name of the resource it links to.
2. ripple_check: derives the canon from the JSX and checks every place that states a count: validator labels, README.md, the study guide's Part 8 mirror and edition note, the deck's stat slide and stamp, the field card's phasing line, and the validators' action counts. It also fails on any stray canon count in Validation/ or in the top-level README.md, CLAUDE.md, index.html, THIRD_PARTY_NOTICES.md and package.json, and on any count stated in this file.
3. statics_check: UTF-8 hygiene, reference-group ordering, WCAG AA contrast floors in both themes, the identity guard, and the text checks: registered figures carry their labels, registered claims keep their canonical form, and cross-references name what exists; UK spellings, figures without a source and absolutes stated as fact are reported as warnings.
4. Deck and document asserts: slide and page counts, the Part 8 mirror and its sub-group labels, the field card, and the self-containment of the landing page and the executive summary.
5. embed_check: every gated figure appears exactly once under its home tab.
6. render_check: headless functional checks in both themes, including that every tab renders each of its body headings exactly once.
7. anchor_check: every deep-link anchor and gated figure resolves.

Layer 5 needs python3; layers 6 and 7 need Chrome or Chromium (set `CHROME_PATH` if it isn't found) and puppeteer. The build needs typescript. `npm install` provides both. The `.public-edition` marker at the root puts the validators in public mode, which skips checks for files that only exist in the private working repo.

The briefing deck and the concept brief ship as PDFs. Their editable sources, the PPTX and the DOCX, stay in the private working repo, so in public mode the checks that read the deck or the brief read these PDFs instead.

`Validation/registry.json` holds the figures and claims registries, the allowlists and the baselines the text checks read, and `Validation/text_units.cjs` reads the shipped text for them. Beyond the battery, `link_check.cjs` adds a currency sweep and a redirect list, the export gate reports authoring residue without failing on it, and the executive summary build warns when its last page is more than 90% full.

## Rules the scripts do not carry

- Canonical counts live in the JSX. Never hardcode them in this file; ripple_check derives them and checks the places listed in ship-gate item 2.
- Verify before changing: read the exact anchor first, assert that each edited anchor appears exactly once, and write in a single pass.
- Every external claim links to its source. Frame vendor claims first-party ("the vendor reports"), prefer primary sources, and quote at most one short passage per source.
- Mirror discipline: a resource change lands together in the JSX, the study guide's Part 8 mirror, README.md and the deck's stat slide.
- Executive summary: edit `Documents/Agentic-SecOps-Executive-Summary.html`, then run `node Validation/build_exec_summary.cjs`. Never edit the PDF by hand.
- Nothing client-specific or engagement-specific enters any artifact.
- UTF-8 throughout, with no `\u` escapes in content.

## License

The work is all rights reserved; see `LICENSE`. Never add a license grant, a line inviting reuse, or a mention of a public content license such as the one earlier versions carried. Third-party material keeps its own terms; see `THIRD_PARTY_NOTICES.md` and `LICENSES/`. The license checks in the battery and the export gate enforce this.

## Definition of done

The battery is ALL GREEN, every mirror is in lockstep, and the commit message says what changed and why.
