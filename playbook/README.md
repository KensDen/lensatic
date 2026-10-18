# Agentic SecOps

A field reference for red, blue, and purple teaming in the age of agentic AI: 87 sourced actions, 243 indexed resources, 88 glossary terms, and 16 diagrams. Every external claim links to its source.

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

- v5.2.1, 19 October 2026: concept brief carries the new name.
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

© 2026 Ken Connell. All rights reserved. This repository is public so the work can be read and reviewed. No license to copy, adapt or reuse it is granted. [LICENSE](LICENSE) has the full notice and how to ask for permission. Embedded fonts and libraries keep their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Third-party product, tool, and framework names referenced in this playbook are trademarks of their respective owners. A personal project: views are my own and do not represent any employer, client, or vendor.

Built by Ken Connell with Claude and Claude Code.
