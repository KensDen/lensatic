# G1 content gauntlet, 9 September 2026

Six lenses read `content/stack.json` cold and reported findings with a JSON path and a severity. Every blocker and major finding went to an independent refuter, whose verdict is recorded (upheld, narrowed, refuted). Dispositions: Fixed, Partly fixed, Deferred (with the reason), Refuted, Reported. This record describes findings by path and class; it quotes no text.

## C1 Purist

| Finding | Path | Severity | Refuter | Disposition |
|---|---|---|---|---|
| C1-01 | doors[id=dow].steps[order=1].text; frameworks[id=dod-zt-strategy].note; frameworks[id=dod-zt-strategy].documents[title=Implementing the DoD Zero Trust | minor | not sent (below major) | Fixed: step and notes now state the observable facts (printed expiry passed, still listed, no replacement) and the deadline's basis; recheck date set |
| C1-02 | orgs.dow.statusNote | minor | not sent (below major) | Fixed: naming status note now distinguishes the House deeming section from the Senate redesignation |
| C1-03 | frameworks[id=nsa-zt].note | minor | not sent (below major) | Fixed: note attributes the guideline statement to the hub page and the phase counts to the January release |
| C1-04 | frameworks[id=dod-zt-strategy].authority.verification.note | minor | not sent (below major) | Fixed: footnote 14 carve-back for national security systems added |
| C1-05 | sources[id=cmmc20].documents[title=Suspension of CMMC Phase 2 requirements (department news release)]; sources[id=cmmc20].authority.verification.note | minor | not sent (below major) | Fixed: implementing memorandum added as an unverified document with the URL tried; conflict note cites it |
| C1-06 | frameworks[id=dod-zt-overlays].note; frameworks[id=dod-zt-overlays].verification.note | nit | not sent (below major) | Fixed: launch date from the department's newsletter added to the note |
| C1-07 | helper[id=csf-and-zero-trust].answer; frameworks[id=csf20].note | nit | not sent (below major) | Fixed: the printed Tiers phrase used in both places |
| C1-08 | frameworks[id=dod-zt-strategy].verification | nit | not sent (below major) | Deferred: the successor-strategy announcement was not verified against a primary this round |
| C1-09 | helper[id=where-others-land].answer | nit | not sent (below major) | Fixed: the clause was dropped (see C7-01) |

## C2 Skeptic

| Finding | Path | Severity | Refuter | Disposition |
|---|---|---|---|---|
| C2-01 | helper[id=csf-and-zero-trust].answer | major | narrowed (nit) | Fixed: Target Profile sentence rewritten per the narrowed verdict |
| C2-02 | doors[id=federal-civilian].steps[order=6].text; doors[id=dow].steps[order=6].text; doors[id=defense-contractor].steps[order=5].text; helper[id=what-fi | major | narrowed (minor) | Fixed: what-first answer rewritten to reconcile with the door order |
| C2-03 | layers[id=l3].question; frameworks[id=nsa-zt].answersQuestion; sources[id=dod-zt-roadmap].role; doors[id=dow].steps[order=1].text; doors[id=dow].steps | major | narrowed (nit) | Partly fixed: phase counts attributed to the release; the discovery-phase count was not verified this round and is not stated |
| C2-04 | frameworks[id=cora].note; frameworks[id=cora].answersQuestion; layers[id=l5].question; doors[id=dow].steps[order=5].text | major | refuted (none) | Refuted: already applied and ratified in the previous round |
| C2-05 | doors[id=defense-contractor].steps[order=3].text | major | narrowed (nit) | Fixed: contractor step 3 rewritten; the strategy added to its basis |
| C2-06 | matrix.cells[functionId=RC] (all eight); matrix.cells[pillarId=user/device/application/data,functionId=DE]; functions[id=RC].ztLanding; functions[id=D | minor | not sent (below major) | Deferred: rewriting twelve cells is content authoring for the owner, not a mechanical fix |
| C2-07 | matrix.cells[pillarId=governance,functionId=GV].text; functions[id=GV].ztLanding; pillars.canonical[id=governance].mapping | minor | not sent (below major) | Fixed: governance Govern cell reworded; editorial sentence removed |
| C2-08 | helper[id=csf-and-zero-trust].answer; helper[id=where-mappings].answer; helper[id=csf-mandatory].answer | minor | not sent (below major) | Partly fixed: two of the three answers were rewritten under other findings; the mandatory-question answer stays |
| C2-09 | helper[id=csf-vs-iso27001]; helper[id=where-others-land].answer | minor | not sent (below major) | Deferred: the ISO 27001 question is required by the content specification |
| C2-10 | helper[id=where-others-land].question; helper[id=where-others-land].answer; helper[id=where-others-land].verification.basisIds | minor | not sent (below major) | Fixed: question and answer aligned; the unsupported clause dropped; basis extended |
| C2-11 | doors[id=dow].steps[order=1].text; doors[id=dow].steps[order=2].text; frameworks[id=dod-zt-strategy].note; frameworks[id=dod-zt-strategy].documents[1] | minor | not sent (below major) | Deferred: step order is the door design; repetition reduced under C1-01 |
| C2-12 | doors[id=defense-contractor].steps[order=2].text | minor | not sent (below major) | Fixed: CMMC step rewritten as one directive sentence |
| C2-13 | frameworks[id=sp1353].oneLiner; frameworks[id=sp1353].note; ai.column[id=sp1353].kind; elevator.frameworkIds | minor | not sent (below major) | Deferred: scope frozen; the entry is required by the content specification |
| C2-14 | layers[id=l1].question; layers[id=l1].oneLiner; frameworks[id=csf20].oneLiner; frameworks[id=csf20].answersQuestion; layers[id=l2].question; layers[id | minor | not sent (below major) | Deferred: editorial; single-entry layers are the design |
| C2-15 | elevator.frameworkIds; elevator.omits | minor | not sent (below major) | Deferred: the elevator order is the specified six-item paragraph |
| C2-16 | ai.socProfile[functionId=ID/DE/RS/RC].outcome; ai.note | minor | not sent (below major) | Deferred: the rows are fixed verbatim by ruling |
| C2-17 | layers[id=l2].oneLiner; doors[id=dow].steps[] | minor | not sent (below major) | Fixed: definition layer one-liner rewritten |
| C2-18 | doors[id=other].paragraph | minor | not sent (below major) | Fixed: the other door names the CISA model as the borrowable target |
| C2-19 | matrix.cells[pillarId=user,functionId=PR].text; matrix.cells[pillarId=governance,functionId=GV].text; matrix.cells[pillarId=visibility,functionId=DE]. | nit | not sent (below major) | Fixed: four editorial sentences removed from cells |
| C2-20 | layers[id=l6].question; layers[id=l3].question; pillars.canonical[id=user].mapping; pillars.canonical[id=device/application/data].mapping; pillars.can | nit | not sent (below major) | Partly fixed: layer 3 and layer 6 questions fixed; null mappings would need a schema change |
| C2-21 | frameworks[id=dod-zt-strategy].oneLiner; sources[id=dod-zt-roadmap].oneLiner; sources[id=dod-zt-roadmap].authority.deadline.text | nit | not sent (below major) | Fixed: roadmap one-liner trimmed; the deadline lives in the deadline field |

## C3 Non-DoD reader

| Finding | Path | Severity | Refuter | Disposition |
|---|---|---|---|---|
| C3-01 | helper[id=where-mappings].answer | major | narrowed (minor) | Fixed: mapping answer rewritten per the narrowed verdict |
| C3-02 | doors[id=other].paragraph (with doors[id=other].pillarView and doors[id=other].steps) | major | narrowed (minor) | Fixed: other door gains the verification and contractor sentences; basis extended |
| C3-03 | doors[id=defense-contractor].steps[order=3].text | minor | not sent (below major) | Fixed: see C2-05 |
| C3-04 | frameworks[id=cora].authority.binds and frameworks[id=cora].authority.note | minor | not sent (below major) | Partly fixed: authority note now records the cleared-contractor assessments; the binds enum has no matching value (schema) |
| C3-05 | doors[id=federal-civilian].steps[order=5] (layerId) and layers[id=l5].frameworkIds | minor | not sent (below major) | Deferred: a separate layer 5 step would be a seventh step; six is the maximum |
| C3-06 | doors[id=defense-contractor].pillarView | minor | not sent (below major) | Fixed: step 4 names the seven-pillar view for a department customer; pillarView stays null by design |
| C3-07 | pillars.canonical[id=user].mapping | minor | not sent (below major) | Fixed: the view-order sentence removed from the user pillar mapping |
| C3-08 | layers[id=l5].oneLiner | nit | not sent (below major) | Fixed: layer 5 one-liner no longer assumes an authorizing official |
| C3-09 | helper[id=csf-and-zero-trust].answer | nit | not sent (below major) | Fixed: the control catalog clause generalized |
| C3-10 | helper[id=where-others-land].question and helper[id=where-others-land].answer | nit | not sent (below major) | Fixed: question aligned to the answer |

## C4 Prior art

| Finding | Path | Severity | Refuter | Disposition |
|---|---|---|---|---|
| C4-01 | ai.note; matrix.cells[pillarId=automation,functionId=PR].text; matrix.cells[pillarId=automation,functionId=DE].text; pillars.canonical[id=automation]. | major | narrowed (minor) | Fixed: automation pillar mapping and the AI column note record where AI lands in each model |
| C4-02 | matrix.cells[pillarId=*,functionId=RS].verification.basisIds; matrix.cells[pillarId=*,functionId=RC].verification.basisIds (16 cells); functions[id=RS | major | refuted (none) | Refuted: pillar definitions are a legitimate basis in every function row |
| C4-03 | matrix.cells[*].verification.note (identical string on all 48 cells); matrix.cells[*].verification.basisIds (identical list on 42 cells); matrix.cells | major | refuted (none) | Refuted: the shared authored basis is the ruled shape; located capability ids are a later schema decision |
| C4-04 | frameworks[id=ai-defense-matrix].oneLiner; helper[id=csf-and-zero-trust].answer; frameworks[id=ai-defense-matrix].note | major | refuted (none) | Refuted: no priority claim is made; the lineage is already in the note |
| C4-05 | helper[id=where-mappings].answer; helper[id=where-mappings].entityIds | major | narrowed (minor) | Fixed: practice-guide mappings named in the mapping answer; a source entry is reported for the next scope round |
| C4-06 | frameworks[id=ai-rmf].authority; frameworks[id=ir8596].authority; frameworks[id=ai-defense-matrix].authority; frameworks[id=sp1353].authority; ai.note | major | narrowed (minor) | Fixed: AI column note names the governing memorandum; a source entry is reported for the next scope round |
| C4-07 | pillars.canonical[id=device].mapping; pillars.canonical[id=application].mapping; pillars.canonical[id=governance].mapping; pillars.canonical[id=user]. | minor | not sent (below major) | Deferred: the proposed pillar differences need a primary check before they enter the mappings |
| C4-08 | helper[id=where-others-land].answer; helper[id=where-others-land].entityIds; helper[id=where-others-land].verification.basisIds; helper[id=where-other | minor | not sent (below major) | Fixed: see C7-01 and C3-10 |
| C4-09 | frameworks[id=ai-rmf].authority.note; frameworks[id=sp1353].authority.note; frameworks[id=sp1353].authority.verification.note; frameworks[id=ir8596].a | minor | not sent (below major) | Deferred: editorial rewrites of authority notes; no factual error |
| C4-10 | functions[id=DE].ztLanding; functions[id=RS].ztLanding; functions[id=RC].ztLanding; functions[id=ID].ztLanding | minor | not sent (below major) | Deferred: capability ids per function need verification before they enter the landing statements |
| C4-11 | helper[id=csf-vs-iso27001].answer; helper[id=where-others-land].answer | minor | not sent (below major) | Deferred: the mapping date needs verification; the question is required by the content specification |
| C4-12 | matrix.cells[pillarId=governance,functionId=GV].text; matrix.cells[pillarId=governance,functionId=GV].verification.note | nit | not sent (below major) | Deferred: the footnote claim was not verified this round |
| C4-13 | layers[id=l6].question | nit | not sent (below major) | Fixed: see C7-21 |

## C6 Wall auditor

| Finding | Path | Severity | Refuter | Disposition |
|---|---|---|---|---|
| C6-01 | ai.socProfile[0..5].verification.note (functionId GV, ID, PR, DE, RS, RC), the final clause of each note; char offsets 131730-131757, 132304-132331, 1 | major | narrowed (nit) | Fixed: the six notes no longer carry the process clause; the wording is marked fixed |
| C6-02 | content/schema/stack.schema.json properties.pillars.properties.views.properties.dow.description, final sentence; char offsets 4800-4861 | minor | not sent (below major) | Deferred: the recorded ruling in the schema description is required by ruling 1.2 |
| C6-03 | content/schema/stack.schema.json $defs.verificationRecord.properties.method.enum[1] (char offsets 24184-24195) and its single use at content/stack.jso | minor | not sent (below major) | Fixed: the method value removed from the enum; the thirteen unreached records use one value |
| C6-04 | README.md, section "Running the battery", char offsets 2186-2226 (the never-committed list sentence), 2267-2276 and 2447-2456 (two mentions of the loc | minor | not sent (below major) | Fixed: README no longer names the local folder or describes working history |
| C6-05 | README.md, section heading at char offset 1135-1146 and the rule sentence beginning at char offset 1191 | nit | not sent (below major) | Fixed: README section retitled and stated positively |
| C6-06 | content/stack.json frameworks[id=sp1353].note, final clause; char offsets 46652-46672 | nit | not sent (below major) | Fixed: absolute date used |
| C6-07 | content/stack.json meta.name (char offsets 18-36) and content/schema/stack.schema.json properties.meta.properties.name.const | nit | not sent (below major) | Reported: naming association recorded for the release-name check; no change |

## C7 Consistency cop

| Finding | Path | Severity | Refuter | Disposition |
|---|---|---|---|---|
| C7-01 | helper[id=where-others-land].answer and helper[id=where-others-land].verification.basisIds | major | upheld (major) | Fixed: basis extended to the cited entries; the unsupported clause dropped |
| C7-02 | elevator.derivedFrom, elevator.omits, elevator.frameworkIds | minor | not sent (below major) | Fixed: schema description now says the id list is complete and the omits list informational |
| C7-03 | pillars.canonical[id=user].mapping | minor | not sent (below major) | Fixed: see C3-07 |
| C7-04 | doors[id=dow].steps[order=4].text and helper[id=where-mappings].answer | minor | not sent (below major) | Fixed: the duplicated sentence was rewritten in the mapping answer |
| C7-05 | frameworks[id=dod-zt-strategy].documents[1].note versus frameworks[id=dod-zt-strategy].note and doors[id=dow].steps[order=1].text | minor | not sent (below major) | Fixed: the three statements aligned under C1-01 |
| C7-06 | frameworks[id=cora].authority.binds, frameworks[id=cora].authority.verification.note, frameworks[id=cora].date | minor | not sent (below major) | Fixed: date set to the release; the launch date moved to the note; contractor assessments recorded |
| C7-07 | frameworks[id=dod-zt-strategy].authority.deadline.text, sources[id=dod-zt-roadmap].authority.deadline.text, frameworks[id=dod-zt-strategy].oneLiner | minor | not sent (below major) | Fixed: roadmap deadline text is a pointer; roadmap one-liner trimmed |
| C7-08 | frameworks[id=ir8596].verification.recheckAfter; frameworks[id=sp1353].verification; frameworks[id=dod-zt-strategy].verification | minor | not sent (below major) | Partly fixed: recheck dates added to the quick-start guide and the memorandum; the null value on the AI profile entry is by ruling |
| C7-09 | frameworks[id=nsa-zt].documents[0..11].verification.method versus frameworks[id=dod-zt-overlays].verification.method | minor | not sent (below major) | Fixed: one method value for all unreached records |
| C7-10 | sources[id=cmmc20].documents[2].title | minor | not sent (below major) | Deferred: a render token inside a citation field would print oddly; the paraphrased title is labeled |
| C7-11 | sources[id=sp800-171].edition, frameworks[id=cora].edition, frameworks[id=nsa-zt].edition, frameworks[id=dod-zt-overlays].edition, frameworks[id=ai-de | minor | not sent (below major) | Fixed: edition fields reduced to the printed form |
| C7-12 | matrix.cells[pillarId=governance,functionId=DE].categories | minor | not sent (below major) | Fixed: cross-function category removed from the cell |
| C7-13 | ai.socProfile[functionId=PR].verification.basisIds and ai.note | minor | not sent (below major) | Partly fixed: definition source added to the two rows; provenance records on notes would need a schema change |
| C7-14 | helper[id=csf-and-zero-trust].answer and helper[id=csf-and-zero-trust].verification.basisIds | minor | not sent (below major) | Fixed: basis extended; the duplicate maturity sentence merged |
| C7-15 | sources[id=eo13800].oneLiner restated at frameworks[id=csf20].authority.note, sources[id=eo13800].authority.note, helper[id=csf-mandatory].answer, doo | minor | not sent (below major) | Partly fixed: the memo's role reworded; trimming the authority notes is editorial and deferred |
| C7-16 | helper[id=where-others-land].question versus helper[id=where-others-land].answer | minor | not sent (below major) | Fixed: question and answer aligned and reordered |
| C7-17 | frameworks[id=nsa-zt].oneLiner; doors[id=dow].steps[order=1].text; doors[id=defense-contractor].verification.note | nit | not sent (below major) | Fixed: casing and date form aligned |
| C7-18 | frameworks[id=rmf-ato].note | nit | not sent (below major) | Fixed: Prepare placed |
| C7-19 | sources[id=eo14028].authority.deadline.text versus sources[id=eo14028].verification.note | nit | not sent (below major) | Fixed: subsection cited |
| C7-20 | frameworks[id=nsa-zt].note versus sources[id=dod-zt-roadmap].oneLiner and frameworks[id=nsa-zt].oneLiner | nit | not sent (below major) | Partly fixed: the note now scopes the phase counts; the remainder is stated as not counted |
| C7-21 | layers[id=l6].question | nit | not sent (below major) | Fixed: layer 6 question phrased as a question |
| C7-22 | sources[id=eo14028].authority.verification.note; orgs.dow.renderRule versus schema description of orgs.dow; orgs.dow.verifiedOn | nit | not sent (below major) | Partly fixed: schema description aligned with the first-mention rule; the duplicate date field is required by the field list |
| C7-23 | frameworks[id=sp1353].answersQuestion; frameworks[id=ir8596].note; frameworks[id=cisa-ztmm].verification.note | nit | not sent (below major) | Fixed: the quick-start guide's question no longer echoes its one-liner |

## Totals

83 findings; 15 blocker or major, all sent to refuters: 1 upheld, 10 narrowed, 4 refuted; no blocker survived. Dispositions: 53 fixed, 9 partly fixed, 16 deferred, the rest refuted or reported.

## What changed

- Provenance: the thirteen unreached records use one method value; the implementing memorandum for the CMMC pause is recorded as unreached with its URL; recheck dates were added to the quick-start guide and the expired memorandum.
- Doors: the other door now covers verification and points contract holders to the contractor door and names the CISA model as the borrowable target; the contractor door's CMMC and zero trust steps state what binds and what does not; the department door's first step states the observable facts about the expired memorandum.
- Helpers: the mapping answer covers both pillar models and the practice-guide mappings; the landing answer is aligned with its question and drops an unsupported inspection claim; the zero trust answer states what a filled matrix is and is not; the what-first answer reconciles with the door order.
- Legend: the automation pillar and the AI column record where AI lands in each zero trust model, and the AI column names the memorandum that governs federal AI use as outside the stack.
- Entries: national security systems carve-back on the strategy; launch date on the overlays; release date, launch note and cleared-contractor assessments on the inspection program; edition fields reduced to printed form; the Tiers phrase quoted as printed.
- Cells and layers: four editorial sentences removed; the governance Govern cell reworded; one cross-function category removed; four layer fields reworded so questions are questions.
- Schema and README: elevator derivation and department-name descriptions clarified; one method value retired; README states its sources positively and no longer describes local working folders.

## Reported for the next scope round

- A source entry for the NIST zero trust practice guide (final, June 2025) with its mapping volume.
- A source entry for the April 2025 OMB memorandum on federal AI use, as an AI step on the civilian and department doors.
- A landing for contractors that hold only federal contract information, and for civilian-agency CUI contractors, which the current door set and binds enum cannot express.
- Located capability ids per matrix cell, if the owner wants the cells pinned to the models.
