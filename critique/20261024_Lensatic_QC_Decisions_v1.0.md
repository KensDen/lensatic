# Lensatic QC Decisions, 24 October 2026 (v1.0)

Questions for Ken from the QC round on branch `qc/lensatic-20261024`. Finding IDs refer to `20261024_Lensatic_QC_Ledger_v1.0.md`.
Each question marks one option "(Recommended)". Nothing here has been changed. No answer changes content counts, frameworks or
features unless the question says so.

## The playbook section

**Q1. A playbook patch for the objective defects?** L-02, L-06, V-01 (app, executive summary, diagrams), V-06, V-10, V-12, B-02,
W-09 (diagrams), R-24, R-42 to R-47. They are: the dead DCSA link and the moved Australian address; the app's 31px chips, 25px
buttons, 13.5px search input and cut placeholder; the two diagram overlaps and the diagrams' 10 to 11px phone text and dark-only
look; one-word last lines in the app, the executive summary and six diagrams; the Resource Index order warning; preview tags on the
16 diagrams; the crosswalk's unlabeled phone cards; the spectrum diagram's missing scoring note; the workforce diagram's one
technique among tactics.
- A (Recommended): one Agentic SecOps patch, v5.4.2, with posters and their twins together, as usual. Three items change words
  (the search placeholder, for example "Search the playbook"; the spectrum diagram's scoring note; the workforce card's mapping),
  so their text comes to Ken before it ships.
- B: the links, tap targets and input now; leave the diagrams for a later design pass.
- C: leave the section as it is.

**Q2. The Resource Index corrections (P-01 to P-25)?** Eight were rechecked in Chrome (P-01 to P-08); the rest rest on one agent's
reading.
- A (Recommended): ship P-01 to P-08 in Q1's patch, and recheck P-09 to P-25 by hand before they ship.
- B: ship all 25 as found.
- C: leave the index as it is.

**Q3. "The Gödel mandate (NIST, Jun 2026)" in the identity-first diagram and the app (F-10)?** It names a research proof, which
mandates nothing, with no title or link.
- A (Recommended): "the Gödel result (Vassilev, NIST, June 2026)", linked to NIST's news item, which the Resource Index already cites.
- B: keep the wording and add the link.
- C: leave it.

**Q4. "Human in Command" across the site (W-04, R-32)?** The app writes "human-in-command" about 30 times, four diagrams and the
executive summary use hyphenated and lower-case forms, the field card says "human in command", and the map says "Humans in
Command" twice.
- A (Recommended): "Human in Command" wherever it names the principle (the map's two lines, headings, the executive summary,
  diagram labels); keep the hyphen only where it stands before a noun ("human-in-command decision gates"). The map's lines are a
  content release; the rest goes in Q1's patch.
- B: "Human in Command" everywhere, rewording the adjective uses.
- C: leave it.

**Q5. Where the credit line appears (W-05, R-35)?** The hub and the guides index do not carry it; the playbook landing carries it twice.
- A (Recommended): drop the playbook landing's "How it was built" block (the footer keeps the line), and add the line once to the
  hub's About, as the map and the Zero Trust guide carry it.
- B: only drop the duplicate.
- C: leave it.

## Wording and licence

**Q6. The Zero Trust guide's LICENSE and README say "read and used for personal study" (W-06)?**
- A (Recommended): "read, reviewed and used for personal study", through a new licence asset in the private pipeline and v1.2 of the
  v2.8.3 build (same edition, text and PDFs).
- B: at the guide's next edition.
- C: leave it.

**Q7. The personal-study wording on the published pages (W-07)?** Rights lines say "All rights reserved" and link the notice; the map's
About licensing paragraph says all rights reserved and how to ask about reuse.
- A (Recommended): add one sentence to the map's About licensing paragraph: "The work is published so it can be read, reviewed and
  used for personal study." (a content release; the hub's About renders the same paragraph).
- B: leave the pages as they are; the notices carry the wording.

**Q8. The 1.2.4 changelog line on the map ("a guide to the federal cybersecurity frameworks", W-02)?**
- A (Recommended): leave it; it records what 1.2.4 did, and 1.2.10's line records the move to "public sector".
- B: reword it to "public sector".

**Q9. "federally credible" twice in the app (W-03)?**
- A (Recommended): keep it; it names the NIST and NSA origin of the SARD corpus and the Juliet suite.
- B: "government-built" instead.

## Framework Maps facts

**Q10. NSA's zero trust sheet of 8 October 2026 on operational technology (F-01)?** Adding it changes a count in the NSA entry
("eight cybersecurity information sheets").
- A (Recommended): add it to the NSA entry's documents in the next content release (nine sheets), and to the Zero Trust guide's OT
  material at its next edition.
- B: wait for the 15 November SP 1353 recheck release and add it then.
- C: leave it out.

**Q11. The AI Defense Matrix's publisher (F-02)?**
- A (Recommended): "Lenny Zeltser and Sounil Yu", as the matrix's site credits them.
- B: keep "aidefensematrix.com".

**Q12. NIST's note that the AI RMF 1.0 is being revised (F-03)?**
- A (Recommended): add a status line to the entry's note in the next content release, with a recheck date.
- B: leave it until NIST publishes a draft.

**Q13. Two small catalogue gaps: SP 800-53A Release 5.2.0 (F-06) and SP 1800-35's subtitle on the Zero Trust guide (F-07)?**
- A (Recommended): add both at the next release of each.
- B: leave them.

**Q14. The DoD Zero Trust Overlays entry links an official address that answers 404 (L-03)?**
- A (Recommended): link the archived copy the Zero Trust guide already uses, labeled as an archived copy; the entry stays unverified.
- B: keep the dead official address, which the note explains.

## Layout and chrome

**Q15. Reference links under 44px on the map and the Zero Trust guide (V-07)?**
- A (Recommended): leave citation links inside running text (WCAG 2.5.8 exempts inline links), and give the map's layer tags and the
  guide's source-table host links a 44px row.
- B: give every reference link a 44px target.
- C: leave all of them.

**Q16. One bar width (V-08, R-36)?** The bar is 1088px on most pages, 1072px on the map and 912px on the Zero Trust guide at 1440.
- A (Recommended): one bar width everywhere (the hub's), with the guide's own column staying 960px under it; this needs another
  CSS-only refresh of the guide.
- B: keep the guide's bar lined up with its column.

**Q17. Secondary button colours (V-09)?**
- A (Recommended): secondary buttons take their section's accent outline everywhere, as the map's do, and the app's rule under the
  bar takes the playbook purple.
- B: leave them.

**Q18. The 404 page (W-09, V-11)?**
- A (Recommended): keep it without preview tags (noindex, served at any address), and carry the page background to the bottom of
  short screens.
- B: add preview tags as well.

**Q19. Twitter title, description and image tags (W-09)?** Most pages carry og tags and a twitter card only; X falls back to the og
tags. The Zero Trust guide lacks only its twitter description.
- A (Recommended): leave them.
- B: add the three twitter tags to every page that has a card.

**Q20. The sitemap's lastmod (X-01)?**
- A (Recommended): `build_hub.py` writes each page's own date: the content's builtOn for the map, privacy and support, the
  playbook's release date for its landing and app, the site date for the rest.
- B: keep one date for every page.

**Q21. `handoffs/` in the private sweep (S-02)?** 17,674 lines in 646 local files hit the list; the folder is gitignored and never
published.
- A (Recommended): keep it out of the sweep's scope, as the battery does, and keep the file and line list local.
- B: scrub the hits from `handoffs/`.
- C: move `handoffs/` outside the repository folder.

## From the fresh-eyes reviewer

**Q22. A start button above the fold (R-01, R-02, R-21)?** On a phone the hub's first screen has no tappable start, and the playbook
landing's "Open the app" does not say what the app holds.
- A (Recommended): add one "Find your trailhead" link (the map's own button label) under the hub's three section lines, and leave the
  tagline as Ken set it.
- B: lead the hub with a plain sentence and move the tagline below it.
- C: leave both pages.

**Q23. One vocabulary for the playbook and the map's sections (R-05, R-19, R-20, R-29)?** The hub counts 87 actions, the app 35
tabs, a diagram "35 plays across 7 themes" (listing six phrases), and the app calls its groups sections; the app's name and tagline
vary. On the map the framework cards sit under Sources.
- A (Recommended): tabs, sections and actions everywhere (the diagram's subtitle names all seven sections); keep the map's section
  names.
- B: adopt "plays" for the tabs.
- C: leave it.

**Q24. The Zero Trust guide's "Private sector" track also serves state and local government (R-14)?**
- A (Recommended): keep the name, which is on three PDFs, and keep the track table's line naming state and local governments.
- B: rename it at the next edition (for example "Non-federal").

**Q25. The Zero Trust guide's heading with the compass zero (R-15)?**
- A (Recommended): keep it; it is the guide's mark, and the page title and accessible name read "Zero Trust".
- B: plain text for the heading.

**Q26. Vendor balance and the threat persona (R-37 to R-40)?**
- A (Recommended): label the vendor-built diagrams "an example on one vendor's stack", add a one-line disclosure beside the
  Anthropic sources, and link the executive summary's statistics; keep APT_UNICORN.
- B: also move the persona below the thesis.
- C: leave it.

**Q27. Footers and version schemes (R-30, R-35)?**
- A (Recommended): keep each section's own version (they release separately), and give the app's footer the privacy, support and
  source links the others carry.
- B: one shared footer and one release number for the site.

**Q28. A contact route without a GitHub account (R-50)?**
- A (Recommended): leave GitHub issues as the one route; the site collects no data.
- B: add an email address.

**Q29. Privacy and support mention an iOS app that no page links (R-51)?**
- A (Recommended): leave them; they serve the App Store listing, and the hub can link the app once it ships.
- B: say on both pages that the app is not yet released.

**Q30. The rest of the reviewer's list?** Each item below with its recommended handling; mark any you want changed.
- R-03 the hub's About reads as legal text: keep (Recommended), it is the licensing record.
- R-04 three glossaries: cross-link the map's and the playbook's glossaries in each other's intro (Recommended).
- R-06 and R-07 the map's long phone page and the matrix's 1.5 columns: keep for now (Recommended), and take them to a design pass.
- R-09 Conflict and Unverified badges: keep (Recommended); the map's status key explains each status.
- R-10 the back-to-top button covers line ends in an opened card: add bottom room to opened cards (Recommended).
- R-11 two About links in the map's two bars: keep (Recommended), one is the site's, one the map's.
- R-12 and R-13 the guides index card and the playbook's study guide: keep (Recommended).
- R-16 a section menu on the Zero Trust guide: keep the contents and the back-to-top links (Recommended).
- R-17 security abbreviations on the Zero Trust guide: spell out PDP, PEP, PE, PA, MFA and DLP at first use at the next edition
  (Recommended).
- R-18 mark the NotebookLM link as external and needing a Google account: the card already says so; keep (Recommended).
- R-22 and R-23 the app's reading paths and its "How to read it" paragraph: make the paths links in Q1's patch (Recommended).
- R-26 app search across sections: keep (Recommended), the app searches itself.
- R-27 spell out the Action Plan's coverage codes: link them to the glossary in Q1's patch (Recommended).
- R-28 cross-links between the map and the playbook's frameworks: keep (Recommended), different scopes.
- R-31 DoW and DoD: keep (Recommended), the map's naming note and glossary explain it.
- R-32 the remaining style mix (zero trust and Zero Trust, Federal civilian, ranges): keep (Recommended), the map follows NIST's
  lower case and the guide its own title case.
- R-33 two brand marks: keep (Recommended), the plain pages carry the app's mark.
- R-34 no bar on privacy, support, the executive summary and diagrams: keep (Recommended), by design.
- R-48 and R-49 the diagram list's bare titles and the GitHub-hosted documents: keep (Recommended).
- Emoji in the app and diagrams: keep (Recommended).
