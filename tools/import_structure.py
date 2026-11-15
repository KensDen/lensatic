#!/usr/bin/env python3
"""Fill a framework file's structure from the publisher's own machine-readable edition (Lensatic 2.0, Round 1).

A framework file under content/frameworks/ has two halves. The card half is written by hand: what the framework is, who
it binds, how it is verified, its sources and terms. The structure half (levels, nodes, sets, crosswalks, depth) comes
from the publisher's data, so no identifier, title or count is typed. This tool writes that half and leaves the card
half as it is. It reads local files only and makes no network request: download the publisher's files by hand, pass
their paths, and record in the file's source note where and when each was fetched.

  csf        NIST's CSF 2.0 core export (the Cybersecurity and Privacy Reference Tool's JSON) and the CSF 2.0 Reference
             Tool download (xlsx) for the informative references to SP 800-53
  sp800-53   NIST's OSCAL catalog for SP 800-53 and the SP 800-53B baseline profiles
  profiles   a set of OSCAL profiles over SP 800-53, as sets on another framework's file
  fedramp    FedRAMP's Consolidated Rules data file: the rulesets, the Key Security Indicators with their statements and
             related controls, and the Rev5 class baselines as sets on SP 800-53
  attack     MITRE ATT&CK's STIX bundle for one domain: tactics, techniques and sub-techniques (names and identifiers only)
  cprt-171   NIST's reference tool exports of SP 800-171 Revision 2 and Revision 3: both editions' families and
             requirements with NIST's text, and Revision 3's references to SP 800-53
  cmmc       the CMMC rule's Level 1 and Level 3 requirement tables (32 CFR Part 170, extracted from the eCFR by script),
             with Level 2 as a set on SP 800-171 Revision 2
  rmf        the seven steps and 47 tasks of SP 800-37 Revision 2 (the task tables, extracted from NIST's PDF by script)
  ai-rmf     NIST's reference tool export of the AI RMF 1.0 Core: functions, categories and subcategories
  ztmm       CISA's Zero Trust Maturity Model 2.0: pillars, functions and the four stages of each (extracted from CISA's
             PDF by script)
  dod-zt     the department's zero trust pillars, capabilities and activities, with Target and Advanced as sets
             (extracted from the Capabilities and Activities PDF by script)
  d3fend     MITRE D3FEND's matrix file: tactics and defensive techniques (names and identifiers only)
  atlas      the data file of MITRE's knowledge base of attacks on AI systems: tactics, techniques and sub-techniques

Usage: python3 tools/import_structure.py <kind> --into content/frameworks/<id>.json [inputs]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import typography  # noqa: E402  (curly quotes, the content's rule)

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
CSF_ORDER = ["GV", "ID", "PR", "DE", "RS", "RC"]


def load(path: str) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


DASHED: list[str] = []  # the publisher's texts whose dash was set as a spaced hyphen, for the import's report
KEPT: list[str] = []  # the publisher's texts that carry, as published, the one word the house rule keeps out of Lensatic's own text

try:  # the word is read at run time from the local sweep source and never written here (tools/validate.py)
    import validate as _V
    HOUSE_WORD = _V.FORBIDDEN_WORD
except SystemExit:
    HOUSE_WORD = ""


def prose(s: str, dash: bool = False) -> str:
    """Publisher text as the content prints it: one line and curly quotes; the words are the publisher's. Lensatic prints
    no em or en dash, so a text that carries one stops the import unless the caller asks for the house substitute: a
    spaced hyphen, which is how NIST's own CSF export prints the dashes of its PDF. Each substitution is counted and
    printed, so the source note can say how many titles differ from the publisher's by that one mark."""
    s = re.sub(r"\s+", " ", s).strip()
    if "\u2014" in s or "\u2013" in s:
        if not dash:
            sys.exit(f"a dash in the publisher's text, to settle by hand: {s[:80]}")
        s = re.sub(r"\s*[\u2014\u2013]\s*", " - ", s)
        DASHED.append(s)
    # one word may not stand with a capital in anything Lensatic writes (the validator's rule). A publisher's title keeps
    # it as published (owner's ruling 5 of 15 November 2026): the import counts those texts, and the caller lists their
    # elements in the file's asPublished, which is what the checks let through
    if HOUSE_WORD and HOUSE_WORD in s:
        KEPT.append(s)
        print(f"  one word kept with its capital, as published, in a publisher's text ({len(KEPT)} so far)")
    return typography.curl(s)


def as_published(nodes: list[dict]) -> list[str]:
    """The ids of the elements whose title carries that word as published, for the file's asPublished."""
    return [n["id"] for n in nodes if HOUSE_WORD and HOUSE_WORD in n.get("title", "")]


def write_into(path: str, **blocks) -> None:
    p = Path(path)
    doc = json.loads(p.read_text(encoding="utf-8"))
    # a set's line is written by hand (why a baseline's count is what it is): a re-import keeps it
    lines = {s["id"]: s["line"] for s in doc.get("sets", []) if "line" in s}
    for s in blocks.get("sets", []):
        if s["id"] in lines:
            s["line"] = lines[s["id"]]
    # so is a note on a node the import itself gives none (what an edition is, in Lensatic's words)
    notes = {n["id"]: n["note"] for n in doc.get("nodes", []) if "note" in n}
    for n in blocks.get("nodes", []):
        if "note" not in n and n["id"] in notes:
            n["note"] = notes[n["id"]]
    titles = {s["id"]: s["title"] for s in doc.get("sets", []) if "title" in s}
    for s in blocks.get("sets", []):
        if s["id"] in titles and "title" not in s:
            s["title"] = titles[s["id"]]
    doc.update(blocks)
    p.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{p.name}: " + ", ".join(f"{k} {len(v) if isinstance(v, (list, dict)) else v}" for k, v in blocks.items()))


def xlsx_rows(path: str, sheet: str) -> list[dict[str, str]]:
    """The rows of one worksheet as {column letter: text}, read with the standard library."""
    z = zipfile.ZipFile(path)
    shared = []
    if "xl/sharedStrings.xml" in z.namelist():
        for si in ET.fromstring(z.read("xl/sharedStrings.xml")).findall("m:si", NS):
            shared.append("".join(t.text or "" for t in si.iter("{%s}t" % NS["m"])))
    out = []
    for r in ET.fromstring(z.read(sheet)).iter("{%s}row" % NS["m"]):
        row = {}
        for c in r.findall("m:c", NS):
            col = re.match(r"[A-Z]+", c.attrib["r"]).group(0)
            v = c.find("m:v", NS)
            if c.attrib.get("t") == "s" and v is not None:
                row[col] = shared[int(v.text)]
            elif c.attrib.get("t") == "inlineStr":
                row[col] = "".join(x.text or "" for x in c.iter("{%s}t" % NS["m"]))
            else:
                row[col] = v.text if v is not None else ""
        out.append(row)
    return out


# --------------------------------------------------------------------------- CSF 2.0
def csf(args) -> None:
    core = load(args.core)["response"]["elements"]
    els, rels = core["elements"], core["relationships"]
    reasons = {e["element_identifier"] for e in els if e["element_type"] == "withdraw_reason"}
    withdrawn = {r["source_element_identifier"] for r in rels if r["dest_element_identifier"] in reasons}
    # the order is the Reference Tool download's, which is the order of the publication's own tables (Detect lists
    # Continuous Monitoring before Adverse Event Analysis); the export's sort keys put those two the other way round
    rows = xlsx_rows(args.refs, "xl/worksheets/sheet2.xml")
    order: dict[str, int] = {}
    for row in rows:
        for col, pattern in (("A", r"\(([A-Z]{2})\):"), ("B", r"\(([A-Z]{2}\.[A-Z]{2})\):"), ("C", r"^([A-Z]{2}\.[A-Z]{2}-\d{2}):")):
            m = re.search(pattern, row.get(col, ""))
            if m:
                order.setdefault(m.group(1), len(order))
    live = [e for e in els if e["element_type"] in ("function", "category", "subcategory") and e["element_identifier"] not in withdrawn]
    if any(e["element_identifier"] not in order for e in live):
        sys.exit("the download does not list every element of the export")
    live.sort(key=lambda e: order[e["element_identifier"]])
    nodes = []
    for e in live:
        i, kind = e["element_identifier"], e["element_type"]
        node = {"id": i, "level": kind,
                "parents": [] if kind == "function" else [i[:2]] if kind == "category" else [i[:5]]}
        if e.get("title"):
            node["title"] = prose(e["title"].title() if kind == "function" else e["title"])
        if e.get("text"):
            node["text"] = prose(e["text"])
        nodes.append(node)
    counts = {k: sum(1 for n in nodes if n["level"] == k) for k in ("function", "category", "subcategory")}
    if [n["id"] for n in nodes if n["level"] == "function"] != CSF_ORDER:
        sys.exit("the functions are not in the Core's order")
    # the informative references to SP 800-53, as the Reference Tool's download prints them beside each Subcategory
    refs: dict[str, list[str]] = {}
    release = args.release
    for row in rows:
        m = re.match(r"([A-Z]{2}\.[A-Z]{2}-\d{2}): ", row.get("C", ""))
        if not m or m.group(1) in withdrawn:
            continue
        got = []
        for line in row.get("E", "").split("\n"):
            if line.startswith(f"SP 800-53 Rev {release}:"):
                ref = line.split(":", 1)[1].strip()
                if ref not in got:
                    got.append(ref)
        if got:
            refs[m.group(1)] = got
    missing = [n["id"] for n in nodes if n["level"] == "subcategory" and n["id"] not in refs]
    # the references print zero-padded identifiers (AC-02(01)); the catalog file prints AC-2(1). Each reference is
    # resolved to the catalog's own label. One the current catalog does not hold (a withdrawn control the references
    # still list) is kept as the catalog would print it and named in "unresolved", so the app can say so
    host = load(args.catalog_file)
    known = {n["id"] for n in host["nodes"]}
    unpad = lambda r: re.sub(r"\d+", lambda m: str(int(m.group(0))), r)  # noqa: E731
    unresolved = sorted({unpad(r) for v in refs.values() for r in v if unpad(r) not in known})
    refs = {k: [unpad(r) for r in v] for k, v in refs.items()}
    print(f"csf: {counts}; {len(refs)} Subcategories carry SP 800-53 Rev {release} references ({sum(map(len, refs.values()))} in all, "
          f"{len({r for v in refs.values() for r in v})} distinct); none for {missing or 'no Subcategory'}; not in the catalog: {unresolved or 'none'}")
    levels = [{"id": "function", "name": "Function", "plural": "Functions"},
              {"id": "category", "name": "Category", "plural": "Categories"},
              {"id": "subcategory", "name": "Subcategory", "plural": "Subcategories"}]
    walks = [{"to": host["id"], "relation": "Informative Reference", "edition": f"SP 800-53 Rev {release}",
              "sourceId": args.source, "unresolved": unresolved, "map": refs}]
    # the same download's references to other frameworks (Round 2): prefix=framework-id[=listed|unlisted], each read from
    # the same column. A listed target must be an identifier the other file holds; an unlisted one is kept as NIST
    # prints it, for a framework whose elements Lensatic does not list
    for spec in args.also or []:
        prefix, to, mode = (spec.split("=") + ["listed"])[:3]
        other = load(str(Path(args.into).parent / f"{to}.json"))
        ids = {n["id"] for n in other["nodes"]}
        got: dict[str, list[str]] = {}
        for row in rows:
            m = re.match(r"([A-Z]{2}\.[A-Z]{2}-\d{2}): ", row.get("C", ""))
            if not m or m.group(1) in withdrawn:
                continue
            for line in row.get("E", "").split("\n"):
                if not line.startswith(prefix + ":"):
                    continue
                ref = line[len(prefix) + 1:].strip()
                if mode == "listed":
                    # the identifier is the reference's last identifier-shaped token that the other file holds
                    hit = [t for t in re.findall(r"[A-Za-z0-9][A-Za-z0-9.()\-]*", ref) if t in ids]
                    if not hit:
                        got.setdefault(m.group(1), [])
                        if ref not in got[m.group(1)]:
                            got[m.group(1)].append(ref)
                        continue
                    ref = hit[0]
                else:
                    # an unlisted reference is reduced to its identifiers: the kind NIST prints before them (a clause
                    # of the standard's body, or a control of its annex) and each number, so 'Mandatory Clause: 6.1,'
                    # and 'Annex A Controls: 5.15' become 'Clause 6.1' and 'Annex A 5.15'; one with no number is left out
                    kind = "Clause " if "Clause" in ref else "Annex A " if ("Annex" in ref or "Control" in ref) else ""
                    for num in re.findall(r"(?<![\d.])\d+(?:\.\d+)+|(?<![\d.:])\b\d+\b(?!\s*:)", ref):
                        if (kind + num) not in got.setdefault(m.group(1), []):
                            got[m.group(1)].append(kind + num)
                    continue
                if ref not in got.setdefault(m.group(1), []):
                    got[m.group(1)].append(ref)
        got = {k: v for k, v in got.items() if v}
        missing_ids = sorted({r for v in got.values() for r in v if r not in ids}) if mode == "listed" else []
        walk = {"to": to, "relation": "Informative Reference", "edition": prefix, "sourceId": args.source,
                "unresolved": missing_ids, "map": got}
        if mode != "listed":
            walk["listed"] = False
        walks.append(walk)
        print(f"  {prefix} -> {to}: {len(got)} Subcategories, {sum(map(len, got.values()))} references, "
              f"{len({r for v in got.values() for r in v})} distinct; not in the file: {missing_ids or 'none'}")
    write_into(args.into, levels=levels, nodes=nodes,
               depth={"shown": counts["subcategory"], "of": counts["subcategory"], "unit": "Subcategories", "why": None},
               crosswalks=walks)


# --------------------------------------------------------------------------- SP 800-53
def label(control: dict, cls: str | None = None) -> str:
    for p in control.get("props", []):
        if p.get("name") == "label" and p.get("class") == cls:
            return p["value"]
    sys.exit(f"{control['id']} has no label")


def is_withdrawn(control: dict) -> bool:
    return any(p.get("name") == "status" and p.get("value") == "withdrawn" for p in control.get("props", []))


def profile_ids(path: str) -> list[str]:
    p = load(path)["profile"]
    return [i for imp in p["imports"] for inc in imp.get("include-controls", []) for i in inc.get("with-ids", [])]


def sp80053(args) -> None:
    cat = load(args.catalog)["catalog"]
    nodes, by_oscal = [], {}
    for g in cat["groups"]:
        fam = g["id"].upper()
        nodes.append({"id": fam, "level": "family", "parents": [], "title": prose(g["title"])})
        for c in g["controls"]:
            if is_withdrawn(c):
                continue
            by_oscal[c["id"]] = label(c)
            nodes.append({"id": label(c), "level": "control", "parents": [fam], "title": prose(c["title"], dash=True)})
            for e in c.get("controls", []):
                if is_withdrawn(e):
                    continue
                by_oscal[e["id"]] = label(e)
                nodes.append({"id": label(e), "level": "enhancement", "parents": [label(c)], "title": prose(e["title"], dash=True)})
    counts = {k: sum(1 for n in nodes if n["level"] == k) for k in ("family", "control", "enhancement")}
    sets = []
    for spec in args.baseline or []:
        sid, name, path = spec.split("=", 2)
        ids = profile_ids(path)
        unknown = [i for i in ids if i not in by_oscal]
        if unknown:
            sys.exit(f"{name}: not in the catalog or withdrawn: {unknown[:8]}")
        sets.append({"id": sid, "name": name, "of": "sp800-53", "sourceId": args.baseline_source,
                     "members": [by_oscal[i] for i in ids]})
    print(f"sp800-53 {cat['metadata']['version']}: {counts}; " + ", ".join(f"{s['name']} {len(s['members'])}" for s in sets))
    print(f"  {len(DASHED)} titles print a dash at the source and a spaced hyphen here: " + "; ".join(DASHED[:4]) + (" ..." if len(DASHED) > 4 else ""))
    total = counts["control"] + counts["enhancement"]
    levels = [{"id": "family", "name": "Family", "plural": "Families"},
              {"id": "control", "name": "Control", "plural": "Controls"},
              {"id": "enhancement", "name": "Enhancement", "plural": "Enhancements"}]
    write_into(args.into, levels=levels, nodes=nodes, sets=sets,
               depth={"shown": total, "of": total, "unit": "controls and enhancements",
                      "why": "Each is listed by its identifier and title. The control statements, discussions and parameters are at the source."})


# --------------------------------------------------------------------------- OSCAL profiles on SP 800-53 (FedRAMP)
def profiles(args) -> None:
    host = load(args.catalog_file)
    known = {n["id"] for n in host["nodes"]}
    # OSCAL's identifiers (ac-2.1) as the publication prints them (AC-2(1))
    def printed(i: str) -> str:
        m = re.fullmatch(r"([a-z]{2})-(\d+)(?:\.(\d+))?", i)
        if not m:
            sys.exit(f"an identifier this tool does not read: {i}")
        return f"{m.group(1).upper()}-{int(m.group(2))}" + (f"({int(m.group(3))})" if m.group(3) else "")
    sets = []
    for spec in args.set:
        sid, name, path = spec.split("=", 2)
        ids = [printed(i) for i in profile_ids(path)]
        unknown = [i for i in ids if i not in known]
        if unknown and not args.allow_unknown:
            sys.exit(f"{name}: not in {host['id']}'s current catalog: {unknown}")
        sets.append({"id": sid, "name": name, "of": host["id"], "sourceId": args.source,
                     "members": [i for i in ids if i in known]})
        if unknown:
            print(f"  {name}: {len(unknown)} identifiers are not in {host['id']}'s current catalog and are left out: {unknown}")
    write_into(args.into, sets=sets)


# --------------------------------------------------------------------------- FedRAMP's Consolidated Rules
def fedramp(args) -> None:
    rules = load(args.rules)
    host = load(args.catalog_file)
    known = {n["id"] for n in host["nodes"]}

    def printed(i: str) -> str:
        """AC-02 (01) and ac-2.1, the rules file's two spellings, as the catalog prints the control: AC-2(1)."""
        m = re.fullmatch(r"([A-Za-z]{2})-0*(\d+)(?:\s*\(0*(\d+)\)|\.0*(\d+))?", i.strip())
        if not m:
            sys.exit(f"an identifier this tool does not read: {i}")
        enh = m.group(3) or m.group(4)
        return f"{m.group(1).upper()}-{int(m.group(2))}" + (f"({int(enh)})" if enh else "")

    nodes, walk = [], {}
    for short, rs in rules["FRR"].items():
        info = rs["info"]
        nodes.append({"id": info["short_name"], "level": "ruleset", "parents": [], "title": prose(info["name"]), "text": prose(info["purpose"])})
    for theme in rules["KSI"].values():
        nodes.append({"id": theme["id"], "level": "theme", "parents": [], "title": prose(theme["name"])})
        for iid, ind in theme["indicators"].items():
            node = {"id": iid, "level": "indicator", "parents": [theme["id"]], "title": prose(ind["name"])}
            if "statement" in ind:
                node["text"] = prose(ind["statement"])
            else:
                # an indicator whose statement varies by class: the statement of the highest class that states it, and a
                # note, in Lensatic's own words, naming each class where the file marks it optional
                by = ind["varies_by_class"]
                node["text"] = prose(by[max(by)]["statement"].replace("**Optional:**", "").strip())
                optional = [c.upper() for c in sorted(by) if by[c]["statement"].startswith("**Optional:**")]
                same = {by[c]["statement"].replace("**Optional:**", "").strip() for c in by}
                if len(same) != 1:
                    sys.exit(f"{iid}: the statement differs by class in more than being optional")
                if optional:
                    node["note"] = "Optional for Class " + " and ".join(optional) + "."
            nodes.append(node)
            refs = [printed(c) for c in ind.get("controls", [])]
            if refs:
                walk[iid] = sorted(set(refs), key=lambda r: (host_order.get(r, 10 ** 6), r)) if (host_order := {n["id"]: k for k, n in enumerate(host["nodes"])}) else refs
    unresolved = sorted({r for v in walk.values() for r in v if r not in known})
    sets = []
    for cls, spec in rules["FRR"]["FRC"]["data"]["rev5"]["CSF"]["FRC-CSF-BSL"]["varies_by_class"].items():
        ids = [printed(i) for fam in spec["rev5_controls_list"].values() for i in fam]
        bad = [i for i in ids if i not in known]
        if bad:
            sys.exit(f"Class {cls.upper()}: not in {host['id']}'s current catalog: {bad}")
        sets.append({"id": f"rev5-class-{cls}", "name": f"Rev5 Class {cls.upper()}", "of": host["id"], "sourceId": args.source, "members": ids})
    counts = {k: sum(1 for n in nodes if n["level"] == k) for k in ("ruleset", "theme", "indicator")}
    print(f"fedramp {rules['info']['version']}: {counts}; " + ", ".join(f"{x['name']} {len(x['members'])}" for x in sets)
          + f"; {len(walk)} indicators carry related controls ({len({r for v in walk.values() for r in v})} distinct); not in the catalog: {unresolved or 'none'}")
    levels = [{"id": "ruleset", "name": "Ruleset", "plural": "Rulesets"}, {"id": "theme", "name": "Theme", "plural": "Themes"},
              {"id": "indicator", "name": "Key Security Indicator", "plural": "Key Security Indicators"}]
    write_into(args.into, levels=levels, nodes=nodes, sets=sets,
               depth={"shown": counts["indicator"], "of": counts["indicator"], "unit": "Key Security Indicators",
                      "why": f"The {counts['ruleset']} rulesets are listed by name and purpose; their rules are at the source."},
               crosswalks=[{"to": host["id"], "relation": "Related Control", "edition": "SP 800-53 Rev 5", "sourceId": args.source,
                            "unresolved": unresolved, "map": walk}])


# --------------------------------------------------------------------------- ATT&CK
def attack(args) -> None:
    objs = load(args.stix)["objects"]
    live = lambda o: not o.get("revoked") and not o.get("x_mitre_deprecated")  # noqa: E731
    ext = lambda o: next(r["external_id"] for r in o["external_references"] if r.get("source_name") == "mitre-attack")  # noqa: E731
    matrix = next(o for o in objs if o["type"] == "x-mitre-matrix" and live(o))
    by_id = {o["id"]: o for o in objs}
    tactics = [by_id[t] for t in matrix["tactic_refs"]]
    short = {t["x_mitre_shortname"]: ext(t) for t in tactics}
    nodes = [{"id": ext(t), "level": "tactic", "parents": [], "title": prose(t["name"])} for t in tactics]
    techs = [o for o in objs if o["type"] == "attack-pattern" and live(o)]
    top = sorted((o for o in techs if not o.get("x_mitre_is_subtechnique")), key=ext)
    subs = [o for o in techs if o.get("x_mitre_is_subtechnique")]
    for o in top:
        parents = [short[p["phase_name"]] for p in o.get("kill_chain_phases", []) if p["phase_name"] in short]
        nodes.append({"id": ext(o), "level": "technique", "parents": sorted(parents, key=list(short.values()).index), "title": prose(o["name"])})
    # a sub-technique's parent is the technique whose identifier it extends (T1059.001 under T1059); the bundle's
    # subtechnique-of relationships say the same, and both are checked
    live_ids = {o["id"] for o in techs}
    rel = {r["source_ref"]: r["target_ref"] for r in objs if r.get("type") == "relationship" and r.get("relationship_type") == "subtechnique-of"
           and r["source_ref"] in live_ids and not r.get("revoked") and not r.get("x_mitre_deprecated")}
    top_ids = {ext(o) for o in top}
    for o in sorted(subs, key=ext):
        parent = ext(o).split(".")[0]
        if parent not in top_ids or ext(by_id[rel[o["id"]]]) != parent:
            sys.exit(f"{ext(o)}: its parent is not a live technique, or the relationship names another")
        nodes.append({"id": ext(o), "level": "subtechnique", "parents": [parent], "title": prose(o["name"])})
    print(f"attack: {len(tactics)} tactics, {len(top)} techniques, {len(subs)} sub-techniques")
    levels = [{"id": "tactic", "name": "Tactic", "plural": "Tactics"}, {"id": "technique", "name": "Technique", "plural": "Techniques"},
              {"id": "subtechnique", "name": "Sub-Technique", "plural": "Sub-Techniques"}]
    total = len(top) + len(subs)
    write_into(args.into, levels=levels, nodes=nodes,
               depth={"shown": total, "of": total, "unit": "techniques and sub-techniques",
                      "why": "Each is listed by identifier and name. Descriptions, detections and mitigations are at the source."})


# --------------------------------------------------------------------------- NIST's reference tool exports (CPRT)
def cprt(path: str) -> tuple[list[dict], dict[str, list[str]], list[dict]]:
    """An export's elements, each parent's children by the projection relationship, and every relationship."""
    e = load(path)["response"]["elements"]
    kids: dict[str, list[str]] = {}
    for r in e["relationships"]:
        if r["relationship_identifier"] == "projection":
            kids.setdefault(r["source_element_identifier"], []).append(r["dest_element_identifier"])
    return e["elements"], kids, e["relationships"]


def dotted(i: str) -> list[int]:
    return [int(x) for x in re.findall(r"\d+", i)]


def title_case(s: str) -> str:
    """A title NIST prints in capitals, as a title: small words stay small after the first."""
    small = {"and", "or", "of", "the", "to", "in", "for", "a", "an", "on"}
    words = s.lower().split()
    out = [w if k and w in small else "-".join(p[:1].upper() + p[1:] for p in w.split("-")) for k, w in enumerate(words)]
    return " ".join(out)


def cprt171(args) -> None:
    nodes: list[dict] = []
    # Revision 2: families and requirements; a requirement has no title, only its statement
    els, kids, _ = cprt(args.rev2)
    by = {e["element_identifier"]: e for e in els}
    nodes.append({"id": "rev2", "level": "revision", "parents": [], "title": "Revision 2"})
    r2 = []
    for fam in sorted((e for e in els if e["element_type"] == "family"), key=lambda e: dotted(e["element_identifier"])):
        nodes.append({"id": fam["element_identifier"], "level": "family", "parents": ["rev2"], "title": prose(title_case(fam["title"]))})
        for rid in sorted((k for k in kids.get(fam["element_identifier"], []) if by[k]["element_type"] == "requirement"), key=dotted):
            nodes.append({"id": rid, "level": "requirement", "parents": [fam["element_identifier"]], "text": prose(by[rid]["text"], dash=True)})
            r2.append(rid)
    # Revision 3: families, and the requirements that are not withdrawn, each with its title and its statement put
    # together from the statement's lettered and numbered parts
    els, kids, rels = cprt(args.rev3)
    by = {e["element_identifier"]: e for e in els}
    nodes.append({"id": "rev3", "level": "revision", "parents": [], "title": "Revision 3"})

    def statement(sr: str) -> str:
        e = by[sr]
        parts = sorted((k for k in kids.get(sr, []) if by[k]["element_type"] == "security_requirement"), key=lambda k: k)
        own = e["text"].strip()
        label = e["title"].strip()
        # a part's label as the publication prints it in the requirement: a letter, or a number without the leading
        # zero the data file gives it ("01" in the file, "1." in the text)
        lead = f"{int(label) if label.isdigit() else label}. " if label and len(label) <= 2 else ""
        if not sr.startswith("SR-") or sr.count(".") == 2:
            lead = ""
        body = " ".join(statement(p) for p in parts)
        return (lead + " ".join(x for x in (own, body) if x)).strip()

    r3, withdrawn3, walk = [], [], {}
    for fam in sorted((e for e in els if e["element_type"] == "family"), key=lambda e: dotted(e["element_identifier"])):
        nodes.append({"id": fam["element_identifier"], "level": "family", "parents": ["rev3"], "title": prose(fam["title"])})
        for rid in sorted((k for k in kids.get(fam["element_identifier"], []) if by[k]["element_type"] == "requirement"), key=dotted):
            if not by[rid]["title"].strip():
                withdrawn3.append(rid)
                continue
            text = statement("SR-" + rid)
            if not text:
                sys.exit(f"{rid}: no statement")
            nodes.append({"id": rid, "level": "requirement", "parents": [fam["element_identifier"]], "title": prose(by[rid]["title"], dash=True),
                          "text": prose(text, dash=True)})
            r3.append(rid)
    # Revision 3's own references to SP 800-53, requirement by requirement
    host = load(args.catalog_file)
    known = {n["id"] for n in host["nodes"]}
    live = set(r3)
    for r in rels:
        if r["relationship_identifier"] == "external_reference" and r["dest_doc_identifier"].startswith("SP_800_53_5") and r["source_element_identifier"] in live:
            t = re.sub(r"\d+", lambda m: str(int(m.group(0))), r["dest_element_identifier"])
            if t not in walk.setdefault(r["source_element_identifier"], []):
                walk[r["source_element_identifier"]].append(t)
    order = {n["id"]: k for k, n in enumerate(host["nodes"])}
    walk = {k: sorted(v, key=lambda t: order.get(t, 10 ** 6)) for k, v in sorted(walk.items(), key=lambda kv: dotted(kv[0]))}
    unresolved = sorted({t for v in walk.values() for t in v if t not in known})
    print(f"sp800-171: Revision 2 {len(r2)} requirements; Revision 3 {len(r3)} requirements, {len(withdrawn3)} withdrawn numbers left out; "
          f"{len(walk)} Revision 3 requirements point at SP 800-53 ({len({t for v in walk.values() for t in v})} distinct); not in the catalog: {unresolved or 'none'}")
    print(f"  {len(DASHED)} texts print a dash at the source and a spaced hyphen here")
    total = len(r2) + len(r3)
    levels = [{"id": "revision", "name": "Revision", "plural": "Revisions", "identified": False},
              {"id": "family", "name": "Family", "plural": "Families"},
              {"id": "requirement", "name": "Requirement", "plural": "Requirements"}]
    doc_edition = next(d for d in load(args.rev3)["response"]["elements"]["documents"])["version"]
    write_into(args.into, levels=levels, nodes=nodes,
               depth={"shown": total, "of": total, "unit": "requirements",
                      "why": f"Both editions are listed: Revision 2's {len(r2)} and Revision 3's {len(r3)}. Revision 3's {len(withdrawn3)} withdrawn numbers are left out, and the discussions and assessment procedures are at the source."},
               crosswalks=[{"to": host["id"], "relation": "Source Control", "edition": f"SP 800-171 Rev 3 ({doc_edition})", "sourceId": args.source,
                            "unresolved": unresolved, "map": walk}])
    Path(args.members).write_text(json.dumps({"rev2": r2, "rev3": r3}), encoding="utf-8") if args.members else None


def airmf(args) -> None:
    els, kids, _ = cprt(args.core)
    by = {e["element_identifier"]: e for e in els}
    nodes = []
    for fn in ("GOVERN", "MAP", "MEASURE", "MANAGE"):  # the publication's order; the export sorts them by the alphabet
        nodes.append({"id": fn, "level": "function", "parents": [], "title": fn.capitalize(), "text": prose(by[fn]["text"])})
        for cat in sorted((k for k in kids[fn] if by[k]["element_type"] == "category"), key=dotted):
            nodes.append({"id": cat, "level": "category", "parents": [fn], "text": prose(by[cat]["text"], dash=True)})
            for sub in sorted((k for k in kids[cat] if by[k]["element_type"] == "subcategory"), key=dotted):
                nodes.append({"id": sub, "level": "subcategory", "parents": [cat], "text": prose(by[sub]["text"], dash=True)})
    counts = {k: sum(1 for n in nodes if n["level"] == k) for k in ("function", "category", "subcategory")}
    print(f"ai-rmf: {counts}; {len(DASHED)} texts print a dash at the source and a spaced hyphen here")
    write_into(args.into, levels=[{"id": "function", "name": "Function", "plural": "Functions"}, {"id": "category", "name": "Category", "plural": "Categories"},
                                  {"id": "subcategory", "name": "Subcategory", "plural": "Subcategories"}], nodes=nodes,
               depth={"shown": counts["subcategory"], "of": counts["subcategory"], "unit": "Subcategories", "why": None})


def slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


# --------------------------------------------------------------------------- tables extracted from a publisher's PDF or rule
def rmf(args) -> None:
    tasks = load(args.tasks)
    nodes, seen = [], []
    for t in tasks:
        sid = slug(t["step"])
        if sid not in seen:
            seen.append(sid)
            nodes.append({"id": sid, "level": "step", "parents": [], "title": t["step"]})
        node = {"id": t["id"], "level": "task", "parents": [sid], "title": prose(title_case(t["title"]), dash=True), "text": prose(t["statement"], dash=True)}
        if t.get("level"):
            node["note"] = f"{t['level']} level."
        nodes.append(node)
    counts = {k: sum(1 for n in nodes if n["level"] == k) for k in ("step", "task")}
    print(f"rmf: {counts}; {len(DASHED)} titles print a dash at the source and a spaced hyphen here")
    write_into(args.into, levels=[{"id": "step", "name": "Step", "plural": "Steps", "identified": False}, {"id": "task", "name": "Task", "plural": "Tasks"}],
               nodes=nodes, depth={"shown": counts["task"], "of": counts["task"], "unit": "tasks",
                                   "why": "Each task is listed by identifier, title and statement. The outcomes, inputs, outputs, roles and discussions are at the source."})


def cmmc(args) -> None:
    host = load(args.catalog_file)
    known = {n["id"] for n in host["nodes"]}
    nodes, walk = [], {}
    for lv, path in (("1", args.level1), ("3", args.level3)):
        rows = load(path)
        nodes.append({"id": f"level-{lv}", "level": "level", "parents": [], "title": f"Level {lv}"})
        if lv == "1":
            nodes.append({"id": "level-2", "level": "level", "parents": [], "title": "Level 2"}) if False else None
        doms: list[str] = []
        for r in rows:
            did = f"l{lv}-{slug(r['domain'])}"
            if did not in doms:
                doms.append(did)
                nodes.append({"id": did, "level": "domain", "parents": [f"level-{lv}"], "title": prose(r["domain"])})
            nodes.append({"id": r["id"], "level": "requirement", "parents": [did], "text": prose(r["text"], dash=True)})
            if r.get("sp800171r2"):
                bad = [x for x in r["sp800171r2"] if x not in known]
                if bad:
                    sys.exit(f"{r['id']}: {bad} is not in {host['id']}")
                walk[r["id"]] = r["sp800171r2"]
    # the levels in the rule's order, Level 2 between the two it states itself
    two = {"id": "level-2", "level": "level", "parents": [], "title": "Level 2"}
    k = next(i for i, n in enumerate(nodes) if n["id"] == "level-3")
    nodes.insert(k, two)
    rev2 = [n["id"] for n in host["nodes"] if n["level"] == "requirement" and re.fullmatch(r"3\.\d+\.\d+", n["id"])]
    l1 = [m for v in walk.values() for m in v]
    counts = {k: sum(1 for n in nodes if n["level"] == k) for k in ("level", "domain", "requirement")}
    print(f"cmmc: {counts}; Level 2 is {len(rev2)} requirements of {host['id']}; Level 1 maps to {len(l1)} of them")
    sets = [{"id": "level-1-in-171", "name": "Level 1 in SP 800-171’s Numbering", "of": host["id"], "sourceId": args.source, "members": l1},
            {"id": "level-2", "name": "Level 2", "of": host["id"], "sourceId": args.source, "members": rev2}]
    write_into(args.into, levels=[{"id": "level", "name": "Level", "plural": "Levels", "identified": False},
                                  {"id": "domain", "name": "Domain", "plural": "Domains", "identified": False},
                                  {"id": "requirement", "name": "Requirement", "plural": "Requirements"}],
               nodes=nodes, sets=sets,
               depth={"shown": counts["requirement"], "of": counts["requirement"], "unit": "requirements the rule states itself",
                      "why": f"Level 1’s 15 and Level 3’s 24, in the rule’s own words. Level 2’s {len(rev2)} are SP 800-171 Revision 2’s and are listed there."},
               crosswalks=[{"to": host["id"], "relation": "SP 800-171 Requirement", "edition": "32 CFR 170.15, Table 2", "sourceId": args.source,
                            "unresolved": [], "map": walk}])


def ztmm(args) -> None:
    d = load(args.model)
    nodes = []

    def function(parent: str, f: dict) -> None:
        fid = f"{parent}.{slug(f['name'])}"  # a key of the file's own, with no slash, so a screen's address can carry it
        node = {"id": fid, "level": "function", "parents": [parent], "title": prose(f["name"])}
        if f.get("kind", "").startswith("cross-cutting") and parent != "cross-cutting":
            node["note"] = "A cross-cutting capability, as it applies in this pillar."
        nodes.append(node)
        for stage in d["stages"]:
            nodes.append({"id": f"{fid}.{slug(stage)}", "level": "stage", "parents": [fid], "title": stage, "text": prose(f["stages"][stage], dash=True)})

    for p in d["pillars"]:
        nodes.append({"id": p["id"], "level": "pillar", "parents": [], "title": prose(p["name"])})
        for f in p["functions"]:
            function(p["id"], f)
    nodes.append({"id": "cross-cutting", "level": "capability-table", "parents": [], "title": "Cross-Cutting Capabilities"})
    for f in d["cross_cutting_capabilities"]["functions"]:
        function("cross-cutting", f)
    counts = {k: sum(1 for n in nodes if n["level"] == k) for k in ("pillar", "capability-table", "function", "stage")}
    print(f"ztmm: {counts}")
    write_into(args.into, levels=[{"id": "pillar", "name": "Pillar", "plural": "Pillars", "identified": False},
                                  {"id": "capability-table", "name": "Table", "plural": "Tables", "identified": False},
                                  {"id": "function", "name": "Function", "plural": "Functions", "identified": False},
                                  {"id": "stage", "name": "Stage", "plural": "Stage Descriptions", "identified": False}],
               nodes=nodes, depth={"shown": counts["function"], "of": counts["function"], "unit": "functions and capabilities, each at four stages", "why": None})


def dodzt(args) -> None:
    d = load(args.model)
    nodes = [{"id": p["id"], "level": "pillar", "parents": [], "title": prose(p["name"])} for p in d["pillars"]]
    for c in d["capabilities"]:
        node = {"id": c["id"], "level": "capability", "parents": [c["pillar"]], "title": prose(c["name"], dash=True)}
        if c["level"] == "Advanced":
            node["note"] = "Advanced Level: every activity under it is Advanced."
        nodes.append(node)
    for a in d["activities"]:
        nodes.append({"id": a["id"], "level": "activity", "parents": [a["capability"]], "title": prose(a["name"], dash=True), "note": f"{a['level']} Level."})
    # the file's order: each pillar, its capabilities, each capability's activities
    order = {n["id"]: (dotted(n["id"]) + [0, 0])[:3] for n in nodes}
    nodes.sort(key=lambda n: order[n["id"]])
    sets = [{"id": lv.lower(), "name": f"{lv} Level", "of": Path(args.into).stem, "sourceId": args.source,
             "members": [a["id"] for a in d["activities"] if a["level"] == lv]} for lv in ("Target", "Advanced")]
    counts = {k: sum(1 for n in nodes if n["level"] == k) for k in ("pillar", "capability", "activity")}
    print(f"dod-zt: {counts}; " + ", ".join(f"{s['name']} {len(s['members'])}" for s in sets))
    kept = as_published(nodes)
    write_into(args.into, levels=[{"id": "pillar", "name": "Pillar", "plural": "Pillars"}, {"id": "capability", "name": "Capability", "plural": "Capabilities"},
                                  {"id": "activity", "name": "Activity", "plural": "Activities"}],
               nodes=nodes, sets=sets, **({"asPublished": kept} if kept else {}),
               depth={"shown": counts["activity"], "of": counts["activity"], "unit": "activities",
                      "why": "Each is listed by number and name. The descriptions, outcomes and end states are at the source."})


# --------------------------------------------------------------------------- D3FEND and the knowledge base of attacks on AI
def d3fend(args) -> None:
    matrix = load(args.matrix)
    nodes, skipped = [], []

    def walk(parent: str, kids: list[dict]) -> None:
        for k in sorted(kids, key=lambda k: k["rdfs:label"].lower()):  # the order the publisher's matrix shows
            ident = k.get("d3f:d3fend-id")
            if not ident:
                skipped.append(k["rdfs:label"])
                continue
            nodes.append({"id": ident, "level": "technique", "parents": [parent], "title": prose(k["rdfs:label"])})
            walk(ident, k.get("children", []))

    for t in matrix:
        tid = slug(t["rdfs:label"])
        nodes.append({"id": tid, "level": "tactic", "parents": [], "title": prose(t["rdfs:label"])})
        walk(tid, t.get("children", []))
    n = sum(1 for x in nodes if x["level"] == "technique")
    print(f"d3fend: {len(matrix)} tactics, {n} techniques with an identifier; without one and left out: {skipped or 'none'}")
    write_into(args.into, levels=[{"id": "tactic", "name": "Tactic", "plural": "Tactics", "identified": False},
                                  {"id": "technique", "name": "Defensive Technique", "plural": "Defensive Techniques"}],
               nodes=nodes, depth={"shown": n, "of": n + len(skipped), "unit": "defensive techniques",
                                   "why": ("Each is listed by identifier and name. " + (f"{', '.join(skipped)} is in the matrix without an identifier in this release and is left out. " if skipped else "")
                                           + "Definitions and the links to attacker techniques are at the source.")})


def atlas(args) -> None:
    d = load(args.data)
    rel = d["relationships"]
    seq = sorted(rel[d["matrix"]["id"]]["sequences"], key=lambda r: r["position"])
    tactics = [r["target"] for r in seq]
    nodes = [{"id": t, "level": "tactic", "parents": [], "title": prose(d["tactics"][t]["name"])} for t in tactics]
    tech = d["techniques"]
    subs = {k for k in tech if re.fullmatch(r"AML\.T\d{4}\.\d{3}", k)}
    for k in sorted(tech):
        if k in subs:
            continue
        parents = [r["target"] for r in rel.get(k, {}).get("achieves", [])]
        nodes.append({"id": k, "level": "technique", "parents": sorted(parents, key=tactics.index), "title": prose(tech[k]["name"], dash=True)})
    for k in sorted(subs):
        parent = [r["target"] for r in rel.get(k, {}).get("specializes", [])]
        if len(parent) != 1 or parent[0] != k.rsplit(".", 1)[0]:
            sys.exit(f"{k}: its parent is not the technique it extends")
        nodes.append({"id": k, "level": "subtechnique", "parents": parent, "title": prose(tech[k]["name"], dash=True)})
    top = len(tech) - len(subs)
    print(f"{d['collection']['version']}: {len(tactics)} tactics, {top} techniques, {len(subs)} sub-techniques; {len(DASHED)} names print a dash at the source")
    total = top + len(subs)
    write_into(args.into, levels=[{"id": "tactic", "name": "Tactic", "plural": "Tactics"}, {"id": "technique", "name": "Technique", "plural": "Techniques"},
                                  {"id": "subtechnique", "name": "Sub-Technique", "plural": "Sub-Techniques"}], nodes=nodes,
               depth={"shown": total, "of": total, "unit": "techniques and sub-techniques",
                      "why": "Each is listed by identifier and name. Descriptions, mitigations and case studies are at the source."})


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="kind", required=True)
    a = sub.add_parser("csf")
    a.add_argument("--into", required=True); a.add_argument("--core", required=True); a.add_argument("--refs", required=True)
    a.add_argument("--release", default="5.2.0"); a.add_argument("--source", required=True)
    a.add_argument("--catalog-file", required=True, help="the framework file the references point into")
    a.add_argument("--also", action="append", help="prefix=framework-id[=unlisted]: another framework the download references")
    a.set_defaults(run=csf)
    a = sub.add_parser("sp800-53")
    a.add_argument("--into", required=True); a.add_argument("--catalog", required=True)
    a.add_argument("--baseline", action="append", help="id=Name=profile.json"); a.add_argument("--baseline-source", required=True)
    a.set_defaults(run=sp80053)
    a = sub.add_parser("profiles")
    a.add_argument("--into", required=True); a.add_argument("--catalog-file", required=True, help="the framework file the sets select from")
    a.add_argument("--set", action="append", required=True, help="id=Name=profile.json"); a.add_argument("--source", required=True)
    a.add_argument("--allow-unknown", action="store_true")
    a.set_defaults(run=profiles)
    a = sub.add_parser("fedramp")
    a.add_argument("--into", required=True); a.add_argument("--rules", required=True); a.add_argument("--source", required=True)
    a.add_argument("--catalog-file", required=True, help="the framework file the baselines select from")
    a.set_defaults(run=fedramp)
    a = sub.add_parser("attack")
    a.add_argument("--into", required=True); a.add_argument("--stix", required=True)
    a.set_defaults(run=attack)
    a = sub.add_parser("cprt-171")
    a.add_argument("--into", required=True); a.add_argument("--rev2", required=True); a.add_argument("--rev3", required=True)
    a.add_argument("--catalog-file", required=True, help="the SP 800-53 framework file Revision 3's references point into")
    a.add_argument("--source", required=True); a.add_argument("--members")
    a.set_defaults(run=cprt171)
    a = sub.add_parser("ai-rmf")
    a.add_argument("--into", required=True); a.add_argument("--core", required=True)
    a.set_defaults(run=airmf)
    a = sub.add_parser("rmf")
    a.add_argument("--into", required=True); a.add_argument("--tasks", required=True)
    a.set_defaults(run=rmf)
    a = sub.add_parser("cmmc")
    a.add_argument("--into", required=True); a.add_argument("--level1", required=True); a.add_argument("--level3", required=True)
    a.add_argument("--catalog-file", required=True, help="the SP 800-171 framework file the levels select from")
    a.add_argument("--source", required=True)
    a.set_defaults(run=cmmc)
    a = sub.add_parser("ztmm")
    a.add_argument("--into", required=True); a.add_argument("--model", required=True)
    a.set_defaults(run=ztmm)
    a = sub.add_parser("dod-zt")
    a.add_argument("--into", required=True); a.add_argument("--model", required=True); a.add_argument("--source", required=True)
    a.set_defaults(run=dodzt)
    a = sub.add_parser("d3fend")
    a.add_argument("--into", required=True); a.add_argument("--matrix", required=True)
    a.set_defaults(run=d3fend)
    a = sub.add_parser("atlas")
    a.add_argument("--into", required=True); a.add_argument("--data", required=True)
    a.set_defaults(run=atlas)
    args = ap.parse_args()
    args.run(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
