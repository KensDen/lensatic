#!/usr/bin/env python3
"""The iOS app's Library (the redesign, R2): the Zero Trust guide and the Agentic SecOps playbook as plain data the app
draws natively, generated from each section's own source and kept in that section's tree, because the text is theirs.

  guides/zero-trust/app/guide.json   from guides/zero-trust/index.html: the guide's parts as chapters of blocks, and the
                                     eight weeks (the core plan's four, then each track's four)
  playbook/app/plays.json            from playbook/Playbook/agentic-secops-teaming.jsx: the sections (plays) in their nav
                                     groups, each as blocks

Every block is one of a few kinds (heading, text, callout, list, cards, table, stats, links), so the app needs no web
view and no knowledge of either source's markup. Text is copied, not rewritten: the only changes are the ones the app's
writing rules require (an emoji used as an icon or a heading's ornament is left out; " & " in a nav label reads "and",
as the mockups write it), and, from R3, the few that make a website's wording fit a phone (APP_WORDING: the playbook's
"tabs" are the app's plays, its tap-to-expand hints go, a cross-reference to a table in another chapter names the
chapter, a guide chapter's "Part 1." moves to its eyebrow). Counts are never stored: the app counts weeks, groups and
plays from these files.

R3 also adds, for a phone that reads summary first:
  - a summary per chapter and per play, written by hand in each section's app folder (summaries.json) and held here to
    the app's short-text rules: 1 to 3 lines at the app's 17 pt across 350 pt, no one-word last line, no em or en dash,
    no emoji, one closing full stop, and no number that the chapter's or play's own text does not state;
  - an outline: the chapter's or play's section headings, each with the block it opens at;
  - run-in labels ("What it is.") kept apart from their sentence as a lead, so the app sets them bold;
  - the Action Plan play, which the website assembles in the browser from every play's actions, assembled here;
  - the playbook's figures (playbook/app/figures/, rendered by tools/build_figures.mjs): each a figure block placed at
    the end of the section the website shows it in, with its accessible name; the PNGs must be there at their sizes.
Deterministic: the output depends only on the inputs. The playbook's content object is read by node, exactly as its own
build evaluates it.

Usage: python3 tools/build_library.py            write both files
       python3 tools/build_library.py --check    exit 1 if either differs from a fresh generation, or a summary breaks a rule
       python3 tools/build_library.py --lint     the summaries' rule breaks only, with each summary's lines on a phone
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUIDE_HTML = ROOT / "guides" / "zero-trust" / "index.html"
JSX = ROOT / "playbook" / "Playbook" / "agentic-secops-teaming.jsx"
GUIDE_OUT = ROOT / "guides" / "zero-trust" / "app" / "guide.json"
PLAYS_OUT = ROOT / "playbook" / "app" / "plays.json"
GUIDE_SUMMARIES = ROOT / "guides" / "zero-trust" / "app" / "summaries.json"
PLAYS_SUMMARIES = ROOT / "playbook" / "app" / "summaries.json"
# the playbook's figures (R3): tools/build_figures.mjs renders each diagram on the published page to a PNG here, with a
# manifest of where it goes; this tool places each one in its play as a figure block
FIGURES = ROOT / "playbook" / "app" / "figures"

sys.path.insert(0, str(ROOT / "tools"))
import validate as V  # noqa: E402  (the app's text layout: IBM Plex's advance widths, the line breaking, keep_whole)

# a summary sits at the top of a chapter or a play in the app's summary face: IBM Plex Sans 17 pt across 350 pt
SUMMARY_SIZE, SUMMARY_WIDTH, SUMMARY_LINES = 17.0, 350.0, 3

EMOJI = re.compile("[\U0001F000-\U0001FAFF☀-➿⬀-⯿️‍]")
# an emoji in parentheses that the sentence already names ("emoji status markers (✅/❌)") is left out with its brackets
EMOJI_GROUP = re.compile(r"\s*\((?:[\U0001F000-\U0001FAFF☀-➿️]|/)+\)")
SPACE = re.compile(r"\s+")


def clean(s: str) -> str:
    s = EMOJI_GROUP.sub("", s)
    s = EMOJI.sub("", s)
    return SPACE.sub(" ", s).strip()


def label(s: str) -> str:
    return clean(s).replace(" & ", " and ")


# --------------------------------------------------------------------------- the guide

class Node:
    def __init__(self, tag: str, attrs: dict, parent: "Node | None"):
        self.tag, self.attrs, self.parent, self.kids = tag, attrs, parent, []

    @property
    def cls(self) -> set[str]:
        return set((self.attrs.get("class") or "").split())

    def text(self) -> str:
        out = []
        for k in self.kids:
            if isinstance(k, str):
                out.append(k)
            elif k.tag == "br":
                out.append(" ")
            else:
                out.append(k.text())
        return "".join(out)

    def find(self, pred) -> list["Node"]:
        found = []
        for k in self.kids:
            if isinstance(k, Node):
                if pred(k):
                    found.append(k)
                found += k.find(pred)
        return found


VOID = {"br", "img", "hr", "meta", "link", "input", "source", "wbr"}


class Tree(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node("root", {}, None)
        self.cur = self.root

    def handle_starttag(self, tag, attrs):
        n = Node(tag, dict(attrs), self.cur)
        self.cur.kids.append(n)
        if tag not in VOID:
            self.cur = n

    def handle_endtag(self, tag):
        n = self.cur
        while n is not None and n.tag != tag:
            n = n.parent
        if n is not None and n.parent is not None:
            self.cur = n.parent

    def handle_data(self, data):
        self.cur.kids.append(data)


def first_url(n: Node) -> str | None:
    links = n.find(lambda k: k.tag == "a" and (k.attrs.get("href") or "").startswith("http"))
    return links[0].attrs["href"] if links else None


def table_block(div: Node) -> dict:
    head = [clean(th.text()) for th in div.find(lambda k: k.tag == "th" and k.parent.parent.tag == "thead")]
    rows = []
    for tr in div.find(lambda k: k.tag == "tr" and k.parent.tag == "tbody"):
        cells = [c for c in tr.kids if isinstance(c, Node) and c.tag in ("td", "th")]
        row = {"cells": [clean(c.text()) for c in cells]}
        url = first_url(tr)
        if url:
            row["url"] = url
        rows.append(row)
    return {"type": "table", "columns": head, "rows": rows}


def run_in(n: Node) -> tuple[str, str]:
    """A paragraph's or a list item's run-in label and the rest: "<strong>What it is.</strong> A ..." gives ("What it
    is.", "A ..."). A bold opening that is not a short label ending in a full stop or a colon is not a run-in."""
    kids = [k for k in n.kids if not (isinstance(k, str) and not k.strip())]
    if kids and isinstance(kids[0], Node) and kids[0].tag in ("strong", "b"):
        lead = clean(kids[0].text())
        if 0 < len(lead) <= 80 and lead[-1] in ".:?":
            # a paragraph that is all label ("What you will be able to do by the end of Week 8.") is a lead alone
            return lead, clean("".join(k if isinstance(k, str) else (" " if k.tag == "br" else k.text()) for k in kids[1:]))
    return "", clean(n.text())


def guide_blocks(n: Node, out: list[dict]) -> None:
    """Walk one chapter's elements in order and append its blocks."""
    for k in n.kids:
        if not isinstance(k, Node):
            continue
        t, c = k.tag, k.cls
        if t in ("h3", "h4"):
            out.append({"type": "heading", "text": clean(k.text()), "level": 3 if t == "h3" else 4})
        elif t == "p":
            lead, text = run_in(k)
            if text or lead:
                blk = {"type": "callout", "label": "", "text": text} if "callout" in c else {"type": "text", "text": text}
                if lead:
                    blk["lead"] = lead
                out.append(blk)
        elif t == "blockquote":
            out.append({"type": "callout", "label": "", "text": clean(k.text())})
        elif t == "pre":
            out.append({"type": "text", "text": k.text().strip("\n")})
        elif t in ("ul", "ol"):
            items, leads = [], []
            for li in (x for x in k.kids if isinstance(x, Node) and x.tag == "li"):
                lead, text = run_in(li)
                items.append(text)
                leads.append(lead)
            blk = {"type": "list", "ordered": t == "ol", "items": items}
            if any(leads):
                blk["leads"] = leads
            out.append(blk)
        elif t == "article":
            heads = [x for x in k.kids if isinstance(x, Node) and x.tag in ("h3", "h4")]
            num = heads[0].find(lambda x: "num" in x.cls) if heads else []
            ttl = heads[0].find(lambda x: "ttl" in x.cls) if heads else []
            runs = [run_in(li) for li in k.find(lambda x: x.tag == "li")]
            card = {"eyebrow": clean(num[0].text()).rstrip(".") if num else "",
                    "title": clean(ttl[0].text()) if ttl else (clean(heads[0].text()) if heads else ""),
                    "bullets": [text for _, text in runs]}
            if any(lead for lead, _ in runs):
                card["leads"] = [lead for lead, _ in runs]
            if out and out[-1]["type"] == "cards":
                out[-1]["items"].append(card)
            else:
                out.append({"type": "cards", "items": [card]})
        elif t == "div" and "tbl" in c:
            out.append(table_block(k))
        elif t in ("div", "section"):
            guide_blocks(k, out)


def build_guide() -> dict:
    tree = Tree()
    tree.feed(GUIDE_HTML.read_text(encoding="utf-8"))
    main = tree.root.find(lambda k: k.tag == "main")[0]
    chapters = []
    for sec in main.find(lambda k: k.tag == "section" and k.find(lambda h: h.tag == "h2")):
        if sec.parent.tag == "section":
            continue
        h2 = sec.find(lambda h: h.tag == "h2")[0]
        blocks: list[dict] = []
        guide_blocks(sec, blocks)
        if not blocks:
            continue
        chapter = {"id": (h2.attrs.get("id") or "").removesuffix("-h"), "title": clean(h2.text()), "blocks": blocks}
        # a numbered part ("Part 1. The core (Weeks 1 to 4)") keeps its number as the chapter's eyebrow, the title alone
        m = re.fullmatch(r"(Part \d+)\. (.+)", chapter["title"])
        if m:
            chapter = {"id": chapter["id"], "part": m.group(1), "title": m.group(2), "blocks": blocks}
        chapters.append(chapter)
    # the eight weeks: the core plan's four rows, then each track's four, read from the plan tables by their ids
    def plan(heading_id: str) -> list[dict]:
        h = main.find(lambda k: k.attrs.get("id") == heading_id)
        if not h:
            sys.exit(f"build_library: the guide has no {heading_id}")
        n = h[0]
        sib = n.parent.kids[n.parent.kids.index(n) + 1:]
        table = next(x for x in sib if isinstance(x, Node) and "tbl" in x.cls)
        tb = table_block(table)
        if tb["columns"][:1] != ["Week"]:
            sys.exit(f"build_library: {heading_id} is not a weekly plan")
        weeks = []
        for r in tb["rows"]:
            m = re.fullmatch(r"Week (\d+)", r["cells"][0])
            if not m:
                sys.exit(f"build_library: {heading_id} row {r['cells'][0]!r}")
            weeks.append({"week": int(m.group(1)), **{key: cell for key, cell in zip(("read", "apply", "check"), r["cells"][1:])}})
        return weeks
    tracks = []
    for h3 in main.find(lambda k: k.tag == "h3" and "track" in k.cls):
        tid = h3.attrs["id"].removeprefix("track-")
        tracks.append({"id": tid, "name": clean(h3.text()), "weeks": plan(f"{tid}-track-weekly-plan")})
    head = tree.root.find(lambda k: k.tag == "p" and "edition" in k.cls)
    return {"source": "guides/zero-trust/index.html", "edition": clean(head[0].text()) if head else "",
            "core": plan("core-weekly-plan"), "tracks": tracks, "chapters": chapters}


# --------------------------------------------------------------------------- the playbook

NODE_EVAL = r"""
const fs = require('fs');
const src = fs.readFileSync(process.argv[1], 'utf8');
const a = src.indexOf('const palette = {'), b = src.indexOf('const severityColor');
if (a < 0 || b < 0) { console.error('the content object was not found'); process.exit(2); }
const o = new Function(src.slice(a, b) + '; return {sections, navGroups, content};')();
process.stdout.write(JSON.stringify(o));
"""


def play_blocks(s: dict) -> list[dict]:
    out: list[dict] = []
    if s.get("intro"):
        out.append({"type": "text", "text": clean(s["intro"])})
    if s.get("introLink"):
        il = s["introLink"]
        out.append({"type": "text", "text": clean(f"{il['before']}{il['label']}{il['after']}")})
        out.append({"type": "links", "items": [{"label": clean(il["label"]), "url": il["url"]}]})
    if s.get("stats"):
        out.append({"type": "stats", "items": [{"value": clean(x["value"]), "label": clean(x["label"]), "source": clean(x["source"])}
                                               for x in s["stats"]]})
    for b in s.get("body", []):
        if b.get("divider"):
            continue
        if b.get("heading") or b.get("text"):
            blk = {"type": "text", "text": clean(b.get("text", ""))}
            if b.get("heading"):
                blk["heading"] = clean(b["heading"])
            out.append(blk)
        if b.get("paths"):
            out.append({"type": "list", "ordered": False, "items": [clean(p["label"]) for p in b["paths"]]})
        if b.get("links"):
            out.append({"type": "links", "items": [{"label": clean(x["label"]), "url": x["url"]} for x in b["links"]]})
    if s.get("levels"):
        out.append({"type": "cards", "items": [{"eyebrow": f"Level {x['level']}", "title": clean(x["name"]), "text": clean(x["description"]),
                                                "bullets": [clean(e) for e in x.get("examples", [])], "meta": clean(x.get("signals", ""))}
                                               for x in s["levels"]]})
    if s.get("phases"):
        out.append({"type": "cards", "items": [{"eyebrow": clean(f"{x['phase']} · {x['window']} · {x['target']}"), "title": clean(x["name"]),
                                                "text": clean(x["objective"]), "bullets": [clean(m) for m in x.get("moves", [])],
                                                "meta": clean(x.get("exit", ""))} for x in s["phases"]]})
    if s.get("techniques"):
        out.append({"type": "cards", "items": [{"eyebrow": clean(x.get("maturity", "")), "title": clean(x["name"]), "text": clean(x["detail"])}
                                               for x in s["techniques"]]})
    if s.get("questions"):
        q = s["questions"]
        for key in ("a", "b"):
            x = q[key]
            out.append({"type": "cards", "items": [{"eyebrow": clean(f"{x['tag']} · {x['role']}"), "title": clean(x["title"]), "text": clean(x["desc"]),
                                                    "bullets": [clean(i if isinstance(i, str) else json.dumps(i)) for i in x.get("items", [])]}]})
        if q.get("converge"):
            out.append({"type": "callout", "label": "", "text": clean(q["converge"] if isinstance(q["converge"], str) else q["converge"].get("text", ""))})
    for g in s.get("groups", []):
        items = []
        for x in g.get("items", []):
            if "metric" in x:
                items.append({"title": clean(x["metric"]), "text": clean(x.get("note", "")), "meta": clean(x.get("target", ""))})
            elif "term" in x:
                items.append({"title": clean(x["term"]), "text": clean(x["def"])})
            else:
                item = {"eyebrow": clean(x.get("sub", "")), "title": clean(x["name"]), "text": clean(x.get("desc", ""))}
                if x.get("url"):
                    item["url"] = x["url"]
                items.append(item)
        out.append({"type": "cards", "heading": clean(g["group"]), "items": items})
    for cat in s.get("categories", []):
        blk = {"type": "cards", "heading": clean(cat["name"]), "items": []}
        if cat.get("summary"):
            blk["text"] = clean(cat["summary"])
        if cat.get("url"):
            blk["url"] = cat["url"]
        for x in cat.get("items", []):
            item = {"title": clean(x["name"]), "text": clean(x["use"])}
            if x.get("url"):
                item["url"] = x["url"]
            blk["items"].append(item)
        out.append(blk)
    if s.get("papers"):
        out.append({"type": "cards", "items": [{"eyebrow": clean(x.get("tag", "")), "title": clean(x["name"]), "text": clean(x["desc"]),
                                                "meta": clean(x.get("authors", "")), "url": x["url"]} for x in s["papers"]]})
    if s.get("risks"):
        out.append({"type": "cards", "items": [{"eyebrow": clean(" · ".join(v for v in (x.get("severity", ""), x.get("kind", "")) if v)),
                                                "title": clean(x["category"]), "text": clean(x["description"]),
                                                "bullets": [clean(m) for m in x.get("mitigations", [])]} for x in s["risks"]]})
    if s.get("track"):
        out.append({"type": "cards", "items": [{"eyebrow": clean(str(x["wk"])), "title": clean(x["focus"]), "text": clean(x["body"])}
                                               for x in s["track"]]})
    if s.get("labs"):
        out.append({"type": "list", "ordered": False, "items": [clean(f"{x['tag']}: {x['text']}") for x in s["labs"]]})
    for c in s.get("certs", []):
        out.append({"type": "cards", "heading": clean(f"{c['team']} · {c['frame']}"),
                    "items": [{"eyebrow": clean(r["code"]), "title": clean(r["name"]), "text": clean(r["lens"]), "meta": clean(r["cert"]), "url": r["url"]}
                              for r in c["rows"]]})
    if s.get("actions"):
        out.append({"type": "cards", "heading": "Actions", "items": [
            {"eyebrow": clean(f"{a['phase']} · {a['owner']}"), "title": clean(a["text"]),
             "text": clean(a["impl"]["summary"]) if a.get("impl") else "",
             "bullets": [clean(x) for x in (a.get("impl") or {}).get("steps", [])],
             "meta": clean(a["source"])} for a in s["actions"]]})
    if s.get("callout"):
        out.append({"type": "callout", "label": clean(s["callout"]["label"]), "text": clean(s["callout"]["text"])})
    return out


def build_plays() -> dict:
    run = subprocess.run(["node", "-e", NODE_EVAL, str(JSX)], capture_output=True, text=True)
    if run.returncode:
        sys.exit(f"build_library: node could not read the playbook: {run.stderr.strip()[:300]}")
    o = json.loads(run.stdout)
    labels = {s["id"]: s["label"] for s in o["sections"]}
    groups = [{"label": label(g["label"]), "playIds": g["ids"]} for g in o["navGroups"]]
    grouped = [i for g in o["navGroups"] for i in g["ids"]]
    if sorted(grouped) != sorted(labels) or len(set(grouped)) != len(grouped):
        sys.exit("build_library: the nav groups do not hold every section once")
    figures = json.loads((FIGURES / "figures.json").read_text(encoding="utf-8"))["figures"]
    placed = {f["id"]: False for f in figures}
    plays = []
    for g in o["navGroups"]:
        for pid in g["ids"]:
            s = o["content"][pid]
            blocks = action_plan(o, labels) if pid == ACTION_PLAN else play_blocks(s)
            blocks = with_figures(pid, blocks, figures)
            plays.append({"id": pid, "name": label(labels[pid]), "title": clean(s["title"]), "subtitle": clean(s.get("subtitle", "")),
                          "blocks": blocks})
    missing = [f["id"] for f in figures if not any(b.get("figure") == f["id"] for p in plays for b in p["blocks"])]
    if missing:
        sys.exit(f"build_library: figures with no place in their play: {missing}")
    return {"source": "playbook/Playbook/agentic-secops-teaming.jsx", "groups": groups, "plays": plays}


def png_size(path: Path) -> tuple[int, int]:
    import struct
    head = path.read_bytes()[:24]
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        sys.exit(f"build_library: {path.relative_to(ROOT)} is not a PNG")
    return struct.unpack(">II", head[16:24])


def with_figures(pid: str, blocks: list[dict], figures: list[dict]) -> list[dict]:
    """A play's blocks with its figures placed: each at the end of the section headed by its manifest's "after" (before
    the next headed block), or after the play's opening block when it has none, in the manifest's order."""
    out = list(blocks)
    texts = figure_texts()
    for f in (f for f in figures if f["play"] == pid):
        for path in [] if f.get("native") else [FIGURES / f"{f['id']}.png", FIGURES / "light" / f"{f['id']}.png"]:
            if not path.exists():
                sys.exit(f"build_library: {path.relative_to(ROOT)} is missing")
            w, h = png_size(path)
            if (w, h) != (f["width"], f["height"]) and not ("light" in path.parts and abs(w - f["width"]) <= 3 and abs(h - f["height"]) <= max(6, f["height"] // 100)):
                sys.exit(f"build_library: {path.relative_to(ROOT)} is {w} x {h}, not {f['width']} x {f['height']}")
        if f["after"] is None:
            at = 1
            while at < len(out) and out[at]["type"] == "figure":
                at += 1
        else:
            heads = [i for i, b in enumerate(out) if (b.get("heading") or (b.get("text") if b["type"] == "heading" else None)) == f["after"]]
            if len(heads) != 1:
                sys.exit(f"build_library: figure {f['id']}: {len(heads)} blocks in {pid} are headed {f['after']!r}")
            at = heads[0] + 1
            while at < len(out) and not out[at].get("heading") and not (out[at]["type"] == "heading"):
                at += 1
        block = {"type": "figure", "figure": f["id"], "alt": f["alt"], "description": texts[f["id"]]["description"]}
        if f.get("native"):
            block |= {"native": True, "caption": texts[f["id"]]["caption"], "parts": texts[f["id"]]["parts"]}
        else:
            block |= {"width": f["width"], "height": f["height"]}
        out.insert(at, block)
    return out


def figure_texts() -> dict:
    """Each figure's VoiceOver description (R4), and the caption under a native one, from figures/descriptions.json:
    1 to 4 sentences, at most 480 characters, no dash; a native figure has a caption and its drawing's words (parts),
    each found word for word in the playbook's source, and a drawn one neither."""
    source = JSX.read_text(encoding="utf-8")
    texts = json.loads((FIGURES / "descriptions.json").read_text(encoding="utf-8"))["figures"]
    manifest = {f["id"]: f for f in json.loads((FIGURES / "figures.json").read_text(encoding="utf-8"))["figures"]}
    if set(texts) != set(manifest):
        sys.exit(f"build_library: figure descriptions do not match the manifest: {sorted(set(texts) ^ set(manifest))}")
    for fid, t in texts.items():
        d = t.get("description", "")
        sentences = len(re.findall(r"[.!?](?:\s|$)", d))
        if not 1 <= sentences <= 4 or len(d) > 480 or not d.endswith("."):
            sys.exit(f"build_library: figure {fid}: a description is 1 to 4 sentences, at most 480 characters, ending with a period")
        if not (bool(manifest[fid].get("native")) == ("caption" in t) == ("parts" in t)):
            sys.exit(f"build_library: figure {fid}: a native figure has a caption and parts, and a drawn one neither")
        for text in [t.get("caption", "")] + t.get("parts", []):
            if text not in source:
                sys.exit(f"build_library: figure {fid}: {text!r} is not in the playbook's source")
        for text in (d, t.get("caption", "")):
            if "\u2014" in text or "\u2013" in text:
                sys.exit(f"build_library: figure {fid}: a dash in its text")
    return texts


ACTION_PLAN = "actionplan"
PHASES = ("Now", "Next", "Later")


def action_plan(o: dict, labels: dict) -> list[dict]:
    """The Action Plan, which the website assembles in the browser: its intro paragraph from the page's own markup, then
    every play's actions by phase (Now, Next, Later), in the order the website lists them, each naming and opening the
    play it comes from. The steps of each action stay in its play."""
    src = JSX.read_text(encoding="utf-8")
    m = re.search(r"\n\s*(This tab aggregates every Recommended Action[^<{]*?)\s*\n", src)
    if not m:
        sys.exit("build_library: the Action Plan's intro paragraph was not found")
    intro = clean(m.group(1))
    # the website's intro, for a phone: its first sentence is the play's summary already, and its definitions read as
    # words, not "Now = ..."
    defs = "Now = start immediately. Next = once the Now items are moving. Later = as the program matures."
    if not intro.endswith(defs):
        sys.exit("build_library: the Action Plan's definitions of Now, Next and Later changed in the source")
    out: list[dict] = [{"type": "text", "text": "Now means start immediately; Next, once the Now items are moving; and Later, as the program matures."}]
    for phase in PHASES:
        items = []
        for pid, v in o["content"].items():
            for a in v.get("actions") or []:
                if a.get("phase") == phase:
                    item = {"eyebrow": clean(f"{label(labels.get(pid, pid))} · {a['owner']}"), "title": clean(a["text"]), "play": pid}
                    if a["source"] != "Playbook":  # an action the playbook sources to itself names no source here
                        item["meta"] = clean(a["source"])
                    items.append(item)
        if items:
            out.append({"type": "cards", "heading": phase, "items": items})
    if len(out) == 1:
        sys.exit("build_library: no play has an action for the Action Plan")
    return out


# --------------------------------------------------------------------------- the app's wording (R3)

# The playbook's website names its sections "tabs" and its cards expand on a tap; in the app the sections are plays and
# the cards are drawn open. A playbook label with "&" reads "and" when it names a play, as the app's play names do.
TAB = re.compile(r"\btab(s|'s)?\b")
TAP_HINTS = (" Tap any card to expand.", "Tap any source to expand its key concepts. ", " Tap any to expand its core elements.",
             " Tap any to expand.", "; tap to expand.")
# the website's references that do not hold on a phone, each rewritten where it stands, counted so a change in the
# source that moves one fails the check instead of slipping through: (old, new, expected count)
GUIDE_WORDING = (
    ("Pick your track using the table above.", "Pick your track with the \u201cWhich track are you?\u201d table in How to use this guide.", 2),
)
PLAYS_WORDING = (
    ("Each name above is a tab in the navigation.", "Each name above is a play in the Library.", 1),
)


def strings(o, fn, skip=("url", "id", "play", "playIds", "figure")):
    """o with fn applied to every string in it but the addresses and ids."""
    if isinstance(o, dict):
        return {k: (v if k in skip else strings(v, fn, skip)) for k, v in o.items()}
    if isinstance(o, list):
        return [strings(v, fn, skip) for v in o]
    return fn(o) if isinstance(o, str) else o


def reword(doc: dict, wording, extra=None) -> dict:
    seen = {old: 0 for old, _, _ in wording}

    def fn(t: str) -> str:
        for old, new, _ in wording:
            seen[old] += t.count(old)
            t = t.replace(old, new)
        return extra(t) if extra else t
    out = strings(doc, fn)
    for old, _, want in wording:
        if seen[old] != want:
            sys.exit(f"build_library: {old!r} appears {seen[old]} times in the source, the wording expects {want}")
    return out


def plays_wording(doc: dict) -> dict:
    names = {}
    for p in doc["plays"]:
        names.setdefault(p["name"].replace(" and ", " & "), p["name"])
    amp = [web for web, app in names.items() if web != app]
    hints = {h: 0 for h in TAP_HINTS}

    def fn(t: str) -> str:
        for h in TAP_HINTS:
            hints[h] += t.count(h)
            t = t.replace(h, "." if h.startswith(";") else "")
        if TAB.search(t):
            for web in amp:  # "the OT, ICS & SCADA tab" names the play "OT, ICS and SCADA"
                t = re.sub(re.escape(web) + r"(?=(?:,? (?:and )?[^.;()]{0,60})?\s+tab)", names[web], t)
            t = TAB.sub(lambda m: "play" + (m.group(1) or ""), t)
        return t.strip()
    out = reword(doc, PLAYS_WORDING, fn)
    if missing := [h for h, n in hints.items() if not n]:
        sys.exit(f"build_library: the tap hints {missing} are no longer in the source")
    return out


# --------------------------------------------------------------------------- summaries and outlines (R3)

def outline(blocks: list[dict]) -> list[dict]:
    """A chapter's or a play's sections: each top-level heading and the block it opens at. A chapter with fewer than
    two headings is laid out in cards (the guide's documents, a quick reference's parts), so its outline is its cards'
    titles, each with the card it opens at."""
    out = []
    for i, b in enumerate(blocks):
        title = b.get("text") if b["type"] == "heading" and b.get("level") == 3 else b.get("heading")
        if title and b["type"] in ("heading", "text", "cards"):
            out.append({"title": title, "block": i})
    if len(out) < 2:
        cards = [{"title": c["title"], "block": i, "card": j} for i, b in enumerate(blocks) if b["type"] == "cards"
                 for j, c in enumerate(b["items"]) if c.get("title")]
        if len(cards) >= 2:
            return cards
    return out


def block_text(o) -> str:
    return " ".join(strings_of(o))


def strings_of(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k not in ("url", "id", "play", "playIds"):
                yield from strings_of(v)
    elif isinstance(o, list):
        for v in o:
            yield from strings_of(v)
    elif isinstance(o, str):
        yield o


_FONT = None


def summary_lines(text: str) -> list[str]:
    global _FONT
    _FONT = _FONT or V.ttf_advances(V.PLEX_SANS)
    return V.lay_out(text, SUMMARY_SIZE, SUMMARY_WIDTH, _FONT)


def summary_errors(where: str, text: str | None, source: str) -> list[str]:
    """The short-text rules, as content check 17 holds the card's short summary to them."""
    if not text:
        return [f"{where}: no summary"]
    errs = []
    if V.EM_DASH in text or "\u2013" in text:
        errs.append(f"{where}: em or en dash")
    if re.search("[\U0001F000-\U0001FAFF\u2600-\u27BF\uFE0F]", text):
        errs.append(f"{where}: emoji")
    if not text.endswith(".") or text.endswith("..") or "  " in text or text != text.strip():
        errs.append(f"{where}: one sentence or two, ending in one full stop, single-spaced")
    for num in re.findall(r"\d+(?:\.\d+)*", text):
        if not re.search(rf"(?<![\d.]){re.escape(num)}(?![\d])", source):
            errs.append(f"{where}: the number {num} is not in its text")
    lines = summary_lines(text)
    if len(lines) > SUMMARY_LINES:
        errs.append(f"{where}: {len(lines)} lines on a phone, at most {SUMMARY_LINES}")
    if len(lines) > 1 and len(lines[-1].replace(V.NBSP, " ").split()) < 2:
        errs.append(f"{where}: ends on one word ({lines[-1]!r})")
    return errs


def with_summaries(doc: dict, key: str, path: Path) -> tuple[dict, list[str]]:
    """Each chapter or play with its summary (from the section's summaries.json) and its outline, and the rule breaks."""
    given = json.loads(path.read_text(encoding="utf-8")).get(key, {}) if path.exists() else {}
    errs = []
    items = []
    for it in doc[key]:
        text = given.get(it["id"])
        source = block_text([it.get("title"), it.get("subtitle"), it["blocks"]])
        errs += summary_errors(f"{path.relative_to(ROOT)} {key}.{it['id']}", text, source)
        out = {k: v for k, v in it.items() if k != "blocks"}
        if text:
            out["summary"] = text
        out["outline"] = outline(it["blocks"])
        out["blocks"] = it["blocks"]
        items.append(out)
    errs += [f"{path.relative_to(ROOT)}: {k} has no {key[:-1]} of that id" for k in given if k not in {i['id'] for i in doc[key]}]
    return {**doc, key: items}, errs


def render(obj: dict) -> str:
    return json.dumps(obj, indent=1, ensure_ascii=False) + "\n"


def build() -> tuple[dict, dict, list[str]]:
    guide = reword(build_guide(), GUIDE_WORDING)
    plays = plays_wording(build_plays())
    guide, e1 = with_summaries(guide, "chapters", GUIDE_SUMMARIES)
    plays, e2 = with_summaries(plays, "plays", PLAYS_SUMMARIES)
    return guide, plays, e1 + e2


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--lint", action="store_true")
    args = ap.parse_args()
    guide, plays, errs = build()
    if args.lint:
        for key, doc in (("chapters", guide), ("plays", plays)):
            for it in doc[key]:
                if it.get("summary"):
                    print(f"{key}.{it['id']}: " + " / ".join(summary_lines(it["summary"])))
        print("\n".join(errs) or "summaries: no rule broken")
        return 1 if errs else 0
    outs = {GUIDE_OUT: render(guide), PLAYS_OUT: render(plays)}
    if args.check:
        stale = [p for p, text in outs.items() if not p.exists() or p.read_text(encoding="utf-8") != text]
        for p in stale:
            print(f"{p.relative_to(ROOT)} is stale; run: python3 tools/build_library.py")
        for e in errs:
            print(e)
        return 1 if stale or errs else 0
    for e in errs:
        print(f"warning: {e}")
    for p, text in outs.items():
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
        print(f"wrote {p.relative_to(ROOT)} ({len(text.encode('utf-8'))} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
