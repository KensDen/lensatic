# G2 presentation gauntlet, 16 September 2026

Two lenses read the built page, not the content file: the HTML, a copy with every script removed except the embedded data, the visible text at 375 px with scripts on and off, screenshots at 375 and 1280 px, and the print rendering. Every blocker and major finding went to an independent refuter, whose verdict is recorded (upheld, narrowed, refuted). Dispositions: Fixed, Partly fixed, Deferred (with the reason). This record cites element ids and describes findings by class; it quotes no page text.

## C5 Mobile and offline reader

| Finding | Element ids | Severity | Refuter | Disposition |
|---|---|---|---|---|
| C5-01 | view-sources, ent-csf20 to ent-sp1353, main | blocker | upheld (blocker) | Fixed: the entry grid and summaries size to the screen, status pills and long links wrap, the summary stacks below 600 px; the battery now opens every disclosure at 360, 375, 390 and 414 px, scripts on and off, and fails on anything clipped past the right edge (the check fails on the old stylesheet) |
| C5-02 | top, nav, to-top, theme-toggle | major | narrowed (minor) | Partly fixed: back to top is a fixed corner button below 768 px, the section strip fades at its right edge and keeps the current section's link in view, the brand links to the top without script, and the theme button carries an icon with plain labels. Deferred: the strip still shows about two links at a time on a phone; the header stays one sticky row by design |
| C5-03 | cell-dow-user-PR, cell-dow-device-PR, cell-dow-visibility-DE, cell-dow-user-RS, table-dow | major | upheld (major) | Fixed: capability numbers sit on their own line above the sentence; measured sentence width in cell-dow-user-PR is now 154 px at 375, 138 px at 1280 and 157 px at 1440 |
| C5-04 | matrix-dow, matrix-cisa, table-dow, table-cisa | major | narrowed (minor) | Fixed: a scroll shadow on the clipped right edge that works without script, and a no-script hint that the tables scroll sideways and that the function cards repeat each cell in one column. Deferred: per-cell pillar labels on phones |
| C5-05 | matrix-dow, view-matrix | minor | not sent (below major) | Partly fixed: the scroll box uses the small viewport height where supported. Deferred: a bottom fade and scrolling the section into view on a view change |
| C5-06 | cap-dow, cap-cisa | minor | not sent (below major) | Fixed: each view's caption is a heading above the scroll box, and the table and its scroll region are labelled by it |
| C5-07 | view-matrix, matrix-dow, matrix-cisa | minor | not sent (below major) | Fixed: a jump line names both views and links them and the function cards |
| C5-08 | ent-csf20, ent-eo14028, layer-l1 | minor | not sent (below major) | Partly fixed: source entries show the same open and close marker as doors and questions. Deferred: without script a link lands on a closed entry, which is native disclosure behavior |
| C5-09 | view-matrix, h-matrix, row-dow-RC | minor | not sent (below major) | Fixed: rows do not split across pages, and the section heading prints with the first table |
| C5-10 | view-sources, view-functions | minor | not sent (below major) | Partly fixed: headings are kept with what follows and entries may break across pages; the printout is 48 pages with no near-empty page but the last. Deferred: a shorter print edition |
| C5-11 | door-federal-civilian-step-2, ent-cisa-ztmm | minor | not sent (below major) | Fixed: internal references are underlined on paper, and each entry shows its short label beside its name |
| C5-12 | door-dow, helper-csf-mandatory, ent-csf20 | minor | not sent (below major) | Deferred: printing with scripts off relies on the browser expanding closed disclosures; opening every disclosure by default would lengthen the no-script page, and printing with scripts on is measured by the battery |
| C5-13 | ent-csf20, door-federal-civilian-step-3 | minor | not sent (below major) | Fixed: primary links in the entry details reach 44 px, and short citation links do not break across lines |
| C5-14 | ent-csf20, ent-dod-zt-overlays | nit | not sent (below major) | Fixed: web addresses in notes are links |

## C8 Plain reader

| Finding | Element ids | Severity | Refuter | Disposition |
|---|---|---|---|---|
| C8-01 | intro, layer-l2, elevator | major | narrowed (minor) | Fixed: the intro defines zero trust in one plain sentence, and the definition layer's framework, whose one-liner opens the stack section, now says what the policy engine and the enforcement point do |
| C8-02 | view-doors, view-matrix, about-body | major | narrowed (minor) | Fixed: layer tags on door steps link to their layer, the doors open with a sentence on step order and tags, the matrix intro keys the category codes, and the department's two names are explained in the intro. The section order is kept, as the refuter advised |
| C8-03 | intro, door-dow, about-body | major | narrowed (minor) | Fixed: the intro says the current name is a secondary name for the department, the statutory title is unchanged, and older documents keep their printed name |
| C8-04 | door-federal-civilian, door-dow, door-defense-contractor, door-other, landing-fci-only | major | narrowed (minor) | Fixed: agency, program and document abbreviations are spelled out at first use in each door, including the contractor door's title. Deferred: an abbreviation list and marked-up abbreviations |
| C8-05 | door-dow-step-2, cap-cisa, cell-cisa-data-GV | major | narrowed (minor) | Partly fixed: the matrix intro says what a pillar is, capability numbers in the CISA view are labelled as the department's, and the department door gives the activity counts behind Target and Advanced Level. Deferred: a definition of Community Profile, which needs a check against the profile's own text |
| C8-06 | sources-intro, about-body, ent-cmmc20 | major | narrowed (minor) | Fixed: a key to the four status labels in Sources and About, the note shown wherever a conflict or an unreached primary is badged, and a marker on an entry's summary when a conflict sits inside it |
| C8-07 | intro | minor | not sent (below major) | Fixed: the description names the United States federal stack, and the intro shows the content version and the latest check date |
| C8-08 | elevator, layer-l1 to layer-l5 | minor | not sent (below major) | Partly fixed: a sentence saying what the stack is, with a key to the three chip styles. Deferred: the six-sentence opening paragraph is the specified form |
| C8-09 | fn-GV, ent-ir8596, soc-GV | minor | not sent (below major) | Partly fixed: category codes keyed in the matrix intro. Deferred: the different meanings of one two-letter code, identity-management abbreviations inside cells, and the capitals in the worked example rows, which are fixed as written by ruling |
| C8-10 | matrix-control, cap-dow | minor | not sent (below major) | Fixed: the view buttons and captions name the models and their pillar counts, and the intro explains the capability numbers |
| C8-11 | nav, theme-toggle, h-helper | minor | not sent (below major) | Fixed: the section link and heading for questions match, the theme button shows an icon and plain names, and the section strip shows it scrolls |
| C8-12 | helper-csf-mandatory, helper-csf-vs-iso27001, helper-where-others-land | minor | not sent (below major) | Deferred: the standards bodies and programs named in these answers need their expanded names checked against publisher pages first |
| C8-13 | ent-cora, ent-cmmc20, ent-sp1800-35, ent-thunderdome, ent-flank-speed | minor | not sent (below major) | Partly fixed: the new solution entries spell out the agency and explain a purple team. Deferred: abbreviations inside citation and note fields, which keep their printed form or need a primary check |
| C8-14 | ent-sp800-207, ent-dod-zt-strategy | minor | not sent (below major) | Fixed with C5-01 |
| C8-15 | cell-dow-user-PR, cell-dow-device-PR | minor | not sent (below major) | Fixed with C5-03 |

## Totals

29 findings: 1 blocker, 9 major, 18 minor and 1 nit before refutation. The blocker and one major were upheld at their severity; the other eight majors were narrowed to minor; none was refuted outright. Dispositions: 19 fixed, 8 partly fixed, 2 deferred.

## What the lenses confirmed

- With scripts removed, the page reads as complete: every door, layer, entry, answer and both matrix views are present, and no script-only control shows.
- At 375 px the intro, doors, stack, functions, AI column, worked example, questions and About survive; summaries, chips and column buttons meet 44 px; the matrix's first column stays put with and without script.
- The print rendering expands every disclosure, prints both matrix views in landscape with repeated header rows, and prints full web addresses.

## Session 5 re-read, 17 September 2026

One C8 plain-reader agent re-read the built page cold, after the session 5 fixes: screenshots and visible text of the first screenful at 375 px (script on and off) and 1280 px, the door for everyone else opened, the matrix, the glossary, and the glossary popover. It was asked whether a smart reader outside federal cybersecurity gets through the first screenful, one door and the matrix without an unexplained term. No new lenses. The major finding was checked by the session against the door's content (no independent refuter was run this session). As before, this record cites element ids, describes findings by class and quotes no page text.

Before the re-read, the session's own capture showed the phone section menu cutting off the name of the section in view at 375 px. The menu button now puts its label above the section name below 481 px, and the battery brings every section into view at 360 and 375 px and fails on a cut-off name (the check failed at 360 px before the padding was tightened).

Verdicts: the first screenful, the door for everyone else and the matrix each get through with friction.

| Finding | Element ids | Severity | Refuter | Disposition |
|---|---|---|---|---|
| S5-C8-01 | door-other, landing-fci-only, landing-civilian-cui, gl-fci, gl-cui | major | upheld on check (major) | Fixed: each of the door's two cases opens with a one-sentence definition of the information it covers, taken from the verified glossary entry, and the door's closing sentence points to those cases |
| S5-C8-02 | door-other, door-defense-contractor | minor | not sent (below major) | Fixed with S5-C8-01: only holders of controlled unclassified information under a department contract are sent to the contractor door |
| S5-C8-03 | door-other, layer-l5 | minor | not sent (below major) | Deferred: door paragraphs are plain prose and the content model has no inline links in prose; layer tags live on door steps, and this door has none |
| S5-C8-04 | navmenu, nav | minor | not sent (below major) | Fixed: a defect in this session's menu, not the popover. Back above the first section the menu kept naming the last section seen; now it names nothing there, and the battery scrolls back to the intro at 360 and 375 px and fails if a section is still named (the check fails on the unfixed script) |
| S5-C8-05 | view-matrix, matrix-control, matrix-dow, matrix-cisa | minor | not sent (below major) | Deferred: a sentence on who uses each model and what the civilian model's cross-cutting capabilities are is authored text to check against both models' own wording in a content session |
| S5-C8-06 | cell-dow-user-PR, cell-dow-application-PR, expand-all | minor | not sent (below major) | Deferred: capability numbers keep the department's own numbering and grouping; a label for the expand control is a wrapper change for the next round |
| S5-C8-07 | cell-dow-application-DE, cell-dow-user-GV, cell-dow-device-ID | minor | not sent (below major) | Deferred: first-use linking covers abbreviations; linking spelled-out terms of art inside cells needs glossary entries for them, each checked against a primary |
| S5-C8-08 | to-top | minor | not sent (below major) | Deferred: the floating button is the C5-02 disposition; a reserved gutter has to be measured against the clipping check at four phone widths |
| S5-C8-09 | door-federal-civilian-step-1, door-federal-civilian-step-2 | minor | not sent (below major) | Deferred: the doors intro already keys layer tags (C8-02); a clause on pillars is authored text for the next content round |
| S5-C8-10 | gl-ai, intro | minor | not sent (below major) | Deferred: the popover opens under the term without hiding it; covering the lines that follow is inherent to a popover, and a tooltip for the badge is a later wrapper change |
| S5-C8-11 | row-dow-GV, row-dow-ID, view-matrix | nit | not sent (below major) | Deferred: function codes are keyed in the function cards (C8-09) |
| S5-C8-12 | gl-ai, gl-c3pao, gl-cmmc, view-matrix | nit | not sent (below major) | Partly fixed: the glossary sentence where an inserted expansion split a possessive is reworded. Deferred: the other spots follow the per-section rule the battery asserts; exceptions would need an override field |
| S5-C8-13 | door-other | nit | not sent (below major) | Deferred: the rule is first use per section, and that abbreviation is spelled out earlier in the same section; labels for the link lists are a later wrapper change |
| S5-C8-14 | theme-toggle | nit | not sent (below major) | Deferred: the icon and plain names were the C8-11 disposition; a prefix on phones takes width the section menu now uses |

Totals: 14 findings, 1 major, 9 minor and 4 nits. Dispositions: 3 fixed, 1 partly fixed, 10 deferred.

What the re-read confirmed:

- The intro reads cleanly at both widths and without scripts; the zero trust definition and the note on the department's two names answer a newcomer's first questions.
- Every abbreviation in the door for everyone else and in the matrix intro is spelled out at first use, and the dimmer styling keeps the added words quiet.
- Pillar names on phone matrix cells keep a reader oriented when one column fits.
- Glossary entries read as plain sentences, and the Community Profile entry is clear.
- The popover opens beside its term and links to the full entry.
