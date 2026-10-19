# Agentic SecOps

A tradecraft playbook for red, blue and purple teaming in the age of Agentic AI: 87 sourced actions, 243 indexed resources, 89 glossary terms, and 16 diagrams. Every external claim links to its source.

**Open it:** https://kensden.github.io/lensatic/playbook/

## What's inside

| | |
|---|---|
| [Playbook app](https://kensden.github.io/lensatic/playbook/Playbook/) | The interactive reference: one self-contained HTML file that works offline in any modern browser and makes no network calls. |
| [Executive summary](Documents/Agentic-SecOps-Executive-Summary.pdf) | The leadership read, built from [its HTML source](Documents/Agentic-SecOps-Executive-Summary.html). |
| [Briefing deck](Deck/Agentic-SecOps-Master-Deck.pdf) | One story told three ways, for executive, technical, and general audiences. |
| [Study guide](Documents/Agentic-SecOps-Study-Guide.md) | A self-study path from "what is an agent" to running red, blue, and purple exercises against agentic systems. |
| [Field card](Documents/Agentic-SecOps-Tradecraft-Field-Card.md) | The operational spine on two pages. Load it into an agent's context or read it in one sitting. |
| [Concept brief](Documents/Adversary-Emulation-Concept-Brief.pdf) | Intelligence-driven agentic adversary emulation, written as a discussion piece. |
| [Diagrams](https://kensden.github.io/lensatic/playbook/#diagrams) | Sixteen standalone posters, fourteen of them also embedded in the app. |
| [Validation](Validation/) | The battery that keeps everything above in lockstep. |

## Version history

- v5.4.0, 18 October 2026: 20 sentences and 6 list labels whose punctuation the v5.3.0 dash removal left wrong now read correctly, four study guide glossary entries match the app again, the value stream poster heading takes its colon outside the accent, and twelve app headings capitalize the word after the colon. 50 more places in the app, summary, study guide and one poster, where the dash removal ran an aside into a list or cut a subject from its verb, take parentheses or a clearer mark. The summary describes operational technology operators as the app does, says the DoW CIO presented the Cybersecurity Risk Management Construct to succeed the RMF, links the supply chain risk designation to usage boundaries, calls the Mexican case the APT_UNICORN persona made real, and keeps number ranges on one line. To stay at seven pages, the summary drops the ATO's three-year term and an aside on blast-radius containment. The Maturity Model shows its benchmark callout, the Attacker Moves Second card opens the arXiv paper, Back to the bare address shows Overview, the Torq survey links its report, the Metrics & ROI tab drops the MTTR, MTTC and triage figures that had no primary source, and the summary drops its MTTC figure. The landing and app footers link All rights reserved to the LICENSE, and the app's credit ends with a full stop. Two general points say public sector instead of federal, Agentic SecOps is capitalized throughout, quotation marks are straight in the app, study guide, summary and posters, and the Alberta entry's MIT terms are an approved mention. On a phone the menu keeps each group label readable and fades at its edge, and every tab ends with a link to the next. Search opens each Resource Index card and leaves out the case sub-labels. Three titles are in title case, a capitalized heading drops (cATO), DoW is spelled out on its tab and added to the glossary, the APT_UNICORN card names its months, the access hand-off tile says after initial access, the Gödel heading no longer says continuous defense became a theorem, and the threat timeline poster says Anthropic reports the first documented AI-orchestrated campaign. The study guide corrects its GIAC note, drops two duplicate glossary entries and two date stamps, and titles crawl, walk, run the autonomy dial. The field card says action plan and human approval gates and explains three terms. Both link the app. The deck counts 89 glossary terms and capitalizes Agentic SecOps. The three-jobs poster cites its source, the value stream poster names Security Copilot, and this README carries the one build credit.
- v5.3.0, 18 October 2026: no em or en dash left in the app, study guide, summary, posters, field card or landing, and the deck title follows. The theme toggle moves to the Lensatic bar, the header is compact on phones, the emblem sits in its tile and the primary button is purple.
- v5.2.2, 18 October 2026: DoW in prose and a Federal & DoW tab, generic role names, Agentic AI capitalized, one build credit, the deck re-exported with the app's address, the counter in menu order, phone layout fixes, and current sources for NIS2, GPT-Red and Apache Caldera.
- v5.2.1, 18 October 2026: concept brief carries the new name.
- v5.2, 18 Oct 2026: joins Lensatic as its Playbook section, renamed Agentic SecOps.
- v5.1, 27 Sep 2026: public edition, all rights reserved. New content and study guide self-checks. Fixes through 14 Oct 2026 added Zero Trust for AI sources and talks, links to the Zero Trust guide, and glossary and emblem fixes.
- v5.0, 25 Sep 2026: first public edition. The playbook, deck, study guide and executive summary, rebuilt for publication.
- v4.0, 4 Aug 2026: implementation steps for 78 of the 85 recommended actions, each linked to its sources. The Reference Index grows to 210 entries.
- v3.0, 16 Jul 2026: visual redesign, with dark and light themes and all 16 diagrams retinted.
- v2.0, 15 Jul 2026: a full content cycle after a deep quality review. 85 recommended actions, 195 indexed entries, 16 diagrams.
- v1.0, 2 Jul 2026: first edition.

## Go deeper

[Zero Trust](https://kensden.github.io/lensatic/guides/zero-trust/), in Lensatic's Field Guides, is my companion study guide: an eight-week plan with a shared Zero Trust core (NIST SP 800-207 and the CISA Zero Trust Maturity Model), then DoW, federal civilian and private-sector tracks, with one-page quick references. Public sources only; it links back here for the agentic view.

## How it was built

I built this with Claude and Claude Code. Claude helped me research, draft, and cross-check. Claude Code made the edits, rendered the documents, and ran a validation battery that checks every count, mirror, and rendered page before anything ships.

I reviewed every change, and I own the result, mistakes included.

## Run it yourself

Open `Playbook/index.html` in a browser. That is the whole install.

To run the checks, install Node.js, then:

    npm install
    npm run battery

The browser layers need Chrome or Chromium; set `CHROME_PATH` if yours isn't found. The embed check needs `python3`; the deck and document checks use `unzip` and `pdfinfo` when they are available.

After editing `Playbook/agentic-secops-teaming.jsx`, rebuild the app with `npm run build`. After editing the executive summary's HTML, rebuild its PDF with `npm run build:summary`.

## License

© 2026 Ken Connell. All rights reserved. This repository is public so the work can be read, reviewed and used for personal study. No license to copy, adapt or reuse it is granted. [LICENSE](LICENSE) has the full notice and how to ask for permission. Embedded fonts and libraries keep their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Third-party product, tool, and framework names referenced in this playbook are trademarks of their respective owners. A personal project: views are my own and do not represent any employer, client, or vendor.

Built with Claude and Claude Code, reviewed by a human who owns the mistakes.
