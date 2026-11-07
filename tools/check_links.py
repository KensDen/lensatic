#!/usr/bin/env python3
"""The map's source links (content release 1.0.1, Ken's ruling of 5 November 2026: web pages first, PDFs tagged).

Offline (the battery runs this): every url in content/stack.json is counted, and every link to a PDF is known as one: an
address whose path ends in .pdf, a `pdf` field (the PDF edition kept beside a web page, which must end in .pdf), or an
entry marked urlFormat "pdf" (an address that serves a PDF without saying so). On the built map, every link that opens a
PDF (a content url, or an address a note links) carries the PDF tag, right after it or as the link itself, and no other
link does.

Online (--online, run by hand before a release; it needs the network and is never part of the battery): every address
answers 200 after redirects. A Federal Register document page is checked through the Federal Register's own API, since
the site sends scripts to a captcha page. A host that answers every script with 403 (bot protection on the department's
and NSA's sites) is listed apart, to be opened in a browser by hand; the tool never imitates a browser to get past it.

Usage: python3 tools/check_links.py [--online] [--counts]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import subprocess
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STACK = ROOT / "content" / "stack.json"
MAP = ROOT / "docs" / "maps" / "index.html"
PDF_TAG_CLASS = "pdf-tag"
FR_DOC = re.compile(r"^https://www\.federalregister\.gov/documents/\d{4}/\d{2}/\d{2}/([0-9-]+)/")
# hosts that answer any script with 403 whatever it asks: checked in a browser by hand, never by imitating one
BROWSER_ONLY = ("dowcio.war.gov", "media.defense.gov", "www.nsa.gov", "www.esd.whs.mil", "www.war.gov", "www.dcdc.mil")
AGENT = "lensatic-link-check (https://github.com/KensDen/lensatic)"


def is_pdf_address(u: str) -> bool:
    return u.split("#")[0].split("?")[0].lower().endswith(".pdf")


def records(d: dict) -> list[tuple[str, str, bool]]:
    """Every url field in the content as (where, address, opens a PDF)."""
    out: list[tuple[str, str, bool]] = []

    def walk(o, path: str, pdf_marked: bool = False) -> None:
        if isinstance(o, dict):
            marked = o.get("urlFormat") == "pdf"
            for k, v in o.items():
                if k in ("url", "pdf") and isinstance(v, str):
                    out.append((f"{path}.{k}", v, k == "pdf" or (k == "url" and marked) or is_pdf_address(v)))
                else:
                    walk(v, f"{path}.{k}")
        elif isinstance(o, list):
            for i, v in enumerate(o):
                walk(v, f"{path}[{i}]")
    walk(d, "")
    return out


class Links(HTMLParser):
    """Each <a href> on the page, and whether the PDF tag follows it directly."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.links: list[list] = []   # [href, tagged]
        self.last_closed_a: list | None = None
        self.depth_a = 0

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "a":
            # a link drawn as the tag (the PDF kept beside a web page, labelled PDF) is tagged by itself
            self.links.append([a.get("href") or "", PDF_TAG_CLASS in (a.get("class") or "").split()])
            self.depth_a += 1
            self.last_closed_a = None
        elif tag == "span" and PDF_TAG_CLASS in (a.get("class") or "").split() and self.last_closed_a is not None:
            self.last_closed_a[1] = True
            self.last_closed_a = None
        else:
            self.last_closed_a = None

    def handle_endtag(self, tag):
        if tag == "a":
            self.depth_a -= 1
            self.last_closed_a = self.links[-1]

    def handle_data(self, data):
        if data.strip():
            self.last_closed_a = None


def offline(d: dict) -> list[str]:
    errs = []
    recs = records(d)
    pdf_addresses = {u for _, u, p in recs if p}
    for where, u, p in recs:
        if where.endswith(".pdf") and not is_pdf_address(u):
            errs.append(f"{where}: the PDF edition {u} does not end in .pdf")
    if not MAP.exists():
        return errs + [f"{MAP.relative_to(ROOT)} missing"]
    page = Links()
    page.feed(MAP.read_text(encoding="utf-8"))
    for href, tagged in page.links:
        if (href in pdf_addresses or is_pdf_address(href)) and not tagged:
            errs.append(f"the map links {href} without the PDF tag")
        if tagged and href not in pdf_addresses and not is_pdf_address(href):
            errs.append(f"the map tags {href} as a PDF, which it is not")
    return errs


def fetch(u: str) -> int:
    """The status after redirects, through curl and the system's certificate store (some .mil servers send an incomplete
    chain that Python's own store cannot finish); one retry for a timeout."""
    for _ in range(2):
        r = subprocess.run(["curl", "-s", "-o", "/dev/null", "-L", "--max-time", "40", "-A", AGENT, "-w", "%{http_code}", u],
                           capture_output=True, text=True)
        code = int(r.stdout or 0)
        if code:
            return code
    return 0


def online(d: dict) -> int:
    seen: dict[str, int] = {}
    blocked, bad = [], []
    for _, u, _ in records(d):
        if u in seen:
            continue
        m = FR_DOC.match(u)
        if m:
            code = fetch(f"https://www.federalregister.gov/api/v1/documents/{m.group(1)}.json?fields[]=html_url")
        else:
            code = fetch(u)
        seen[u] = code
        host = re.sub(r"^https?://([^/]+).*$", r"\1", u)
        if code == 200:
            continue
        (blocked if code == 403 and host in BROWSER_ONLY else bad).append(f"{code} {u}")
    ok = sum(1 for c in seen.values() if c == 200)
    print(f"check_links --online: {len(seen)} distinct addresses, {ok} answered 200 to the script")
    if blocked:
        print(f"  {len(blocked)} on hosts that refuse scripts (403), to open in a browser:")
        print("\n".join(f"    {x}" for x in blocked))
    if bad:
        print(f"  FAIL {len(bad)} did not answer 200:")
        print("\n".join(f"    {x}" for x in bad))
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--online", action="store_true")
    ap.add_argument("--counts", action="store_true")
    args = ap.parse_args()
    d = json.loads(STACK.read_text(encoding="utf-8"))
    recs = records(d)
    if args.counts:
        print(f"{len(recs)} links in content/stack.json, {sum(1 for r in recs if r[2])} open a PDF, "
              f"{len({r[1] for r in recs})} distinct addresses")
    if args.online:
        return online(d)
    errs = offline(d)
    n_pdf = sum(1 for r in recs if r[2])
    if errs:
        print("FAIL  source links: " + "; ".join(errs[:6]) + (f"; ... {len(errs) - 6} more" if len(errs) > 6 else ""))
        return 1
    print(f"PASS  source links: every link that opens a PDF carries the PDF tag on the map, and no other link does; every "
          f"PDF edition ends in .pdf  ({len(recs)} links, {n_pdf} open a PDF)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
