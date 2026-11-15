#!/usr/bin/env python3
"""What Changed (the iOS redesign, R3): the dated list each content release bundles for the app, generated from the
content diff and the verification log, never written by hand.

Every content release is a version of content/stack.json in the repository's history (the last commit at each
contentVersion), and the working tree is the release being built. Each release from FIRST on is compared with the one
before it, entry by entry (frameworks, sources and solutions), and what a reader would want to know becomes an item.

News, what moved in the world (the R5 rules, item 19):
  added      an entry joins the map because its publisher    dated the entry's own date (the release day when
             put it out after the release before             the entry gives only a month or a year)
  removed    an entry leaves the map (a source replaced or   dated the release day
             expired)
  document   an entry gains a document                     dated the document's own date; named by its shortTitle
  deadline   a deadline's date moves, or a deadline the     dated the release day
             publisher set after the release before appears
  link       an entry's address changes                    dated the release day (not when the old address is kept
                                                             as the PDF beside the publication's web page)

Source checks, shown only when the reader asks (the app's Show Source Checks):
  status     an entry's verification status changes        dated the release day
  recheck    an entry, its authority or one of its          dated the newest of the new verifiedOn dates (the
             documents is re-verified on a later day        verification log)

The framework navigator (Lensatic 2.0, Round 2): the files under content/frameworks/ are compared release by release
too, each framework by its own sources.
  edition    a framework's first source moves to a new       dated that edition's own date; news
             edition (ATT&CK v20.1 to the next)
  recheck    a framework's sources are checked on a later    dated the newest of its sources' verifiedOn dates; a
             day, or a framework is in the folder for the     source check, shown only when the reader asks
             first time, its sources checked then
A navigator item carries its framework's id (frameworkId), which the app opens, and the framework's own stack entry
where it has one, so the item still marks the steps on a path that name that entry.

Lensatic's own news (owner's ruling of 15 November 2026): a release's changelog entry may name, in `news`, what it adds
to Lensatic itself that a reader should hear about, a new trailhead or the framework navigator.
  feature    a headline the release's changelog entry        dated the release day; news. It opens the trailhead
             carries, in the list's own style                question or the Frameworks tab (its `action`)

Apart from those headlines, the app's own additions are not news: an entry the map adds that its publisher put out long before, or a date the map
records for a deadline its source has stated all along, makes no item. Wording and notes, short text for the app, roles
and publishers' spellings are not items either. Each item names its entry,
so the app can say which steps on the reader's path it affects, and its release, so the app can tell what is newer than
the reader's last view. Items run newest release first. The output is deterministic: it depends only on the history and
the working tree.

Usage: python3 tools/build_changes.py            write content/changes.json
       python3 tools/build_changes.py --check    exit 1 if it differs from a fresh generation
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STACK = ROOT / "content" / "stack.json"
OUT = ROOT / "content" / "changes.json"
# the first release the list covers: content 1.2.0 made the trailheads and their steps, which the items point into
FIRST = (1, 2, 0)
EM_DASH = "—"
# each release's last commit, filled by releases(); None is the working tree
COMMITS: dict[str, str | None] = {}
TOKEN = re.compile(r"\{\{\s*([^}]+?)\s*\}\}")


def version(v: str) -> tuple[int, ...]:
    return tuple(int(x) for x in v.split("."))


def releases() -> list[dict]:
    """Each content release once, oldest first: the history's last commit at each version, then the working tree."""
    log = subprocess.run(["git", "-C", str(ROOT), "log", "--reverse", "--format=%H", "--", "content/stack.json"],
                         capture_output=True, text=True)
    if log.returncode:
        sys.exit(f"build_changes: git log failed: {log.stderr.strip()[:200]}")
    by_version: dict[str, dict] = {}
    COMMITS.clear()
    for commit in log.stdout.split():
        show = subprocess.run(["git", "-C", str(ROOT), "show", f"{commit}:content/stack.json"], capture_output=True, text=True)
        if show.returncode:
            continue
        try:
            data = json.loads(show.stdout)
        except json.JSONDecodeError:
            continue
        by_version[data["meta"]["contentVersion"]] = data
        COMMITS[data["meta"]["contentVersion"]] = commit
    current = json.loads(STACK.read_text(encoding="utf-8"))
    by_version[current["meta"]["contentVersion"]] = current
    COMMITS[current["meta"]["contentVersion"]] = None  # the release being built is the working tree
    return [by_version[v] for v in sorted(by_version, key=version)]


def frameworks_at(commit: str | None) -> dict[str, dict]:
    """The navigator's frameworks at a commit (the working tree when None), by id, in the catalog's order; none before
    the folder existed."""
    def read(name: str) -> dict | None:
        if commit is None:
            p = ROOT / "content" / "frameworks" / name
            return json.loads(p.read_text(encoding="utf-8")) if p.exists() else None
        show = subprocess.run(["git", "-C", str(ROOT), "show", f"{commit}:content/frameworks/{name}"], capture_output=True, text=True)
        return json.loads(show.stdout) if show.returncode == 0 else None
    catalog = read("catalog.json")
    if not catalog:
        return {}
    return {i: f for i in catalog["frameworks"] if (f := read(f"{i}.json"))}


def navigator_diff(old: dict[str, dict], new: dict[str, dict], rel: str, day: str) -> list[dict]:
    items: list[dict] = []
    for fid, f in new.items():
        if not f.get("sources"):
            continue  # a card that rests on its stack entry alone: the entry's own items speak for it
        short, was = f["shortName"], old.get(fid)
        def item(kind: str, title: str, date: str) -> None:
            items.append({"id": f"{rel}/framework:{fid}/{kind}", "release": rel, "released": day, "date": date, "kind": kind,
                          "entityId": f.get("entityId", ""), "title": title, "frameworkId": fid})
        first = f["sources"][0]
        if was and was.get("sources") and was["sources"][0]["edition"] != first["edition"]:
            item("edition", f"{short} moves to a new edition", first["date"] if len(first["date"]) == 10 else day)
        checked = sorted(s["verification"]["verifiedOn"] for s in f["sources"] if s["verification"].get("verifiedOn"))
        before = sorted(s["verification"]["verifiedOn"] for s in (was or {}).get("sources", []) if s["verification"].get("verifiedOn"))
        if checked and (not before or checked[-1] > before[-1]):
            item("recheck", f"{short} checked against its source", checked[-1])
    order = {"edition": 0, "recheck": 1}
    return sorted(items, key=lambda i: order[i["kind"]])


def entities(data: dict) -> dict[str, dict]:
    return {e["id"]: e for coll in ("frameworks", "sources", "solutions") for e in data.get(coll, [])}


def resolve(text: str, data: dict) -> str:
    """The department's tokens ({{dow}}, {{dow.current}}) as the content's own fields write them."""
    dow = data.get("orgs", {}).get("dow", {})
    return TOKEN.sub(lambda m: str(dow.get((m.group(1).split(".") + ["abbr"])[1], "")), text)


def verified(e: dict) -> list[str]:
    """Every verifiedOn date on an entry: its own, its authority's and its documents'."""
    out = [e.get("verification", {}).get("verifiedOn"), e.get("authority", {}).get("verification", {}).get("verifiedOn")]
    out += [d.get("verification", {}).get("verifiedOn") for d in e.get("documents") or []]
    return [d for d in out if d]


def diff(old: dict, new: dict, short_titles: dict[str, str]) -> list[dict]:
    rel, day = new["meta"]["contentVersion"], new["meta"]["builtOn"]
    before = old["meta"]["builtOn"]
    a, b = entities(old), entities(new)
    items: list[dict] = []

    def item(kind: str, eid: str, title: str, date: str) -> None:
        items.append({"id": f"{rel}/{eid}/{kind}", "release": rel, "released": day, "date": date, "kind": kind,
                      "entityId": eid, "title": title})

    for eid, e in b.items():
        short = resolve(e["shortName"], new)
        if eid not in a:
            # news only when the publisher put it out after the release before; otherwise the map is catching up
            if (e.get("date") or "") > before:
                item("added", eid, f"{short} joins the map", e["date"] if len(e["date"]) == 10 else day)
            continue
        was = a[eid]
        # a document is the same one when its address, or the PDF it now keeps beside a web page (content 1.3.0), was
        # an address the release before gave it
        urls = {d["url"] for d in was.get("documents") or []}
        for d in e.get("documents") or []:
            if d["url"] not in urls and d.get("pdf") not in urls:
                title = d.get("shortTitle") or short_titles.get(d["url"])
                if not title:
                    sys.exit(f"build_changes: {rel} adds a document to {eid} with no shortTitle for What Changed")
                item("document", eid, resolve(title, new), d["date"])
        due_a = ((was.get("authority", {}).get("deadline") or {}).get("due") or {})
        due_b = ((e.get("authority", {}).get("deadline") or {}).get("due") or {})
        # a date that moves is news; a first date is news only when the source set it after the release before (the map
        # recording a deadline its source has stated all along is not a change)
        moved = due_a.get("date") and due_b.get("date") != due_a.get("date")
        fresh = not due_a.get("date") and (e.get("date") or "") > before
        if due_b and (moved or fresh):
            y, m, dd = (int(x) for x in due_b["date"].split("-"))
            month = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")[m - 1]
            item("deadline", eid, f"{due_b['label']} due {dd} {month} {y}", day)
        # a new address is news; the map pointing to the publication's web page with the same PDF kept beside it is not
        # (content 1.3.0, web pages first)
        if e.get("url") != was.get("url") and e.get("pdf") != was.get("url"):
            item("link", eid, f"{short} has a new link", day)
        sa, sb = was.get("verification", {}).get("status"), e.get("verification", {}).get("status")
        if sa != sb:
            item("status", eid, f"{short} is now {sb}", day)
        newer = sorted(d for d in verified(e) if d > max(verified(was), default=""))
        if newer:
            item("recheck", eid, f"{short} rechecked against its source", newer[-1])
    for eid, e in a.items():
        if eid not in b:
            item("removed", eid, f"{resolve(e['shortName'], old)} leaves the map", day)
    order = {k: i for i, k in enumerate(("added", "removed", "document", "deadline", "status", "link", "recheck"))}
    place = {eid: i for i, eid in enumerate(list(b) + [x for x in a if x not in b])}
    return headlines(new) + sorted(items, key=lambda i: (order[i["kind"]], place[i["entityId"]]))


def headlines(data: dict) -> list[dict]:
    """A release's own news, from its changelog entry: first in the release, in the entry's order."""
    rel, day = data["meta"]["contentVersion"], data["meta"]["builtOn"]
    entry = next((c for c in data["meta"].get("changelog", []) if c.get("version") == rel), {})
    return [{"id": f"{rel}/app:{n['id']}/feature", "release": rel, "released": day, "date": day, "kind": "feature",
             "entityId": "", "title": n["title"], "action": n["opens"]} for n in entry.get("news", [])]


def build() -> dict:
    rels = releases()
    # a document a past release added is named by the short title the current release gives it
    short_titles = {d["url"]: d["shortTitle"] for e in entities(rels[-1]).values() for d in e.get("documents") or [] if d.get("shortTitle")}
    items: list[dict] = []
    for old, new in zip(rels, rels[1:]):
        if version(new["meta"]["contentVersion"]) >= FIRST:
            nav = navigator_diff(frameworks_at(COMMITS[old["meta"]["contentVersion"]]), frameworks_at(COMMITS[new["meta"]["contentVersion"]]),
                                 new["meta"]["contentVersion"], new["meta"]["builtOn"])
            items = diff(old, new, short_titles) + nav + items
    for i in items:
        t = i["title"]
        if EM_DASH in t or "–" in t or t.endswith(".") or len(t) > 60 or not t[:1].isupper():
            sys.exit(f"build_changes: {i['id']}: {t!r} breaks the list's writing rules (no dash, no full stop, at most 60 characters, a capital first)")
    current = rels[-1]["meta"]
    return {"contentVersion": current["contentVersion"], "builtOn": current["builtOn"],
            "from": ".".join(map(str, FIRST)), "items": items}


def render(obj: dict) -> str:
    return json.dumps(obj, indent=1, ensure_ascii=False) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    text = render(build())
    if args.check:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print(f"{OUT.relative_to(ROOT)} is stale; run: python3 tools/build_changes.py")
            return 1
        return 0
    OUT.write_text(text, encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)} ({len(json.loads(text)['items'])} items)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
