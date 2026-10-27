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
as the mockups write it). Counts are never stored: the app counts weeks, groups and plays from these files.
Deterministic: the output depends only on the inputs. The playbook's content object is read by node, exactly as its own
build evaluates it.

Usage: python3 tools/build_library.py            write both files
       python3 tools/build_library.py --check    exit 1 if either differs from a fresh generation
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


def guide_blocks(n: Node, out: list[dict]) -> None:
    """Walk one chapter's elements in order and append its blocks."""
    for k in n.kids:
        if not isinstance(k, Node):
            continue
        t, c = k.tag, k.cls
        if t in ("h3", "h4"):
            out.append({"type": "heading", "text": clean(k.text()), "level": 3 if t == "h3" else 4})
        elif t == "p":
            text = clean(k.text())
            if text:
                out.append({"type": "callout", "label": "", "text": text} if "callout" in c else {"type": "text", "text": text})
        elif t == "blockquote":
            out.append({"type": "callout", "label": "", "text": clean(k.text())})
        elif t == "pre":
            out.append({"type": "text", "text": k.text().strip("\n")})
        elif t in ("ul", "ol"):
            items = []
            for li in (x for x in k.kids if isinstance(x, Node) and x.tag == "li"):
                items.append(clean(li.text()))
            out.append({"type": "list", "ordered": t == "ol", "items": items})
        elif t == "article":
            heads = [x for x in k.kids if isinstance(x, Node) and x.tag in ("h3", "h4")]
            num = heads[0].find(lambda x: "num" in x.cls) if heads else []
            ttl = heads[0].find(lambda x: "ttl" in x.cls) if heads else []
            card = {"eyebrow": clean(num[0].text()).rstrip(".") if num else "",
                    "title": clean(ttl[0].text()) if ttl else (clean(heads[0].text()) if heads else ""),
                    "bullets": [clean(li.text()) for li in k.find(lambda x: x.tag == "li")]}
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
        chapters.append({"id": (h2.attrs.get("id") or "").removesuffix("-h"), "title": clean(h2.text()), "blocks": blocks})
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
    plays = []
    for g in o["navGroups"]:
        for pid in g["ids"]:
            s = o["content"][pid]
            plays.append({"id": pid, "name": label(labels[pid]), "title": clean(s["title"]), "subtitle": clean(s.get("subtitle", "")),
                          "blocks": play_blocks(s)})
    return {"source": "playbook/Playbook/agentic-secops-teaming.jsx", "groups": groups, "plays": plays}


def render(obj: dict) -> str:
    return json.dumps(obj, indent=1, ensure_ascii=False) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    outs = {GUIDE_OUT: render(build_guide()), PLAYS_OUT: render(build_plays())}
    if args.check:
        stale = [p for p, text in outs.items() if not p.exists() or p.read_text(encoding="utf-8") != text]
        for p in stale:
            print(f"{p.relative_to(ROOT)} is stale; run: python3 tools/build_library.py")
        return 1 if stale else 0
    for p, text in outs.items():
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
        print(f"wrote {p.relative_to(ROOT)} ({len(text.encode('utf-8'))} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
