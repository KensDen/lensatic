# Lensatic

Lensatic is a small, offline explainer of the United States federal cybersecurity framework stack. It is the map legend: it says what each framework is for, how the frameworks relate, who each one binds, and where zero trust and AI land. The stack is sorted by the question each framework answers, from outcomes and communication (NIST CSF 2.0) through definition (NIST SP 800-207), target state and maturity (the zero trust models), controls (NIST SP 800-53 and the overlays that point into it) and verification (the assessment regimes), with an AI column alongside. A matrix of zero trust pillars against CSF 2.0 functions sits at the center of the model. It is a mental-model tool, not a control lookup.

Live at https://kensden.github.io/lensatic/ (privacy policy: https://kensden.github.io/lensatic/privacy.html, support: https://kensden.github.io/lensatic/support.html).

Works offline, no account, no data collected by Lensatic. The privacy policy notes what GitHub Pages logs about visits to the hosted copy.

## License

Lensatic's own code and text are copyright 2026 Ken Connell, all rights reserved ([`LICENSE`](LICENSE)). The text is the summaries, matrix cell text, doors, helper answers and glossary in `content/stack.json`, the schema descriptions, the review records in `critique/`, and this README. The code is `tools/`, `web/src/`, the build and check scripts, and any future `ios/` source. The built pages, `web/lensatic.html` and everything in `docs/`, hold both. The repository is published so the work can be read and reviewed. No license is granted to copy, modify, distribute or otherwise use its code, text or artwork, in whole or in part, except as the law allows without a license or with Ken Connell's prior written permission. To ask about reusing any of it, open an issue at https://github.com/KensDen/lensatic/issues.

GitHub's Terms of Service (section D.5) let other GitHub users view and fork a public repository on GitHub, as GitHub's features allow; that is not permission to use the work anywhere else.

Versions of this repository published before this notice was added on 27 September 2026 were released under the MIT License (code) and Creative Commons Attribution 4.0 International (text). Those grants still apply to copies of those earlier versions. They do not apply to anything added or changed since. On 27 September 2026 the repository's earlier history was replaced with a single fresh commit, so those versions are no longer part of its history.

Most of the frameworks Lensatic describes are United States government publications. Works prepared by United States government officers and employees as part of their official duties are in the public domain in the United States. The app cites these publications and links to them, and the notice above covers only Lensatic's own code and text.

IBM Corp. holds the copyright in the typefaces the built pages embed, IBM Plex Sans and IBM Plex Mono, which are licensed under the SIL Open Font License, Version 1.1 ([`web/src/fonts/OFL.txt`](web/src/fonts/OFL.txt)). That license, not the notice above, governs them.

Where a cited work is protected, its title, names and any short quotation remain its owner's, and the work itself is described, not reproduced. Nothing from the AI Defense Matrix, which its authors publish under CC BY-SA 4.0, is reproduced. The app cites it, describes it in its own words, and credits its authors and license.

## Running the battery

    tools/battery.sh

Before the first run, create the local sweep list. The sweep terms and the forbidden word are never stored in this repository, so the battery reads them at run time from a gitignored file. Use `content/_sweep.txt` or `tools/sweep.txt`, holding the sweep terms and a line `forbidden: <word>`, or `tools/sweep_source.json`, which names a local document and the patterns that pull them from it. Without one, the battery stops and says so. It fails if any of these files is ever tracked.

The battery needs Python 3.11 or newer, Node 22 or newer, and a Chrome, Chromium or Edge browser. Set `LENSATIC_CHROME` if the browser is not in a standard place. Nothing is installed, and nothing leaves the repository.

`tools/validate.py` checks the content:

- The JSON parses and validates against the schema.
- One-liners are unique and appear nowhere else.
- Provenance and authority fields are complete.
- The matrix holds exactly 48 unique cells, and the two pillar views cover all eight canonical pillars.
- Door steps resolve.
- The sweep is clean in plain and rot13 form across `content/`, `web/`, `ios/`, `critique/`, `docs/`, this file and `LICENSE`, and the forbidden word appears nowhere in them.
- No em dash appears in `content/`, `critique/`, this file or `LICENSE`.
- The department name is rendered only from `orgs.dow`.
- Glossary terms and spellings are unique, resolve to their entries and carry an expansion.
- `LICENSE` and `web/src/fonts/OFL.txt` hold their pinned text (SHA-256), `meta.licenses` names them, and `content/LICENSE`, retired at content 0.7.0, stays absent.
- No dated recheck is overdue on the release date. That date is `meta.builtOn`, which must match the last changelog entry.

The font license, `web/src/fonts/OFL.txt`, is a verbatim legal text, so it is exempt from the em-dash and planning-vocabulary checks and from nothing else. `LICENSE` is Lensatic's own notice and has no exemption. `tools/check_web.py` checks the built page and the site, as described under the web wrapper below.

## Session rules

These apply to every working session on this repository, by a person or an agent.

1. Every file created, edited, deleted or moved stays inside this repository. No exceptions, including configuration and tooling that appears shared. The battery keeps its temporary files in `.tmp/`, which is gitignored.
2. Do not read, edit or restore any file under another project's directory, and do not start, stop or restart any process defined outside this repository. If a tool here appears to depend on a file outside it, stop and report rather than fixing it.
3. Any preview or dev server started for this repository must be defined by it, bound to localhost, and stopped before the session ends; report the port and the stop.

## JSON first

`content/stack.json` is the single source of truth. Every framework one-liner, every matrix cell, every door step and every helper answer lives there once, and nothing that will be rendered is written anywhere else. The schema is `content/schema/stack.schema.json` (JSON Schema draft 2020-12). The web wrapper, and the iOS wrapper when it exists, are thin views over that file and restate nothing.

## Sources

Public frameworks and public sources only. Every framework and source entry carries publisher, title as printed, edition, date, URL, and a verification record that says whether the primary was fetched on the recorded date and matched; the owner's own synthesis is marked as authored, with the entries it draws on. Prose uses plain, short sentences and no em dashes.

## Building the web wrapper

    python3 tools/build_web.py --author "Your Name" --pages

`tools/build_web.py` renders every door, layer, framework, source, solution, helper answer, function, and all matrix cells in both pillar views into `web/lensatic.html` at build time, so the page is complete when scripts do not run (mail and file previews, locked-down desktops). The builder also renders the glossary as its own section and spells out each abbreviation where it first appears in every section, linked to its glossary entry. The behavior script under `web/src/` only enhances what is already there: one matrix view at a time, cells collapsed to their first sentence, column scrolling, a glossary popover on those links, the theme toggle and a link back to the top. Below 1200 pixels the header navigation becomes a labeled section menu that names the section in view, and below 768 pixels each matrix cell carries its pillar name. The print stylesheet opens every disclosure with CSS, prints the department's matrix view with each cell cut to its first sentence, and keeps every other section complete. The content file is also embedded byte for byte as the provenance of the render. The built file is never hand-edited.

With `--pages` the builder also writes the project site under `docs/` for GitHub Pages: `docs/index.html` (the built page byte for byte), `docs/privacy.html` and `docs/support.html` (plain pages with no script, their text from `content/stack.json`, on the app's theme tokens) and an empty `docs/.nojekyll`.

The web checks:

- Rebuild the page twice, and fail if the builds differ or the embedded JSON does not hash to the content file.
- Check that the rendered text of every item is present, in the built page and in a copy with its scripts removed.
- Measure the page in a headless Chrome, Chromium or Edge, driven through the DevTools protocol with no packages. The collapsed matrix must fit a 1280 pixel window. The header must not overflow from 360 to 1440 pixels. Nothing may be clipped at phone widths with every section open. The script-off rendering must show every text.
- Print with scripts on and off. Each printout must stay under 20 pages, with every non-matrix text and each cell's first sentence present.
- Scan the built page section by section. Every abbreviation needs a glossary entry and must be spelled out at its first use.
- Build a fresh copy of `docs/` in `.tmp/` and compare it with the committed `docs/`. Fail if they differ, if `docs/` holds any other file, or if `docs/index.html` is not the built page byte for byte.
- Hold the privacy and support pages to the app's offline and wall rules: no script, no resource loading, no storage, no em dash, and a clean sweep. Check that their dates, content version, next recheck and paragraphs come from content.
- Fail on any em dash in the built page and on any email address in `docs/`, including encoded ones.
- Check that the app keeps nothing but the theme choice and that every external link in the app sits inside Sources, as the privacy policy says.
- Hold the footer's license line, the About licensing paragraph and the support page's sentence on reuse to the all-rights-reserved wording of content 0.7.0.
- Report containment: no stray untracked files, temporary files inside the repository, and no tool naming a path outside it.

The page works from a local file with no network access.

## Layout

    content/   stack.json and its schema
    web/       lensatic.html (built) and src/ (templates, stylesheets, behavior script, mark)
    docs/      the project site for GitHub Pages (built by build_web.py --pages)
    ios/       SwiftUI wrapper (later phase)
    critique/  review findings and dispositions
    tools/     validate.py, battery.sh, build_web.py, check_web.py, dom_check.mjs, layout_check.mjs
    LICENSE    the all-rights-reserved notice for Lensatic's code and text

The privacy policy in `docs/privacy.html` already speaks for the app, so the iOS wrapper must keep to it: no network access, every outside link opened in the system browser, and a link to the privacy policy inside the app (App Store Review Guideline 5.1.1). When that link is added, the policy's links sentence and the battery's link check change with it.
