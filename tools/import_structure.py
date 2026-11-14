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
  attack     MITRE ATT&CK's STIX bundle for one domain: tactics and techniques (names and identifiers only)

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
    return typography.curl(s)


def write_into(path: str, **blocks) -> None:
    p = Path(path)
    doc = json.loads(p.read_text(encoding="utf-8"))
    # a set's line is written by hand (why a baseline's count is what it is): a re-import keeps it
    lines = {s["id"]: s["line"] for s in doc.get("sets", []) if "line" in s}
    for s in blocks.get("sets", []):
        if s["id"] in lines:
            s["line"] = lines[s["id"]]
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
    write_into(args.into, levels=levels, nodes=nodes,
               depth={"shown": counts["subcategory"], "of": counts["subcategory"], "unit": "Subcategories", "why": None},
               crosswalks=[{"to": host["id"], "relation": "Informative Reference", "edition": f"SP 800-53 Rev {release}",
                            "sourceId": args.source, "unresolved": unresolved, "map": refs}])


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
    print(f"attack: {len(tactics)} tactics, {len(top)} techniques, {len(subs)} sub-techniques")
    levels = [{"id": "tactic", "name": "Tactic", "plural": "Tactics"}, {"id": "technique", "name": "Technique", "plural": "Techniques"}]
    write_into(args.into, levels=levels, nodes=nodes,
               depth={"shown": len(top), "of": len(top) + len(subs), "unit": "techniques and sub-techniques",
                      "why": "The techniques are listed by identifier and name. Sub-techniques, descriptions, detections and mitigations are at the source."})


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="kind", required=True)
    a = sub.add_parser("csf")
    a.add_argument("--into", required=True); a.add_argument("--core", required=True); a.add_argument("--refs", required=True)
    a.add_argument("--release", default="5.2.0"); a.add_argument("--source", required=True)
    a.add_argument("--catalog-file", required=True, help="the framework file the references point into")
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
    args = ap.parse_args()
    args.run(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
