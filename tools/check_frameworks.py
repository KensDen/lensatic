#!/usr/bin/env python3
"""Battery checks for the framework navigator's content (Lensatic 2.0, Round 1): content/frameworks/.

The folder holds the catalog, one file for each framework it lists, and one for each comparison and readiness check, and
nothing else. Each validates against its schema in content/schema/. Then the rules the schemas cannot state:

  references   every group, related framework, stack entry, layer, source, set member, crosswalk end, comparison side and
               check item resolves, so a card never points at something that is not there
  counts       a count on a card equals the structure under it wherever the app shows that structure, and a file that
               shows fewer elements than the publisher has says how many of how many, and why
  sources      every framework carries a source of its own or a stack entry that has one; every source has its
               publisher, edition, date, link and the day it was last checked; no recheck is overdue on the day the
               content was checked, and nothing is dated after that day
  terms        a framework whose text is copyrighted or licensed shows structure only: no node carries the publisher's
               text; a framework under MITRE's terms carries the notice or the link those terms ask for
  colour       each framework's one colour reads as text, 4.5:1 or better, on the app's two surfaces and on the tinted
               card and chip the app draws with it, in light and in dark (the surface tokens come from web/src/styles.css)
  house rules  no em or en dash, no straight quote mark in prose, no forbidden word, no planning vocabulary, no email
               address; card texts end as sentences and stay short
  one name     the owner ruled one publisher's name fine to include (14 November 2026): MITRE's knowledge base of attacks
               on AI systems. The local sweep leaves that one word out, so this check holds it to the name: wherever the
               word appears in what the sweep covers, it is the name in capitals or part of MITRE's own addresses

Usage: python3 tools/check_frameworks.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import gen_ios_colors as G  # noqa: E402  (the surface tokens)
import typography  # noqa: E402
import validate as V  # noqa: E402  (the schema validator, the report format, the forbidden word)

DIR = ROOT / "content" / "frameworks"
SCHEMAS = ROOT / "content" / "schema"
STACK = ROOT / "content" / "stack.json"
MIN_CONTRAST = 4.5
# the washes the app draws a framework's colour with, over the card surface: the hero card's 7% and the identifier chip's 10%
TINTS = (0.07, 0.10)
DASHES = {"—": "em dash", "–": "en dash"}
EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}")
# the one publisher's name the owner's ruling lets through the sweep, and the only forms it may take: the name itself in
# capitals, and MITRE's own addresses for it
RULED_NAME = re.compile(r"atlas", re.I)
RULED_FORMS = re.compile(r"\bATLAS\b|atlas\.mitre\.org|mitre-atlas|atlas-data")


def load(p: Path):
    return json.loads(p.read_text(encoding="utf-8"))


def rgb(hex6: str) -> tuple[float, float, float]:
    h = hex6.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))  # type: ignore[return-value]


def luminance(c: tuple[float, float, float]) -> float:
    def lin(v: float) -> float:
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(v) for v in c)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a: tuple[float, float, float], b: tuple[float, float, float]) -> float:
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def over(fg: tuple[float, float, float], bg: tuple[float, float, float], alpha: float) -> tuple[float, float, float]:
    return tuple(f * alpha + b * (1 - alpha) for f, b in zip(fg, bg))  # type: ignore[return-value]


def walk_strings(node, path: str = "$"):
    if isinstance(node, dict):
        for k, v in node.items():
            yield from walk_strings(v, f"{path}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk_strings(v, f"{path}[{i}]")
    elif isinstance(node, str):
        yield path, node


def main() -> int:
    rep = V.Report()
    try:
        catalog = load(DIR / "catalog.json")
    except Exception as exc:  # noqa: BLE001
        print(f"FAIL  content/frameworks/catalog.json: {exc}\nFRAMEWORKS RED")
        return 1
    stack = load(STACK)
    entities = {e["id"]: e for kind in ("frameworks", "sources", "solutions") for e in stack[kind]}
    layers = {l["id"]: l for l in stack["layers"]}

    # 1. the folder holds exactly what the catalog names, and every file parses
    names = {"catalog": "framework-catalog"}
    names.update({i: "framework" for i in catalog.get("frameworks", [])})
    names.update({i: "framework-compare" for i in catalog.get("compares", [])})
    names.update({i: "framework-check" for i in catalog.get("checks", [])})
    present = sorted(p.name for p in DIR.iterdir() if p.is_file() and p.name != ".DS_Store")
    errs = [f"{n}.json is named by the catalog and missing" for n in names if f"{n}.json" not in present]
    errs += [f"{n} is in the folder and named by nothing in the catalog" for n in present if n[:-5] not in names or not n.endswith(".json")]
    docs: dict[str, dict] = {}
    for n in names:
        if f"{n}.json" in present:
            try:
                docs[n] = load(DIR / f"{n}.json")
            except Exception as exc:  # noqa: BLE001
                errs.append(f"{n}.json does not parse: {exc}")
    rep.check("frameworks: the folder holds the catalog and exactly the files it names, and each parses", errs, f"{len(present)} files")

    # 2. schemas
    errs, engine = [], ""
    for n, doc in docs.items():
        got, engine = V.validate_schema(doc, load(SCHEMAS / f"{names[n]}.schema.json"))
        errs += [f"{n}.json {e}" for e in got]
        if doc.get("id", n) != n and n != "catalog":
            errs.append(f"{n}.json holds the id {doc.get('id')!r}")
    rep.check("frameworks: every file validates against its schema in content/schema/, and its id is its file name", errs, engine)

    fws = {i: docs[i] for i in catalog.get("frameworks", []) if i in docs}
    nodes = {i: {n["id"]: n for n in f.get("nodes", [])} for i, f in fws.items()}

    # 3. references
    errs = []
    groups = {g["id"] for g in catalog.get("groups", [])}
    for i, f in fws.items():
        srcs = {s["id"] for s in f.get("sources", [])}
        if len(srcs) != len(f.get("sources", [])):
            errs.append(f"{i}: two sources share an id")
        if f.get("group") not in groups:
            errs.append(f"{i}: no group {f.get('group')!r}")
        if "entityId" in f and f["entityId"] not in entities:
            errs.append(f"{i}: the stack has no entry {f['entityId']!r}")
        errs += [f"{i}: the stack has no layer {l!r}" for l in f["sits"]["layers"] if l not in layers]
        if f["compliance"] and not f["sits"]["layers"]:
            errs.append(f"{i}: a compliance framework that sits on no layer")
        errs += [f"{i}: related {r['id']!r} is not a framework" for r in f["related"] if r["id"] not in fws]
        errs += [f"{i}: related to itself" for r in f["related"] if r["id"] == i]
        errs += [f"{i}: deadline {d['date']} cites the source {d['sourceId']!r}, which it does not have" for d in f["deadlines"] if d["sourceId"] not in srcs]
        own, levels = nodes[i], [l["id"] for l in f["levels"]]
        if len(own) != len(f["nodes"]):
            errs.append(f"{i}: two nodes share an identifier")
        for n in f["nodes"]:
            if n["level"] not in levels:
                errs.append(f"{i}: node {n['id']} is at the level {n['level']!r}, which the file does not define")
            errs += [f"{i}: node {n['id']} names the parent {p!r}, which the file does not hold" for p in n["parents"] if p not in own]
            if "title" not in n and "text" not in n:
                errs.append(f"{i}: node {n['id']} has neither a title nor a text")
        for s in f["sets"]:
            if s["sourceId"] not in srcs:
                errs.append(f"{i}: set {s['id']} cites the source {s['sourceId']!r}, which it does not have")
            if s["of"] not in fws:
                errs.append(f"{i}: set {s['id']} is on {s['of']!r}, which is not a framework")
            else:
                bad = [m for m in s["members"] if m not in nodes[s["of"]]]
                errs += [f"{i}: set {s['id']} names {bad[:5]}, which {s['of']} does not hold"] if bad else []
        for c in f["crosswalks"]:
            if c["sourceId"] not in srcs:
                errs.append(f"{i}: a crosswalk cites the source {c['sourceId']!r}, which it does not have")
            if c["to"] not in fws:
                errs.append(f"{i}: a crosswalk to {c['to']!r}, which is not a framework")
                continue
            host = nodes[c["to"]]
            errs += [f"{i}: the crosswalk starts at {k!r}, which the file does not hold" for k in c["map"] if k not in own]
            bad = sorted({t for v in c["map"].values() for t in v if t not in host and t not in c["unresolved"]})
            errs += [f"{i}: the crosswalk points at {bad[:5]}, which {c['to']} does not hold and the file does not list as unresolved"] if bad else []
            errs += [f"{i}: {t} is listed as unresolved but {c['to']} holds it" for t in c["unresolved"] if t in host]
            errs += [f"{i}: {t} is listed as unresolved but no element points at it" for t in c["unresolved"] if not any(t in v for v in c["map"].values())]
    for land in catalog.get("lands", []):
        errs += [f"{land['id']} lands on {x!r}, which is not a framework" for x in land["frameworkIds"] if x not in fws]
    errs += [f"the catalog features {x!r}, which is not a framework" for x in catalog.get("featured", []) if x not in fws]
    guide = ROOT / "guides" / "zero-trust" / "app" / "guide.json"
    chapters = {c["id"] for c in load(guide)["chapters"]} if guide.exists() else set()
    errs += [f"{i}: the Field Guide has no chapter {f['chapterId']!r}" for i, f in fws.items() if "chapterId" in f and f["chapterId"] not in chapters]
    for n in catalog.get("compares", []):
        c = docs.get(n, {})
        if c and (c["a"] not in fws or c["b"] not in fws):
            errs.append(f"{n}: compares a framework that is not there")
        elif c and not any(w["to"] == y for x, y in ((c["a"], c["b"]), (c["b"], c["a"])) for w in fws[x]["crosswalks"]):
            errs.append(f"{n}: no published crosswalk joins {c['a']} and {c['b']}, so there is no overlap to count")
    for n in catalog.get("checks", []):
        c = docs.get(n, {})
        if not c:
            continue
        if c["frameworkId"] not in fws:
            errs.append(f"{n}: checks {c['frameworkId']!r}, which is not a framework")
            continue
        errs += [f"{n}: item {it['id']} is tied to {it['nodeId']!r}, which {c['frameworkId']} does not hold" for it in c["items"] if it["nodeId"] not in nodes[c["frameworkId"]]]
        if len({it["id"] for it in c["items"]}) != len(c["items"]) or len({a["id"] for a in c["answers"]}) != len(c["answers"]):
            errs.append(f"{n}: two items or two answers share an id")
        if len({a["value"] for a in c["answers"]}) != len(c["answers"]):
            errs.append(f"{n}: two answers share a value, so the next steps cannot be ordered")
    rep.check("frameworks: every reference resolves (groups, stack entries, layers, sources, parents, set members, crosswalks, "
              "comparisons, check items)", errs, f"{len(fws)} frameworks, {sum(len(n) for n in nodes.values())} nodes")

    # 4. counts: what a card says equals what the app shows, and a subset says so
    errs, shown = [], []
    for i, f in fws.items():
        by_level = {l["plural"]: sum(1 for n in f["nodes"] if n["level"] == l["id"]) for l in f["levels"]}
        for size in f["size"]:
            if size["unit"] in by_level and by_level[size["unit"]] != size["count"]:
                errs.append(f"{i}: the card says {size['count']} {size['unit']} and the file holds {by_level[size['unit']]}")
        d = f["depth"]
        if f["nodes"] and d is None:
            errs.append(f"{i}: a structure with no depth line (N of M)")
        if d is not None:
            if not f["nodes"]:
                errs.append(f"{i}: a depth line and no structure")
            if d["shown"] > d["of"]:
                errs.append(f"{i}: shows {d['shown']} of {d['of']}")
            if d["shown"] < d["of"] and not d["why"]:
                errs.append(f"{i}: shows {d['shown']} of {d['of']} {d['unit']} and does not say why")
            if d["shown"] not in by_level.values() and d["shown"] != sum(by_level.values()) - by_level.get(f["levels"][0]["plural"], 0):
                errs.append(f"{i}: the depth line's {d['shown']} is the count of no level the file holds")
            shown.append(f"{f['shortName']} {d['shown']} of {d['of']}")
    rep.check("frameworks: each card's counts equal the structure the app shows, and a structure says how many of how many it "
              "shows, with the reason when it is fewer", errs, "; ".join(shown))

    # 5. sources: on everything, each complete, none overdue
    errs, dated, checked = [], [], str(catalog.get("checkedOn", ""))
    records = [(f"{i}.json", s) for i, f in fws.items() for s in f["sources"]] + [("catalog.json", l["source"]) for l in catalog.get("lands", [])]
    for i, f in fws.items():
        if not f["sources"] and "entityId" not in f:
            errs.append(f"{i}: no source of its own and no stack entry")
        if f["nodes"] and not f["sources"]:
            errs.append(f"{i}: a structure with no source of its own for it")
    for where, s in records:
        v = s["verification"]
        if v["status"] != "unverified" and v["verifiedOn"] > checked:
            errs.append(f"{where} {s['id']}: checked on {v['verifiedOn']}, after the catalog's checkedOn {checked}")
        if s["date"][:10] > checked:
            errs.append(f"{where} {s['id']}: dated {s['date']}, after the catalog's checkedOn {checked}")
        if "recheckAfter" in v:
            dated.append(v["recheckAfter"])
            if v["recheckAfter"] < checked:
                errs.append(f"{where} {s['id']}: recheck was due {v['recheckAfter']}, before {checked}; recheck it and reset the date")
    rep.check("frameworks: sources on everything, each with its publisher, edition, date, link and check; no recheck overdue on the "
              "catalog's checkedOn, nothing dated after it", errs,
              f"{len(records)} sources, {len(dated)} with a recheck date, next {min(dated, default='none')}")

    # 6. terms: licensed and copyrighted text is never reproduced
    errs = []
    for i, f in fws.items():
        t = f["terms"]
        if t["basis"] in ("copyrighted", "licensed", "publisher"):
            if t["shows"] != "structure":
                errs.append(f"{i}: {t['basis']} material may show structure only, not {t['shows']}")
            errs += [f"{i}: node {n['id']} carries the publisher's text" for n in f["nodes"] if "text" in n][:3]
        if t["shows"] in ("titles", "structure"):
            errs += [f"{i}: shows {t['shows']} but node {n['id']} carries text" for n in f["nodes"] if "text" in n][:3]
        if t["basis"] == "mitre" and not t["url"]:
            errs.append(f"{i}: MITRE's terms are not linked")
        if t["basis"] == "mitre" and t["shows"] != "structure" and not t["notice"]:
            errs.append(f"{i}: MITRE's material is listed without the notice its terms require in any copy")
    rep.check("frameworks: copyrighted, licensed and publisher-owned material shows structure only, with no node carrying the "
              "publisher's text; MITRE material carries its terms link and, where it is listed, the required notice", errs,
              ", ".join(sorted({f["terms"]["basis"] for f in fws.values()})))

    # 7. colour
    errs, lowest = [], 99.0
    css = G.STYLES.read_text(encoding="utf-8")
    surfaces = {"light": G.block(css, ":root"), "dark": G.block(css, ':root[data-theme="dark"]')}
    seen: dict[str, str] = {}
    for i, f in fws.items():
        pair = (f["color"]["light"].upper(), f["color"]["dark"].upper())
        if pair in seen.values():
            errs.append(f"{i}: shares its colour with {[k for k, v in seen.items() if v == pair][0]}")
        seen[i] = pair  # type: ignore[assignment]
        for mode in ("light", "dark"):
            tone = rgb(f["color"][mode])
            page, card = rgb(surfaces[mode]["bg"]), rgb(surfaces[mode]["bg-2"])
            grounds = {"the page": page, "the card": card}
            grounds.update({f"the card under its {int(a * 100)}% wash": over(tone, card, a) for a in TINTS})
            for name, ground in grounds.items():
                c = contrast(tone, ground)
                lowest = min(lowest, c)
                if c < MIN_CONTRAST:
                    errs.append(f"{i}: {f['color'][mode]} on {name} in {mode} is {c:.2f}:1, under {MIN_CONTRAST}:1")
    rep.check("frameworks: each framework has its own colour, and it reads at 4.5:1 or better on the page, the card and the "
              "tinted card and chip, in light and in dark", errs, f"lowest {lowest:.2f}:1")

    # 8. house rules
    errs = []
    for n, doc in docs.items():
        raw = (DIR / f"{n}.json").read_text(encoding="utf-8")
        for ch, name in DASHES.items():
            errs += [f"{n}.json:{k}: {name}" for k, line in enumerate(raw.splitlines(), 1) if ch in line][:5]
        errs += [f"{n}.json:{k}: the forbidden word" for k, line in enumerate(raw.splitlines(), 1) if V.FORBIDDEN_WORD in line][:5]
        errs += [f"{n}.json {p}: a straight quote mark" for p in typography.straight(doc)][:5]
        for p, s in walk_strings(doc):
            if EMAIL.search(s):
                errs.append(f"{n}.json {p}: an email address")
            if any(re.search(rf"\b{re.escape(w)}", s, re.I) for w in V.PROCESS_WORDS):
                errs.append(f"{n}.json {p}: planning vocabulary")
            if s != s.strip() or "  " in s:
                errs.append(f"{n}.json {p}: stray white space")
    for i, f in fws.items():
        for key in ("purpose", "what"):
            if not f[key].endswith("."):
                errs.append(f"{i}.{key} does not end as a sentence")
        for key in ("binds", "verifiedBy"):
            if not f[key]["line"].endswith(".") or f[key]["short"].endswith("."):
                errs.append(f"{i}.{key}: the line is a sentence and the short form is not")
    rep.check("frameworks: no em or en dash, no straight quote mark in prose, no forbidden word, no planning vocabulary, no email "
              "address; card texts are sentences and short forms are not", errs, f"{len(docs)} files")

    # 9. the one ruled name, wherever the validator's sweep looks
    errs, seen_name = [], 0
    for scope in V.SWEEP_SCOPES:
        base = ROOT / scope
        for p in ([base] if base.is_file() else sorted(x for x in base.rglob("*") if x.is_file()) if base.exists() else []):
            rel = p.relative_to(ROOT).as_posix()
            if rel.startswith(V.SWEEP_SKIP):
                continue
            if RULED_NAME.search(p.name):
                errs.append(f"{rel}: the name is in a file name")
            try:
                text = p.read_text(encoding="utf-8")
            except (UnicodeDecodeError, OSError):
                continue
            for k, line in enumerate(text.splitlines(), 1):
                hits = len(RULED_NAME.findall(line))
                if hits:
                    seen_name += hits
                    if hits != len(RULED_FORMS.findall(line)):
                        errs.append(f"{rel}:{k}: the word is not the knowledge base's name")
    rep.check("frameworks: the one publisher's name the owner let through the sweep appears only as that name, in capitals or in "
              "MITRE's own addresses, and in no file name", errs[:12], f"{seen_name} uses")

    print("\n".join(rep.lines))
    if rep.failures:
        print(f"FRAMEWORKS RED ({len(rep.failures)} failing check{'s' if len(rep.failures) != 1 else ''})")
        return 1
    print("FRAMEWORKS GREEN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
