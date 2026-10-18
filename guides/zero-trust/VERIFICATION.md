# Zero Trust Field Guide: Verification Record

Public edition v1.0, 27 September 2026.

This record lists what was checked in the study guide and Quick Reference, against which primary source, and what changed as a result. Claude verified the core facts with Ken Connell on 26 September 2026. On 27 September 2026 Claude Code downloaded the primary PDFs, closed the four open checks (V1 to V4), re-checked the guide against the sources, and corrected what they contradicted.

Page references give the PDF page first (page 1 is the first page of the file), then the printed page in brackets where it differs: "p. 29 [16]".

## Verified

| Claim in the guide | Result | Source |
|---|---|---|
| 152 activities; 91 Target | Confirmed | NSA ZIG Primer (Jan 2026), p. 3 [ii] and p. 4 [iii]: "152 ZT Activities"; "Target-level Capabilities (42) and Target-level Activities (91)" |
| 61 Advanced | Confirmed by arithmetic (152 minus 91), and by counting the current activity list (V2) | Same; DoD Capabilities and Activities list |
| Target per pillar: 13, 14, 12, 17, 10, 13, 12 | Confirmed by counting activity IDs; recounted 27 Sep 2026 | DoD Capabilities and Activities list (`ZT-CapabilitiesActivities.pdf`, hyphenated), pp. 10 to 26 |
| Target spans 42 of 45 capabilities | CORRECTED from "43 of 45." 3.5, 6.4 and 7.6 have no Target activities | Target activity list; matches the NSA Primer's 42 |
| ZIG counts: Discovery 14, Phase One 36, Phase Two 41 | Confirmed. Recounted 27 Sep 2026 from each guideline's contents: 91 IDs in all, none shared | NSA Primer; NSA press release 30 Jan 2026 |
| Primer and Discovery released 14 Jan 2026; Phase One and Two released 30 Jan 2026 | CORRECTED 27 Sep 2026 from "8 Jan 2026" for the Primer and Discovery. NSA's release is dated Jan. 14, 2026 and says "Releasing today, the Primer and Discovery Phase". The 08 in the media.defense.gov path is not the release date; the PDFs were created 13 Jan 2026. 30 Jan 2026 is confirmed | NSA press releases of 14 Jan and 30 Jan 2026 |
| Phases Three and Four: Advanced, not yet published | Confirmed. Primer: "may be developed at a later date" (p. 4 [iii] and p. 12 [4]). Still unpublished on 27 September 2026 | NSA Primer |
| Discovery includes 1.1.1, 4.1.1, 5.1.1; excludes 1.3.1 | Confirmed | NSA ZIG Discovery Phase (the 14 IDs are listed there) |
| The earlier activity list at the unhyphenated address | CORRECTED 27 Sep 2026. This row previously read "still serves the 2022 list: 127 activities, 68 Target, 59 Advanced." The address now returns 404 on dodcio.defense.gov and dowcio.war.gov, and archived captures show 404 since 26 Apr 2025. The only file ever archived there (cover dated 6 January 2023) lists 152 activities, 91 of them Target, the same counts as the current list. The guide's warning and field-note example were corrected to match | Wayback Machine capture of 7 Mar 2025 of `ZTCapabilitiesActivities.pdf` |
| 3.5.1 and 3.5.2 (cATO Parts 1 and 2) are Advanced | Confirmed in the current list ("Advanced Level ZT") and in the archived earlier list | DoD Capabilities and Activities list |
| Library now at dowcio.war.gov | Confirmed. dodcio.war.gov fails its TLS certificate (hostname mismatch). dodcio.defense.gov copies of the Strategy, Reference Architecture, Capabilities and Activities, OT activities and Library page still resolve; `ZeroTrustOverlays.pdf` and `ZTCapabilitiesActivities.pdf` return 404 on both hosts | dowcio.war.gov/Library |
| DoD ZT Overlays: June 2024, v1.1, maps SP 800-53 Rev. 5 to activities | Confirmed from the archived official copy: the cover reads June 2024 (Version 1.1), and p. 25 [14] says the SP 800-53 Rev. 5 controls "are mapped to the activities". No longer posted: both official addresses return 404, and the Library dropped the link between July and August 2025 | Archived `ZeroTrustOverlays.pdf` (Wayback Machine, 27 May 2025) |
| CISA ZTMM 2.0: April 2023; 5 pillars, 3 cross-cutting | Confirmed | CISA v2 PDF, dated 2023-04 |
| CISA ZTMM v1.0: public comment 7 Sep to 1 Oct 2021 (drafted June 2021) | Confirmed. Reworded to "draft released for public comment" | cisa.gov ZTMM page |
| EO 14347 restoring the Department of War name | Confirmed. Signed 5 Sep 2025; Federal Register 10 Sep 2025 | Federal Register 2025-17508 |

## Open checks, closed 27 September 2026

### V1. Is 1.3.1 in NSA ZIG Phase One?

**Yes.** Phase One's contents list all 36 Phase One activities, and 1.3.1 is the first of them (p. 5 [iv]). The activity section and its Table 3 begin on p. 29 [16]. The Primer's roster of Target activities (Figure D-1, p. 59 [D-1]) places "1.3.1 Organizational MFA & IdP" in the Phase I column. 1.3.1 is not on the Discovery or Phase Two rosters, and both of those guidelines refer to it as "Activity 1.3.1 (Phase One)".

On the link to 1.1.1: NSA's first consideration for 1.3.1 is to consider completing Discovery activity 1.1.1, Inventory User, "prior to this activity, to obtain User/Person Entity (PE) inventory list" (p. 29 [16]), and its implementation tasks draw on 1.1.1's Master User Inventory (p. 31 [18]). This is NSA guidance, not a DoW-defined dependency: Table 3 lists no predecessor for 1.3.1, and 1.1.1's only DoW-defined successor is 1.2.2 (ZIG Discovery p. 24 [16]).

The guide's Fluency 2 table now reads: "Phase One. NSA advises completing Discovery activity 1.1.1 (inventory users) first, because you cannot enforce MFA against identities you have not enumerated."

### V2. Advanced activities per pillar

**Confirmed.** The current Capabilities and Activities list carries all 152 activities, each with its level; only the Target activities were updated in this revision (p. 1). Counting activity IDs on pp. 10 to 26 gives:

| Pillar | Capabilities | Target | Advanced |
|---|---|---|---|
| 1 User | 9 | 13 | 15 |
| 2 Device | 7 | 14 | 10 |
| 3 Application & Workload | 5 | 12 | 6 |
| 4 Data | 7 | 17 | 14 |
| 5 Network & Environment | 4 | 10 | 3 |
| 6 Automation & Orchestration | 7 | 13 | 7 |
| 7 Visibility & Analytics | 6 | 12 | 6 |
| **Total** | **45** | **91** | **61** |

Cross-checks:

- The NSA Primer names exactly the 91 Target activity IDs, with no Advanced IDs; its Figure D-1 (p. 59 [D-1]) is headed "Zero Trust Target Level Activities".
- The [Execution Roadmap v1.1](https://dowcio.war.gov/Portals/0/Documents/Library/ZT-ExecutionRoadmap-v1.1.pdf) (22 November 2024) states "91 ZT Activities within TARGET + 61 ZT Activities within ADVANCED" (p. 8). Its Gantt chart, which has names and no IDs, draws one Application & Workload activity (3.2.3) in the Advanced color. The current list and the NSA guidelines both treat 3.2.3 as Target, and the current list governs.

The Advanced column stays in both the study guide and the Quick Reference.

### V3. Cover dates

- **Capabilities and Activities (current list).** The cover image on p. 1 reads "DOD Zero Trust Execution Roadmap (COAs 1-3), v1.1, 22 January 2025". It carries a clearance stamp: "Cleared for Open Publication, Mar 18, 2025". The NSA Primer cites the list "as of 18 Mar 25" (p. 21 [13]), and the Discovery, Phase One and Phase Two guidelines cite it as dated 22 January 2025. The guide keeps "as of 18 March 2025".
- **DoD Zero Trust Strategy.** The cover and every page footer read "October 21, 2022"; the clearance stamp is Nov 07, 2022. The guide now says October 2022 (it said November 2022).
- **Reference Architecture v2.0.** The cover reads "Version 2.0, July 2022"; the clearance stamp is Sep 12, 2022, which is the "Sep22" in the file name. The guide now says July 2022 (it said 2022).

### V4. Link check

Checked 27 September 2026. Every link in the Sources list below returns HTTP 200 and serves the expected document, with two exceptions. The official addresses of the DoD ZT Overlays and of the earlier unhyphenated activity list return 404 on both dodcio.defense.gov and dowcio.war.gov. No other official copy was found, so those two rows link archived copies from the Wayback Machine, labeled as archived. dowcio.war.gov is used wherever it and dodcio.defense.gov both work.

NSA's seven "Advancing Zero Trust Maturity Throughout the ... Pillar" guides were found on media.defense.gov. Each title was confirmed on the PDF's first page, and the release dates come from NSA's press releases.

Note for anyone re-running the check: media.defense.gov and dodcio.defense.gov answer 403 to requests that do not send browser headers. The same URLs return 200 in a browser.

## Other corrections from the source re-check

Checked 27 September 2026 against the downloaded primary sources. Each item below was contradicted by its source and corrected in the page and both PDFs.

| Where | Was | Now | Source |
|---|---|---|---|
| Part 1, NIST SP 800-207 | Sections 2 and 3, "About 15 pages" | "About 19 pages" | SP 800-207 contents: Section 2 starts on printed p. 4, Section 4 on printed p. 23 |
| Part 1, NIST SP 800-207 | "Section 6 migration" | "Section 7 migration" | SP 800-207 contents: Section 7 is "Migrating to a Zero Trust Architecture" (printed p. 36); Section 6 covers existing federal guidance |
| Part 1, DoD Zero Trust Strategy | "the appendix on the DoD ZT Portfolio Management Office" | "including the material on the DoD ZT Portfolio Management Office" | Strategy contents, p. 8 [vii]: Appendices A to F, none on the PfMO |
| Part 1, Reference Architecture; Part 2, Week 6 | "Executive summary ... the pillar chapters for User, Device and Network" | "Section 1 (purpose and strategic goals), the principles, and the User, Device and Network pillar descriptions in Section 2" | RA v2.0 contents, pp. 3 to 5 [iii to v]: no executive summary; pillars in 2.3, principles in 2.4 |
| Part 2, Week 7 | "mapping data flows (5.1.1)" | "defining granular access rules (5.1.1)" | 5.1.1 is "Define Granular Control Access Rules & Policies Pt1": Capabilities and Activities list p. 21; ZIG Discovery Table 30, p. 74 [66] |
| Part 3, Fluency 2 | 1.1.1's "applications operating their own user account management" | "applications using their own user account management" | Capabilities and Activities list p. 10; ZIG Discovery p. 24 [16] |
| Part 1, Capabilities and Activities; Part 5 field-note example | The unhyphenated file "still serves the 2022 list (127 activities, 68 Target)"; "the 2022 count of 127" | "An older file at the similar, unhyphenated address served an earlier edition (6 January 2023); that link is now dead. Check the cover date before you trust a copy."; "an old count" | See "The earlier activity list at the unhyphenated address" above |
| Part 6, Where the sources live; Quick Reference, Sources | The DoW CIO Library holds the Overlays | The Overlays are no longer posted there, and the Sources section links an archived copy | V4 |
| Dates (study guide and Quick Reference); Sources | Primer and Discovery, 8 Jan 2026 | 14 Jan 2026 | NSA press release, 14 Jan 2026, now listed in Sources |
| How to use, Naming; Quick Reference, Naming | "The Department's current name is Department of War (DoW), per Executive Order 14347" | "The Department's current title is Department of War (DoW), authorized by Executive Order 14347"; the Quick Reference line to match | EO 14347, Sec. 2(b): the Department "may be referred to as the Department of War"; NSA Primer p. 3 [ii], footnote 1: "an authorized secondary title" |
| Part 1, Capabilities and Activities; Sources | "The current Target activity list"; "(current Target list)" | "The current activity list"; "(current activity list)" | V2: the file lists all 152 activities with their levels |

The re-check also confirmed these, among others: all 45 capability names and numbers against the capability table (pp. 2 to 9); the Discovery set and its 14 IDs; the four strategic goals, seven pillars and the FY27 Target deadline in the Strategy; CISA ZTMM 2.0's five pillars, three cross-cutting capabilities and four stages; and the release dates of NSA's seven pillar guides.

## v2.0 additions

Public edition v2.0, 30 September 2026.

v2.0 adds a shared core and tracks for federal civilian and private-sector readers. On 29 September 2026 Claude, working with Ken Connell, read the primary sources behind the claims in the Verified table below and left six checks open. The same day Claude Code downloaded the new primary sources, closed the six open checks (V5 to V10), re-checked the new tracks and all three Quick References against the sources, re-checked the DoW material against v1.0 and against the sources as they stood that day, and corrected what the sources contradicted. Every v1.0 row and correction above carries forward unchanged. The v1.0 sources are in the Sources list below, now grouped by track and unchanged except for two rows changed on 30 September 2026 (below): the CISA ZTMM landing-page row now links CISA's current page for the model, and SP 800-207A carries its full title.

The date-stamped checks were re-run on 30 September 2026 for this build, with the same results: OMB's memoranda (no memo after M-26-19; M-22-09 not rescinded), executive orders (none amends EO 14028), NSA's implementation guidelines (no Phase Three or Four), the DoW CIO Library (the 18 March 2025 activity list is still current; no Overlays), the CMMC rule (Level 2 still on SP 800-171 Rev. 2), and the CISA and CoSAI files (unchanged). Every link returned HTTP 200 that day, including the two added that day. One of them, the NotebookLM notebook in Part 7 and in the Sources list, returns 200 only after redirecting a signed-out reader to Google's sign-in page, so the check confirms that the address resolves, not that the notebook opens without a Google account.

Also on 30 September 2026:

- The author revised 18 lines of the guide and Quick References, added a notebook bullet to Part 7, and added two see-also rows to Sources, for the Playbook and the notebook. Each revised claim was checked against its source and holds, for example the boards and auditors CSF 2.0 names (p. 2 [i]), the inputs of SP 800-207's tenet 4 (p. 15 [6]) and the planning considerations in CISA's microsegmentation guide (p. 18 [14]). The notebook bullet's note that opening it needs a Google account matches what a signed-out reader gets; the notebook's contents were not checked, because that needs a Google sign-in.
- The SP 800-207A Sources row now carries the full title its CSRC record gives, "A Zero Trust Architecture Model for Access Control in Cloud-Native Applications in Multi-Cloud Environments"; v1.0 used a shortened form. The PDF's own title page reads "Multi-Location Environments"; the row follows the CSRC record it links.
- The CISA ZTMM landing-page row now links CISA's current publication page for the model (<https://www.cisa.gov/resources-tools/resources/zero-trust-maturity-model>), which carries no Archived Content banner, gives "Revision Date April 11, 2023", and is the page CISA's Zero Trust topic page links. The archived page's note was dropped. The PDF that page serves matches the v2.0 PDF in the Sources list except in its revision table on p. 2, which dates version 2.0 "April 2023*" ("*Updated for release date") where the older file says "March 2022".

Page references follow the v1.0 convention: PDF page first, printed page in brackets where it differs. Federal Register pages are given as FR page numbers.

### Verified (primary source read on 29 Sep 2026)

| Claim in v2.0 | Result | Source |
|---|---|---|
| M-22-09: title; dated 26 Jan 2022; addressed to heads of executive departments and agencies; goals due by the end of FY2024; organized by the CISA model's pillars | Confirmed | M-22-09 PDF, whitehouse.gov |
| M-22-09's five pillar goals, as summarized in the guide | Confirmed against the memo's executive summary | Same |
| M-22-09 defines "agency" by 44 U.S.C. 3502 (footnote 1) | Confirmed | Same |
| OMB M-26-14, "Ensuring Effective and Efficient Agency Logging and Network Visibility to Defend Against Evolving Cyber Threats," 22 May 2026; rescinds M-21-31; aligns logging requirements with the ZTMM | Confirmed | M-26-14 PDF, whitehouse.gov; OMB memoranda page |
| EO 14306 (June 2025) does not amend EO 14028 and does not mention Zero Trust | Confirmed | Federal Register 2025-10804 |
| CISA, "The Journey to Zero Trust: Microsegmentation in Zero Trust, Part One: Introduction and Planning," 29 Jul 2025; four-phase approach; "any organization can apply the information provided"; a technical part is planned | Confirmed | CISA PDF (the CISA landing page returned 403 to the fetcher) |
| Federal Zero Trust Data Security Guide: CISO Council and Federal CDO Council; Oct 2024, revised May 2025 (added Chapter 4); focuses on the ZTMM Data pillar; cites M-22-09 | Confirmed | Guide PDF, resources.data.gov |
| NIST SP 1800-35, "Implementing a Zero Trust Architecture: High-Level Document," final 10 Jun 2025, NCCoE; 19 example implementations; 24 collaborators | Confirmed | CSRC record |
| NIST CSF 2.0, CSWP 29, 26 Feb 2024; for any organization regardless of size, sector or maturity | Confirmed | CSRC record |

The checks below sharpen two of these rows. The five pillar goals, as the guide summarizes them, are M-22-09's Section III goals (p. 4); the executive summary states the same vision in other words. M-26-14's tie to the maturity model is a requirement that the logging reference architecture CISA was to publish "will align with the Zero Trust Maturity Model" (p. 5 [Appendix A, p. 1]); CISA published that architecture in August 2026.

### Open checks, closed 29 September 2026

#### V5. Is M-22-09 still in force?

**Yes.** No rescission or supersession was found. OMB's memoranda page on whitehouse.gov lists M-25-10 to M-25-36 and M-26-01 to M-26-19; earlier memos, M-22-09 among them, are listed on OMB's archived memoranda page, and the whitehouse.gov copy of M-22-09 still returns HTTP 200. Every 2025 and 2026 memo (56 documents, M-25-01 to M-26-19 plus one fact sheet) was downloaded and searched for "22-09", "Zero Trust", "rescind" and "supersede". None rescinds or supersedes M-22-09.

- M-26-14 (22 May 2026) rescinds M-21-31 and nothing else: "Effective immediately, OMB Memorandum M-21-31 is rescinded" (p. 2).
- M-26-18 (31 August 2026) tells agencies that, to manage digital identity, they should follow existing OMB policy, including M-22-09 (p. 2, footnote 5).
- M-25-04 (15 January 2025), the latest OMB FISMA guidance memo, calls M-22-09 the Federal Zero Trust Strategy (p. 1). OMB has issued no FY 2026 FISMA guidance memo; the FY 2026 and FY 2027 CIO FISMA Metrics (v1.1, 1 September 2026) say their system interconnection metrics reflect requirements under M-22-09 (p. 18 [15]).

M-22-09 requires its goals "by the end of Fiscal Year (FY) 2024" (p. 4), which ended 30 September 2024 (31 U.S.C. 1102). The guide's "Watch" note stands as written.

#### V6. Did EO 14144 or EO 14306 change EO 14028 Section 3?

**No.** Checked against the Federal Register texts. EO 14144 (16 January 2025) cites EO 14028 six times but amends only EO 13694 (Sec. 9, 90 FR 6767). EO 14306 (6 June 2025) amends only EO 14144 and EO 13694; it does not amend EO 14028 and does not use the words "zero trust". It did replace EO 14144's Section 7, dropping a call to revise OMB Circular A-130 to cover "migration to zero trust architectures" (EO 14144, 90 FR 6765; EO 14306 Sec. 2(f), 90 FR 24725). That was a Zero Trust item in EO 14144, not in EO 14028, and it is one of the "other parts of the cybersecurity agenda" the guide says later orders changed.

The Federal Register's record for EO 14028 (document 2021-10460) has no "Amended by" or "Revoked by" entry, and a search of presidential documents for "14028" found no order that amends or revokes it, through EO 14431 (published 23 September 2026) and the orders posted on whitehouse.gov through 29 September 2026. Section 3, "Modernizing Federal Government Cybersecurity" (86 FR 26635 to 26637, three pages), still says the Federal Government must "advance toward Zero Trust Architecture" (86 FR 26635), and Section 3(b)(ii) gave each agency head 60 days to "develop a plan to implement Zero Trust Architecture" (86 FR 26636).

#### V7. Does M-22-09 reach the Department?

**Yes.** M-22-09 is addressed "MEMORANDUM FOR THE HEADS OF EXECUTIVE DEPARTMENTS AND AGENCIES" and gives "agency" the meaning in 44 U.S.C. 3502 (p. 1, footnote 1). Section 3502(1) covers any executive department, military department or other establishment in the executive branch; its only exclusions are GAO, the Federal Election Commission, the governments of the District of Columbia and the territories, and government-owned contractor-operated facilities. 5 U.S.C. 101 lists "The Department of Defense" among the executive departments. A full-text search of the 29-page memo found no exclusion or carve-out of any agency; the Department appears only as a source (its Zero Trust Reference Architecture, p. 2 and p. 27).

A carve-out does exist for national security systems, but it covers systems, not departments, and it is not in M-22-09. FISMA sets it (44 U.S.C. 3553(d) and (e)), and EO 14028 Section 9 kept the order's requirements off national security systems until a national security memorandum set equivalent ones (86 FR 26645). NSM-8 (19 January 2022) did so, including a Zero Trust Architecture plan for those systems. So the Department is an M-22-09 addressee, and its national security systems follow NSM-8. The v1.0 page said M-22-09 "does not bind DoW components"; v2.0 no longer says that, and the guide's two v2.0 statements ("addressed to every executive department, the Department included"; "specific goals for every executive department and agency") are accurate as written.

#### V8. CISA ZTMM audience and stage summaries

**Confirmed.** ZTMM 2.0 says the model "is specifically tailored for federal agencies as required by EO 14028" and that "all organizations should review and consider adoption of the approaches outlined in this document" (p. 4). The same page frames it within CISA's support for Federal Civilian Executive Branch agencies, and the version 1.0 draft describes it as designed to support FCEB agencies (p. 2 [ii]). That supports the guide's "CISA wrote it for federal civilian agencies" and "private-sector teams can borrow its stages as a target".

The Federal Civilian Quick Reference's one-line stage summaries follow the guiding criteria for each stage (p. 9), with one wording difference: p. 9 does not say "continuously optimized" for Optimal (it says "continuous monitoring"); that phrase reflects the model's progress "toward optimization" (p. 6). Traditional: manually configured lifecycles, static security policies, siloed pillars. Initial: starting automation and initial cross-pillar solutions. Advanced: automated controls with cross-pillar coordination and centralized visibility. Optimal: fully automated, just-in-time lifecycles, dynamic policies, and cross-pillar interoperability with continuous monitoring.

Also confirmed: five pillars and three cross-cutting capabilities (p. 6); four stages (pp. 8 to 10); a description at every stage for every function (Tables 2 to 7, pp. 13 to 30); April 2023 and 32 pages; the Fluency 2 row against the Identity pillar (p. 10); the version 1.0 draft's public comment period of 7 September to 1 October 2021 (CISA's response to comments, p. 1); and M-22-09's statement that its goals "are organized using the zero trust maturity model developed by CISA" (M-22-09 p. 4). On 29 September CISA's landing page for the model carried an "Archived Content" banner, and the PDF was still posted and unchanged. On 30 September the Sources row moved to CISA's current, unarchived page for the model (below).

#### V9. Link check for the new sources

Checked 29 September 2026 with curl sending browser headers, and in headless Chrome for the cisa.gov, cio.gov and resources.data.gov links. Every link in the Sources list below returns HTTP 200. One link checked for v2.0 did not, and was replaced. The Data Security Guide's page on cio.gov is gone: its address on `www.cio.gov` fails the certificate check (the certificate covers `cio.gov`, not `www.cio.gov`), and the same path on `cio.gov` returns 404. The Sources row and the Federal Civilian Quick Reference now point to the official PDF on resources.data.gov, which returns 200. cisa.gov returned 200 both to curl and in Chrome.

#### V10. CoSAI, Zero Trust for AI Systems

**Confirmed.** Checked 29 September 2026 on the PDF the guide links. The cover gives the title "Zero Trust for AI Systems", Version 1.0 and the date 4 September 2026 (p. 1). The paper names itself an OASIS Open Project paper of the Coalition for Secure AI (CoSAI), from Workstream 2: Preparing Defenders for a Changing Threat Landscape, approved by the CoSAI Project Governing Board on 4 September 2026 (p. 3 [2]). The GitHub page the guide links returned HTTP 200, and its raw file is the same PDF that was checked. CoSAI announced the paper on its blog on 16 September 2026 with the same link, and its Resources page lists a byte-identical copy.

The guide's three uses of the paper hold:

- **Part 7 summary.** The paper puts the model inside its own "AI Threat Boundary" and says authorization decisions must never be delegated to it (p. 10 [9]). It treats each tool call as a separate authorization, checked against the scope the user delegated (pp. 8 to 10 [7 to 9]), and gives three implementation patterns, at initial, intermediate and advanced maturity (p. 8 [7]).
- **Fluency 3 row.** The DoD capabilities exist and fit: 1.2 Conditional User Access, 1.7 Least Privileged Access and 3.4 Resource Authorization & Integration. The paper's own Table 2 maps its matching controls to the same three (p. 14, an unnumbered table page). Logging by the enforcement point rather than the agent is the paper's advanced tier (p. 8 [7]). Identity and Applications and Workloads are CISA ZTMM 2.0 pillars.
- **Dates row.** Version 1.0, September 2026, matches the cover.

The paper's copyright notice (Copyright OASIS Open 2026) permits copies of the paper, and derivative works that comment on or explain it, provided that the notice and the whole Copyright Notice section are included on them (p. 23 [22]). The guide copies and quotes none of the paper's text: it summarizes the paper in its own words, and cites and links it in the Sources list below.

### Other corrections from the source re-check

Checked 29 September 2026. Each item below was contradicted by its source and corrected in the page and PDFs.

| Where | Was | Now | Source |
|---|---|---|---|
| Federal Civilian Quick Reference, M-22-09 goals, Networks | "break perimeters into isolated environments" | "start breaking perimeters into isolated environments" | M-22-09 p. 4: agencies "begin executing a plan to break down their perimeters" |
| Federal Civilian Quick Reference, M-22-09 goals, Data | "Protections built on thorough data categorization" | "A shared path to protections built on thorough data categorization" | M-22-09 p. 4: agencies "are on a clear, shared path to deploy protections" |
| Federal Civilian and Private Sector Quick References, Terms, Microsegmentation | "so a breach cannot move laterally" | "so a breach cannot easily move laterally" | CISA Microsegmentation Part One: it limits lateral movement (p. 5 [1]); M-22-09's aim, as CISA quotes it, is that an adversary "cannot easily move laterally" (p. 7 [3]) |
| Federal Civilian Quick Reference, Sources | "Federal Zero Trust Data Security Guide (cio.gov)" | "(resources.data.gov)" | V9 |
| Sources, Federal Zero Trust Data Security Guide | cio.gov page, with the PDF | The PDF on resources.data.gov | V9 |
| Sources, NIST SP 800-171 | One row, linking Rev. 3 without naming it | A Rev. 3 row (May 2024), and a Rev. 2 row noting that CMMC Level 2 uses it | CMMC rule, 32 CFR 170.14(c)(3): Level 2 requirements "are identical to the requirements in NIST SP 800-171 R2" (89 FR 83226); "Revision 3 is not currently applicable to this rule" (89 FR 83107). eCFR, current to 25 September 2026, shows no amendment |

The re-check also confirmed these, among others:

- **Federal civilian.** EO 14028's title, date and Section 3; M-22-09's title, date, addressees and five goals (p. 4, and the pillar sections from p. 5); M-26-14's title, date and rescission of M-21-31; CISA's Microsegmentation Part One (29 July 2025, CISA's Journey to Zero Trust series, four phases on p. 17 [13], "any organization can apply the information provided" on p. 5 [1], a planned technical guide on p. 22 [18], not yet published); the Federal Zero Trust Data Security Guide (published October 2024, revised May 2025 to add Chapter 4, by the Federal CDO and CISO Councils, focused on the Data pillar, pp. 1 to 5).
- **Private sector.** NIST CSF 2.0 (CSWP 29, 26 February 2024; for any organization "regardless of its size, sector, or maturity", p. 2 [i]; six Functions, p. 8 [3]; Protect includes Identity Management, Authentication, and Access Control, PR.AA); NIST SP 1800-35 (final 10 June 2025; 19 example implementations with 24 collaborators, p. 3 [iii]); the seven tenets of SP 800-207 (pp. 15 to 16 [6 to 7]); the CMMC program rule (32 CFR Part 170, Federal Register 15 October 2024, issued by the Office of the DoD CIO).
- **DoW, as of 29 September 2026.** No v1.0 correction regressed. The counts were recounted and hold: 152 activities, 91 Target and 61 Advanced; 13, 14, 12, 17, 10, 13 and 12 Target by pillar; 42 of 45 capabilities with a Target activity; ZIG Discovery 14, Phase One 36 and Phase Two 41, exactly the 91 Target IDs. NSA has not published ZIG Phase Three or Four; its 28 May 2026 release launching a ZIG webpage says the page "will be updated with future Phases". The DoW CIO Library still lists the 18 March 2025 Capabilities and Activities list as the current one (the same file as in v1.0), and still lists no Overlays. EO 14347 Sec. 2(b): the Department "may be referred to as the Department of War" (90 FR 43893).

## v2.2 additions

Public edition v2.2, 30 September 2026.

v2.2 adds "Talks to watch" to Part 7 of the guide: twelve recorded talks, one for the core, three for each track and two on AI agents. It also adds a Talks group to the Sources list below. The author chose the talks and wrote their descriptions. On 30 September 2026 Claude Code checked each talk before it went in:

- The link loads publicly and the talk plays with no sign-in.
  - WarU Media: Kaltura's public API (partner 2203981) showed each recording ready to play with no access restriction, and a headless browser with no saved sign-in played each one from its page.
  - YouTube: each watch page reported the video public, listed and playable, and a headless browser played each one.
- The title, speaker, venue and date match the talk's own page. For the 4th Annual DoW Zero Trust Virtual Learning Exchange (7 to 9 April 2026), they match the Exchange's agenda and the recording's own name on WarU Media instead; the speakers page confirms roles where it lists the speaker.
- Each length is the talk's own running time, rounded to the nearest whole minute.
- Each WarU Media link is the one the Exchange's video library page gives for that talk.

Every talk passed these checks. Where the guide's wording of a title did not match its source, the wording was corrected (below). After the first check the author revised four descriptions: one venue name, the CSA webcast's date (October 2023), and the ATARC and Resnick descriptions. Each revised claim holds against the sources recorded below.

### Talks (checked 30 Sep 2026)

| Talk | Link | Checked | What was matched |
|---|---|---|---|
| John Kindervag: "Containment, ZT and the Security Graph: The Path to Anti-Fragility" | <https://media.waru.edu/playlist/dedicated/62925431/1_78sgkifi/1_u4dhitnh> | 30 Sep 2026 | Public, plays with no sign-in (Kaltura entry 1_u4dhitnh). Title, speaker and date from the agenda: Day 2, 8 Apr 2026, "Containment, ZT and the Security Graph: The Path to Anti-Fragility" (a dash on the agenda), John Kindervag, Chief Evangelist, Illumio; the speakers page credits him with creating the Zero Trust Model at Forrester Research. Link from the Exchange's videos page. 3092 s. |
| Dr. Shelly Kelly, NSA: "Zero Trust Implementation Guidelines (ZIGs)" | <https://media.waru.edu/playlist/dedicated/62925431/1_78sgkifi/1_bzak7d09> | 30 Sep 2026 | Public, plays with no sign-in (Kaltura entry 1_bzak7d09). Agenda: Day 2, 8 Apr 2026, "Zero Trust Implementation Guidelines (ZIGS)", Dr. Shelly Kelly, Chief Operations Officer for Critical Government Systems, National Security Agency; the guide writes "(ZIGs)", as it does elsewhere. Same link on the videos page. 1357 s. |
| Randy Resnick, DoW Zero Trust Portfolio Management Office: centralized Zero Trust planning | <https://www.youtube.com/watch?v=T4G4FHaS_6U> | 30 Sep 2026 | Public, plays with no sign-in. Its page: DefenseScoop channel, published 12 Dec 2025; the description names Resnick as Senior Advisor for the Zero Trust Portfolio Management Office at the Department of War and describes the office coordinating zero trust across 40 components with quarterly implementation plans. Recorded at DefenseTalks 2025 on 9 Dec 2025 (the DefenseTalks agenda; DefenseScoop, 9 Dec 2025). 316 s. |
| David Voelker, Department of the Navy: "Zero Trust for Operational Technology" | <https://media.waru.edu/playlist/dedicated/62925431/1_78sgkifi/1_sr95lihm> | 30 Sep 2026 | Public, plays with no sign-in (Kaltura entry 1_sr95lihm). Agenda: Day 2, 8 Apr 2026, "Zero Trust for Operational Technology", David Voelker, NAVWAR SYSCOM Standardization Officer, U.S. Department of the Navy. Same link on the videos page. 1459 s. |
| CISA and DoD architects: "Understanding the CISA Maturity Model and DoD's Zero Trust Strategy" | <https://www.youtube.com/watch?v=wpAjYp0yiSs> | 30 Sep 2026 | Public, plays with no sign-in. Its page: same title, Cloud Security Alliance channel, uploaded 13 Mar 2026; "a panel of CISA and DoD experts". First shown on CSA's BrightTALK channel on 13 Oct 2023 (63 min), presented by Sean Connelly and John Simms (CISA), Randy Resnick (DoD) and Jerry Chapman (CSA Zero Trust co-chair). 3837 s. |
| Sean Connelly: "Zero Trust as Global Policy: How Governments Are Adopting Zero Trust" | <https://media.waru.edu/playlist/dedicated/62925431/1_og8bhh9i/1_l01174ak> | 30 Sep 2026 | Public, plays with no sign-in (Kaltura entry 1_l01174ak). Agenda: Day 3 (International ZT schedule), 9 Apr 2026, "Zero Trust as Global Policy: How Governments Are Adopting Zero Trust" (a dash on the agenda), Sean Connelly, Executive Director, Global Zero Trust Strategy and Policy, Zscaler. Link from the videos page. 1222 s. |
| ATARC panel: "Mastering Zero Trust: Leveraging Network Visibility in Zero Trust Frameworks" | <https://www.youtube.com/watch?v=yoSKqpQhio8> | 30 Sep 2026 | Public, plays with no sign-in. Its page: ATARC Channel, published 5 Dec 2024; the description dates the webinar 5 Dec 2024. ATARC's event page (Internet Archive copy, 13 Oct 2025) gives the same title and date and lists seven speakers: five from federal agencies (Coast Guard, GSA, State, CFPB, Navy) and two from industry. 3617 s. |
| Andy Ellis: "Leading to Zero Trust: Principles for a Smooth Journey" | <https://media.waru.edu/playlist/dedicated/62925431/1_khqyas09/1_ywwwu11x> | 30 Sep 2026 | Public, plays with no sign-in (Kaltura entry 1_ywwwu11x). Agenda: Day 1, 7 Apr 2026, "Leading to Zero Trust: Principles for a Smooth Journey", Andy Ellis, Legendary CISO, Duha. Link from the videos page. 1404 s. |
| Jennifer Minella: "The Zero Trust Maturity Myth" | <https://media.waru.edu/playlist/dedicated/62925431/1_og8bhh9i/1_tacy9nke> | 30 Sep 2026 | Public, plays with no sign-in (Kaltura entry 1_tacy9nke; a different recording from Connelly's, which runs within a second of it). Agenda: Day 3, 9 Apr 2026, "The Zero Trust Maturity Myth", Jennifer Minella, Advisory CISO, Carolina Advanced Digital, Inc. Link from the videos page. 1222 s. |
| Rich Mogull: "When AI Breaks Security: Why Zero Trust Is No Longer Optional" | <https://media.waru.edu/playlist/dedicated/62925431/1_og8bhh9i/1_8ebjco3g> | 30 Sep 2026 | Public, plays with no sign-in (Kaltura entry 1_8ebjco3g). The recording's own name and the agenda (Day 3, 9 Apr 2026) both read "When AI Breaks Security: Why Zero Trust Is No Longer Optional", Rich Mogull, Chief Analyst, Cloud Security Alliance; the videos page shortens it to "Why ZT is No Longer Optional". Link from the videos page. 1977 s. |
| Niki Aimable Niyikiza: "Capability-Based Authorization for AI Agents: Warrants That Survive Prompt Injection" | <https://youtu.be/bw928cFShK4> | 30 Sep 2026 | Public, plays with no sign-in. Its page: unprompted channel, published 25 Mar 2026; the description gives the full title and the speaker. The conference's Day 2 agenda (unpromptedcon.org) lists the talk on 4 Mar 2026; the conference ran 3 and 4 Mar 2026 in San Francisco. 1722 s. |
| Matt Maisel: "Hooking Coding Agents with the Cedar Policy Language" | <https://youtu.be/m6pzrqFJ6hE> | 30 Sep 2026 | Public, plays with no sign-in. Its page: same title, unprompted channel, published 25 Mar 2026. The conference's Day 1 agenda lists the talk on 3 Mar 2026. 1034 s. |

### Corrections before publishing

| Where | Was | Now | Source |
|---|---|---|---|
| Talks to watch, John Kindervag: title | Containment, ZT and the Security Graph | Containment, ZT and the Security Graph: The Path to Anti-Fragility | Exchange agenda, video library and the recording's own name, which separate the two parts with a dash |
| Talks to watch, Rich Mogull: title | Why ZT is No Longer Optional | Why Zero Trust Is No Longer Optional | Exchange agenda and the recording's own name; the video library shortens it |

Not checked:

- what each talk says beyond its title and its own page's description, since no transcript was read;
- the companion notebook's contents, which need a Google sign-in.

## Sources

### Core

| Source | Publisher, date | Link |
|---|---|---|
| Zero Trust Architecture, NIST SP 800-207 | NIST, Aug 2020 | <https://csrc.nist.gov/pubs/sp/800/207/final> |
| A Zero Trust Architecture Model for Access Control in Cloud-Native Applications in Multi-Cloud Environments, NIST SP 800-207A | NIST, Sep 2023 | <https://csrc.nist.gov/pubs/sp/800/207/a/final> |
| Zero Trust Maturity Model v2.0 | CISA, Apr 2023 | <https://www.cisa.gov/sites/default/files/2023-04/zero_trust_maturity_model_v2_508.pdf> |
| Zero Trust Maturity Model (landing page) | CISA | <https://www.cisa.gov/resources-tools/resources/zero-trust-maturity-model> |
| Zero Trust in the Age of AI (see-also; the author's companion NotebookLM notebook; opening it needs a Google account) | Ken Connell | <https://notebooklm.link.google/jaUFZqYbnxIe> |
| Agentic SecOps Tradecraft Playbook (see-also; the author's own companion project) | Ken Connell | <https://kensden.github.io/agentic-secops-playbook/> |
| Zero Trust for AI Systems, v1.0 | Coalition for Secure AI (CoSAI, an OASIS Open Project), Sep 2026 | <https://github.com/cosai-oasis/ws2-defenders/blob/main/zero-trust/Zero-Trust-for-AI-Systems.pdf> |

### DoW

| Source | Publisher, date | Link |
|---|---|---|
| EO 14347, Restoring the United States Department of War | White House, Sep 2025 | <https://www.federalregister.gov/documents/2025/09/10/2025-17508/restoring-the-united-states-department-of-war> |
| DoD Zero Trust Strategy | DoD CIO, Oct 2022 | <https://dowcio.war.gov/Portals/0/Documents/Library/DoD-ZTStrategy.pdf> |
| DoD Zero Trust Reference Architecture v2.0 | DISA and NSA for DoD CIO, Jul 2022 | <https://dowcio.war.gov/Portals/0/Documents/Library/(U)ZT_RA_v2.0(U)_Sep22.pdf> |
| DoD Zero Trust Capabilities and Activities (current activity list) | DoD CIO ZT PfMO, 18 Mar 2025 | <https://dowcio.war.gov/Portals/0/Documents/Library/ZT-CapabilitiesActivities.pdf> |
| Earlier activity list at the unhyphenated address (for the warning only). Archived copy (Wayback Machine, 7 Mar 2025); the original address returns 404. | DoD CIO, Jan 2023 | <https://web.archive.org/web/20250307065129/https://dodcio.defense.gov/Portals/0/Documents/Library/ZTCapabilitiesActivities.pdf> |
| DoD Zero Trust Overlays v1.1. Archived copy (Wayback Machine, 27 May 2025); no longer on the DoW CIO site, and the official addresses return 404. | DoD CIO, Jun 2024 | <https://web.archive.org/web/20250527093843/https://dodcio.defense.gov/Portals/0/Documents/Library/ZeroTrustOverlays.pdf> |
| Zero Trust for Operational Technology Activities and Outcomes | DoW CIO | <https://dowcio.war.gov/Portals/0/Documents/Library/ZT-OperationalTechnologyActivitiesOutcomes_v2.pdf> |
| DoW CIO Library (index) | DoW CIO | <https://dowcio.war.gov/Library/> |
| ZIG Primer | NSA, 14 Jan 2026 | <https://media.defense.gov/2026/Jan/08/2003852320/-1/-1/0/CTR_ZERO_TRUST_IMPLEMENTATION_GUIDELINE_PRIMER.PDF> |
| ZIG Discovery Phase | NSA, 14 Jan 2026 | <https://media.defense.gov/2026/Jan/08/2003852321/-1/-1/0/CTR_ZIG_DISCOVERY_PHASE.PDF> |
| ZIG Phase One | NSA, 30 Jan 2026 | <https://media.defense.gov/2026/Jan/30/2003868308/-1/-1/0/CTR_ZIG_PHASE_ONE.PDF> |
| ZIG Phase Two | NSA, 30 Jan 2026 | <https://media.defense.gov/2026/Jan/30/2003868302/-1/-1/0/CTR_ZIG_PHASE_TWO.PDF> |
| NSA press release, Primer and Discovery Phase | NSA, 14 Jan 2026 | <https://www.nsa.gov/Press-Room/Press-Releases-Statements/Press-Release-View/Article/4378980/nsa-releases-first-in-series-of-zero-trust-implementation-guidelines/> |
| NSA press release, Phase One and Two | NSA, 30 Jan 2026 | <https://www.nsa.gov/Press-Room/Press-Releases-Statements/Press-Release-View/Article/4393480/nsa-releases-phase-one-and-phase-two-of-the-zero-trust-implementation-guidelines/> |
| Advancing Zero Trust Maturity Throughout the ... Pillar (seven guides). This row links NSA's July 2024 release, which recaps all seven; each guide has its own row below. | NSA, 2023 to 2024 | <https://www.nsa.gov/Press-Room/Press-Releases-Statements/Press-Release-View/Article/3833594/nsas-final-zero-trust-pillar-report-outlines-how-to-achieve-faster-threat-respo/> |
| Advancing Zero Trust Maturity Throughout the User Pillar | NSA, Mar 2023; v1.1 Apr 2023 | <https://media.defense.gov/2023/Mar/14/2003178390/-1/-1/0/CSI_Zero_Trust_User_Pillar_v1.1.PDF> |
| Advancing Zero Trust Maturity Throughout the Device Pillar | NSA, Oct 2023 | <https://media.defense.gov/2023/Oct/19/2003323562/-1/-1/0/CSI-DEVICE-PILLAR-ZERO-TRUST.PDF> |
| Advancing Zero Trust Maturity Throughout the Application and Workload Pillar | NSA, May 2024 | <https://media.defense.gov/2024/May/22/2003470825/-1/-1/0/CSI-APPLICATION-AND-WORKLOAD-PILLAR.PDF> |
| Advancing Zero Trust Maturity Throughout the Data Pillar | NSA, Apr 2024 | <https://media.defense.gov/2024/Apr/09/2003434442/-1/-1/0/CSI_DATA_PILLAR_ZT.PDF> |
| Advancing Zero Trust Maturity Throughout the Network and Environment Pillar | NSA, Mar 2024 | <https://media.defense.gov/2024/Mar/05/2003405462/-1/-1/0/CSI-ZERO-TRUST-NETWORK-ENVIRONMENT-PILLAR.PDF> |
| Advancing Zero Trust Maturity Throughout the Automation and Orchestration Pillar | NSA, Jul 2024 | <https://media.defense.gov/2024/Jul/10/2003500250/-1/-1/0/CSI-ZT-AUTOMATION-ORCHESTRATION-PILLAR.PDF> |
| Advancing Zero Trust Maturity Throughout the Visibility and Analytics Pillar | NSA, May 2024 | <https://media.defense.gov/2024/May/30/2003475230/-1/-1/0/CSI-VISIBILITY-AND-ANALYTICS-PILLAR.PDF> |

### Federal civilian

| Source | Publisher, date | Link |
|---|---|---|
| EO 14028, Improving the Nation's Cybersecurity | White House, May 2021 | <https://www.federalregister.gov/documents/2021/05/17/2021-10460/improving-the-nations-cybersecurity> |
| OMB M-22-09, Moving the U.S. Government Toward Zero Trust Cybersecurity Principles | OMB, Jan 2022 | <https://www.whitehouse.gov/wp-content/uploads/2022/01/M-22-09.pdf> |
| OMB M-26-14, Ensuring Effective and Efficient Agency Logging and Network Visibility to Defend Against Evolving Cyber Threats | OMB, May 2026 | <https://www.whitehouse.gov/wp-content/uploads/2026/05/M-26-14-Ensuring-Effective-and-Efficient-Agency-Logging-and-Network-Visibility-to-Defend-Against-Evolving-Cyber-Threats.pdf> |
| OMB memoranda (index) | OMB | <https://www.whitehouse.gov/omb/information-resources/guidance/memoranda> |
| Microsegmentation in Zero Trust, Part One: Introduction and Planning | CISA, Jul 2025 | <https://www.cisa.gov/resources-tools/resources/microsegmentation-zero-trust-part-one-introduction-and-planning> (PDF: <https://www.cisa.gov/sites/default/files/2025-07/ZT-Microsegmentation-Guidance-Part-One_508c.pdf>) |
| Federal Zero Trust Data Security Guide. The official PDF on resources.data.gov. The guide's cio.gov page no longer loads. | Federal CISO Council and CDO Council, Oct 2024, rev. May 2025 | <https://resources.data.gov/assets/documents/Zero-Trust-DataSecurityGuide_RevisedMay2025_CIO.govVersion.pdf> |

### Private sector

| Source | Publisher, date | Link |
|---|---|---|
| Microsegmentation in Zero Trust, Part One: Introduction and Planning | CISA, Jul 2025 | <https://www.cisa.gov/resources-tools/resources/microsegmentation-zero-trust-part-one-introduction-and-planning> (PDF: <https://www.cisa.gov/sites/default/files/2025-07/ZT-Microsegmentation-Guidance-Part-One_508c.pdf>) |
| The NIST Cybersecurity Framework (CSF) 2.0, CSWP 29 | NIST, Feb 2024 | <https://csrc.nist.gov/pubs/cswp/29/the-nist-cybersecurity-framework-csf-20/final> |
| Implementing a Zero Trust Architecture, NIST SP 1800-35 | NIST NCCoE, Jun 2025 | <https://csrc.nist.gov/pubs/sp/1800/35/final> |
| Protecting Controlled Unclassified Information in Nonfederal Systems and Organizations, NIST SP 800-171 Rev. 3 | NIST, May 2024 | <https://csrc.nist.gov/pubs/sp/800/171/r3/final> |
| Protecting Controlled Unclassified Information in Nonfederal Systems and Organizations, NIST SP 800-171 Rev. 2. The CMMC program's Level 2 requirements are identical to Rev. 2 (32 CFR 170.14(c)(3)); NIST withdrew Rev. 2 when it published Rev. 3. Checked 29 September 2026. | NIST, Feb 2020, updated Jan 2021 | <https://csrc.nist.gov/pubs/sp/800/171/r2/upd1/final> |
| Cybersecurity Maturity Model Certification (CMMC) Program, 32 CFR Part 170 | DoD CIO, Oct 2024 | <https://www.govinfo.gov/content/pkg/FR-2024-10-15/pdf/2024-22905.pdf> |

### Talks

| Source | Publisher, date | Link |
|---|---|---|
| John Kindervag: "Containment, ZT and the Security Graph: The Path to Anti-Fragility" | DoW Zero Trust Virtual Learning Exchange, Apr 2026 | <https://media.waru.edu/playlist/dedicated/62925431/1_78sgkifi/1_u4dhitnh> |
| Dr. Shelly Kelly, NSA: "Zero Trust Implementation Guidelines (ZIGs)" | DoW Zero Trust Virtual Learning Exchange, Apr 2026 | <https://media.waru.edu/playlist/dedicated/62925431/1_78sgkifi/1_bzak7d09> |
| Randy Resnick, DoW Zero Trust Portfolio Management Office: "DOW's Randy Resnick on how centralized zero-trust planning prevents chaos" | DefenseScoop, Dec 2025 | <https://www.youtube.com/watch?v=T4G4FHaS_6U> |
| David Voelker, Department of the Navy: "Zero Trust for Operational Technology" | DoW Zero Trust Virtual Learning Exchange, Apr 2026 | <https://media.waru.edu/playlist/dedicated/62925431/1_78sgkifi/1_sr95lihm> |
| CISA and DoD panel: "Understanding the CISA Maturity Model and DoD's Zero Trust Strategy" | Cloud Security Alliance, Oct 2023 (on YouTube Mar 2026) | <https://www.youtube.com/watch?v=wpAjYp0yiSs> |
| Sean Connelly: "Zero Trust as Global Policy: How Governments Are Adopting Zero Trust" | DoW Zero Trust Virtual Learning Exchange, Apr 2026 | <https://media.waru.edu/playlist/dedicated/62925431/1_og8bhh9i/1_l01174ak> |
| ATARC webinar: "Mastering Zero Trust: Leveraging Network Visibility in Zero Trust Frameworks" | ATARC, Dec 2024 | <https://www.youtube.com/watch?v=yoSKqpQhio8> |
| Andy Ellis: "Leading to Zero Trust: Principles for a Smooth Journey" | DoW Zero Trust Virtual Learning Exchange, Apr 2026 | <https://media.waru.edu/playlist/dedicated/62925431/1_khqyas09/1_ywwwu11x> |
| Jennifer Minella: "The Zero Trust Maturity Myth" | DoW Zero Trust Virtual Learning Exchange, Apr 2026 | <https://media.waru.edu/playlist/dedicated/62925431/1_og8bhh9i/1_tacy9nke> |
| Rich Mogull: "When AI Breaks Security: Why Zero Trust Is No Longer Optional" | DoW Zero Trust Virtual Learning Exchange, Apr 2026 | <https://media.waru.edu/playlist/dedicated/62925431/1_og8bhh9i/1_8ebjco3g> |
| Niki Aimable Niyikiza: "Capability-Based Authorization for AI Agents: Warrants That Survive Prompt Injection" | [un]prompted 2026, Mar 2026 | <https://youtu.be/bw928cFShK4> |
| Matt Maisel: "Hooking Coding Agents with the Cedar Policy Language" | [un]prompted 2026, Mar 2026 | <https://youtu.be/m6pzrqFJ6hE> |
