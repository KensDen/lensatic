# Lensatic QC Ledger, 24 October 2026 (v1.0)

Branch `qc/lensatic-20261024` from main `7b48d83` (clean, up to date with origin). Run from 18:59 EDT, Saturday 24 October 2026.
Scope: the hub, the three sections (Framework Maps, Field Guides with the Zero Trust guide, the playbook section with its landing,
app, 16 diagrams and the executive summary), privacy, support, 404 and the sitemap. The iOS app only through `tools/battery.sh`;
no Xcode run (the battery ran with `LENSATIC_NO_XCODE=1`, so its Xcode stage printed SKIP).

The questions for Ken are in `20261024_Lensatic_QC_Decisions_v1.0.md`. The captures are in `20261024_Lensatic_QC_Captures/`.

## 1. Summary

| | Count |
|---|---|
| Findings (lenses 1, 2, 3 and 5, notes included) | 68 |
| Findings from the fresh-eyes reviewer (lens 4), 9 of them also found by lenses 1 to 3 | 51 |
| Findings in all, counting each overlap once | 110 |
| Fixed AUTO on the branch (A-01 to A-10), closing 6 findings in full and 2 in part (V-01, W-09) | 10 fixes |
| Questions for Ken | 30 |
| Battery | green before and after (105 PASS; the playbook battery ALL GREEN with 1 non-fatal warning) |
| Private sweep | tracked files: 603 hits on 380 lines in 26 files, every file at or below its 18 October baseline; nothing new |

How each lens ran:

- **Facts:** every Framework Maps entry and listed document (58 items), every Zero Trust source row (46) and 228 of the 243 playbook
  Resource Index entries went to six reviewer agents, each with a masked table and the rule to check against the publisher's own
  page. Sixteen items whose fields hold private-list terms were withheld from the agents (1 map entry, 15 Resource Index entries);
  they were checked by link status only. Agent findings that change a fact were rechecked in Chrome before they were listed as
  confirmed; two agent findings were refuted that way (section 3.1, notes).
- **Links:** 545 unique external addresses and 87 internal references across the 28 published pages, by GET. 447 answered 200 to
  curl; the other 98 were loaded in headless Chrome, and the rest in the in-app browser. No challenge was solved.
- **Visuals:** 9 main pages and 17 sub-pages (16 diagrams, the executive summary) at 375x667, 390x844 and 1440x900, light and dark:
  page overflow, clipped text, one-word last lines, tap targets under 44px, inputs under 16px, console and CSP errors, failed
  requests. Contact sheets were read by eye, plus interactive states (a framework opened, two app tabs, the app's search).
- **Locked wording:** scripted counts and contexts on every published page and the licence files.
- **Fresh eyes:** one reviewer agent saw only the captures and the card, and nothing else.
- **Battery and sweep:** `bash tools/battery.sh` with the private list, and a sweep of the whole tree (tracked and untracked text
  files, docs/ included, data URIs removed as the battery does), file and line only. There were no "name 2" sync duplicates to delete.

## 2. AUTO fixes on the branch

| Fix | What changed | Files | Closes | Evidence |
|---|---|---|---|---|
| A-01 | Line breaks in the shared stylesheet, scoped to `.lx-page`: headings and the eyebrow balance, running text uses `text-wrap: pretty` | `hub/lensatic.css`, its published and inlined copies (`apply_chrome.py`, `build_hub.py`, `build_web.py`) | V-01 for the hub, guides index, 404 and playbook landing | one-word last lines, light, 375/390/1440: hub 2/1/0 to 0/0/0, guides 1/1/0 to 0, playbook landing 4/7/1 to 0, 404 0 |
| A-02 | The bar's section links are at least 44px wide (About measured 38px on every bar page) | `hub/lensatic.css` | V-03 | small targets on the hub, guides and 404 1 to 0; the app 44 to 43 |
| A-03 | The hub eyebrow keeps each section name whole and breaks only after a dot (non-breaking spaces inside the names, then balance) | `tools/build_hub.py` | V-02 | `after/fixes/hub_eyebrow_375_*`, `hub_eyebrow_390_*`: the last name no longer sits alone |
| A-04 | Line breaks on Framework Maps: headings, table heads and short labels balance, running text uses `pretty` | `web/src/styles.css` | V-01 (map, partly) | 133/128/99 to 38/36/30; what is left sits in the matrix's narrow scroll cells (V-01 note) |
| A-05 | Framework Maps entry cards put their status badges on a row under the title at every width (the phone layout); beside the title, a long recheck badge squeezed five titles to one word per line from 1024px up and overlapped them | `web/src/styles.css` | V-04, R-08 | `after/fixes/maps_card_1440_before.jpg` and `_after.jpg`; the overlap probe finds 0 squeezed titles at 1024 and 1440 |
| A-06 | Line breaks on privacy and support | `web/src/page.css` | V-01 for both pages | privacy 2/4/3 to 0, support 1/0/0 to 0 |
| A-07 | Zero Trust guide, CSS-only refresh: v1.1 of the v2.8.3 build with the field system snapshot v1.4 (A-01, A-02) and two line-break rules of the page's own (headings and table cells balance, running text `pretty`). Same edition, text, PDFs, README, LICENSE and record. New tools in the private pipeline, none edited: `tools/20261024_ZT_Build_v2.8.3_v1.1.py`, `tools/20261024_ZT_Finalize_v2.8.3_v1.1.sh`, `tools/20261024_ZT_Gate_v2.8.3_v1.1.py`, `tools/assets/20261024_ZT_Lensatic_Field_System_v1.4.css`; output `export_v2_8_3_v1_1/` | `guides/zero-trust/index.html`, `docs/guides/zero-trust/index.html` | V-01 (guide, partly), V-03 on the guide | the v1.1 gate: ALL PASS (page text identical to v2.8.3's, only the stylesheet differs, every other file byte for byte, shared chrome current, sweep counts equal); orphans 138/127/101 to 21/21/5 |
| A-08 | The playbook landing's short format links (PDF, web) are at least 44px wide | `playbook/index.html`, `docs/playbook/index.html` | V-05 | small targets 4 to 0 |
| A-09 | Framework Maps content 1.2.16: five links in verification notes go to their pages' new addresses (10 U.S.C. 111, 31 U.S.C. 1102 and the FAQ on uscode.house.gov, which moved off `view.xhtml` and `faq.xhtml`; the House Armed Services Committee's NDAA history page, now `/ndaa/`); one note spells canceled the US way. Version, builtOn (24 October, so the privacy policy's effective date moves with it), one changelog line, README, schema id, iOS text fixture | `content/stack.json`, `content/schema/stack.schema.json`, `README.md`, `web/lensatic.html`, `docs/maps/index.html`, `docs/privacy.html`, `docs/support.html`, `ios/LensaticTests/Fixtures/web_texts.json` | L-01, W-08 | each new address answers 200 with the right page title |
| A-10 | Privacy and support carry link-preview tags (title, description, type, address, a text card). No image: the hub card's alt text names the third section in the capitalised form these two pages never use, which the battery's forbidden-word check caught in a first try | `tools/build_web.py`, `web/src/page.html` | W-09 (privacy, support) | 5 preview tags on each page; battery green |

`hub/DESIGN.md` records the 44px width and the line-break rules. Nothing in the app, the diagrams, the documents or any wording Ken chose was changed.

## 3. Findings by lens

Status: **AUTO** fixed on the branch; **Q** a question in the Decisions file; **Note** recorded, no change proposed.

### 3.1 Facts and links (lens 1)

| ID | Page | Finding | Evidence | Status |
|---|---|---|---|---|
| L-01 | Framework Maps (notes) | Five dead links: three US Code section and FAQ addresses (the site moved to `/us/usc/<release point>/t<title>/s<section>/` and `faq.html`) and the House Armed Services Committee's NDAA history page (moved to `/ndaa/`) | 404 in curl, Chrome and the in-app browser; new addresses 200 | AUTO A-09 |
| L-02 | playbook app, study guide | DCSA's counterintelligence and insider threat page is gone; the agency's page is now `https://www.dcsa.mil/Counterintelligence/` | 404 with DCSA's not-found page; the new link is on dcsa.mil's home page | Q1 |
| L-03 | Framework Maps | The DoD Zero Trust Overlays entry links an official address that answers 404. The entry is already marked unverified and its note lists the dead addresses; the Zero Trust guide links an archived copy instead | 404 | Q14 |
| L-04 | Framework Maps (notes, solutions) | All six Department of the Navy CIO links reset the connection from this network, in curl, headless Chrome and the in-app browser. The notes already record a rejection page on 30 September | connection reset | Note: recheck from another network |
| L-05 | playbook app, study guide | One link answers automated browsers with a bot challenge. Its address holds a private-list term, so it is named here by page only | 403 challenge | Note: needs one manual click |
| L-06 | playbook app, study guide | The Australian Cyber Security Centre's guidance moved to `/publication/opportunities-for-ai-in-cyber-defence` (the old address redirects) | redirect, 200 | Q1 |
| L-07 | Framework Maps, playbook app | Bot protection only: two senate.gov pages, two EUR-Lex pages, Sublime Security (429). Each loads with the right title in a real browser | browser load | Note: no action |

Link totals: 545 unique external addresses, every one answering 200 or explained above (one deliberate citation of a dead file name sits
inside a Zero Trust for OT note, as written). All 14 YouTube videos are available. The 87 internal references resolve; six hits in the
React bundle's code are not links.

| ID | Page | Finding | Evidence | Status |
|---|---|---|---|---|
| F-01 | Framework Maps, Zero Trust guide | NSA released a new zero trust information sheet on 8 October 2026, "Hardening Department of War (DoW) Critical Operational Technology (OT) Environments with Zero Trust (ZT) Principles". The NSA entry counts eight sheets (2021 to 2024) and four implementation guidelines | PDF on media.defense.gov 200; NSA press release dated Oct. 8, 2026 (rechecked) | Q10 |
| F-02 | Framework Maps | The AI Defense Matrix's publisher reads "aidefensematrix.com"; the site credits Lenny Zeltser and Sounil Yu | rechecked | Q11 |
| F-03 | Framework Maps | NIST's AI RMF page says the 1.0 text "is being revised as part of the White House AI Action Plan"; the entry does not say so (the playbook's Resource Index does) | rechecked | Q12 |
| F-04 | Framework Maps | NIST IR 8596's CSRC page now notes that NIST is moving its wording to "super intelligence" under the 29 September 2026 executive order; the title and the preliminary draft status are unchanged | rechecked | Note: watch |
| F-05 | Framework Maps | NIST SP 1353 is still the initial public draft; comments closed 15 October 2026. The 15 November recheck stands | agent | Note (not chased, as asked) |
| F-06 | Framework Maps | SP 800-53A Revision 5 is current, but Release 5.2.0 (27 August 2025) added procedures; the map notes that release for SP 800-53 and not for 800-53A | agent | Q13 |
| F-07 | Zero Trust guide | The SP 1800-35 row leaves out the subtitle "High-Level Document" | agent | Q13 |
| F-08 | Framework Maps, playbook | Reviewers could not confirm "Version 1.0" for the CoSAI Zero Trust for AI Systems paper: the repository's text copy prints no version and the PDF's text did not extract. The map's primary record of 30 September says the PDF cover prints it | agents | Note: the record stands |
| F-09 | Framework Maps, Zero Trust guide | No DoD Zero Trust Strategy 2.0 yet: the DoW CIO library lists the same seven Zero Trust documents the site cites | library page read in Chrome | Note: no change |
| F-10 | playbook diagram (identity-first enforcement), app | The diagram calls a research proof "the Gödel mandate (NIST, Jun 2026)", with no title or link. The source is NIST's June 2026 news item on Vassilev's peer-reviewed proof, which the Resource Index carries; it mandates nothing | read in the diagram and the app source | Q3 |

Notes on refuted or low-confidence agent findings (not counted): an agent said DTM 25-003 is listed as current, but the map records its
passed expiry in four places; an agent said SP 800-171 Revision 2 shows no withdrawal, but its note records the withdrawal and why
Revision 2 stays the entry edition; a CMMC memo title and a memo date (10 or 13 July) rest on law-firm alerts only.

The playbook's Resource Index (agent findings; **R** marks the ones rechecked in Chrome):

| ID | Entry | Finding | Confidence | Status |
|---|---|---|---|---|
| P-01 | Cotool: BlueBench | The leaderboard now covers 24 models, not 16, and the best incident-response report score is 83.5%, not 77.8% | high, R | Q2 |
| P-02 | CASP: Boko Haram and frontier AI | 27 interviews, not 57 | high, R | Q2 |
| P-03 | CSA: State of AI Cybersecurity 2026 | Darktrace's survey, republished on the CSA blog; its headline is the 73% figure, not the agentic workforce line | high, R | Q2 |
| P-04 | Google DeepMind: Three Layers | The title is "Three Layers of Agent Security" | high, R | Q2 |
| P-05 | Anthropic: auto mode default | A 22 October 2026 update widens it to new sessions in most Claude apps on Pro, Max and Team | high, R | Q2 |
| P-06 | OWASP AISVS 1.0 | The latest stable version is 1.01 | high, R | Q2 |
| P-07 | MIT AI Incident Tracker | Labeled "validated Jun 2026"; the page says a systematic validation study has not been completed | medium, R | Q2 |
| P-08 | Small Wars Journal | The title is "Ubiquitous Technical Surveillance and the Renewal of Irregular Warfare" | medium, R | Q2 |
| P-09 | Anthropic: DoD and CDAO partnership | A petition for rehearing was filed 13 October 2026 (secondary sources) | medium | Q2 |
| P-10 | ASD ACSC: AI in cyber defence | Joint guidance from four of the Five Eyes; no US agency is named | medium | Q2 |
| P-11 | Microsoft: humanist superintelligence | The link is the author's personal site; Microsoft's own copy is on microsoft.ai | medium | Q2 |
| P-12 | OpenAI: prompt injection | The title is "Understanding prompt injections: a frontier security challenge" | medium | Q2 |
| P-13 | Microsoft: AI investigation playbook | The full title is longer (from trade press) | medium | Q2 |
| P-14 | Microsoft: MAI-Cyber-1-Flash | The page is dated 13 August 2026; trade press supports a late July first announcement | low | Q2 |
| P-15 | Google: securing the AI frontier | The $430K+ figure is across Google's existing reward programs, not the new AI program | medium | Q2 |
| P-16 | Aurora | The paper's title is "From Sands to Mansions ..."; Aurora is the system's name | medium | Q2 |
| P-17 | Singer et al.: multi-host attacks | The title is now "Incalmo: An Autonomous LLM-assisted System for Red Teaming Multi-Host Networks" | medium | Q2 |
| P-18 | Georgia Tech and Intel: CPU-centric agentic AI | Version 3 (16 April 2026) is retitled with five authors | high | Q2 |
| P-19 | Chuvakin: 2003 SOC, part 1 | Parts 2 and 3 are out, so the answers are no longer "promised" | high | Q2 |
| P-20 | Maisel: Cedar hooks | A regular Day 1 slot, not a lightning talk | low | Q2 |
| P-21 | NIST NCCoE: agent identity concept paper | The comment summary came out 29 September 2026 and the hub was renamed | high | Q2 |
| P-22 | Google: SAIF | "SAIF 2.0" is not the site's headline; it is in Google's 6 October 2025 blog | medium | Q2 |
| P-23 | DCSA: adjudications | DCSA now calls the function Trust Decisions (from search snippets; dcsa.mil blocked the agent) | medium | Q2 |
| P-24 | CoSAI: Zero Trust for AI Systems | Version 1.0 unconfirmed (see F-08) | medium | Q2 |
| P-25 | Lensatic Field Guides: Zero Trust | The entry dates the guide September 2026; the guide reads public edition v2.8.3, 18 October 2026 | medium | Q2 |

Reviewers could not verify 27 more Resource Index details, mostly on sites that refused them (dcsa.mil, nsa.gov, openai.com,
rand.org, Turing, cyber.mil) or PDFs whose text did not extract. None is listed as a finding.

### 3.2 Visuals (lens 2)

No page in any view had page overflow, clipped text, a console or CSP error or a failed request.

| ID | Page | Finding | Evidence | Status |
|---|---|---|---|---|
| V-01 | every page | No page set `text-wrap`, so one-word last lines were common: before, light, 375/390/1440: hub 2/1/0, guides 1/1/0, playbook landing 4/7/1, privacy 2/4/3, support 1/0/0, map 133/128/99, Zero Trust guide 138/127/101, app 1/1/0, executive summary 27/15/5, six diagrams 1 to 3 | metrics | AUTO A-01, A-04, A-06, A-07; the map keeps 30 to 38 in the matrix's narrow scroll cells, 8 to 10 lines long, where Chrome does not balance and `pretty` cannot move a word; the guide keeps 5 to 21 in table cells; app, executive summary and diagrams in Q1 |
| V-02 | hub | The eyebrow's last section name sat alone on the second line at 375 and 390 | `before/390x844_light/hub_first-screen.jpg` | AUTO A-03 |
| V-03 | every bar page | The bar's About link was 38px wide | metrics | AUTO A-02 |
| V-04 | Framework Maps | From 1024px up, five entry cards (DoD Zero Trust Strategy, RMF and ATO, IR 8596, SP 1353, CMMC) squeezed the title to one word per line and the recheck badge overlapped it | `after/fixes/maps_card_1440_before.jpg` | AUTO A-05 |
| V-05 | playbook landing | The PDF and web format links were 31 to 32px wide | metrics | AUTO A-08 |
| V-06 | playbook app | 35 navigation chips are 31px tall and seven buttons 25px; the search input is 13.5px, so iOS zooms on focus; its placeholder is cut at 390 | metrics, `before/390x844_light/app_first-screen.jpg` | Q1 |
| V-07 | Framework Maps, Zero Trust guide | Reference links under 44px: on the map about 100 citation links (18px tall) and 19 layer tags (19px); on the guide 47 source-table host links (17px) and about 50 cell and list links (19 to 43px) | metrics | Q15 |
| V-08 | bar, every section | At 1440 the bar is 1088px wide on the hub, guides, playbook landing, app and 404, 1072px on the map and 912px on the Zero Trust guide (its v2.8 rule lines the bar up with its 960px column), so it shifts between sections | alignment probe | Q16 |
| V-09 | Zero Trust guide, map, playbook landing, app | Secondary buttons differ: the map's take the section accent, the guide's Quick Reference buttons the link blue, the playbook landing's are neutral; the app's rule under the bar is blue though the section accent is purple | contact sheets | Q17 |
| V-10 | playbook diagrams | At 390 the Zero Trust for AI agents matrix's "months to hours" figure overlaps its text and the MAESTRO band's "06" touches its label; diagram text is 10 to 11px monospace on phones; diagrams stay dark in the light theme | `before/390x844_light/dg-*` | Q1 |
| V-11 | 404 | On short screens the page background shows a band below the footer | `before/390x844_light/404_full.jpg` | Q18 |
| V-12 | executive summary | One-word last lines (27/15/5) | metrics | Q1 |

### 3.3 Locked wording (lens 3)

Passed: the tagline is exact on the hub, the map and the hub's preview description (the only places it appears); "Agentic AI" is
capitalized in all visible text; every credit line that appears is exact; US spelling holds apart from W-08 (the other UK forms are
proper names or quoted titles, which the playbook battery allowlists).

| ID | Page | Finding | Status |
|---|---|---|---|
| W-02 | Framework Maps (What's new) | The 1.2.4 changelog line says Lensatic "now calls itself a guide to the federal cybersecurity frameworks". It records 11 October; "public sector" replaced it in 1.2.10 | Q8 |
| W-03 | playbook app | "federally credible" twice (NIST SARD and the Juliet suite); every other "federal" names a federal thing | Q9 |
| W-04 | playbook app, diagrams, executive summary, field card, Framework Maps | "Human in Command" appears as "human-in-command" about 30 times in the app and in four diagrams, as "human in command" in the field card, "humans in command" in the executive summary, and "Humans in Command" twice on the map | Q4 |
| W-05 | hub, guides index, playbook landing | The credit line does not appear on the hub or the guides index, and appears twice on the playbook landing ("How it was built" and the footer) | Q5 |
| W-06 | Zero Trust guide (LICENSE, README) | Both say "read and used for personal study", without "reviewed" (the private pipeline's licence asset carries it) | Q6 |
| W-07 | every published page | Rights lines say "All rights reserved" and link the notice; the map's About licensing paragraph does not carry the personal-study wording | Q7 |
| W-08 | Framework Maps (notes) | "cancelled" in a verification note | AUTO A-09 |
| W-09 | privacy, support, 404, diagrams, every page | Privacy and support had no preview tags; the 404 has none (noindex, served at any address); the 16 diagrams have none; most pages carry no twitter title, description or image (X falls back to the og tags), and the guide lacks only its twitter description | AUTO A-10 for privacy and support; Q18, Q1, Q19 |

### 3.4 Fresh eyes (lens 4)

The reviewer's ten-second verdict: a one-person reference site for US public sector cyber staff, with maps of the federal frameworks,
an eight-week Zero Trust study plan and an AI-era red, blue and purple teaming playbook; it would start on Framework Maps with "Find
your trailhead", then go to the Zero Trust guide for its track.

| ID | Page | Finding, in short | Status |
|---|---|---|---|
| R-01 | hub | No button or card on the first phone screen; the section names appear three times before anything is tappable | Q22 |
| R-02 | hub | The tagline is a metaphor; the plain description only appears on the map | Q22 |
| R-03 | hub | The About block reads as a long legal paragraph | Q30 |
| R-04 | hub, map, app | Three glossaries (92 terms, 89 terms, the app's AI Fluency) with no cross-links | Q30 |
| R-05 | map | The framework cards sit in section 07, called Sources, after about 13,000px on a phone | Q23 |
| R-06 | map | The function cards repeat the matrix cells, making the phone page very long | Q30 |
| R-07 | map | The matrix shows about 1.5 columns on a phone, with two small arrows to move | Q30 |
| R-08 | map | Long badges squeeze card titles and overlap them at 1440 | AUTO A-05 (same as V-04) |
| R-09 | map | The Conflict and Unverified badges read as unfinished and do not say what the conflict is | Q30 |
| R-10 | map | The back-to-top button covers the end of lines inside an opened card | Q30 |
| R-11 | map | Two About links in the two stacked bars | Q30 |
| R-12 | guides index | With one guide, the Open button sits below four PDF links and a notebook note | Q30 |
| R-13 | guides index, playbook landing | The playbook's study guide is not listed under Field Guides | Q30 |
| R-14 | Zero Trust guide | State and local readers are sent to the "Private sector" track | Q24 |
| R-15 | Zero Trust guide | The heading's compass zero reads like a typo | Q25 |
| R-16 | Zero Trust guide | No sticky section menu on a very long page | Q30 |
| R-17 | Zero Trust guide | PDP, PEP, PE, PA, MFA and DLP are not spelled out where the index spells out PDF | Q30 |
| R-18 | guides index | The NotebookLM link is not marked as external and needing a Google account | Q30 |
| R-19 | playbook section | "Play" is not used consistently: 87 actions, 35 tabs, "35 plays across 7 themes" in a diagram, sections in the app | Q23 |
| R-20 | playbook diagram (at a glance) | The subtitle promises 7 themes and lists six phrases | Q23 |
| R-21 | playbook landing | "Open the app" does not say what the app is; no direct path to the plays or the Action Plan | Q22 |
| R-22 | app overview | The reading paths sit about 4,000px down and are not links | Q30 |
| R-23 | app overview | "How to read it" packs all 35 tab names into one paragraph | Q30 |
| R-24 | app | The headers, tab strip, counter, label row and search fill half the first screen; tab labels are clipped | Q1 |
| R-25 | app | The search placeholder is cut | Q1 (same as V-06) |
| R-26 | app search | Searches stay inside the playbook, and some titles squeeze into a narrow column | Q30 |
| R-27 | app Action Plan | Coverage codes (LLM06, ASI02, cATO, NHI) are not spelled out | Q30 |
| R-28 | app, crosswalk diagram, map | The playbook's frameworks are not on the map and the map's AI column is not in the crosswalk; neither links the other | Q30 |
| R-29 | app, executive summary | The name and tagline vary | Q23 |
| R-30 | every page | Four version schemes and four dates | Q27 |
| R-31 | map, guide, app | "Department of War (DoW)" in prose and "DoD" in titles; the reason is only in the guide's naming note | Q30 |
| R-32 | every page | Mixed styles: Zero Trust or zero trust, Human or Humans in Command, Federal civilian or Federal Civilian, "3 - 6 weeks" and "Weeks 1 to 4" | Q4 (Human in Command), Q30 (the rest) |
| R-33 | hub, map, privacy, support | Two forms of the brand mark | Q30 |
| R-34 | privacy, support, executive summary, diagrams | No site bar on these pages; diagrams have only a small link at the bottom | Q30 |
| R-35 | every footer | Several footer variants; the credit twice on the playbook landing; the app's footer has no privacy or support link | Q5 (credit), Q27 (the rest) |
| R-36 | hub, map, guide, support, app | Header and content edges shift between pages at 1440 | Q16 (same as V-08) |
| R-37 | playbook section | Leans on single vendors (Microsoft architecture, Anthropic proof points) on a site built with Claude | Q26 |
| R-38 | app, executive summary, diagram | The APT_UNICORN persona and art confuse the message and undercut credibility | Q26 |
| R-39 | executive summary | "One Capability, Three Faces" against the diagram's "Same Horsepower, Two Outcomes" | Q26 |
| R-40 | executive summary | Statistics carry no visible links | Q26 |
| R-41 | identity-enforcement diagram | The "Gödel mandate (NIST, Jun 2026)" has no title or link | Q3 (same as F-10) |
| R-42 | MAESTRO diagram | "06" touches its label; the stack runs 07 to 05 | Q1 (same as V-10; the cross-cutting band is the design) |
| R-43 | Zero Trust for AI agents diagram | The figure overlaps its text; tiers told apart only by border colour | Q1 (same as V-10) |
| R-44 | crosswalk diagram | Stacked phone cards lose their field labels; "243 controls; 247 in v1.1" is unclear | Q1 |
| R-45 | jailbreak spectrum diagram | No scoring rules; a partner name is unexplained | Q1 |
| R-46 | AI workforce diagram | One card maps to a technique, the others to tactics | Q1 |
| R-47 | every diagram | Dark in the light theme; 10 to 11px text on phones | Q1 (same as V-10) |
| R-48 | playbook landing | The diagram list is bare titles, and one gap is tight | Q30 |
| R-49 | playbook landing | Tiny one-word links; two documents open on GitHub, often blocked on government networks | AUTO A-08 (targets); Q30 (hosting) |
| R-50 | support, privacy | The only contact route is a public GitHub issue | Q28 |
| R-51 | privacy, support | Both mention an iOS app no other page links; the privacy policy opens on Framework Maps alone | Q29 |

The reviewer also noted the 404's below-footer band and the "Open the Lensatic hub" wording (V-11, Q18) and emoji in the app and
diagrams (Q30); those are folded into the rows above.

### 3.5 Battery and sweep (lens 5)

| ID | Finding | Status |
|---|---|---|
| B-01 | Battery green before (on main `7b48d83`) and after the AUTO fixes, with the private list: 105 PASS, WEB, iOS (static), LISTING and UMBRELLA green, the umbrella sweep "finds nothing in the files the umbrella wrote (46 terms, counts only)", the playbook battery ALL GREEN. The Xcode stage printed SKIP (no Xcode run) | Note |
| B-02 | The playbook battery's one non-fatal warning: a Resource Index entry out of alphabetical order in Vendor and Platform Security, Cisco and Splunk | Q1 |
| S-01 | Tracked files: 603 hits on 380 lines in 26 files, each file at or below its count in the 18 October baseline (`assets-archive/20261018_Lensatic_PrivateList_Hits_v1.0.md`, compared by file and count, never printed). No new file, no new line | Note: all known expected |
| S-02 | `handoffs/` (local working history, gitignored, never tracked): 43,986 hits on 17,674 lines in 646 files, outside the baseline's scope. The file and line list is kept locally in `handoffs/20261024_Lensatic_QC_Sweep_Handoffs_FileLines_v1.0.txt`, not in this ledger | Q21 |
| S-03 | No "name 2" sync duplicates anywhere in the tree | Note |
| X-01 | Sitemap: every page's lastmod is the site date, 18 October. The map, the app, privacy and support changed on 20 October, and the map, privacy and support change again on this branch | Q20 |

## 4. Captures

`20261024_Lensatic_QC_Captures/before/<viewport>_<theme>/` holds what the fresh-eyes reviewer saw: the first screen of every page in
all six views, full pages at 390x844 light and 1440x900 light (desktop full pages at half width to keep the folder small; very long
pages stop at 14,000px), and the diagram and executive summary pages at 390x844 light. `before/390x844_light_states/` has a
framework opened on the map (dark, as Chrome opened it), two app tabs and the app's search. `after/` has the first screens and full
pages after the AUTO fixes at 390x844 light and 1440x900 light, first screens at 390x844 dark, and `after/fixes/` the before and
after crops for A-03 and A-05.

## 5. Limits

The iOS app was checked only through the battery's static stage. PDF text was not read. Sixteen fact items with private-list terms
were not given to reviewers. Facts marked "agent" were not rechecked by hand; Q2 asks for a recheck before they ship.
