# Lensatic

Public sector cyber frameworks are thick woods. Lensatic is the compass.

Framework Maps, Lensatic's first section, is a small guide to the United States public sector cybersecurity frameworks. It is for anyone handed a framework, a maturity model, or a zero trust deadline and asked where it fits: federal civilian agencies, Department of War (DoW) components, defense contractors, and anyone else borrowing the United States federal models. It is the map legend: it says what each framework is for, how the frameworks relate, who each one binds, and where zero trust and AI land. The stack is sorted by the question each framework answers, from outcomes and communication (the National Institute of Standards and Technology (NIST) Cybersecurity Framework (CSF) 2.0) through definition (NIST Special Publication (SP) 800-207), target state and maturity (the zero trust models), controls (NIST SP 800-53 and the overlays that point into it) and verification (the assessment regimes), with an AI column alongside. A matrix of zero trust pillars against CSF 2.0 functions sits at the center of the model. Framework Maps is a wayfinder, not a crosswalk. It guides you, showing which framework answers which question and how the trails converge, so you know your bearing before you step into a control catalog or navigate the cyber assurance terrain. The name comes from the lensatic compass, the Army's field compass for taking a bearing; Lensatic helps you take a bearing on the framework stack.

Lensatic 2.0.3 holds three sections, each with its own build, checks and README in its own tree:

- **Framework Maps**, https://kensden.github.io/lensatic/maps/: the map described above, built from `content/stack.json` by `tools/`, with the iOS app in `ios/`.
- **Field Guides**, https://kensden.github.io/lensatic/guides/: guided study routes. The first is [Zero Trust](https://kensden.github.io/lensatic/guides/zero-trust/), in `guides/zero-trust/`.
- **Playbook**, https://kensden.github.io/lensatic/playbook/: Agentic SecOps, a tradecraft playbook for red, blue and purple teaming in the age of Agentic AI, in `playbook/`.

The hub at https://kensden.github.io/lensatic/ links all three (privacy policy: https://kensden.github.io/lensatic/privacy.html, support: https://kensden.github.io/lensatic/support.html).

Framework Maps content version: 1.2.18.

No account, no data collected by Lensatic. The privacy policy notes what GitHub Pages logs about visits to the hosted copy.

Not affiliated with NIST, CISA, NSA, Department of War, OMB, or any framework publisher.

    content/    the map's content: stack.json and its schema
    web/        the map's web page: lensatic.html (built) and src/ (templates, stylesheets, behavior script, mark, photo)
    tools/      the map's build and checks, the hub build, the shared-chrome tool and the umbrella checks
    ios/        the map's SwiftUI app: project.yml, the generated Xcode project, sources, tests, and store/, its App Store listing
    hub/        the hub's source: the field system's shared stylesheet, site.json, the marks and DESIGN.md
    guides/     Field Guides: zero-trust/, the Zero Trust guide as it publishes (page, PDFs, README, record, LICENSE)
    playbook/   Agentic SecOps, whole: the app, documents, deck, diagrams, its notices and its own battery
    docs/       the GitHub Pages root: published copies only
    critique/   review findings and naming records

## Version history

- 2.0.3, 25 October 2026: every closing block lines up. On every page the closing paragraph, the footer lines, the copyright line and the badge run the full width of the page's column, on the cards' left edge, and under 520px the legend boxes span it like the cards. A new battery check, the layout guard (`tools/layout_guard.mjs`, playwright-core driving the system Chrome), holds every published page to that at 375, 390 and 1440 wide, in light and dark.
- 2.0.2, 18 October 2026: one theme toggle in the umbrella bar for every page, Framework Maps under its own name, section-tinted buttons, the APT_UNICORN emblem in its tile, and a rights line in the hub and guides index footers.
- 2.0.1, 18 October 2026: the hub tells where the name comes from; the notices allow personal study.
- 2.0, 18 October 2026: Framework Maps, Field Guides and Playbook under one roof.

## License

Lensatic's own code and text are copyright 2026 Ken Connell, all rights reserved ([`LICENSE`](LICENSE)). The text is the summaries, matrix cell text, trailheads, helper answers and glossary in `content/stack.json`, the schema descriptions, the review records in `critique/`, and this README. The code is `tools/`, `web/src/`, the build and check scripts, and the iOS app's source in `ios/`. The built pages, `web/lensatic.html` and everything in `docs/`, hold both. The repository is published so the work can be read, reviewed and used for personal study. No license is granted to copy, modify, distribute or otherwise use its code, text or artwork, in whole or in part, except as the law allows without a license or with Ken Connell's prior written permission. To ask about reusing any of it, open an issue at https://github.com/KensDen/lensatic/issues.

GitHub's Terms of Service (section D.5) let other GitHub users view and fork a public repository on GitHub, as GitHub's features allow; that is not permission to use the work anywhere else.

Versions of this repository published before this notice was added on 27 September 2026 were released under the MIT License (code) and Creative Commons Attribution 4.0 International (text). Those grants still apply to copies of those earlier versions. They do not apply to anything added or changed since. On 27 September 2026 the repository's earlier history was replaced with a single fresh commit, so those versions are no longer part of its history.

Zero Trust, in `guides/zero-trust/`, and Agentic SecOps, in `playbook/`, carry their own notices, [`guides/zero-trust/LICENSE`](guides/zero-trust/LICENSE) and [`playbook/LICENSE`](playbook/LICENSE), and LICENSE marks each work. For Zero Trust it records, in its own words: "Versions 1.0 (27 September 2026) and 2.0 (30 September 2026) were released under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International license (CC BY-NC-SA 4.0). That grant still applies to copies of those versions. It does not apply to anything added or changed since."

Most of the frameworks Lensatic describes are United States government publications. Works prepared by United States government officers and employees as part of their official duties are in the public domain in the United States. Framework Maps and its iOS app cite these publications and link to them, and the notice above covers only Lensatic's own code and text.

IBM Corp. holds the copyright in the typefaces the built pages embed, IBM Plex Sans and IBM Plex Mono, which are licensed under the SIL Open Font License, Version 1.1 ([`web/src/fonts/OFL.txt`](web/src/fonts/OFL.txt)). That license, not the notice above, governs them.

The iOS app in `ios/` is covered by the same all-rights-reserved notice as the rest of Framework Maps. Its fonts are IBM's own TrueType files for the same IBM Plex faces, unmodified, under the same license, with IBM's license beside them ([`ios/Lensatic/Resources/Fonts/OFL.txt`](ios/Lensatic/Resources/Fonts/OFL.txt)); the Lensatic icon identifies this project and, like the rest of it, is not licensed for any other use.

Where a cited work is protected, its title, names and any short quotation remain its owner's, and the work itself is described, not reproduced. Nothing from the AI Defense Matrix, which its authors publish under CC BY-SA 4.0, is reproduced. Framework Maps cites it, describes it in its own words, and credits its authors and license.

## Running the battery

    tools/battery.sh

Before the first run, create the local sweep list. The sweep terms and the forbidden word are never stored in this repository, so the battery reads them at run time from a gitignored file. Use `content/_sweep.txt` or `tools/sweep.txt`, holding the sweep terms and a line `forbidden: <word>`, or `tools/sweep_source.json`, which names a local document and the patterns that pull them from it, and may list words the owner has ruled out of the sweep. Without one, the battery stops and says so. It fails if any of these files is ever tracked.

The battery needs Python 3.11 or newer, Node 22 or newer, and a Chrome, Chromium or Edge browser. Set `LENSATIC_CHROME` if the browser is not in a standard place. The map's checks install nothing, and nothing leaves the repository.

Since Lensatic 2.0 the battery also runs `tools/check_umbrella.py` (the hub, the guides index, the published copies of the moved sections and the field system) and the Agentic SecOps battery in `playbook/`, which needs that section's dev dependencies: run `npm install` in `playbook/` once (see `playbook/README.md`). `LENSATIC_PRIVATE_SWEEP` may name the owner's private sweep list for the umbrella's sweep, which is skipped without it. `LENSATIC_NO_XCODE=1` runs the iOS stage's static checks only, for a machine where Xcode cannot run unattended.

Since Lensatic 2.0.3 it also runs the layout guard, `tools/layout_guard.mjs`: it loads every published page under `docs/` at 375, 390 and 1440 wide, in light and dark, and fails when a block of text in the page's closing area (its footer, copyright and closing lines, and a summary note after cards), or a legend box under 520px, is more than 2px narrower than the page's main column or offset from it, when a closing line wraps without `text-wrap: pretty` or ends on one word, when a page scrolls sideways, or when it cannot classify a page, which it names. It needs `playwright-core`, the only package at the root: run `npm install --no-package-lock --ignore-scripts` once in the repository root. It drives the same Chrome and downloads no browser.

`tools/validate.py` checks the content:

- The JSON parses and validates against the schema.
- One-liners are unique and appear nowhere else.
- Provenance and authority fields are complete.
- The matrix holds exactly 48 unique cells, and the two pillar views cover all eight canonical pillars.
- Trailhead steps resolve.
- The sweep is clean in plain and rot13 form across `content/`, `web/`, `ios/` (the App Store listing in `ios/store/` included), `critique/`, `docs/` (bar the moved sections' published copies, which their own checks hold), `hub/`, this file and `LICENSE`, and the forbidden word appears nowhere in `content/`, `critique/` or `LICENSE`.
- No em dash appears in `content/`, `critique/`, this file or `LICENSE`.
- The department name is rendered only from `orgs.dow`.
- Glossary terms and spellings are unique, resolve to their entries and carry an expansion.
- `LICENSE` and `web/src/fonts/OFL.txt` hold their pinned text (SHA-256), `meta.licenses` names them, and `content/LICENSE`, retired at content 0.7.0, stays absent.
- No dated recheck is overdue on the release date. That date is `meta.builtOn`, which must match the last changelog entry.

The font license, `web/src/fonts/OFL.txt`, is a verbatim legal text, so it is exempt from the em-dash and planning-vocabulary checks and from nothing else. `LICENSE` is Lensatic's own notice and has no exemption. `tools/check_web.py` checks the built page and the site, as described under the web wrapper below.

Every working session on this repository, by a person or an agent, follows the session rules in [`CONTRIBUTING.md`](CONTRIBUTING.md).

## JSON first

`content/stack.json` is the single source of truth. Every framework one-liner, every matrix cell, every trailhead step and every helper answer lives there once, and nothing that will be rendered is written anywhere else. The schema is `content/schema/stack.schema.json` (JSON Schema draft 2020-12). The web wrapper and the iOS app are thin views over that file and restate nothing.

## Sources

Public frameworks and public sources only. Every framework and source entry carries publisher, title as printed, edition, date, URL, and a verification record that says whether the primary was fetched on the recorded date and matched; the owner's own synthesis is marked as authored, with the entries it draws on. Prose uses plain, short sentences and no em dashes.

## Building the web wrapper

    python3 tools/build_web.py --author "Your Name" --pages

`tools/build_web.py` renders every trailhead, layer, framework, source, solution, helper answer, function, and all matrix cells in both pillar views into `web/lensatic.html` at build time, so the page is complete when scripts do not run (mail and file previews, locked-down desktops). The builder also renders the glossary as its own section and spells out each abbreviation where it first appears in every section, linked to its glossary entry, except AI, which every reader knows: it is never spelled out, and is linked to its glossary entry only in the AI column. The behavior script under `web/src/` only enhances what is already there: one matrix view at a time, cells collapsed to their first sentence, column scrolling, a glossary popover on those links and a link back to the top; the theme toggle is the umbrella bar's (hub/theme-bar.js). Below 1200 pixels the header navigation becomes a labeled section menu that names the section in view, and below 768 pixels each matrix cell carries its pillar name. The print stylesheet opens every disclosure with CSS, prints the department's matrix view with each cell's capability numbers and first sentence, leaves out the front door's two buttons, and keeps every other section complete. The content file is also embedded byte for byte as the provenance of the render. The built file is never hand-edited.

With `--pages` the builder also writes the map's part of the project site under `docs/` for GitHub Pages: `docs/maps/index.html` (the built page byte for byte), `docs/privacy.html` and `docs/support.html` (plain pages with no script, their text from `content/stack.json`, on the app's theme tokens), `docs/social-card-v2.png` (the card, from `web/src/social-card.png`) and an empty `docs/.nojekyll`. `python3 tools/build_hub.py` writes the rest: the hub (`docs/index.html`), the guides index, the shared stylesheet, the sitemap and the published copies of `guides/zero-trust/` and `playbook/`. `python3 tools/apply_chrome.py` refreshes the umbrella bar and the shared stylesheet in the two hand-edited Agentic SecOps pages.

The web checks:

- Rebuild the page twice, and fail if the builds differ or the embedded JSON does not hash to the content file.
- Check that the rendered text of every item is present, in the built page and in a copy with its scripts removed.
- Measure the page in a headless Chrome, Chromium or Edge, driven through the DevTools protocol with no packages. The collapsed matrix must fit a 1280 pixel window. The header must not overflow from 360 to 1440 pixels. Nothing may be clipped at phone widths with every section open. The script-off rendering must show every text.
- Print with scripts on and off. Each printout must be at most 20 pages, with every non-matrix text present except the front door's two buttons, which must not print, and each cell's capability numbers and first sentence.
- Scan the built page section by section. Every abbreviation needs a glossary entry and must be spelled out at its first use, except AI, which no built page spells out and which links to the glossary only at its first use in the AI column.
- Build a fresh copy of the map's part of `docs/` in `.tmp/` and compare it with the committed one. Fail if they differ, if `docs/` holds a file neither the map's build nor the umbrella writes, or if `docs/maps/index.html` is not the built page byte for byte.
- Hold the privacy and support pages to the app's offline and wall rules: no script, no resource loading, no storage, no em dash, and a clean sweep. Check that their dates, content version, next recheck and paragraphs come from content.
- Fail on any em dash in the built page and on any email address in `docs/`, including encoded ones.
- Check that the web page keeps nothing but the theme choice and that every external link on it sits inside Sources or among the footer's links to the privacy policy, the support page and the source code, as the privacy policy says.
- Hold the footer's license line, the About licensing paragraph and the support page's sentence on reuse to the all-rights-reserved wording of content 0.7.0.
- Hold the front door's version line to its two links, the second to Why the name in About, and check that the About photo is embedded once, as a `data:` URI of the pinned `web/src/about-photo.jpg`, with no metadata.
- Report containment: no stray untracked files, temporary files inside the repository, and no tool naming a path outside it.

The page works from a local file with no network access.

## iOS app

`ios/` holds a native SwiftUI app for iPhone and iPad that renders the same `content/stack.json` as the web page. The file is a resource of the app by reference, never a copy, and so is the About photo, `web/src/about-photo.jpg`. The app is being redesigned in four rounds (R1 to R4). Since R1 it opens on a welcome screen that asks which trailhead applies, then shows four tabs: My Path (a progress ring, the countdown to the next deadline a source dates, or the next step where none lies ahead, and the trailhead's steps to check off), Explore, Search and Library. An entry opens as a card with a Sources sheet. The sections R1 does not redesign keep their earlier screens under Explore and Library, with the same department tokens and abbreviation rules as `tools/build_web.py`. Every number on screen is computed from the content; the welcome screen and the cards add a few interface words of their own. The app uses the field system's color tokens (`tools/gen_ios_colors.py` writes them into the asset catalog from `web/src/styles.css` and `hub/lensatic.css`) and six IBM Plex faces from IBM's release archives, scaled with Dynamic Type.

`ios/project.yml` is the source of the Xcode project. `ios/Lensatic.xcodeproj` is generated from it with XcodeGen and committed, so it opens directly:

    open ios/Lensatic.xcodeproj

To build and run the tests from the command line, on any iPhone or iPad simulator:

    xcodebuild -project ios/Lensatic.xcodeproj -scheme Lensatic -destination 'platform=iOS Simulator,name=<device>' -derivedDataPath .tmp/DerivedData -resultBundlePath .tmp/<device>.xcresult build test

The unit tests decode the real content strictly, check that the bundled file is the repository's, hold the app to the web page's text (every string `tools/build_web.py --texts` lists must appear in the app), test each transformation rule, and test the path: progress, the next step, the deadline math, the welcome screen's lines, switching trailheads and the saved file. The UI tests pick a trailhead, check off a step, relaunch and find it still checked, switch trailheads, open a step's card and its Sources sheet, open every section kept under Explore and Library, and run the accessibility audit on each screen; they also switch the matrix views and find the three About links. The `LensaticAuditSweep` scheme runs a longer accessibility audit that reads every section top to bottom, one test per section so each has its own audit budget, and fails nothing; its findings are read by hand. `tools/ios_shots.sh` takes screenshots of every section on the largest iPhone and iPad simulators, in light and dark and at two text sizes.

The Simulator needs no Apple account. Archiving the app for the App Store needs the owner's Apple developer team, chosen in Xcode under Signing & Capabilities; nothing in this repository signs, archives or uploads it.

The app keeps to the privacy policy in `docs/privacy.html`: it makes no network requests and every outside link opens in the system browser. About links to the privacy policy, as App Store Review Guideline 5.1.1 requires, and to the support page and the source code. It keeps two things, on the device only: the trailhead picked and the steps checked off, in one small file in the app's own Application Support folder (`ios/Lensatic/Model/ProgressStore.swift`, the app's only file write, which `tools/check_ios.py` holds to that file). Its privacy manifest declares no data collection, no tracking and no required-reason API.

The battery's iOS stage, `tools/check_ios.py`, runs on every machine: the color sets and the text list equal fresh generations; nothing under `ios/` names a web view, a networking API, stored defaults, a file write or any API the privacy manifest would have to declare; the app names no outside address but the policy, support and source links; every font scales with Dynamic Type; the fonts, the icon and the privacy manifest are the pinned files and values; and the app carries no copy of the content or the photo. Where Xcode works, it also compares the committed project with a fresh XcodeGen generation and builds and tests the app on the newest iPhone simulator; elsewhere it prints one SKIP line. XcodeGen is used from `PATH`, or from its release unpacked into `.tmp/xcodegen/`.

### App Store

On the App Store the app will be listed as Lensatic Cyber, because the single word was already reserved by another developer's record; everywhere else, the Home Screen included, it is Lensatic. `ios/store/app-store.json` is the listing's source of truth, every field pasted into App Store Connect and nothing secret; its promotional text and description are built from `content/stack.json`, apart from the description's settled opening paragraph, its What's inside heading and the glosses on two of its items, which `tools/check_listing.py` holds. `ios/store/app-store.md` is its copy sheet, one heading per field with the text to copy and the length of each text, and `python3 tools/check_listing.py --write` rebuilds both. The store screenshots come from `tools/ios_shots.sh --store`; the images stay out of the repository, and `ios/store/screenshots.json` lists them with their sizes and hashes. The battery's listing stage, `tools/check_listing.py`, checks the fields against Apple's length limits, the settled wording and the listing rules, and checks the copy sheet and the screenshot list.

The privacy policy in `docs/privacy.html` speaks for every Lensatic page and for the iOS app; the iOS app section above says how the app keeps to it.
