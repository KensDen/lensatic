#!/usr/bin/env python3
"""Battery checks for the built single-file wrapper (sessions 3 and 4).

Build: determinism (two builds byte-identical), the built file matches a fresh build, the embedded JSON is
byte-identical to content/stack.json (SHA-256), size under 1 MB, both inline scripts parse.
Wall and offline: no resource-loading attribute or call (src, srcset, <link>, @import, url(, fetch( and
the like; links to primaries are plain anchors), no em dash, sweep clean, no forbidden word, no
leftover template placeholder or render token.
Static render (Session 4): the rendered text of every door and step, layer, framework, source, solution,
helper, function, SOC Profile row, and every matrix cell in both views is present in the HTML outside
any hidden element, counted and asserted for every item, in the built file and again in a copy with every
script element removed except the embedded JSON; no section of that copy is empty.
Layout (Session 4): a headless Chrome, Chromium or Edge measures the collapsed DoW table at 1280 and
1440 (fail if wider than the viewport at 1280), checks the page for sideways overflow at 375, 1280 and
1440 and for content clipped past the right edge at 360 to 414 with every disclosure open, exercises the
column buttons, arrow keys and back to top at 375, reads the visible text with scripting disabled, and
reads the print rendering.
Pages (Session 6): docs/index.html is web/lensatic.html byte for byte; docs/ matches a fresh --pages build
(index, privacy, support, the social card, an empty .nojekyll); the privacy and support pages carry no script and
pass the same resource, em-dash, placeholder and sweep rules as the app, show the effective date, content version and
every paragraph from content, and spell abbreviations out at first use; no email address appears anywhere in docs/;
every external link in the app sits inside Sources, as the privacy policy says, except the policy, support and source
repository links.
The new look (Session 7): the only url( in any page is an embedded @font-face source, a data: URI that decodes to one
of the four pinned faces; the tab icon is an SVG data URI with no reference in it; the colour tokens meet the contrast
floors; labels carry no expansion and describe their abbreviations (the label set is read from build_web.py); every
door is closed in the static render and its card shows its title, first sentence and meta line; the front door holds
exactly its five parts; the footer carries the three addresses; docs/ holds exactly one image, the social card, byte
for byte, and the link-preview tags point at the published site; the intro texts that moved render exactly once.
Licensing (Session 7B): the footer's licence line, the About paragraph and the support page's sentence on reuse are
the all-rights-reserved wording ruled for content 0.7.0.
Link previews (Session 9): og:description is meta.pitch; the description tag stays meta.description.
Session 11 (Q20, Q21, Q36): every in-page link lands on an element; layer tags name a layer by its number, or the AI
column by its name, and link to it; links to entries, capability-name lists and entry titles are labels (the classes are
pinned); citation lines give the edition by the ruled rule (left out where it repeats the title or the date, a
descriptive one lowered), pinned on the ledger's cases; entry summaries keep a space between title, badges and citation;
every Unverified or Conflict document shows its verification note; AI Risk Management Framework counts as AI RMF spelled
out; print shows each department cell's capability numbers before its sentence and leaves out the hero's buttons.
The embedded JSON element is exempt from the text checks: it is content/stack.json byte for byte and is
checked by the content battery; its URLs are data, its render tokens are data.
"""
from __future__ import annotations

import base64
import codecs
import hashlib
import html as htmllib
import json
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STACK = ROOT / "content" / "stack.json"
HTML = ROOT / "web" / "lensatic.html"
DOCS = ROOT / "docs"
DOC_FILES = ("index.html", "privacy.html", "support.html", "social-card.png", ".nojekyll")
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".avif", ".svg", ".ico", ".bmp"}
SOCIAL_SRC = ROOT / "web" / "src" / "social-card.png"
SITE = "https://kensden.github.io/lensatic/"
STYLES = ROOT / "web" / "src" / "styles.css"
FONT_DIR = ROOT / "web" / "src" / "fonts"
# the one @font-face shape the build writes; anything else with url( fails the resource check
FONT_FACE_RE = re.compile(r"@font-face \{ font-family: '([^']+)'; font-style: normal; font-weight: (\d+); font-display: swap; "
                          r"src: url\(data:font/woff2;base64,([A-Za-z0-9+/=]+)\) format\('woff2'\); \}")
# the only outside links the privacy policy allows the app beyond the documents cited in Sources (session 7, section 6.2)
POLICY_LINKS = ("https://kensden.github.io/lensatic/privacy.html", "https://kensden.github.io/lensatic/support.html",
                "https://github.com/KensDen/lensatic")
# the licensing wording the owner ruled on 27 Sep 2026 (session 7B, content 0.7.0): the footer's licence line, the About
# paragraph and the support page's sentence on reuse. The page renders them from content; content must say exactly this.
LICENCE_FOOTER = "All rights reserved · Fonts OFL"
LICENCE_ABOUT = ("Most of the frameworks Lensatic describes are United States government publications. Works prepared by United States "
                 "government officers and employees as part of their official duties are in the public domain in the United States. "
                 "Lensatic's own code and text are copyright 2026 Ken Connell, all rights reserved; to ask about reusing them, open an "
                 "issue on the source repository. IBM Corp. holds the copyright in the typefaces, IBM Plex Sans and IBM Plex Mono, which "
                 "are licensed under the SIL Open Font License (OFL), version 1.1. Where a cited work is protected, its title, names and "
                 "any short quotation remain its owner's, and the work itself is described, not reproduced.")
LICENCE_SUPPORT = "To ask about reusing Lensatic's code or text, open an issue on the same page."
# the owner's ruling of 27 Sep 2026 (session 7D): these terms, and only these, are marked wellKnown in the glossary and
# never spelled out on any built page; the guard reads this pin, not the content flag, so dropping the flag fails it
WELL_KNOWN = {"AI": "artificial intelligence"}
# session 11 (Q21, ED-05): the texts that name an entry are labels; the guard reads this pin, not only build_web's set
LABEL_PINS = frozenset({"ref", "caps-list", "ent-title"})
# session 11 (Q21, ED-06): a name with a well-known term written short counts as spelled out
SPELLED_PINS = {"AI RMF": "AI Risk Management Framework"}
# session 11 (Q20, ED-04): in print each key/value value is kept whole, so a note and its status pill stay together and no
# part of a row carried over a page or column break overprints the next row (Chrome's grid fragmentation)
PRINT_KEEP = re.compile(r"(?m)^\s*dl\.kv\s*>\s*dd\s*\{[^}]*\bbreak-inside:\s*avoid\s*;")
# session 11 (Q21: ED-09, ED-10, RED-06): (title, edition, date, the edition the citation line gives), the ledger's cases
# and designations that keep their capital; None is an edition the line leaves out
CITE_RULINGS = (
    ("Class Deviation 2024-O0013, Revision 1: Safeguarding Covered Defense Information and Cyber Incident Reporting", "Revision 1", "2024-05-22", None),
    ("Zero Trust PfMO Newsletter", "November 2024", "2024-11", None),
    ("NSA Zero Trust Guidance", "Eight cybersecurity information sheets (2021 to 2024) and four implementation guidelines (2026)", "2026-05-28",
     "eight cybersecurity information sheets (2021 to 2024) and four implementation guidelines (2026)"),
    ("The AI Defense Matrix", "None printed (copyright 2026)", "2026", "none printed (copyright 2026)"),
    ("Cyber Operational Readiness Assessment (CORA) program", "Program; no printed edition", "2024-02-28", "program; no printed edition"),
    ("DISA awards Thunderdome production agreement", "Production agreement awarded 28 July 2023; no printed edition", "2023-08-02",
     "production agreement awarded 28 July 2023; no printed edition"),
    ("DoD Zero Trust Strategy", "Version 1.0", "2022-10-21", "Version 1.0"),
    ("Security and Privacy Controls for Information Systems and Organizations", "Revision 5 (includes updates as of 10 December 2020)", "2020-09",
     "Revision 5 (includes updates as of 10 December 2020)"),
    ("Improving the Nation's Cybersecurity", "Executive Order 14028", "2021-05-12", "Executive Order 14028"),
    ("Implementing Suspension of CMMC Phase II (memorandum)", "Acquisition and Sustainment memorandum with Attachment 1, CMMC procedures",
     "2026-07-13", "Acquisition and Sustainment memorandum with Attachment 1, CMMC procedures"),
    ("Removing Barriers to Defense Industrial Base Expansion", "CIO memorandum", "2026-07-13", "CIO memorandum"),
)
ISSUES_URL = "https://github.com/kensden/lensatic/issues"
# the one image element the page may hold: the maker's photo in About, embedded (session 7D); the photo check below
# decodes it against the pinned file, and any other <img> or src still fails the resource check
PHOTO = ROOT / "web" / "src" / "about-photo.jpg"
PHOTO_IMG_RE = re.compile(r'<img class="name-photo" src="data:image/jpeg;base64,([A-Za-z0-9+/=]+)" alt="([^"<>]*)" width="(\d+)" height="(\d+)">')
EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}")
BUILD = ROOT / "tools" / "build_web.py"
DOM_CHECK = ROOT / "tools" / "dom_check.mjs"
LAYOUT = ROOT / "tools" / "layout_check.mjs"
TMP = ROOT / ".tmp"  # every temporary file stays inside the repo (Session rules in README.md)
# the built page must stay under 1 MB (1,048,576 bytes); session 13 raised the limit from 900 KB (921,600 bytes)
PAGE_LIMIT = 1024 * 1024
# each printout, with script and without, is at most 20 pages; session 15 raised the cap from under 20
PRINT_PAGES = 20
sys.path.insert(0, str(ROOT / "tools"))
import validate as V  # noqa: E402
import build_web as B  # noqa: E402  (the label set, defined once there)

OPEN = '<script type="application/json" id="stack">'
CLOSE = "</script>"
VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr", "path", "circle"}
BLOCK = {"p", "div", "li", "ul", "ol", "summary", "details", "td", "th", "tr", "table", "caption", "thead", "tbody", "dt", "dd",
         "dl", "h1", "h2", "h3", "h4", "section", "article", "aside", "header", "main", "nav", "br"}
SKIP = {"script", "style", "template", "svg"}


# --------------------------------------------------------------------------- html tree
class Node:
    __slots__ = ("tag", "attrs", "children", "parent")

    def __init__(self, tag: str, attrs: dict, parent: "Node | None") -> None:
        self.tag, self.attrs, self.children, self.parent = tag, attrs, [], parent


class Tree(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.root = Node("#root", {}, None)
        self.cur = self.root
        self.ids: dict[str, list[Node]] = {}
        self.starts: list[tuple[str, dict]] = []

    def handle_starttag(self, tag, attrs):
        a = {k: (v if v is not None else "") for k, v in attrs}
        self.starts.append((tag, a))
        n = Node(tag, a, self.cur)
        self.cur.children.append(n)
        if "id" in a:
            self.ids.setdefault(a["id"], []).append(n)
        if tag not in VOID:
            self.cur = n

    def handle_startendtag(self, tag, attrs):
        a = {k: (v if v is not None else "") for k, v in attrs}
        self.starts.append((tag, a))
        n = Node(tag, a, self.cur)
        self.cur.children.append(n)
        if "id" in a:
            self.ids.setdefault(a["id"], []).append(n)

    def handle_endtag(self, tag):
        n = self.cur
        while n is not None and n.tag != tag:
            n = n.parent
        if n is not None and n.parent is not None:
            self.cur = n.parent

    def handle_data(self, data):
        self.cur.children.append(data)


def parse(text: str) -> Tree:
    t = Tree()
    t.feed(text)
    t.close()
    return t


def hidden_within(n: Node) -> bool:
    while n is not None:
        if "hidden" in n.attrs:
            return True
        n = n.parent
    return False


def text_of(n: Node, skip_classes: frozenset = frozenset({"xp"})) -> str:
    """Rendered text of an element. By default the expansions the build adds after abbreviations are left out,
    so content texts compare byte for byte; the glossary checks pass their own class set."""
    if n.tag in SKIP or "hidden" in n.attrs or n.attrs.get("aria-hidden") == "true":
        return ""
    if skip_classes and set(n.attrs.get("class", "").split()) & skip_classes:
        return ""
    out = []
    for c in n.children:
        if isinstance(c, str):
            out.append(c)
        else:
            t = text_of(c, skip_classes)
            out.append(f" {t} " if c.tag in BLOCK else t)
    return "".join(out)


# --------------------------------------------------------------------------- expected text
def walk_nodes(n: Node):
    yield n
    for c in n.children:
        if not isinstance(c, str):
            yield from walk_nodes(c)


def classes_of(n: Node) -> set[str]:
    return set(n.attrs.get("class", "").split())


def is_label(n: Node) -> bool:
    return B.is_label(n.tag, classes_of(n))


def spaced_text(n: Node, skip_classes: frozenset, skip_labels: bool = False) -> str:
    """Rendered text with a space at every element boundary, so adjacent chips and links never run together.
    With skip_labels the text of every label (build_web.LABEL_TAGS and LABEL_CLASSES) is left out: running text only."""
    if n.tag in SKIP or "hidden" in n.attrs or n.attrs.get("aria-hidden") == "true":
        return ""
    if skip_classes and classes_of(n) & skip_classes:
        return ""
    if skip_labels and is_label(n):
        return " "
    return "".join(c if isinstance(c, str) else f" {spaced_text(c, skip_classes, skip_labels)} " for c in n.children)


def norm(s: str) -> str:
    return B.text_norm(s)


def present(t, body: str) -> bool:
    """A content text is present in a rendered body. A split text (a tuple: the first sentence on a door card and the
    rest in its body) is present when every part is, in order."""
    if isinstance(t, str):
        return t in body
    pos = 0
    for part in t:
        i = body.find(part, pos)
        if i < 0:
            return False
        pos = i + len(part)
    return True


def parts_of(t) -> list[str]:
    return [t] if isinstance(t, str) else list(t)


def split_first(s: str):
    return B.split_first(s)


def expected_items(d: dict) -> tuple[dict[str, list], dict[str, int]]:
    """The population the static-render check counts; defined once, in build_web.py, which --texts also writes."""
    return B.static_texts(d)


# texts that render exactly once on the page (Session 7, section 4.4), by label key
ONCE = ("audience", "ztPlain", "doorsIntro", "dowNote")


def first_sentence_of(s: str) -> tuple[str, str]:
    m = re.match(r"^(.*?[.!?])(\s|$)", s or "")
    return (m.group(1), s[len(m.group(1)):].strip()) if m else (s or "", "")


def tok_dow(d: dict, s: str) -> str:
    dow = d["orgs"]["dow"]
    return re.sub(r"\{\{\s*dow(?:\.([A-Za-z]+))?\s*\}\}", lambda m: str(dow.get(m.group(1), "")) if m.group(1) else dow["abbr"], s or "")


def check_static(html_text: str, items: dict[str, list[str]], label: str) -> tuple[list[str], int]:
    tree = parse(html_text)
    errs, n = [], 0
    for eid, texts in items.items():
        nodes = tree.ids.get(eid, [])
        if len(nodes) != 1:
            errs.append(f"{label}: #{eid} found {len(nodes)} times")
            continue
        node = nodes[0]
        if hidden_within(node):
            errs.append(f"{label}: #{eid} sits inside a hidden element")
            continue
        body = norm(text_of(node))
        for t in texts:
            n += 1
            if not present(t, body):
                errs.append(f"{label}: #{eid} lacks {parts_of(t)[0][:70]!r}")
            elif not isinstance(t, str) and body.count(t[0]) != 1:
                errs.append(f"{label}: #{eid} repeats {t[0][:70]!r}")
    return errs, n


def icon_errors(href: str) -> list[str]:
    """The tab icon: an SVG data URI that refers to nothing (its only address is the SVG namespace)."""
    if not href.startswith("data:image/svg+xml,"):
        return ["the tab icon is not an SVG data URI"]
    svg = urllib.parse.unquote(href[len("data:image/svg+xml,"):])
    errs = [f"the tab icon holds {w!r}" for w in ("href", "url(", "@import", "<image", "<use", "<script", "<style", "<foreignobject", "src=")
            if w in svg.lower()]
    if re.sub(r'xmlns="http://www\.w3\.org/2000/svg"', "", svg).lower().count("http"):
        errs.append("the tab icon names an address")
    if not re.fullmatch(r"<svg [^>]*>.*</svg>", svg, re.S):
        errs.append("the tab icon is not a single SVG element")
    return errs


def resource_errors(text: str) -> list[str]:
    """Resource-loading elements, attributes and calls: anything that would make the page reach the network on its own.
    The embedded @font-face rules in the build's exact shape (a base64 data: URI) are the one url( allowed; the fonts
    check decodes each one against the pinned faces."""
    errs = []
    text = FONT_FACE_RE.sub("@font-face { embedded }", text)
    text = PHOTO_IMG_RE.sub('<span class="name-photo"></span>', text)
    tree = parse(text)
    for tag, attrs in tree.starts:
        if tag == "link" and set(attrs) == {"rel", "href"} and attrs["rel"] == "icon":
            errs += icon_errors(attrs["href"])  # the tile as an inline SVG: it also stops the browser asking the host for /favicon.ico
            continue
        if tag == "meta" and "http-equiv" in attrs:
            errs.append(f"<meta http-equiv={attrs['http-equiv']!r}>")
        if tag in ("link", "img", "iframe", "object", "embed", "audio", "video", "source", "base", "form"):
            errs.append(f"<{tag}> element")
        for k, v in attrs.items():
            if k in ("src", "srcset", "action", "formaction", "poster", "data", "background", "manifest", "ping", "xlink:href") and v:
                errs.append(f"<{tag} {k}=...>")
            if k == "href" and tag != "a":
                errs.append(f"href on <{tag}>")
            if k == "href" and re.match(r"\s*(javascript|data):", v, re.I):
                errs.append(f"{v[:20]!r} link")
            if k.startswith("on"):
                errs.append(f"inline handler {k} on <{tag}>")
    for pat, lab in ((r"(?i)@import", "@import"), (r"(?i)url\(", "url("), (r"\bfetch\(", "fetch("), (r"XMLHttpRequest", "XMLHttpRequest"),
                     (r"sendBeacon", "sendBeacon"), (r"new\s+WebSocket", "WebSocket"), (r"EventSource", "EventSource"), (r"\bimport\(", "import("),
                     (r"(?i)image-set\(", "image-set("), (r"\.src\s*=", ".src="), (r"new\s+Image\b", "new Image"),
                     (r"createElement\(\s*['\"](script|img|iframe|link|audio|video|source|embed|object)", "createElement"),
                     (r"serviceWorker", "serviceWorker"), (r"window\.open\(", "window.open("), (r"speculationrules", "speculationrules"),
                     (r"\blocation\s*=(?!=)", "location="), (r"location\.href\s*=(?!=)", "location.href="), (r"location\.(assign|replace)\(", "location.assign/replace"),
                     (r"insertAdjacentHTML|\binnerHTML\s*=|\bouterHTML\s*=|document\.write", "script-written markup"),
                     (r"setAttribute\(\s*['\"](src|srcset|poster|data|action|formaction)['\"]", "setAttribute of a loading attribute"),
                     (r"new\s+(Audio|Worker|SharedWorker|RTCPeerConnection)\b", "fetching constructor")):
        for m in re.finditer(pat, text):
            errs.append(f"{lab} at offset {m.start()}")
    return errs


def storage_errors(text: str) -> list[str]:
    """Anything a page could keep beyond the theme choice the privacy policy names (localStorage key lensatic-theme)."""
    errs = []
    for pat, lab in ((r"document\.cookie", "document.cookie"), (r"sessionStorage", "sessionStorage"), (r"indexedDB", "indexedDB"),
                     (r"\bcaches\.", "caches"), (r"openDatabase", "openDatabase"), (r"cookieStore", "cookieStore"),
                     (r"navigator\.storage", "navigator.storage"), (r"['\"`]cookie['\"`]", "cookie by name")):
        errs += [f"{lab} at offset {m.start()}" for m in re.finditer(pat, text)]
    # every mention of localStorage must be a direct getItem or setItem call on the theme key; aliases, property
    # writes and access by name all fail
    ok = re.compile(r"localStorage\.(getItem|setItem)\(\s*(['\"`])lensatic-theme\2")
    for m in re.finditer(r"localStorage", text):
        if not ok.match(text, m.start()):
            errs.append(f"localStorage use other than a getItem or setItem call on the lensatic-theme key at offset {m.start()}")
    return errs


def font_errors(text: str, where: str) -> tuple[list[str], int]:
    """Every @font-face source is a data: URI that decodes to one of the four pinned faces, each face exactly once."""
    errs = []
    want = {(fam, w): name for fam, w, name in B.FONT_FACES}
    found = {}
    for m in re.finditer(r"@font-face\s*\{[^}]*\}", text):
        fm = FONT_FACE_RE.fullmatch(m.group(0))
        if not fm:
            errs.append(f"{where}: an @font-face rule is not an embedded data: URI in the build's shape: {m.group(0)[:80]!r}")
            continue
        key = (fm.group(1), int(fm.group(2)))
        if key not in want:
            errs.append(f"{where}: unexpected face {key}")
            continue
        found[key] = found.get(key, 0) + 1
        data = base64.b64decode(fm.group(3))
        pinned = V.FONT_SHA256.get(f"web/src/fonts/{want[key]}")
        if hashlib.sha256(data).hexdigest() != pinned:
            errs.append(f"{where}: {key[0]} {key[1]} does not decode to the pinned face web/src/fonts/{want[key]}")
    for key in want:
        if found.get(key) != 1:
            errs.append(f"{where}: {key[0]} {key[1]} embedded {found.get(key, 0)} times, expected once")
    if re.search(r"@font-face", FONT_FACE_RE.sub("", text)):
        errs.append(f"{where}: an @font-face rule outside the build's shape")
    return errs, len(re.findall(r"@font-face", text))


# --------------------------------------------------------------------------- contrast
def tokens(css: str, selector: str) -> dict[str, str]:
    i = css.find(selector + " {")
    if i < 0:
        return {}
    body = css[i:css.index("}", i)]
    return dict(re.findall(r"--([a-z0-9-]+):\s*([^;]+);", body))


def luminance(hex_: str) -> float:
    def ch(c: float) -> float:
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (int(hex_[k:k + 2], 16) / 255 for k in (1, 3, 5))
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def contrast(a: str, b: str) -> float:
    la, lb = luminance(a), luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


# the tokens in the block that are not six-digit hex colours: the two translucent or empty effects the iOS build skips,
# and the sizes and type stacks; every other token must be six-digit hex
NON_COLOUR_TOKENS = frozenset({"fade", "shadow", "radius", "card-radius", "maxw", "nav-h", "gutter", "sans", "mono"})
# (name, foreground token, background token, WCAG AA floor): 4.5 for text, 3 for the focus ring, graphics, controls and the
# chip border, which is the only cue to a chip's type
CONTRAST_PAIRS = [
    ("text on page", "fg", "bg", 4.5), ("text on surface (cards, header row)", "fg", "bg-2", 4.5),
    ("secondary text on page", "fg-2", "bg", 4.5), ("secondary text on surface", "fg-2", "bg-2", 4.5),
    ("accent text on page (numbers, mono labels)", "accent", "bg", 4.5), ("accent text on surface (door meta, layer tags, codes)", "accent", "bg-2", 4.5),
    ("links on page", "link", "bg", 4.5), ("links on surface", "link", "bg-2", 4.5),
    ("text on accent (primary button, pressed control)", "accent-fg", "accent", 4.5),
    ("text on the AI column", "fg", "seam", 4.5), ("secondary text on the AI column", "fg-2", "seam", 4.5),
    ("chip text", "fg", "chip-bg", 4.5), ("chip border on chip fill (the chip's type: solid, dashed, dotted)", "fg-2", "chip-bg", 3.0),
    ("status badge on surface: verified", "fg", "bg-2", 4.5), ("status badge on surface: authored, unverified", "fg-2", "bg-2", 4.5),
    ("status badge on surface: conflict", "bad", "bg-2", 4.5), ("conflict status on page", "bad", "bg", 4.5),
    ("the mark in the tile (graphic)", "tile-fg", "tile-bg", 3.0),
    ("focus ring on page", "focus", "bg", 3.0), ("focus ring on surface", "focus", "bg-2", 3.0),
    ("accent button and control edge on page", "accent", "bg", 3.0),
]
# measured and printed, not held to a floor: the hairlines are decoration, and a card or chip is named by its text
CONTRAST_INFO = [("hairline on page", "line", "bg"), ("strong line on page", "line-strong", "bg"), ("strong line on surface", "line-strong", "bg-2")]


def contrast_report() -> tuple[list[str], list[tuple[str, str, str, float, float, float]], list[tuple[str, float, float]]]:
    css = STYLES.read_text(encoding="utf-8")
    light, dark = tokens(css, ":root"), tokens(css, ':root[data-theme="dark"]')
    pref = tokens(css, ':root:not([data-theme="light"])')
    errs = []
    if not light or not dark:
        return ["the token blocks were not found at the top of styles.css"], [], []
    if pref != dark:
        errs.append("the dark-by-preference block and the dark-by-choice block differ")
    hexre = re.compile(r"#[0-9A-F]{6}")
    for theme, toks in (("paper", light), ("dial", dark)):
        for k, v in toks.items():
            if k in NON_COLOUR_TOKENS:
                continue
            if not hexre.fullmatch(v):
                errs.append(f"{theme}: --{k} is {v!r}, not six-digit hex")
    rows = []
    for name, f, b, floor in CONTRAST_PAIRS:
        bad = [f"{theme} --{k}" for theme, toks in (("paper", light), ("dial", dark)) for k in (f, b) if not hexre.fullmatch(toks.get(k, ""))]
        if bad:
            errs.append(f"{name}: cannot measure, {', '.join(bad)} missing or not six-digit hex")
            continue
        lr, dr = contrast(light[f], light[b]), contrast(dark[f], dark[b])
        rows.append((name, f, b, floor, lr, dr))
        for theme, r in (("paper", lr), ("dial", dr)):
            if r < floor:
                errs.append(f"{theme}: {name} (--{f} on --{b}) is {r:.2f}, under {floor}")
    info = [(name, contrast(light[f], light[b]), contrast(dark[f], dark[b])) for name, f, b in CONTRAST_INFO
            if all(hexre.fullmatch(toks.get(k, "")) for toks in (light, dark) for k in (f, b))]
    return errs, rows, info


# --------------------------------------------------------------------------- well-known terms (Session 7D)
def first_links(section: Node, forms_rx: re.Pattern, by_form: dict, slug_of) -> dict[str, bool]:
    """For each well-known term used in a section's running text, whether its first use there links to its glossary
    entry. Labels, hidden text and the skipped classes are not running text. A use inside a link, button or summary
    counts as linked, since a link cannot nest there, and so does a glossary entry's own term."""
    found: dict[str, bool] = {}

    def walk(n: Node, anc: list[Node]) -> None:
        if (n.tag in SKIP or "hidden" in n.attrs or n.attrs.get("aria-hidden") == "true" or is_label(n)
                or classes_of(n) & {"url", "pillar-label", "caps", "xp"}):
            return
        for c in n.children:
            if not isinstance(c, str):
                walk(c, anc + [n])
                continue
            for m in forms_rx.finditer(c):
                e = by_form[m.group(0)]
                if not e.get("wellKnown") or e["term"] in found:
                    continue
                chain = anc + [n]
                link = next((a for a in reversed(chain) if a.tag == "a"), None)
                if link is not None and "gl" in classes_of(link):
                    found[e["term"]] = link.attrs.get("href") == f"#gl-{slug_of(e['term'])}"
                else:
                    found[e["term"]] = any(a.tag in ("a", "button", "summary") or "gl-term" in classes_of(a) for a in chain)
    walk(section, [])
    return found


# --------------------------------------------------------------------------- labels (Session 7, section 4.9)
def label_errors(tree: Tree, forms_rx: re.Pattern, by_form: dict, slug_of) -> tuple[list[str], dict]:
    """Labels carry no expansion; each abbreviation in a label links to its glossary entry, described by the expansion, or
    sits in a link, button or summary that the expansion describes. Every description resolves to the glossary."""
    errs, stats = [], {"labels": 0, "uses": 0, "linked": 0, "described": 0, "names": 0}
    exp_ids = {}
    for n in walk_nodes(tree.root):
        if "gl-exp" in classes_of(n) and "id" in n.attrs:
            exp_ids[n.attrs["id"]] = norm(text_of(n, frozenset()))

    def walk(n: Node, anc: list[Node]):
        if n.tag in SKIP or n.attrs.get("aria-hidden") == "true" or classes_of(n) & {"url", "caps", "pillar-label"}:
            return
        in_label = any(is_label(a) for a in anc + [n])
        if in_label and "xp" in classes_of(n):
            lab = next(a for a in anc + [n] if is_label(a))
            errs.append(f"an expansion sits inside a label <{lab.tag} class={lab.attrs.get('class', '')!r}>: {text_of(n, frozenset())[:40]!r}")
        for c in n.children:
            if isinstance(c, str):
                if not in_label:
                    continue
                for m in forms_rx.finditer(c):
                    e = by_form[m.group(0)]
                    stats["uses"] += 1
                    ids = [] if (e.get("notAbbreviation") or e.get("wellKnown") or not e["expansion"]) else [f"glx-{slug_of(e['term'])}"]
                    if e.get("prefix"):
                        after_ = c[m.end():]
                        if n.tag == "a" and "gl" in classes_of(n) and n.parent is not None and m.end() == len(c):
                            sib = n.parent.children
                            nxt = sib[sib.index(n) + 1] if sib.index(n) + 1 < len(sib) else ""
                            after_ = nxt if isinstance(nxt, str) else ""
                        des = re.match(r"(?:/([A-Z][A-Za-z]+))?\s?\d+(?:[-/:]\d+)*", after_)
                        inner = by_form.get(des.group(1) or "") if des else None
                        if inner and inner["expansion"] and not inner.get("notAbbreviation") and not inner.get("wellKnown"):
                            ids.append(f"glx-{slug_of(inner['term'])}")
                    if n.tag == "a" and "gl" in classes_of(n):
                        stats["linked"] += 1
                        if n.attrs.get("href") != f"#gl-{slug_of(e['term'])}":
                            errs.append(f"label link for {m.group(0)!r} points to {n.attrs.get('href')!r}")
                        if n.attrs.get("aria-describedby", "").split() != ids:
                            errs.append(f"label link for {m.group(0)!r} is described by {n.attrs.get('aria-describedby')!r}, expected {' '.join(ids)!r}")
                        continue
                    owner = next((a for a in reversed(anc + [n]) if a.tag in ("a", "button", "summary")), None)
                    if owner is not None:
                        stats["described"] += 1
                        have = owner.attrs.get("aria-describedby", "").split()
                        if any(i not in have for i in ids):
                            errs.append(f"<{owner.tag}> holding the label {m.group(0)!r} is not described by {' '.join(ids)!r} (has {have})")
                        if not ids:
                            stats["names"] += 1
                        continue
                    errs.append(f"label abbreviation {m.group(0)!r} is neither linked to the glossary nor inside a described control")
            else:
                walk(c, anc + [n])
    walk(tree.root, [])
    stats["labels"] = sum(1 for n in walk_nodes(tree.root) if is_label(n))
    for n in walk_nodes(tree.root):
        for i in n.attrs.get("aria-describedby", "").split():
            if i not in exp_ids:
                errs.append(f"aria-describedby {i!r} does not resolve to a glossary expansion")
    return errs, stats


# --------------------------------------------------------------------------- session 11 (Q20, Q21, Q36)
def anchor_errors(tree: Tree) -> tuple[list[str], int]:
    """Every link to a place on the page (#id) lands on an element with that id (FB-002: the AI column's tag led nowhere)."""
    errs, n = [], 0
    for tag, attrs in tree.starts:
        href = attrs.get("href") or ""
        if tag == "a" and href.startswith("#") and len(href) > 1:
            n += 1
            if href[1:] not in tree.ids:
                errs.append(f"a link to {href!r} lands on nothing")
    return sorted(set(errs)), n


def layer_tag_errors(tree: Tree, d: dict) -> tuple[list[str], int]:
    """A layer tag names a layer of the stack by its number and links to its band; the AI column, beside the five layers
    and not a sixth, is tagged with its name and links to the column (RCO-03, FB-002)."""
    errs, n = [], 0
    word = norm(d["ui"]["labels"]["layer"])
    columns = {norm(tok_dow(d, x["name"])): x for x in d["layers"] if x.get("isColumn")}
    by_order = {x["order"]: x for x in d["layers"]}
    if not any(c.tag == "aside" for c in tree.ids.get("seam", [])):
        errs.append("the AI column is not the aside with id seam")
    for node_ in walk_nodes(tree.root):
        if node_.tag != "a" or "layer-tag" not in classes_of(node_):
            continue
        n += 1
        txt, href = norm(text_of(node_, frozenset())), node_.attrs.get("href")
        m = re.fullmatch(re.escape(word) + r" (\d+)", txt)
        if m:
            lay = by_order.get(int(m.group(1)))
            if lay is None or lay.get("isColumn"):
                errs.append(f"a layer tag reads {txt!r}, which is not a layer of the stack")
            elif href != f"#layer-{lay['id']}":
                errs.append(f"the tag {txt!r} links to {href!r}, not #layer-{lay['id']}")
        elif txt in columns:
            if href != "#seam":
                errs.append(f"the tag {txt!r} links to {href!r}, not the column (#seam)")
        else:
            errs.append(f"a layer tag reads {txt!r}")
    return sorted(set(errs)), n


def entry_label_errors(tree: Tree) -> tuple[list[str], dict]:
    """Links to entries, capability-name lists and entry titles are labels (ED-05): the classes are pinned in build_web's
    label set, every link to an entry is a label, and every entry's summary opens with its title as a label."""
    errs, st = [], {"links": 0, "caps": 0, "titles": 0}
    errs += [f"build_web.LABEL_CLASSES lacks {c!r}" for c in sorted(LABEL_PINS - B.LABEL_CLASSES)]
    for node_ in walk_nodes(tree.root):
        cls = classes_of(node_)
        if node_.tag == "a" and (node_.attrs.get("href") or "").startswith("#ent-"):
            st["links"] += 1
            if not (cls & (LABEL_PINS | {"chip"})):
                errs.append(f"the link to {node_.attrs['href']} ({norm(text_of(node_, frozenset()))[:40]!r}) is not a label")
        if "caps-list" in cls:
            st["caps"] += 1
        if node_.tag == "details" and "ent" in cls:
            summ = next((c for c in node_.children if not isinstance(c, str) and c.tag == "summary"), None)
            first = next((c for c in (summ.children if summ else []) if not isinstance(c, str)), None)
            st["titles"] += 1
            if first is None or "ent-title" not in classes_of(first):
                errs.append(f"#{node_.attrs.get('id')}: the summary does not open with the entry's title as a label")
    return errs, st


def summary_errors(tree: Tree) -> list[str]:
    """An entry's summary is its title, its badges and its citation line with a space between each, and a space between
    its badges, so print, where the summary is not a grid, never runs them together (RED-09)."""
    errs = []
    for node_ in walk_nodes(tree.root):
        if node_.tag != "details" or "ent" not in classes_of(node_):
            continue
        summ = next((c for c in node_.children if not isinstance(c, str) and c.tag == "summary"), None)
        kids = [c for c in (summ.children if summ else []) if not (isinstance(c, str) and c == "")]
        shape = [("_" if c.strip() == "" else "text") if isinstance(c, str) else " ".join(sorted(classes_of(c))) for c in kids]
        if shape != ["ent-title", "_", "badges", "_", "cite"]:
            errs.append(f"#{node_.attrs.get('id')}: the summary holds {shape}, expected the title, the badges and the citation, spaced")
            continue
        badges = [c for c in kids[2].children if not (isinstance(c, str) and c == "")]
        got = [("_" if c.strip() == "" else "text") if isinstance(c, str) else "status" for c in badges]
        n_b = got.count("status")
        if got != ["status"] + ["_", "status"] * (n_b - 1):
            errs.append(f"#{node_.attrs.get('id')}: the badges hold {got}, expected each badge with a space between")
    return errs


def cite_line(d: dict, title: str, edition: str, date: str | None, publisher: str | None = None) -> str:
    """The citation line the ruling gives: title, publisher (an entry's line), the edition as cite_edition gives it, date."""
    ed = B.cite_edition(tok_dow(d, title), tok_dow(d, edition), date)
    head = tok_dow(d, title) + (f". {tok_dow(d, publisher)}, " if publisher is not None else ", ")
    return norm(head + (f"{ed}, " if ed else "") + f"{B.fmt_date(date)}.")


def cite_errors(tree: Tree, d: dict) -> tuple[list[str], int]:
    """Citation lines (ED-09, ED-10, RED-06): the rule gives the ledger's rulings, and every entry's and document's line
    on the page is the line the rule gives."""
    errs, n = [], 0
    for title, edition, date, want in CITE_RULINGS:
        got = B.cite_edition(title, edition, date)
        if got != want:
            errs.append(f"the citation rule gives {got!r} for the edition {edition!r} of {title[:40]!r}, the ruling is {want!r}")
    for coll in ("frameworks", "sources", "solutions"):
        for e in d.get(coll, []):
            nodes_ = tree.ids.get(f"ent-{e['id']}") or []
            if len(nodes_) != 1:
                continue
            cite = next((x for x in walk_nodes(nodes_[0]) if "cite" in classes_of(x)), None)
            n += 1
            want = cite_line(d, e["title"], e["edition"], e["date"], e["publisher"])
            if cite is None or norm(text_of(cite)) != want:
                errs.append(f"#ent-{e['id']}: the citation line reads {norm(text_of(cite))[:90] if cite else None!r}, expected {want[:90]!r}")
            docs = next((x for x in walk_nodes(nodes_[0]) if x.tag == "ul" and "docs" in classes_of(x)), None)
            items = [c for c in (docs.children if docs else []) if not isinstance(c, str) and c.tag == "li"]
            for doc, li in zip(e.get("documents", []), items):
                n += 1
                want = cite_line(d, doc["title"], doc["edition"], doc["date"])
                if not norm(text_of(li)).startswith(want):
                    errs.append(f"#ent-{e['id']}: a document line reads {norm(text_of(li))[:90]!r}, expected {want[:90]!r}")
            if len(items) != len(e.get("documents", [])):
                errs.append(f"#ent-{e['id']}: {len(items)} document lines for {len(e.get('documents', []))} documents")
    return errs, n


def document_note_errors(tree: Tree, d: dict) -> tuple[list[str], int]:
    """Every document badged Unverified or Conflict shows its verification note (every address tried, or both readings
    and a date) in its own line, right after its badge, as the status key promises (SK-004); the line reads the link to
    the primary, the badge, that note, then the document's own note. A link to a primary whose address the note shown
    gives carries in-note, and only then, and the print rule that writes a link's address after it leaves those out."""
    errs, n = [], 0
    for coll in ("frameworks", "sources", "solutions"):
        for e in d.get(coll, []):
            nodes_ = tree.ids.get(f"ent-{e['id']}") or []
            docs = next((x for x in walk_nodes(nodes_[0]) if x.tag == "ul" and "docs" in classes_of(x)), None) if len(nodes_) == 1 else None
            items = [c for c in (docs.children if docs else []) if not isinstance(c, str) and c.tag == "li"]
            for i, (doc, li) in enumerate(zip(e.get("documents", []), items)):
                where = f"#ent-{e['id']}: document {i + 1}"
                v = doc.get("verification") or {}
                shown = v.get("status") in B.PROBLEM and bool(v.get("note"))
                kids = [c for c in li.children if not (isinstance(c, str) and c.strip() == "")]
                at = next((k for k, c in enumerate(kids) if not isinstance(c, str) and c.tag == "a" and c.attrs.get("href") == doc["url"]), None)
                if at is None:
                    errs.append(f"{where}: no link to its primary")
                    continue
                after = kids[at + 1:]
                if not after or isinstance(after[0], str) or "status" not in classes_of(after[0]):
                    errs.append(f"{where}: the badge does not follow the link to the primary")
                    continue
                note_ = norm(tok_dow(d, v.get("note") or ""))
                beside = after[1] if len(after) > 1 else None
                is_note = (beside is not None and not isinstance(beside, str) and "small" in classes_of(beside)
                           and norm(text_of(beside)) == note_)
                if shown:
                    n += 1
                    if not is_note:
                        errs.append(f"{where} is {v['status']} but its verification note is not right after its badge")
                elif is_note:
                    errs.append(f"{where} is {v['status']} and shows its verification note")
                marked = "in-note" in classes_of(kids[at])
                if marked != (shown and doc["url"] in tok_dow(d, v.get("note") or "")):
                    errs.append(f"{where}: the link to the primary {'carries' if marked else 'lacks'} in-note, and the note shown "
                                f"{'does not give' if marked else 'gives'} its address")
    css = STYLES.read_text(encoding="utf-8")
    pr = css[css.find("@media print"):] if "@media print" in css else ""
    if not re.search(r'\.ent a\[href\^="http"\]:not\(\.url\):not\(\.in-note\)::after', pr):
        errs.append("the print rule that writes a link's address after it does not leave out in-note links")
    return errs, n


def strip_scripts(html_text: str) -> str:
    def keep(m: re.Match) -> str:
        return m.group(0) if m.group(0).startswith(OPEN) else ""
    return re.sub(r"<script\b[^>]*>.*?</script>", keep, html_text, flags=re.S)


# --------------------------------------------------------------------------- main
def split(html: bytes) -> tuple[bytes, bytes, bytes]:
    i = html.index(OPEN.encode()) + len(OPEN)
    j = html.index(CLOSE.encode(), i)
    return html[:i], html[i:j], html[j:]


def page_size_errors(size: int) -> list[str]:
    """The built page is under PAGE_LIMIT bytes (session 13: 1 MB)."""
    return [] if size < PAGE_LIMIT else [f"{size} bytes, not under the limit of {PAGE_LIMIT} bytes"]


def print_pages_errors(pages: int) -> list[str]:
    """A printout is at most PRINT_PAGES pages (session 15: 20)."""
    return [] if pages <= PRINT_PAGES else [f"{pages} pages, more than {PRINT_PAGES}"]


def main() -> int:
    rep = V.Report()
    if not HTML.exists():
        rep.check("web/lensatic.html exists", ["missing; run tools/build_web.py"])
        print("\n".join(rep.lines)); print("WEB CHECKS RED"); return 1
    html = HTML.read_bytes()
    d = json.loads(STACK.read_text(encoding="utf-8"))

    # determinism: rebuild twice into temp files with the author flag recorded in the built file
    build_meta = json.loads(re.search(rb'<script type="application/json" id="build">(.*?)</script>', html, re.S).group(1))
    author = build_meta.get("author", "")
    TMP.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=TMP) as td:
        a, b = Path(td) / "a.html", Path(td) / "b.html"
        for p in (a, b):
            subprocess.run([sys.executable, str(BUILD), "--author", author, "--out", str(p), "--pages", "--docs", str(p.with_suffix(""))],
                           check=True, capture_output=True)
        same = a.read_bytes() == b.read_bytes()
        current = a.read_bytes() == html
        fresh = {f: (a.with_suffix("") / f).read_bytes() for f in DOC_FILES}
        pages_same = all(fresh[f] == (b.with_suffix("") / f).read_bytes() for f in DOC_FILES)
    rep.check("build is deterministic (two builds byte-identical, the pages build too)", [] if same and pages_same else ["the two builds differ"])
    rep.check("web/lensatic.html matches a fresh build of the current inputs", [] if current else ["built file is stale; rerun tools/build_web.py"])

    # the project site for GitHub Pages
    errs = []
    for f in DOC_FILES:
        if not (DOCS / f).is_file():
            errs.append(f"docs/{f} missing; run tools/build_web.py --pages")
        elif (DOCS / f).read_bytes() != fresh[f]:
            errs.append(f"docs/{f} is stale; rerun tools/build_web.py --pages")
    extra = sorted(q.relative_to(DOCS).as_posix() for q in DOCS.rglob("*")
                   if q.is_file() and q.relative_to(DOCS).as_posix() not in DOC_FILES) if DOCS.is_dir() else []
    errs += [f"docs/{q} is not built by --pages" for q in extra]
    if (DOCS / ".nojekyll").is_file() and (DOCS / ".nojekyll").stat().st_size:
        errs.append("docs/.nojekyll is not empty")
    rep.check("docs/ matches a fresh --pages build: index, privacy, support, the social card, an empty .nojekyll, nothing else", errs)
    ih = hashlib.sha256((DOCS / "index.html").read_bytes()).hexdigest() if (DOCS / "index.html").is_file() else "missing"
    wh = hashlib.sha256(html).hexdigest()
    rep.check("docs/index.html is web/lensatic.html byte for byte (SHA-256)", [] if ih == wh else [f"{ih[:12]} != {wh[:12]}"], wh[:12])

    head, embedded, tail = split(html)
    h1, h2 = hashlib.sha256(embedded).hexdigest(), hashlib.sha256(STACK.read_bytes()).hexdigest()
    rep.check("embedded JSON is byte-identical to content/stack.json (SHA-256)", [] if h1 == h2 else [f"{h1[:12]} != {h2[:12]}"], h1[:12])
    size = len(html)
    rep.check("built HTML under 1 MB", page_size_errors(size), f"{size} bytes, {PAGE_LIMIT - size} under the limit")

    rest = (head + tail).decode("utf-8")
    full = html.decode("utf-8")

    # inline scripts parse (a script that fails to parse would leave the pre-script guard hiding cell text)
    node = shutil.which("node")
    scripts = [m.group(1) for m in re.finditer(r"<script>(.*?)</script>", full, re.S)]
    errs = []
    if node:
        for i, s in enumerate(scripts):
            proc = subprocess.run([node, "-e", "new Function(require('fs').readFileSync(0, 'utf8'))"], input=s, capture_output=True, text=True)
            if proc.returncode:
                errs.append(f"inline script {i}: {proc.stderr.strip().splitlines()[-1] if proc.stderr.strip() else 'does not parse'}")
    else:
        errs.append("node not found; cannot parse the inline scripts")
    rep.check("inline scripts parse", errs, f"{len(scripts)} scripts")

    # no resource loading outside plain anchors to primaries
    rep.check("no network references: no resource-loading element, attribute or call; primaries are plain links", resource_errors(rest))
    rep.check("storage: the page keeps nothing but the theme choice (localStorage key lensatic-theme), as the privacy policy says", storage_errors(rest))
    rep.check("no em dash (U+2014) in the built HTML", [f"offset {i}" for i, ch in enumerate(full) if ch == "—"][:5])
    rep.check("no leftover template placeholders or render tokens", [f"offset {m.start()}" for m in re.finditer(r"\{\{", rest)][:5])

    terms, src = V.load_sweep_terms()
    hits = []
    low = rest.lower()
    for tname in terms:
        for probe in (tname, codecs.encode(tname, "rot13")):
            if probe in low:
                hits.append(f"term #{terms.index(tname) + 1}")
    if V.FORBIDDEN_WORD in rest:
        hits.append("forbidden word")
    rep.check("sweep clean and no forbidden word in the wrapper", hits, f"{len(terms)} terms from {src}")

    # the plain pages: the app's offline and wall rules, and the facts they state come from content
    errs = []
    for key in ("privacy", "support"):
        f = DOCS / f"{key}.html"
        if not f.is_file():
            errs.append(f"docs/{key}.html missing")
            continue
        page = f.read_text(encoding="utf-8")
        errs += [f"{key}: {e}" for e in resource_errors(page)]
        errs += [f"{key}: {e}" for e in storage_errors(page)]
        if re.search(r"<script\b", page, re.I):
            errs.append(f"{key}: has a script element")
        if V.EM_DASH in page:
            errs.append(f"{key}: em dash")
        if "{{" in page:
            errs.append(f"{key}: leftover placeholder or render token")
        low = page.lower()
        for tname in terms:
            if tname in low or codecs.encode(tname, "rot13") in low:
                errs.append(f"{key}: sweep term #{terms.index(tname) + 1}")
        if V.FORBIDDEN_WORD in page:
            errs.append(f"{key}: forbidden word")
        ptree = parse(page)
        main_text = norm(text_of(ptree.ids["main"][0])) if "main" in ptree.ids else ""
        spec = d["pages"][key]
        title = re.search(r"<title>(.*?)</title>", page, re.S)
        if not title or title.group(1) != spec["title"].replace("'", "&#x27;"):
            errs.append(f"{key}: title is not {spec['title']!r}")
        for para in spec["paragraphs"]:
            if norm(tok_dow(d, para)) not in main_text:
                errs.append(f"{key}: paragraph missing: {para[:50]!r}")
        for tag, attrs in ptree.starts:
            href = attrs.get("href")
            if tag == "a" and href is not None and not (href in ("./", "privacy.html", "support.html") or href.startswith("https://")):
                errs.append(f"{key}: link {href!r} is neither a site page nor an https address")
    ptext = (DOCS / "privacy.html").read_text(encoding="utf-8") if (DOCS / "privacy.html").is_file() else ""
    if f'<time datetime="{d["meta"]["builtOn"]}">' not in ptext:
        errs.append("privacy: the effective date is not meta.builtOn")
    stext = (DOCS / "support.html").read_text(encoding="utf-8") if (DOCS / "support.html").is_file() else ""
    if f"<dd>{d['meta']['contentVersion']}</dd>" not in stext:
        errs.append("support: the content version is not meta.contentVersion")
    due = sorted(x for x in re.findall(r'"recheckAfter": "(\d{4}-\d{2}-\d{2})"', STACK.read_text(encoding="utf-8")) if x >= d["meta"]["builtOn"])
    want = f'<dd><time datetime="{due[0]}">' if due else f'<dd>{d["ui"]["labels"]["pagesNoRecheck"]}</dd>'
    if want not in stext:
        errs.append("support: the next dated recheck is not the earliest recheckAfter on or after meta.builtOn")
    sparas = d["pages"]["support"]["paragraphs"]
    at = next((i for i, p_ in enumerate(sparas) if ISSUES_URL in p_), None)
    if at is None or at + 1 >= len(sparas) or sparas[at + 1] != LICENCE_SUPPORT:
        errs.append(f"support: the paragraph after the error-reporting one is not {LICENCE_SUPPORT!r}")
    rep.check("privacy and support pages: no script, no resource loading, no storage, no em dash, sweep clean; title, effective date, "
              "content version, next recheck and every paragraph from content; the support page's reuse sentence follows the "
              "error-reporting paragraph; links are site pages or https", errs)

    # ---- the new look (Session 7) ----
    L = d["ui"]["labels"]
    pages_text = {k: (DOCS / f"{k}.html").read_text(encoding="utf-8") for k in ("privacy", "support") if (DOCS / f"{k}.html").is_file()}
    errs, n_faces = [], 0
    for where, text in [("app", rest)] + list(pages_text.items()):
        e_, n_ = font_errors(text, where)
        errs += e_
        n_faces += n_
    rep.check("type: every @font-face source is a data: URI that decodes to one of the four pinned IBM Plex faces, each face once, "
              "in the app and on both pages", errs, f"{n_faces} faces across {1 + len(pages_text)} pages")

    errs, rows, info_rows = contrast_report()
    lowest = min(((min(r[4], r[5]), r[0]) for r in rows), default=(0.0, "none"))
    rep.check("contrast: text pairs at least 4.5:1, the focus ring, the tile's mark, the accent controls and the chip border at least 3:1, in paper and dial; "
              "every colour token six-digit hex", errs, f"{len(rows)} pairs, lowest {lowest[0]:.2f} ({lowest[1]})")
    for name, f, b, floor, lr, dr in rows:
        rep.info(f"contrast  {name}: --{f} on --{b}  paper {lr:.2f}  dial {dr:.2f}  (floor {floor})")
    for name, lr, dr in info_rows:
        rep.info(f"contrast  {name}: paper {lr:.2f}  dial {dr:.2f}  (not held to a floor)")

    atree_b = parse(rest)
    errs = []
    hero = (atree_b.ids.get("intro") or [None])[0]
    kids = [c for c in hero.children if not isinstance(c, str)] if hero else []
    shape = [(c.tag, classes_of(c)) for c in kids]
    expect = [("div", {"tile"}), ("h1", set()), ("p", {"lede"}), ("p", {"actions"}), ("p", {"stamp"})]
    loose = [c.strip() for c in (hero.children if hero else []) if isinstance(c, str) and c.strip()]
    if shape != expect or loose:
        errs.append(f"the front door holds {[t for t, _ in shape]} {loose if loose else ''}, expected tile, h1, lede, actions, stamp")
    else:
        tile, h1_, lede, actions, stamp = kids
        if tile.attrs.get("aria-hidden") != "true" or [c.tag for c in tile.children if not isinstance(c, str)] != ["svg"]:
            errs.append("the tile is not a hidden graphic holding only the mark")
        for node_, want_ in ((h1_, d["meta"]["name"]), (lede, tok_dow(d, d["meta"]["description"]))):
            if norm(text_of(node_)) != norm(want_):
                errs.append(f"front door: {node_.tag}.{node_.attrs.get('class', '')} reads {norm(text_of(node_))[:50]!r}")
        got = [(c.tag, classes_of(c), c.attrs.get("href"), norm(text_of(c))) for c in actions.children if not isinstance(c, str)]
        want_ = [("a", {"btn", "primary"}, "#view-doors", norm(L["heroPrimary"])), ("a", {"btn", "secondary"}, "#view-stack", norm(L["heroSecondary"]))]
        if got != want_ or any(isinstance(c, str) and c.strip() for c in actions.children):
            errs.append(f"front door buttons are {got}, expected the primary to the doors and the secondary to the stack")
        if not norm(text_of(stamp)).startswith(f'{L["contentVersion"]} {d["meta"]["contentVersion"]}, {L["checkedThrough"]} '):
            errs.append("front door: the version line does not give the content version and the check date")
        # Session 7D: the version line holds its link to About and exactly one more, Why the name?, to the heading in About
        parts_ = [c for c in stamp.children if not (isinstance(c, str) and not c)]
        links_ = [(c.tag, c.attrs.get("href"), norm(text_of(c))) for c in parts_ if not isinstance(c, str)]
        middle = re.escape(f', {L["checkedThrough"]} ') + r"\d{1,2} [A-Z][a-z]{2} \d{4}" + re.escape(L["metaSeparator"])
        if [(t_, h_) for t_, h_, _ in links_] != [("a", "#view-about"), ("a", "#about-name")] or links_[1][2] != norm(L["whyName"]):
            errs.append(f"front door: the version line holds {links_}, expected the link to About and one link {L['whyName']!r} to #about-name")
        elif (len(parts_) != 3 or not isinstance(parts_[1], str)
              or not re.fullmatch(middle, htmllib.unescape(parts_[1]))):
            errs.append(f"front door: between its two links the version line must read exactly ', {L['checkedThrough']} <date>{L['metaSeparator']}', "
                        f"and hold nothing else; it holds {[p_ if isinstance(p_, str) else '<' + p_.tag + '>' for p_ in parts_]}")
        target = atree_b.ids.get("about-name") or []
        about_ = (atree_b.ids.get("view-about") or [None])[0]
        if (len(target) != 1 or target[0].tag != "h3" or norm(text_of(target[0])) != norm(L["whyNameHeading"])
                or about_ is None or target[0] not in list(walk_nodes(about_))):
            errs.append("front door: #about-name is not one h3 in About reading ui.labels.whyNameHeading")
    rep.check("front door: exactly the tile, the name, the description, the two buttons (to the doors and to the stack) "
              "and the version line, in that order; the version line ends with one link, Why the name, to its heading in About", errs)

    errs = []
    orders = {x["id"]: x["order"] for x in d["layers"]}
    for door in d["doors"]:
        nodes_ = atree_b.ids.get(f"door-{door['id']}", [])
        if len(nodes_) != 1 or nodes_[0].tag != "details":
            errs.append(f"door {door['id']}: not one details element")
            continue
        if "open" in nodes_[0].attrs:
            errs.append(f"door {door['id']}: open in the static render")
        steps = door.get("steps") or []
        if steps:
            lay = sorted({orders[s["layerId"]] for s in steps})
            cnt = L["doorMetaStep"] if len(steps) == 1 else L["doorMetaSteps"].replace("{n}", str(len(steps)))
            lst = (L["doorMetaLayer"] if len(lay) == 1 else L["doorMetaLayers"]).replace("{list}", L["listSeparator"].join(map(str, lay)))
            meta_ = cnt + L["metaSeparator"] + lst
        else:
            meta_ = first_sentence_of(door.get("paragraph") or "")[0]
        summ = next((c for c in nodes_[0].children if not isinstance(c, str) and c.tag == "summary"), None)
        got = [(" ".join(sorted(classes_of(c))), norm(text_of(c))) for c in (summ.children if summ else []) if not isinstance(c, str)]
        want_ = [("door-title", norm(tok_dow(d, door["title"]))), ("who", norm(tok_dow(d, first_sentence_of(door["whoYouAre"])[0]))),
                 ("door-meta" if steps else "door-meta sentence", norm(tok_dow(d, meta_)))]
        if got != want_:
            errs.append(f"door {door['id']}: the card reads {got}, expected {want_}")
    rep.check("doors: all four closed in the static render; each card's summary is its title, the first sentence of whom it is for, and "
              "its step count and the layers the steps touch (or, with no steps, its paragraph's first sentence)", errs)

    # session 11 (Q20, Q21, Q36)
    errs, n_ = anchor_errors(atree_b)
    rep.check("in-page links: every link to a place on the page lands on an element with that id", errs, f"{n_} links")
    errs, n_ = layer_tag_errors(atree_b, d)
    rep.check("layer tags: each names a layer of the stack by its number and links to its band; the AI column, not a layer, is tagged "
              "with its name and links to the column", errs, f"{n_} tags")
    errs, st_ = entry_label_errors(atree_b)
    rep.check("labels that name an entry: every link to an entry, every capability-name list and every entry's title is a label (classes "
              f"{', '.join(sorted(LABEL_PINS))} pinned)", errs, f"{st_['links']} links, {st_['caps']} capability lists, {st_['titles']} titles")
    rep.check("entry summaries: the title, the badges and the citation line, a space between each", summary_errors(atree_b))
    errs, n_ = cite_errors(atree_b, d)
    rep.check("citation lines: an edition the title carries or that repeats the date is left out, a descriptive one is lowered, designations "
              "keep their capital; the ledger's rulings hold and every entry's and document's line is the ruled line", errs,
              f"{len(CITE_RULINGS)} rulings, {n_} lines")
    css_ = STYLES.read_text(encoding="utf-8")
    at_ = css_.find("@media print")
    rep.check("print stylesheet: every key/value value prints whole, so a note keeps its status pill and nothing carried over a break "
              "overprints the next row", [] if at_ >= 0 and PRINT_KEEP.search(css_[at_:]) else
              ["the print block does not keep dl.kv > dd whole (break-inside: avoid)"])
    errs, n_ = document_note_errors(atree_b, d)
    rep.check("documents: every Unverified or Conflict document shows its verification note in its own line, right after its badge; "
              "print does not repeat an address the note gives", errs, f"{n_} notes")

    errs = []
    foot = (atree_b.ids.get("footer") or [None])[0]
    if foot is None or foot.tag != "footer" or foot.parent is None or foot.parent.tag != "body":
        errs.append("no footer element directly in body")
    else:
        sibs = [c for c in foot.parent.children if not isinstance(c, str)]
        if [c.tag for c in sibs].index("main") > sibs.index(foot):
            errs.append("the footer does not follow main")
        hrefs = [a.attrs.get("href") for a in walk_nodes(foot) if a.tag == "a" and "gl" not in classes_of(a)]
        if hrefs != list(POLICY_LINKS):
            errs.append(f"the app's footer links are {hrefs}, expected {list(POLICY_LINKS)}")
        lic = [n_ for n_ in walk_nodes(foot) if "foot-lic" in classes_of(n_)]
        if len(lic) != 1 or norm(text_of(lic[0])) != norm(L["footerLicenses"]):
            errs.append("the footer's licence line is not ui.labels.footerLicenses")
        if L["footerLicenses"] != LICENCE_FOOTER:
            errs.append(f"ui.labels.footerLicenses reads {L['footerLicenses']!r}, expected {LICENCE_FOOTER!r}")
        if author and f"{L['madeBy']} {author}" not in norm(text_of(foot)):
            errs.append("the footer lacks the maker line")
    for key, page in pages_text.items():
        pfoot = (parse(page).ids.get("footer") or [None])[0]
        phrefs = [a.attrs.get("href") for a in walk_nodes(pfoot) if a.tag == "a"] if pfoot else []
        if phrefs != ["./"] + list(POLICY_LINKS):
            errs.append(f"{key}: the footer links are {phrefs}, expected the app and {list(POLICY_LINKS)}")
    rep.check("footer: after main, the maker line, the licence line (all rights reserved, fonts OFL) and exactly the privacy, support and source code addresses, absolute; "
              "the plain pages add the link back to the app", errs)

    errs = []
    imgs = sorted(q.relative_to(DOCS).as_posix() for q in DOCS.rglob("*") if q.is_file() and q.suffix.lower() in IMAGE_SUFFIXES) if DOCS.is_dir() else []
    if imgs != ["social-card.png"]:
        errs.append(f"docs/ holds the images {imgs}, expected exactly social-card.png")
    card = DOCS / "social-card.png"
    size_ = "missing"
    if not card.is_file() or not SOCIAL_SRC.is_file() or card.read_bytes() != SOCIAL_SRC.read_bytes():
        errs.append("docs/social-card.png is not web/src/social-card.png byte for byte")
    else:
        data = card.read_bytes()
        w_, h_ = int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")
        size_ = f"{w_} x {h_}, {len(data)} bytes"
        if data[:8] != b"\x89PNG\r\n\x1a\n" or (w_, h_) != B.SOCIAL_SIZE:
            errs.append(f"the social card is not a {B.SOCIAL_SIZE[0]} x {B.SOCIAL_SIZE[1]} PNG ({size_})")
    metas, seen_ = {}, {}
    for tag, attrs in atree_b.starts:
        if tag == "meta" and (attrs.get("property") or attrs.get("name")):
            k = attrs.get("property") or attrs.get("name")
            metas[k] = attrs.get("content")
            seen_[k] = seen_.get(k, 0) + 1
    errs += [f"<meta {k}> appears {v} times" for k, v in seen_.items() if v > 1]
    # the preview's description is the pitch (session 9); the description tag for search engines stays meta.description
    want_ = {"og:title": d["meta"]["name"], "og:description": d["meta"]["pitch"], "og:type": "website", "og:url": SITE,
             "og:image": f"{SITE}social-card.png", "og:image:width": "1200", "og:image:height": "630", "twitter:card": "summary_large_image",
             "description": d["meta"]["description"]}
    if "twitter:description" in metas:
        want_["twitter:description"] = d["meta"]["pitch"]
    for k, v in want_.items():
        if metas.get(k) != v:
            errs.append(f"<meta {k}> is {metas.get(k)!r}, expected {v!r}")
    for k in ("og:url", "og:image"):
        if not (metas.get(k) or "").startswith("https://kensden.github.io/lensatic/"):
            errs.append(f"{k} is not an absolute https address on kensden.github.io/lensatic/")
    rep.check("social card: docs/ holds exactly one image, social-card.png, byte for byte the committed source, 1200 x 630; og:url and "
              "og:image are absolute https addresses on the published site; the preview tags come from content (og:description the pitch, "
              "the description tag meta.description)", errs, size_)

    # the About photo (Session 7D, section 4.4): embedded exactly once, in About, as a data: URI that decodes to the pinned
    # file, with no metadata, its alt text from content and its true size; the plain pages hold no image
    errs, detail = [], ""
    found = PHOTO_IMG_RE.findall(rest)
    if len(found) != 1 or rest.count("<img") != 1:
        errs.append(f"the page holds {rest.count('<img')} <img> element(s) and {len(found)} embedded photo(s), expected exactly one of each")
    else:
        b64, alt, w_, h_ = found[0]
        data = base64.b64decode(b64)
        if not PHOTO.is_file() or data != PHOTO.read_bytes():
            errs.append("the embedded photo does not decode to web/src/about-photo.jpg byte for byte")
        if hashlib.sha256(data).hexdigest() != V.ABOUT_PHOTO_SHA256:
            errs.append("the embedded photo is not the pinned file (SHA-256)")
        try:
            segs, (w, h) = V.jpeg_segments(data)
            meta_ = [x for x in segs if x.startswith("APP") or x == "COM"]
            if meta_:
                errs.append(f"the embedded photo carries metadata segments: {' '.join(meta_)}")
            if (int(w_), int(h_)) != (w, h):
                errs.append(f"the photo's width and height attributes are {w_} x {h_}, the image is {w} x {h}")
            detail = f"{w} x {h}, {len(data)} bytes embedded as {len(b64)} base64 characters"
        except ValueError as exc:
            errs.append(f"the embedded photo does not decode as a JPEG: {exc}")
        if htmllib.unescape(alt) != d["ui"]["labels"].get("aboutPhotoAlt"):
            errs.append("the photo's alt text is not ui.labels.aboutPhotoAlt")
        about_ = (atree_b.ids.get("view-about") or [None])[0]
        if about_ is None or not any("name-photo" in classes_of(n_) for n_ in walk_nodes(about_)):
            errs.append("the photo is not in About")
    for key, page in pages_text.items():
        if "<img" in page:
            errs.append(f"{key}: holds an image")
    rep.check("about photo: embedded exactly once, in About, as a data: URI that decodes to the pinned web/src/about-photo.jpg, no metadata, "
              "alt text from content, true width and height; no image on the plain pages", errs, detail)

    errs = []
    for f in sorted(DOCS.rglob("*")) if DOCS.is_dir() else []:
        if f.is_file():
            raw = f.read_bytes().decode("utf-8", "replace")
            views = [raw, htmllib.unescape(raw), urllib.parse.unquote(htmllib.unescape(raw))]
            blocks = re.findall(r'<script type="application/json"[^>]*>(.*?)</script>', raw, re.S)
            for b in blocks:
                try:
                    views.append("\n".join(s for _, s in V.walk_strings(json.loads(b))))
                except ValueError:
                    errs.append(f"docs/{f.relative_to(DOCS)}: an embedded JSON block does not parse")
            for m in {m.group(0) for v in views for m in EMAIL_RE.finditer(v)}:
                errs.append(f"docs/{f.relative_to(DOCS)}: {m}")
    rep.check("no email address anywhere in docs/ (raw, entity-decoded, percent-decoded, and every embedded JSON string)", errs, f"{len([f for f in DOCS.rglob('*') if f.is_file()]) if DOCS.is_dir() else 0} files")

    # the privacy policy says the only outside links go to the public documents cited in Sources and to the source repository,
    # and that the app also links to the policy and the support page: those three addresses are the only exceptions
    errs = []
    atree = parse(rest)
    for node_ in walk_nodes(atree.root):
        href = node_.attrs.get("href", "") if node_.tag == "a" else ""
        if href and not href.startswith("#") and href not in POLICY_LINKS:
            anc, inside = node_.parent, False
            while anc is not None:
                if anc.attrs.get("id") == "view-sources":
                    inside = True
                    break
                anc = anc.parent
            if not inside:
                errs.append(f"external link outside Sources: {href[:60]}")
    rep.check("every external link in the app sits inside Sources, except the policy, support and source repository links (the privacy policy's claim)", errs)

    # id skeleton: Node script when available, Python fallback otherwise
    items, counts = expected_items(d)
    expected = sorted(set(list(items) + [f"view-{s}" for s in ("doors", "stack", "matrix", "functions", "ai", "helper", "sources", "about")] +
                          ["table-dow", "table-cisa", "matrix-dow", "matrix-cisa", "nav", "theme-toggle", "to-top", "matrix-control", "expand-all",
                           "about-name"]))
    if node and DOM_CHECK.exists():
        proc = subprocess.run([node, str(DOM_CHECK), str(HTML)], input="\n".join(expected), capture_output=True, text=True)
        missing = [l for l in proc.stdout.splitlines() if l.startswith("MISSING")]
        engine = f"node {proc.stdout.splitlines()[-1] if proc.stdout else ''}".strip()
        if proc.returncode not in (0, 1):
            missing.append(f"dom_check.mjs failed: {proc.stderr.strip()[:200]}")
    else:
        ids = set(re.findall(r'\sid="([^"]+)"', rest))
        missing = [f"MISSING {i}" for i in expected if i not in ids]
        engine = "python fallback"
    rep.check(f"id skeleton: {len(expected)} expected element ids present, none duplicated", missing, engine)

    # static render: every item's text in the document, outside hidden elements
    count_line = ", ".join(f"{v} {k}" for k, v in counts.items())
    errs, n = check_static(full, items, "built")
    # the intro texts that moved (Session 7, section 4.4) render exactly once: the audience line and the plain definition of
    # zero trust before the door grid, the note on steps after it, the department's note in About
    ftree = parse(full)
    body_nodes = [n_ for n_ in walk_nodes(ftree.root) if n_.tag == "body"]
    page_text = norm(text_of(body_nodes[0])) if body_nodes else ""
    for key in ONCE:
        k = page_text.count(norm(tok_dow(d, d["ui"]["labels"][key])))
        if k != 1:
            errs.append(f"ui.labels.{key} renders {k} times, expected once")
    order = [n_.attrs.get("id") for n_ in walk_nodes(ftree.root) if n_.attrs.get("id") in ("doors-audience", "zt-plain", "door-federal-civilian", "doors-note")]
    if order != ["doors-audience", "zt-plain", "door-federal-civilian", "doors-note"]:
        errs.append(f"the doors section's texts are in the order {order}")
    if not any(n_.attrs.get("id") == "dow-note" for n_ in walk_nodes(ftree.ids["about-body"][0])) if "about-body" in ftree.ids else True:
        errs.append("the department's note is not in About")
    if d["meta"]["about"].get("licensing") != LICENCE_ABOUT:
        errs.append("meta.about.licensing is not the all-rights-reserved paragraph ruled for content 0.7.0")
    rep.check("static render: rendered text of every door, layer, framework, source, solution, helper, function, SOC row and cell in both views; "
              "the intro texts that moved render exactly once, in place; About carries the all-rights-reserved licensing paragraph", errs,
              f"{len(items)} elements, {n} texts: {count_line}")
    stripped = strip_scripts(full)
    left = len(re.findall(r"<script\b", stripped))
    errs, n = check_static(stripped, items, "script-stripped")
    if left != 1:
        errs.append(f"script-stripped copy keeps {left} script elements, expected only the JSON block")
    stree = parse(stripped)
    for sec in [n_ for n_ in stree.ids if n_.startswith("view-")]:
        node_ = stree.ids[sec][0]
        heading = "".join(text_of(c) for c in walk_nodes(node_) if c.tag == "h2")
        body = norm(text_of(node_))
        if hidden_within(node_) or len(body) - len(norm(heading)) < 100:
            errs.append(f"script-stripped: section #{sec} is empty")
    rep.check("script-stripped copy (every script removed except the JSON block): same texts present, no empty section",
              errs, f"{n} texts, {len([s for s in stree.ids if s.startswith('view-')])} sections, {len(stripped)} bytes")

    # glossary: every abbreviation in rendered text has an entry, and each is spelled out at its first use in every section
    gl = d.get("glossary", [])
    if gl:
        errs_cov, errs_first, n_abbr, n_first = [], [], 0, 0
        dow = d["orgs"]["dow"]
        tokr = lambda v: re.sub(r"\{\{\s*dow(?:\.([A-Za-z]+))?\s*\}\}", lambda m: str(dow.get(m.group(1), "")) if m.group(1) else dow["abbr"], v or "")
        entries = [{"term": tokr(g["term"]), "expansion": tokr(g.get("expansion")) if g.get("expansion") else "",
                    "forms": [tokr(f) for f in g.get("forms", [])], "prefix": g.get("prefix", False),
                    "notAbbreviation": g.get("notAbbreviation", False), "wellKnown": g.get("wellKnown", False)} for g in gl]
        by_form = {f: e for e in entries for f in e["forms"]}
        # the forms that count as an entry spelled out: its expansion, and the expansion with a well-known term written short
        # (session 11, ED-06; build_web.spelled_variants, the rule pinned by SPELLED_PINS)
        well_known = [e for e in entries if e["wellKnown"] and e["expansion"]]
        spelled = {e["term"]: [v.lower() for v in B.spelled_variants(e["expansion"], well_known)] for e in entries if e["expansion"]}
        def alts(forms):
            return "|".join(re.escape(f) for f in sorted(forms, key=len, reverse=True))
        plain = [f for e in entries if not e["prefix"] for f in e["forms"]]
        prefixed = [f for e in entries if e["prefix"] for f in e["forms"]]
        # one pattern, longest form first, the same rule the build uses: NIST IR is one match, not IR inside it
        forms_rx = re.compile("|".join(p_ for p_ in (
            rf"(?<![A-Za-z0-9.])(?:{alts(plain)})(?![A-Za-z0-9])" if plain else "",
            rf"(?<![A-Za-z0-9.])(?:{alts(prefixed)})(?![A-Za-z])" if prefixed else "") if p_))
        ws = lambda v: re.sub(r"\s+", " ", v).strip()
        # function codes sit beside their names; II is a roman numeral in printed titles; SECRET is a classification
        # word inside a network's printed name; SharePoint and iOS are product names
        codes = {f["id"] for f in d["functions"]} | {"II", "III", "SECRET", "SharePoint", "iOS"}
        cand_rx = re.compile(r"(?<![A-Za-z0-9.&/-])(?:[a-z]?[A-Z][A-Za-z]*[A-Z][A-Za-z]*(?:&[A-Z]+)?(?:-[A-Z][A-Za-z]*)*|[A-Z](?:\.[A-Z])+\.)(?![a-z])")
        tree_full = parse(stripped)
        visible_skip = frozenset({"url", "pillar-label", "caps"})
        chunks = [("header", tree_full.ids["top"][0])] + [(k, v[0]) for k, v in tree_full.ids.items() if k == "intro" or k.startswith("view-")]
        if "footer" in tree_full.ids:
            chunks.append(("footer", tree_full.ids["footer"][0]))
        else:
            errs_cov.append("no footer to read")
        def scan(name, node_, coverage=True):
            nonlocal n_abbr, n_first
            # coverage reads every visible word, labels included; the first-use rule reads running text only (Session 7:
            # a label is never a first use and never carries an expansion)
            full_txt = ws(spaced_text(node_, visible_skip))
            cov_spans = [(m.start(), m.end()) for m in forms_rx.finditer(full_txt)]
            for m in (cand_rx.finditer(full_txt) if coverage else ()):
                tokn = m.group(0)
                after = full_txt[m.end():m.end() + 40]
                if (tokn in codes or re.match(r"[A-Z]{2}\.[A-Z]{2}", full_txt[m.start():m.start() + 5])  # category codes such as GV.PO
                        or re.match(r"-\d", after)                                               # control identifiers such as SA-15
                        or re.match(r"[-\w]*\.(pdf|PDF)\b", after)):                             # printed file names
                    continue
                n_abbr += 1
                if not any(a_ <= m.start() < b_ or m.start() <= a_ < m.end() for a_, b_ in cov_spans):
                    errs_cov.append(f"{name}: {tokn!r} has no glossary entry")
            if name in ("header", "footer"):
                return
            txt = ws(spaced_text(node_, visible_skip, skip_labels=True))
            spans = [(m.start(), m.end(), by_form[m.group(0)]) for m in forms_rx.finditer(txt)]
            # a glossary entry's own term counts as spelled out where its expansion, read without inserted spellings, is its own
            own = {}
            if name == "view-glossary":
                for ent_node in [n_ for n_ in walk_nodes(node_) if "gl-entry" in n_.attrs.get("class", "").split()]:
                    term_nodes = [n_ for n_ in walk_nodes(ent_node) if "gl-term" in n_.attrs.get("class", "").split()]
                    exp_nodes = [n_ for n_ in walk_nodes(ent_node) if "gl-exp" in n_.attrs.get("class", "").split()]
                    if term_nodes and exp_nodes:
                        own[ws(spaced_text(term_nodes[0], visible_skip))] = ws(spaced_text(exp_nodes[0], visible_skip | {"xp"}))
            first = {}
            for a_, b_, e in sorted(spans, key=lambda t: t[0]):
                first.setdefault(e["term"], (a_, b_, e))
            for term, (a_, b_, e) in first.items():
                if not e["expansion"]:
                    continue  # a name such as MITRE, or a term with no abbreviation
                if e["wellKnown"]:
                    continue  # a term every reader knows, such as AI: linked, never spelled out (checked below)
                n_first += 1
                exp = e["expansion"].lower()
                forms_ = spelled.get(term, [exp])
                if own.get(term, "").lower() == exp:
                    continue
                # spelled out earlier in the section, or in the parenthesis (square brackets inside a parenthesis)
                # that follows the form and its designation, or the form sits in parentheses after its own name
                if any(v in txt[:a_].lower() for v in forms_):
                    continue
                rest = txt[b_:]
                if e["prefix"]:
                    des = re.match(r"(?:/[A-Z][A-Za-z]+)?\s?\d+(?:[-/:]\d+)*", rest)
                    rest = rest[des.end():] if des else rest
                group = re.match(r" ?[(\[]([^)\]]*)[)\]]", rest)
                if group and any(v in group.group(1).lower() for v in forms_):
                    continue
                want = exp.split()[-3:]
                if (txt[a_ - 1:a_] == "(" and rest.startswith(")")
                        and re.findall(r"[a-z0-9'-]+", txt[:a_ - 1].lower())[-len(want):] == want):
                    continue
                errs_first.append(f"{name}: first use of {term!r} is not spelled out")

        for name, node_ in chunks:
            scan(name, node_)
        # the plain pages spell abbreviations out at first use too; their own spelled-out terms (such as SDKs) are not
        # app abbreviations, so only the first-use rule applies there
        for key in ("privacy", "support"):
            f = DOCS / f"{key}.html"
            if f.is_file():
                ptree = parse(f.read_text(encoding="utf-8"))
                if "main" in ptree.ids:
                    scan(f"docs/{key}.html", ptree.ids["main"][0], coverage=False)
        rep.check("glossary: every abbreviation in the rendered text has a glossary entry", sorted(set(errs_cov)),
                  f"{len(gl)} entries, {n_abbr} abbreviation uses checked across the header, {len(chunks) - 2} sections and the footer")
        for term, short in SPELLED_PINS.items():
            if short.lower() not in spelled.get(term, []):
                errs_first.append(f"{short!r} does not count as {term} spelled out")
        rep.check("glossary: every abbreviation is spelled out at its first use in running text in each section and on the privacy and support pages "
                  f"(a well-known term written short counts: {', '.join(SPELLED_PINS.values())})", errs_first, f"{n_first} first uses checked")
        # labels (Session 7, section 4.9; the label set is build_web.LABEL_TAGS and LABEL_CLASSES)
        errs_lab, st = label_errors(tree_full, forms_rx, by_form, B.slug)
        for key, page in pages_text.items():
            ptree_ = parse(page)
            for n_ in walk_nodes(ptree_.root):
                if is_label(n_) and any("xp" in classes_of(x) for x in walk_nodes(n_)):
                    errs_lab.append(f"{key}: an expansion sits inside a label <{n_.tag}>")
        rep.check("labels: no expansion inserted inside any label; each abbreviation in a label links to its glossary entry described by the expansion, "
                  "or its link, button or summary is described by it; every description resolves to the glossary", errs_lab,
                  f"{st['labels']} labels, {st['uses']} abbreviation uses: {st['linked']} linked, {st['described']} described by their control")
        # well-known terms (Session 7D): linked to the glossary, never spelled out, in any built page
        errs_wk, n_wk = [], 0
        marked = {e["term"]: e["expansion"] for e in entries if e["wellKnown"]}
        if marked != WELL_KNOWN:
            errs_wk.append(f"glossary entries marked wellKnown are {marked}, expected {WELL_KNOWN}")
        built_pages = {"web/lensatic.html": full}
        built_pages.update({f"docs/{f}": (DOCS / f).read_text(encoding="utf-8") for f in ("index.html", "privacy.html", "support.html")
                            if (DOCS / f).is_file()})
        for expansion in WELL_KNOWN.values():
            for o, c in (("(", ")"), ("[", "]")):
                probe = f"{o}{expansion}{c}"
                for where, text in built_pages.items():
                    k = htmllib.unescape(text).lower().count(probe.lower())
                    if k:
                        errs_wk.append(f"{where}: {probe!r} appears {k} time{'s' if k != 1 else ''}")
        for name, node_ in chunks:
            if name in ("header", "footer"):
                continue
            for term, ok in first_links(node_, forms_rx, by_form, B.slug).items():
                n_wk += 1
                if not ok:
                    errs_wk.append(f"{name}: the first use of {term!r} in running text is not a link to its glossary entry")
        rep.check(f"well-known terms: only {', '.join(WELL_KNOWN)} marked; never spelled out, no parenthetical expansion in any built page; "
                  "the first use in running text in each section links to the glossary entry", errs_wk,
                  f"{len(built_pages)} pages, {n_wk} first uses checked")

    # layout, in a real engine
    errs = []
    info = "no browser"
    if not node or not LAYOUT.exists():
        errs.append("node or tools/layout_check.mjs missing")
    else:
        proc = subprocess.run([node, str(LAYOUT), str(HTML)], capture_output=True, text=True, timeout=240)
        try:
            o = json.loads(proc.stdout.strip().split("\n")[-1])
        except Exception:  # noqa: BLE001
            o = {"error": (proc.stderr or proc.stdout).strip()[:300]}
        if "error" in o:
            errs.append(f"layout measurement unavailable: {o['error']}")
        else:
            j12, j14, j375 = o["js_1280"], o["js_1440"], o["js_375"]
            info = (f"collapsed DoW table {j12['dowTableWidth']} px in a {j12['viewport']} px viewport at 1280, "
                    f"{j14['dowTableWidth']} px in {j14['viewport']} px at 1440")
            if j12["dowTableWidth"] > j12["viewport"] or j12["dowWrapScroll"] > j12["dowWrapClient"] + 1:
                errs.append(f"1280: the collapsed DoW table overflows ({j12['dowTableWidth']} px table, scroll {j12['dowWrapScroll']} in {j12['dowWrapClient']})")
            for key, m in (("js_1280", j12), ("js_1440", j14), ("js_375", j375), ("nojs_375", o["nojs_375"]), ("nojs_1280", o["nojs_1280"])):
                if m["pageScrollWidth"] > m["viewport"]:
                    errs.append(f"{key}: the page scrolls sideways ({m['pageScrollWidth']} > {m['viewport']})")
            for key, m in (("js_1280", j12), ("js_1440", j14), ("js_375", j375)):
                if not m["scripted"] or m["openCells"] != 0 or m["cisaHidden"] is not True:
                    errs.append(f"{key}: expected the scripted view (cells collapsed, one table)")
            if j375["dowWrapScroll"] > j375["dowWrapClient"] and (j375["colnavHidden"] or j375["afterNext"]["scrollLeft"] <= 0 or not j375["afterNext"]["fadeLeft"]):
                errs.append("375: column buttons, column step or edge fade not working where the table scrolls")
            ak = j375["arrowKey"]
            if not ak["focused"] or abs(ak["scrollLeft"] - ak["expectedStop"]) > 2:
                errs.append(f"375: ArrowRight on the focused table did not scroll by one column ({ak})")
            bt = j375["backToTop"]
            if bt["hiddenAttr"] or bt["atTop"] != "hidden" or bt["afterScroll"] != "visible":
                errs.append(f"375: back to top does not appear after the first screenful ({bt})")
            want = [p_ for texts in items.values() for t in texts for p_ in parts_of(t)]
            for key in ("nojs_375", "nojs_1280"):
                m = o[key]
                vis = norm(m["visibleText"]).lower()  # innerText applies text-transform: the door meta lines and mono headings read in capitals
                if m["scripted"] or m["openCells"] != 42 or m["cisaHidden"] is not False:
                    errs.append(f"{key}: expected the no-script page (both tables, cells open)")
                lost = [t for t in want if t.lower() not in vis]
                if lost:
                    errs.append(f"{key}: {len(lost)} texts not visible with scripting disabled, first {lost[0][:60]!r}")
            for key, m in o["header"].items():
                if key.startswith("current"):
                    for s in m:
                        if s.get("top"):
                            if not s["hidden"] or s["marked"]:
                                errs.append(f"{key[7:]}: back in the intro the menu still names a section ({s['text']!r})")
                            continue
                        if s["inBand"] and (s["hidden"] or s["text"] != s["expected"]):
                            errs.append(f"{key[7:]}: the menu button does not name {s['sec']!r} in view ({s['text']!r})")
                        if s["truncated"] or s["right"] > s["vw"]:
                            errs.append(f"{key[7:]}: the menu button cuts off or spills the name of {s['sec']!r} (right {s['right']} in {s['vw']})")
                    if not any(s.get("inBand") and not s["hidden"] for s in m):
                        errs.append(f"{key[7:]}: no section could be brought into view to name")
                    continue
                if m["bad"] or m["headerScroll"] > m["headerClient"] + 1 or m["navOverflow"] > 1:
                    errs.append(f"header {key}: overflow (scroll {m['headerScroll']} in {m['headerClient']}, strip overflow {m['navOverflow']}, spill {m['bad'][:2]})")
                if int(key.split("_")[0]) <= 480 and (m["navShown"] or not m["menuShown"]):
                    errs.append(f"header {key}: expected the section menu, not the strip of links")
            # matrix cells carry their pillar name below 768 px, and only there
            for key, m in o.get("pillars", {}).items():
                narrow = key.startswith("375")
                if not m["cells"] or m["mismatch"] or (m["shown"] != m["cells"] if narrow else m["shown"]):
                    errs.append(f"{key}: pillar names on matrix cells: {m['shown']} shown of {m['cells']}, {len(m['mismatch'])} not matching their column {m['mismatch'][:2]}")
            if len(o.get("pillars", {})) != 4:
                errs.append("pillar names on matrix cells were not measured at 375 and 768")
            # tap targets (Session 7): the phone checks run with touch emulation, so the coarse-pointer rules are what is measured
            tg = {"375": o["js_375"].get("targets", {}), **{str(k): v for k, v in o.get("targets", {}).items()}}
            for key, m in tg.items():
                if not m:
                    errs.append(f"{key}: tap targets not measured")
                    continue
                if m["coarse"] != (key in ("360", "375")):
                    errs.append(f"{key}: pointer is {'coarse' if m['coarse'] else 'fine'}, expected {'coarse (touch emulated)' if key in ('360', '375') else 'fine'}")
                if m["small"] or not m["chips"]:
                    errs.append(f"{key}: chips under {m['floor']} px tall ({m['chips']} chips): {m['small']}")
                if m["controls"]:
                    errs.append(f"{key}: buttons or menu links under 44 px: {m['controls']}")
                if key in ("360", "375") and m.get("menuLinks", 0) < 9:
                    errs.append(f"{key}: the section menu's links were not measured open ({m.get('menuLinks')} seen)")
            for key, items_ in o["clipped"].items():
                if items_:
                    errs.append(f"{key}: content clipped past the right edge with every disclosure open: {items_[:3]}")
            # print: every non-matrix text; the department's view only, each cell's first sentence only; at most 20 pages
            cells = {(c["pillarId"], c["functionId"]): c for c in d["matrix"]["cells"]}
            # the hero's two buttons do nothing on paper and do not print (session 11, RED-10)
            buttons = [norm(L["heroPrimary"]), norm(L["heroSecondary"])]
            non_matrix = [p_ for k, texts in items.items() if not k.startswith("cell-") for t in texts for p_ in parts_of(t) if p_ not in buttons]
            leads, rests = [], []
            for p_ in d["pillars"]["views"]["dow"]:
                for f in d["functions"]:
                    lead, rest = first_sentence_of(cells[(p_, f["id"])]["text"])
                    leads.append(norm(tok_dow(d, lead)))
                    if rest:
                        rests.append(norm(tok_dow(d, rest)))
            n_caps = 0
            for key in ("print", "print_nojs"):
                pr = o[key]
                ptext = norm(pr["text"]).lower()
                lost = [t for t in non_matrix + leads if t.lower() not in ptext]
                leaked = [t for t in rests if t.lower() in ptext]
                printed = [b_ for b_ in buttons if b_.lower() in ptext]
                if printed:
                    errs.append(f"{key}: the hero's buttons print: {printed}")
                # the caption promises capability numbers: each department cell prints its numbers right before its sentence
                # (session 11, RED-01), row by row as the table prints
                pos, no_caps, n_caps = 0, [], 0
                for f in d["functions"]:
                    for p_ in d["pillars"]["views"]["dow"]:
                        c_ = cells[(p_, f["id"])]
                        lead_ = norm(tok_dow(d, first_sentence_of(c_["text"])[0])).lower()
                        i_ = ptext.find(lead_, pos)
                        if i_ < 0:
                            continue  # a lost sentence is reported above
                        caps_ = " ".join(c_.get("capabilityIds") or [])
                        if caps_:
                            n_caps += 1
                            if not ptext[pos:i_].rstrip().endswith(caps_.lower()):
                                no_caps.append(f"{p_} x {f['id']}")
                        pos = i_ + len(lead_)
                if no_caps or not n_caps:
                    errs.append(f"{key}: {len(no_caps)} of {n_caps} department cells print no capability numbers before their sentence, first {no_caps[:2]}")
                if lost or leaked or pr["cisaWrapClient"] != 0 or pr["pageScrollWidth"] > pr["viewport"] or print_pages_errors(pr["pages"]):
                    errs.append(f"{key}: {pr['pages']} pages, {len(lost)} texts missing (first {lost[0][:50]!r} )" if lost else
                                f"{key}: {pr['pages']} pages, {len(leaked)} later cell sentences printed, CISA table width {pr['cisaWrapClient']}, page {pr['pageScrollWidth']} in {pr['viewport']}")
            print_info = (f"print {o['print']['pages']} pages with script and {o['print_nojs']['pages']} without, every non-matrix text but the hero's buttons "
                          f"and the {len(leads)} first sentences of the department's view present, the {n_caps} cells that carry capability numbers "
                          f"printing them before the sentence")
            info += f"; at 375 the column buttons, ArrowRight (one column, {ak['scrollLeft']} px) and back to top work"
            info += f"; with touch emulated at 360 and 375 every chip is at least 44 px tall ({tg.get('375', {}).get('chips')} chips), at 1280 at least 36"
            info += f"; header fits at 360, 375, 390, 414, 480, 768, 1024, 1199, 1200, 1280 and 1440, script on or off, with the section menu at 480 and below naming the section in view, in full, for every section at 360 and 375, and nothing back in the intro"
            info += f"; nothing clipped at 360, 375, 390 or 414 with every disclosure open, script on or off; every visible matrix cell names its pillar at 375 ({o.get('pillars', {}).get('375_js', {}).get('shown')} with script, {o.get('pillars', {}).get('375_nojs', {}).get('shown')} without) and none does at 768"
            info += f"; no sideways page scroll at 375, 1280, 1440; {len(want)} texts visible with scripting off at 375 and 1280; {print_info} ({o['browser'].split('/')[-1]})"
    rep.check("layout: DoW table fits at 1280; header fits at phone widths; nothing clipped; script-off text complete; print at most 20 pages and complete, "
              "with capability numbers and without the hero's buttons", errs, info)

    print("\n".join(rep.lines))
    if rep.failures:
        print(f"WEB CHECKS RED ({len(rep.failures)})"); return 1
    print("WEB CHECKS GREEN"); return 0


if __name__ == "__main__":
    sys.exit(main())
