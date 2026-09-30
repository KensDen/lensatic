#!/usr/bin/env python3
"""Build web/lensatic.html from content/stack.json and web/src/.

Static first: every piece of content is rendered into the HTML at build time, so the page is complete
with scripting disabled (attachment previews, locked-down desktops, the iOS Files preview). The behavior
script in web/src/app.js only enhances what is already in the document; it never creates text. Controls
that need script are rendered with the hidden attribute and unhidden by the script.

Type (Session 7): the four IBM Plex faces in web/src/fonts/ are embedded as base64 @font-face rules, so the page
still makes no network request. The tab icon is an inline SVG data URI of the app's tile.

With --pages it also writes the project site under docs/ for GitHub Pages: docs/index.html (byte-identical to
the built page), docs/privacy.html and docs/support.html (plain pages, no script, text from content/stack.json,
theme tokens from the top of styles.css, the same type), docs/social-card.png (web/src/social-card.png, byte
for byte; only a link-preview crawler fetches it) and an empty docs/.nojekyll.

Deterministic: the output depends only on the inputs and the --author flag.
The JSON is embedded verbatim (byte for byte) inside <script type="application/json" id="stack">
as the provenance of the render; the build refuses to run if the JSON contains a byte sequence
that could end the script element.

Usage: python3 tools/build_web.py [--author "Name"] [--pages] [--texts PATH]
"""
from __future__ import annotations

import argparse
import base64
import html
import json
import re
import sys
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STACK = ROOT / "content" / "stack.json"
SRC = ROOT / "web" / "src"
OUT = ROOT / "web" / "lensatic.html"
PHOTO = SRC / "about-photo.jpg"  # the maker's photo beside Why the name in About (session 7D)
DOCS = ROOT / "docs"
PAGES = ("privacy", "support")
FONT_DIR = SRC / "fonts"
# the four faces the page embeds: family, weight, IBM's own Latin1 subset file in web/src/fonts/ (no italics; the
# browser's oblique is acceptable)
FONT_FACES = (("IBM Plex Sans", 400, "IBMPlexSans-Regular-Latin1.woff2"), ("IBM Plex Sans", 700, "IBMPlexSans-Bold-Latin1.woff2"),
              ("IBM Plex Mono", 400, "IBMPlexMono-Regular-Latin1.woff2"), ("IBM Plex Mono", 700, "IBMPlexMono-Bold-Latin1.woff2"))
SOCIAL_CARD = SRC / "social-card.png"
SOCIAL_SIZE = (1200, 630)
# the published site and the source repository: the footer's three links and the link-preview tags point here
SITE = "https://kensden.github.io/lensatic/"
REPO = "https://github.com/KensDen/lensatic"
TILE_BG, TILE_FG = "#0E100D", "#9BE15D"  # the icon tile, dark in both themes (the --tile-* tokens of the paper theme)

TOKEN_RE = re.compile(r"\{\{\s*dow(?:\.([A-Za-z]+))?\s*\}\}")
MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
SECTIONS = ["doors", "stack", "matrix", "functions", "ai", "helper", "sources", "glossary", "about"]

# Labels (Session 7, section 4.9): short texts that name a thing rather than say something about it. An abbreviation in
# a label renders as its short form and never takes an expansion. Where links are allowed it links to its glossary entry,
# with the entry's expansion as the link's accessible description (aria-describedby); inside a link, button or disclosure
# summary, that control is described by the expansion instead. Running text keeps the first-use rule, and label text
# never counts as a first use. tools/check_web.py reads this set from here.
# Session 11 (Q21, ED-05) adds the texts that name an entry: every link to an entry (a link list, a step's citation links,
# the glossary's See: line, Draws on, Assessed against, a deadline's source), a cell's list of capability names, and an
# entry's title in its Sources summary.
LABEL_TAGS = frozenset({"h1", "h2", "h3", "h4", "th", "button", "nav", "footer"})    # headings, table headers, buttons, nav and menu items, the footer
LABEL_CLASSES = frozenset({"door-title", "chip", "btn", "status", "door-meta", "layer-tag", "eyebrow", "stamp", "sec-num",
                           "ref", "caps-list", "ent-title"})
INTERACTIVE = frozenset({"a", "button", "summary"})
# the statuses whose note the status key promises beside the badge: every address tried, or both readings and a date
PROBLEM = ("conflict", "unverified")
MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]


def is_label(tag: str, classes: set[str]) -> bool:
    return tag in LABEL_TAGS or bool(classes & LABEL_CLASSES)


def esc(s) -> str:
    return html.escape("" if s is None else str(s), quote=True)


def first_sentence(s: str) -> tuple[str, str]:
    m = re.match(r"^(.*?[.!?])(\s|$)", s or "")
    if not m:
        return s or "", ""
    return m.group(1), (s[len(m.group(1)):]).strip()


def fmt_date(iso: str | None) -> str:
    m = re.match(r"^(\d{4})(?:-(\d{2})(?:-(\d{2}))?)?$", iso or "")
    if not m:
        return esc(iso or "")
    out = m.group(1)
    if m.group(2):
        out = f"{MONTHS[int(m.group(2)) - 1]} {out}"
    if m.group(3):
        out = f"{int(m.group(3))} {out}"
    return out


URL_RE = re.compile(r'https?://[^\s<>"]+')


def linkify(escaped: str) -> str:
    """Turn plain URLs in already-escaped note text into links, leaving trailing prose punctuation outside."""
    def rep(m: re.Match) -> str:
        url = m.group(0)
        tail = ""
        while url and url[-1] in ".,;:)":
            tail = url[-1] + tail
            url = url[:-1]
        return f'<a class="url" href="{url}" rel="noreferrer">{url}</a>{tail}'
    return URL_RE.sub(rep, escaped)


def slug(term: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", term.lower()).strip("-")


def form_pattern(forms: list[str], prefix: bool = False) -> str:
    """A form matches as a whole token: no letter, digit or dot before it, no letter or digit after it
    (a prefix form such as FY may be followed by digits, as in FY2027)."""
    after = r"(?![A-Za-z])" if prefix else r"(?![A-Za-z0-9])"
    alts = "|".join(re.escape(f) for f in sorted(forms, key=len, reverse=True))
    return rf"(?<![A-Za-z0-9.])(?:{alts}){after}"


def edition_repeats_date(edition: str, date: str | None) -> bool:
    """True where an edition is only a date, the same one the date field gives: 'November 2024' beside 2024-11."""
    months = "|".join(MONTH_NAMES + MONTHS)
    m = re.fullmatch(rf"(?:(\d{{1,2}}) )?({months}) (\d{{4}})", edition or "")
    d = re.fullmatch(r"(\d{4})-(\d{2})(?:-(\d{2}))?", date or "")
    if not m or not d:
        return False
    month = (MONTH_NAMES.index(m.group(2)) if m.group(2) in MONTH_NAMES else MONTHS.index(m.group(2))) + 1
    day = int(m.group(1)) if m.group(1) else None
    return int(m.group(3)) == int(d.group(1)) and month == int(d.group(2)) and day == (int(d.group(3)) if d.group(3) else None)


def descriptive_edition(edition: str) -> bool:
    """A descriptive edition, as opposed to a designation such as 'Version 1.0', 'Revision 5' or 'Executive Order 14028':
    its first word is an ordinary capitalized word, the word after it is a lower-case word, and the phrase up to the first
    comma, semicolon, colon or parenthesis holds no other capitalized word (a month name aside) and no designation."""
    head = re.split(r"[,;:(]", edition or "", maxsplit=1)[0].split()
    if not head or not re.fullmatch(r"[A-Z][a-z]+", head[0]):
        return False
    if len(head) > 1 and not re.fullmatch(r"[a-z]+", head[1]):
        return False
    return all(re.fullmatch(r"[a-z]+|\d+", w) or w in MONTH_NAMES for w in head[1:])


def cite_edition(title: str, edition: str, date: str | None) -> str | None:
    """The edition as a citation line gives it (session 11, Q21: ED-09, ED-10, RED-06). A line leaves out an edition its
    title already carries ('Revision 1' after a title that ends in it) or that only repeats its date ('November 2024'
    beside Nov 2024); a descriptive edition runs into the line after a comma, so its first letter is lowered. The Edition
    field keeps the value as it is."""
    if not edition:
        return None
    if re.search(rf"(?<![A-Za-z0-9]){re.escape(edition)}(?![A-Za-z0-9])", title or ""):
        return None
    if edition_repeats_date(edition, date):
        return None
    return edition[0].lower() + edition[1:] if descriptive_edition(edition) else edition


def spelled_variants(expansion: str, well_known: list[dict]) -> list[str]:
    """The forms that count as an entry's spelled-out name: its expansion, and the expansion with a well-known term's
    expansion written as that term, which is never spelled out (session 11, Q21, ED-06): 'AI Risk Management Framework'
    for 'Artificial Intelligence Risk Management Framework'."""
    out = [expansion]
    for w in well_known:
        for f in w["forms"]:
            v = re.sub(re.escape(w["expansion"]), lambda _m, f=f: f, expansion, flags=re.I)
            if v != expansion and v not in out:
                out.append(v)
    return out


def names_itself(before: str, after: str, expansion: str) -> bool:
    """True where a form sits in parentheses right after its own name: the words before the parenthesis end with
    the expansion's last words (up to three), as in DoD Cyber Defense Command (DCDC)."""
    if not (before.endswith("(") and after.startswith(")")):
        return False
    want = expansion.lower().split()[-3:]
    have = re.findall(r"[a-z0-9'-]+", before[:-1].lower())[-len(want):]
    return have == want


class FirstUse:
    """Spell out each abbreviation at its first use in running text in every section of the built page.

    Runs over the rendered HTML of one section at a time. In running text outside scripts, styles, graphics, hidden
    elements, links to web addresses, capability numbers and pillar labels, the first match of each glossary form
    gets its expansion right after it, in a span the battery can tell apart, unless the expansion already appeared
    earlier in that section's running text (or the expansion with a well-known term written short, as AI Risk Management
    Framework for AI RMF; session 11). Where links are allowed the form itself links to its glossary entry.
    A glossary entry's own term counts as spelled out, because its expansion follows it.

    Labels (LABEL_TAGS, LABEL_CLASSES) never take an expansion and never count as a first use: each form in a label
    links to its glossary entry, described by the expansion, or, inside a link, button or summary, the enclosing
    control is described by it. On the plain pages, which carry no glossary, a label's form is an abbr element whose
    title is the expansion.

    Placement rules: a prefix form keeps its designation, so the expansion follows FY2027, IL4, NAVADMIN 030/22
    or ISO/IEC 27001 (where a second form inside the designation, IEC, adds its own expansion); a form already
    in parentheses right after its spelled-out name, as in DoD Cyber Defense Command (DCDC), is left alone;
    inside an open parenthesis the expansion takes square brackets; a plural form takes a plural expansion;
    a name marked notAbbreviation, such as MITRE, is linked and never expanded; a term marked wellKnown, such as AI,
    is linked the same way and never expanded, in running text or labels, though its glossary entry keeps the
    expansion; an entry marked nameFirst (the department, under its render rule) is spelled out name first, as in
    Department of War (DoW).
    """
    DESIGNATION = re.compile(r"(?:/([A-Z][A-Za-z]+))?\s?\d+(?:[-/:]\d+)*")
    SKIP_TAGS = {"script", "style", "svg", "textarea", "title"}
    SKIP_CLASSES = {"url", "xp", "caps", "pillar-label", "gl"}
    VOID = {"br", "img", "hr", "meta", "input", "wbr", "link", "source", "col", "area", "base", "embed", "track", "path", "circle", "rect"}

    def __init__(self, entries: list[dict], link: bool = True) -> None:
        self.link = link
        self.by_form: dict[str, dict] = {}
        well_known = [e for e in entries if e.get("wellKnown") and e["expansion"]]
        self.variants = {e["term"]: spelled_variants(e["expansion"], well_known) for e in entries if e["expansion"]}
        plain, prefix = [], []
        for e in entries:
            for f in e["forms"]:
                ef = esc(f)
                self.by_form[ef] = e
                (prefix if e.get("prefix") else plain).append(ef)
        pats = [form_pattern(plain)] if plain else []
        if prefix:
            pats.append(form_pattern(prefix, prefix=True))
        self.rx = re.compile("|".join(pats)) if pats else None

    @staticmethod
    def exp_id(e: dict) -> str:
        return f"glx-{e['slug']}"

    def spelled_before(self, e: dict, before: str) -> bool:
        """Whether the text so far already spells the entry out, in its expansion or a variant of it (spelled_variants)."""
        low = before.lower()
        return any(v.lower() in low for v in self.variants.get(e["term"], [e["expansion"]]))

    @staticmethod
    def spells(e: dict) -> bool:
        """Whether the page ever spells this entry out: not a name, and not a term every reader knows."""
        return bool(e["expansion"]) and not e.get("notAbbreviation") and not e.get("wellKnown")

    def label_part(self, part: str, stack: list[dict], out: list[str], describe: dict[int, list[str]]) -> str:
        """A text node inside a label: short forms only, linked or described, never expanded."""
        pieces, pos = [], 0
        nolink = not self.link or any(fr["nolink"] for fr in stack)
        for m in self.rx.finditer(part):
            if m.start() < pos:
                continue
            e = self.by_form.get(m.group(0))
            if not e:
                continue
            end, found = m.end(), [e]
            if e.get("prefix"):
                des = self.DESIGNATION.match(part, end)
                if des:
                    inner = self.by_form.get(des.group(1) or "")
                    if inner:
                        found.append(inner)
                    end = des.end()
            ids = [self.exp_id(x) for x in found if self.spells(x)]
            token = part[m.start():m.end()]
            if not self.link:
                exp = " and ".join(x["expansion"] for x in found if self.spells(x))
                wrapped = f'<abbr title="{esc(exp)}">{token}</abbr>' if exp else token
                pieces += [part[pos:m.start()], wrapped, part[m.end():end]]
            elif nolink:
                owner = next((fr for fr in reversed(stack) if fr["tag"] in INTERACTIVE), None)
                if owner is not None:
                    describe.setdefault(owner["index"], []).extend(ids)
                pieces.append(part[pos:end])
            else:
                desc = f' aria-describedby="{" ".join(ids)}"' if ids else ""
                pieces += [part[pos:m.start()], f'<a class="gl" href="#gl-{e["slug"]}"{desc}>{token}</a>', part[m.end():end]]
            pos = end
        pieces.append(part[pos:])
        return "".join(pieces)

    def section(self, chunk: str) -> str:
        if not self.rx:
            return chunk
        out: list[str] = []
        stack: list[dict] = []
        describe: dict[int, list[str]] = {}
        handled: set[str] = set()
        seen = ""
        for part in re.split(r"(<[^>]+>)", chunk):
            if part.startswith("<"):
                out.append(part)
                m = re.match(r"<\s*(/)?\s*([A-Za-z0-9]+)", part)
                if not m:
                    continue
                closing, tag = m.group(1), m.group(2).lower()
                if closing:
                    while stack:
                        if stack.pop()["tag"] == tag:
                            break
                    continue
                if tag in self.VOID or part.endswith("/>"):
                    continue
                cm = re.search(r'class="([^"]*)"', part)
                classes = set(cm.group(1).split()) if cm else set()
                stack.append({"tag": tag, "index": len(out) - 1,
                              "hard": tag in self.SKIP_TAGS or 'aria-hidden="true"' in part or bool(classes & self.SKIP_CLASSES),
                              "hidden": re.search(r"\shidden(?=[\s>=])", part) is not None,
                              "nolink": tag in INTERACTIVE, "glterm": "gl-term" in classes, "label": is_label(tag, classes)})
                continue
            if not part:
                continue
            if any(fr["hard"] for fr in stack):
                seen += html.unescape(part)
                out.append(part)
                continue
            if any(fr["label"] for fr in stack):
                out.append(self.label_part(part, stack, out, describe))  # a label is never a first use
                continue
            if any(fr["hidden"] for fr in stack):
                seen += html.unescape(part)
                out.append(part)
                continue
            if any(fr["glterm"] for fr in stack):
                e = self.by_form.get(part.strip())
                if e:
                    handled.add(e["term"])
                seen += html.unescape(part)
                out.append(part)
                continue
            nolink = not self.link or any(fr["nolink"] for fr in stack)
            pieces, pos = [], 0
            for m in self.rx.finditer(part):
                if m.start() < pos:
                    continue  # inside a designation already taken, as IEC in ISO/IEC 27001
                e = self.by_form.get(m.group(0))
                if not e or e["term"] in handled:
                    continue
                handled.add(e["term"])
                link = f'<a class="gl" href="#gl-{e["slug"]}">'
                if e.get("notAbbreviation") or e.get("wellKnown"):
                    if not nolink:
                        pieces += [part[pos:m.start()], f"{link}{m.group(0)}</a>"]
                        seen += html.unescape(part[pos:m.end()])
                        pos = m.end()
                    continue
                before = seen + html.unescape(part[:m.start()])
                if self.spelled_before(e, before):
                    continue
                if names_itself(before, part[m.end():], e["expansion"]):
                    continue
                end, expansions = m.end(), [e["expansion"]]
                if e.get("prefix"):
                    des = self.DESIGNATION.match(part, end)
                    if des:
                        end = des.end()
                        inner = self.by_form.get(des.group(1) or "")
                        if inner and inner["term"] not in handled and self.spells(inner):
                            handled.add(inner["term"])
                            if not self.spelled_before(inner, before):
                                expansions.append(inner["expansion"])
                if m.group(0).endswith("s") and not e["term"].endswith("s") and not expansions[0].endswith("s"):
                    expansions[0] += "s"
                opened = html.unescape(part[:m.start()])  # the text node so far: is a parenthesis open?
                o, c = ("[", "]") if opened.count("(") > opened.count(")") else ("(", ")")
                spelled = " and ".join(expansions)
                token = part[m.start():end]
                linked = token if nolink else f"{link}{token}</a>"
                if e.get("nameFirst"):
                    pieces += [part[pos:m.start()], f'<span class="xp">{esc(spelled)} {o}</span>{linked}<span class="xp">{c}</span>']
                    seen += html.unescape(part[pos:m.start()]) + f"{spelled} {o}{html.unescape(token)}{c}"
                else:
                    pieces += [part[pos:m.start()], linked, f'<span class="xp"> {o}{esc(spelled)}{c}</span>']
                    seen += html.unescape(part[pos:end]) + f" {o}{spelled}{c}"
                pos = end
            pieces.append(part[pos:])
            seen += html.unescape(part[pos:])
            out.append("".join(pieces))
        for i, ids in describe.items():
            ids = list(dict.fromkeys(ids))
            if ids:
                out[i] = re.sub(r"\s*>$", f' aria-describedby="{" ".join(ids)}">', out[i])
        return "".join(out)


def jpeg_size(data: bytes) -> tuple[int, int]:
    """Width and height from a JPEG's frame header."""
    i = 2
    while i < len(data) - 9:
        if data[i] != 0xFF:
            break
        m, length = data[i + 1], int.from_bytes(data[i + 2:i + 4], "big")
        if 0xC0 <= m <= 0xCF and m not in (0xC4, 0xC8, 0xCC):
            return int.from_bytes(data[i + 7:i + 9], "big"), int.from_bytes(data[i + 5:i + 7], "big")
        i += 2 + length
    sys.exit("web/src/about-photo.jpg: no frame header")


def mark_paths() -> tuple[str, str]:
    svg = (SRC / "mark.svg").read_text(encoding="utf-8").strip()
    view_box = re.search(r'viewBox="([^"]+)"', svg).group(1)
    paths = "".join(re.findall(r"<path\b[^>]*/>", svg))
    if not paths or "<image" in svg or "data:" in svg:
        sys.exit("web/src/mark.svg must hold vector paths only")
    return view_box, paths


def mark_svg(size: int = 28, cls: str = "mark") -> str:
    """The mark: the traced instrument from web/src/mark.svg, inlined in currentColor."""
    view_box, paths = mark_paths()
    return (f'<svg class="{cls}" viewBox="{view_box}" width="{size}" height="{size}" aria-hidden="true" focusable="false">'
            f"{paths}</svg>")


def favicon() -> str:
    """The tab icon: the tile as an inline SVG data URI, a rounded dark square with the mark in phosphor. Not a request."""
    view_box, paths = mark_paths()
    w = float(view_box.split()[2])
    paths = paths.replace('fill="currentColor"', f'fill="{TILE_FG}"')
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="14" fill="{TILE_BG}"/>'
           f'<g transform="translate(9 9) scale({46 / w:g})">{paths}</g></svg>')
    return "data:image/svg+xml," + urllib.parse.quote(svg, safe="/=:.,-")


def font_css() -> str:
    """The four faces as base64 @font-face rules: the page stays one file and makes no request for its type."""
    rules = []
    for fam, weight, name in FONT_FACES:
        b64 = base64.b64encode((FONT_DIR / name).read_bytes()).decode("ascii")
        rules.append(f"@font-face {{ font-family: '{fam}'; font-style: normal; font-weight: {weight}; font-display: swap; "
                     f"src: url(data:font/woff2;base64,{b64}) format('woff2'); }}")
    return "\n".join(rules)


def door_meta(r: "Renderer", door: dict) -> str:
    """The door card's meta line: the step count and the layers the steps touch, listed; or, for a door with no steps,
    the first sentence of its paragraph."""
    steps = door.get("steps") or []
    if not steps:
        return r.t(first_sentence(door.get("paragraph") or "")[0])  # rendered with the sentence class, in its own case
    layers = sorted({r.layer[s["layerId"]]["order"] for s in steps})
    L = r.L
    count = L["doorMetaStep"] if len(steps) == 1 else L["doorMetaSteps"].replace("{n}", str(len(steps)))
    which = (L["doorMetaLayer"] if len(layers) == 1 else L["doorMetaLayers"]).replace("{list}", L["listSeparator"].join(str(x) for x in layers))
    return r.t(count + L["metaSeparator"] + which)


class Renderer:
    def __init__(self, d: dict, author: str) -> None:
        self.d = d
        self.author = author
        self.ui = d["ui"]
        self.L = d["ui"]["labels"]
        self.dow = d["orgs"]["dow"]
        self.fw = {x["id"]: x for x in d["frameworks"]}
        self.src = {x["id"]: x for x in d["sources"]}
        self.sol = {x["id"]: x for x in d.get("solutions", [])}
        self.layer = {x["id"]: x for x in d["layers"]}
        self.fn = {x["id"]: x for x in d["functions"]}
        self.pillar = {x["id"]: x for x in d["pillars"]["canonical"]}
        self.cap_name = {c["id"]: c["name"] for p in d["pillars"]["canonical"] for c in p.get("capabilities", [])}
        self.sections = [x for x in SECTIONS if x != "glossary" or d.get("glossary")]

    # ---------------------------------------------------------------- text
    def tok(self, s: str | None, hidden: bool = False) -> str:
        """Render department tokens: dow is the abbreviation and dow.<field> the field. The first mention in running
        text in each section is spelled out name first by FirstUse (the glossary entry is marked nameFirst), so a label
        keeps the abbreviation."""
        def rep(m: re.Match) -> str:
            field = m.group(1)
            return str(self.dow.get(field, "")) if field else self.dow["abbr"]
        return TOKEN_RE.sub(rep, s or "")

    def t(self, s: str | None, hidden: bool = False) -> str:
        return esc(self.tok(s, hidden))

    def label(self, key: str, hidden: bool = False) -> str:
        return self.t(self.L[key], hidden)

    def tl(self, s: str | None) -> str:
        """Note text: escaped, tokens rendered, plain URLs made tappable."""
        return linkify(self.t(s))

    # ---------------------------------------------------------------- pieces
    def ent(self, eid: str) -> dict | None:
        return self.fw.get(eid) or self.src.get(eid) or self.sol.get(eid)

    def ent_link(self, eid: str) -> str:
        """A link to an entry, by its short name: a label (class ref), so it never takes an expansion and the link is
        described by the expansions of the abbreviations it holds."""
        e = self.ent(eid)
        if not e:
            sys.exit(f"entity {eid!r} does not resolve")
        return f'<a class="ref" href="#ent-{esc(eid)}">{self.t(e["shortName"])}</a>'

    def ent_links(self, ids) -> str:
        return ", ".join(self.ent_link(i) for i in ids or [])

    def layer_tag(self, lid: str | None) -> str:
        """A layer's tag, linked to its band in the stack: Layer and its number, or, for the AI column (isColumn), which
        is beside the five layers rather than a sixth, the column's name, linked to the column (session 11, Q20 and Q36)."""
        layer = self.layer.get(lid or "")
        if not layer:
            return ""
        if layer.get("isColumn"):
            return f'<a class="layer-tag" href="#seam">{self.t(layer["name"])}</a> '
        return f'<a class="layer-tag" href="#layer-{esc(layer["id"])}">{self.label("layer")} {layer["order"]}</a> '

    def status_badge(self, v: dict | None) -> str:
        if not v:
            return ""
        s = v["status"]
        txt = self.t(self.ui["status"].get(s, s))
        if s == "verified" and v.get("verifiedOn"):
            txt += f', {self.label("verifiedOn")} {fmt_date(v["verifiedOn"])}'
        if v.get("recheckAfter"):
            txt += f', {self.label("recheckAfter")} {fmt_date(v["recheckAfter"])}'
        return f'<span class="status {esc(s)}">{txt}</span>'

    def problem_note(self, v: dict | None) -> str:
        """A conflict or an unreached primary is explained where the badge shows it."""
        if not v or v.get("status") not in PROBLEM:
            return ""
        return f'<br><span class="small">{self.tl(v.get("note"))}</span>'

    def cite(self, title: str, edition: str, date: str | None, publisher: str | None = None) -> str:
        """A citation line: the title, the publisher (an entry's line), the edition as cite_edition gives it, the date."""
        ed = cite_edition(self.tok(title), self.tok(edition), date)
        parts = [self.t(title) + ("." if publisher is not None else "")]
        tail = ([self.t(publisher)] if publisher is not None else []) + ([esc(ed)] if ed else []) + [fmt_date(date)]
        return (parts[0] + " " if publisher is not None else parts[0] + ", ") + ", ".join(tail) + "."

    def chip(self, eid: str) -> str:
        cls = "chip" + (" src" if eid in self.src else " sol" if eid in self.sol else "")
        return f'<a class="{cls}" href="#ent-{esc(eid)}">{self.t(self.ent(eid)["shortName"])}</a>'

    # ---------------------------------------------------------------- header, hero, footer
    def header(self) -> str:
        nav = "".join(f'<a href="#view-{s}" data-sec="{s}">{self.t(self.ui["nav"][s])}</a>' for s in self.sections)
        menu = "".join(f'<a href="#view-{s}" data-sec="{s}">{self.t(self.ui["nav"][s], hidden=True)}</a>' for s in self.sections)
        th = {k: self.label(k, hidden=True) for k in ("theme", "themeSystem", "themeLight", "themeDark")}
        return (
            f'<a class="skip" href="#main">{self.label("skip")}</a>\n'
            '<header class="top" id="top"><div class="top-in">\n'
            f'  <a class="brand" href="#top">{mark_svg()}<span class="wordmark">{esc(self.d["meta"]["name"])}</span></a>\n'
            f'  <nav class="nav" id="nav" aria-label="{self.label("sectionsNav")}">{nav}</nav>\n'
            f'  <details class="navmenu" id="navmenu"><summary class="btn"><span class="navmenu-label">{self.label("sectionsNav")}</span>'
            f'<span class="navmenu-current" hidden></span></summary><nav class="navmenu-list" aria-label="{self.label("sectionsNav")}">{menu}</nav></details>\n'
            '  <div class="tools">\n'
            f'    <a class="btn icon totop" id="to-top" href="#top" hidden><svg viewBox="0 0 16 16" width="18" height="18" aria-hidden="true" focusable="false"><path d="M8 3 L13 9 L9.5 9 L9.5 13 L6.5 13 L6.5 9 L3 9 Z" fill="currentColor"/></svg><span class="vh totop-label">{self.label("backToTop", hidden=True)}</span></a>\n'
            f'    <button type="button" class="btn icon theme" id="theme-toggle" hidden data-label="{th["theme"]}" data-system="{th["themeSystem"]}" data-light="{th["themeLight"]}" data-dark="{th["themeDark"]}"><svg class="theme-icon" viewBox="0 0 16 16" width="18" height="18" aria-hidden="true" focusable="false"><circle cx="8" cy="8" r="6.5" fill="none" stroke="currentColor" stroke-width="1.5"/><path d="M8 1.5 A6.5 6.5 0 0 1 8 14.5 Z" fill="currentColor"/></svg><span class="vh theme-k">{th["theme"]}: </span><span class="vh theme-v">{th["themeSystem"]}</span></button>\n'
            "  </div>\n"
            "</div></header>\n"
        )

    def latest_check(self) -> str:
        dates = []

        def walk(n) -> None:
            if isinstance(n, list):
                for x in n:
                    walk(x)
            elif isinstance(n, dict):
                for k, v in n.items():
                    if k == "verifiedOn" and isinstance(v, str) and re.fullmatch(r"\d{4}-\d{2}-\d{2}", v):
                        dates.append(v)
                    walk(v)
        # the stack's own records; the glossary's spelling checks are not source checks
        walk({k: v for k, v in self.d.items() if k != "glossary"})
        return max(dates)

    def hero(self) -> str:
        """The front door, top to bottom: the tile, the eyebrow, the name, the description, two buttons, the version line,
        which ends with the link to Why the name in About."""
        meta = self.d["meta"]
        return (f'<div class="hero" id="intro">'
                f'<div class="tile" aria-hidden="true">{mark_svg(50, "mark tile-mark")}</div>'
                f'<p class="eyebrow">{self.label("heroEyebrow")}</p>'
                f'<h1>{esc(meta["name"])}</h1>'
                f'<p class="lede">{self.t(meta["description"])}</p>'
                f'<p class="actions"><a class="btn primary" href="#view-doors">{self.label("heroPrimary")}</a> '
                f'<a class="btn secondary" href="#view-stack">{self.label("heroSecondary")}</a></p>'
                f'<p class="stamp"><a href="#view-about">{self.label("contentVersion")} {esc(meta["contentVersion"])}</a>, '
                f'{self.label("checkedThrough")} {fmt_date(self.latest_check())}{self.label("metaSeparator")}'
                f'<a href="#about-name">{self.label("whyName")}</a></p></div>\n')

    def footer(self, page: str | None = None) -> str:
        """After main: the maker line, the licence line (all rights reserved, fonts OFL), and the policy, support and source links. Absolute
        addresses, so the links also work from the offline file. On a plain page the footer also links back to the app
        and marks the page itself as current."""
        made = f'<p class="made-by">{self.label("madeBy")} {esc(self.author)}</p>' if self.author else ""
        links = [(f"{SITE}privacy.html", "pagesPrivacy", "privacy"), (f"{SITE}support.html", "pagesSupport", "support"), (REPO, "sourceCode", "")]
        if page:
            links.insert(0, ("./", "pagesOpenApp", ""))
        current = ' aria-current="page"'
        nav = "".join(f'<a href="{href}" rel="noreferrer"{current if page and k == page else ""}>{self.label(lab)}</a>' for href, lab, k in links)
        return (f'<footer class="foot" id="footer"><div class="foot-in">{made}'
                f'<p class="foot-lic">{self.label("footerLicenses")}</p>'
                f'<nav class="foot-nav" aria-label="{self.label("footerNav")}">{nav}</nav></div></footer>\n')

    # ---------------------------------------------------------------- 1. doors
    def doors(self) -> str:
        out = []
        for door in self.d["doors"]:
            pv = f' data-pillar-view="{esc(door["pillarView"])}"' if door.get("pillarView") else ""
            who, who_rest = first_sentence(door["whoYouAre"])
            para = door.get("paragraph") or ""
            if not door.get("steps") and para:
                para = first_sentence(para)[1]  # its first sentence is the card's meta line
            # all doors closed by default; the summary holds the title, the first sentence and the meta line
            parts = [f'<details class="door" id="door-{esc(door["id"])}"{pv}>',
                     f'<summary><span class="door-title">{self.t(door["title"])}</span>'
                     f'<span class="who">{self.t(who)}</span><span class="door-meta{"" if door.get("steps") else " sentence"}">{door_meta(self, door)}</span></summary><div class="body">']
            if who_rest:
                parts.append(f'<p>{self.t(who_rest)}</p>')
            if para:
                parts.append(f'<p>{self.t(para)}</p>')
            if door.get("steps"):
                parts.append(f'<h3 class="lbl">{self.label("steps")}</h3><ol class="steps">')
                for s in door["steps"]:
                    parts.append(f'<li id="door-{esc(door["id"])}-step-{s["order"]}">{self.layer_tag(s["layerId"])}'
                                 f'{self.t(s["text"])} <small>{self.ent_links(s["entityIds"])}</small></li>')
                parts.append("</ol>")
            for ld in door.get("landings") or []:
                parts.append(f'<div class="landing" id="landing-{esc(ld["id"])}"><h3>{self.t(ld["label"])}</h3>'
                             f'<p>{self.t(ld["text"])} <small>{self.ent_links(ld["entityIds"])}</small></p></div>')
            parts.append("</div></details>")
            out.append("".join(parts))
        # the audience line introduces the doors, the plain definition of zero trust follows before the grid, and the
        # note on how steps and layer tags read sits below it
        return self.section("doors", f'<p class="section-intro lede-2" id="doors-audience">{self.label("audience")}</p>\n'
                                     f'<p class="note" id="zt-plain">{self.label("ztPlain")}</p>\n<div class="door-grid">\n'
                                     + "\n".join(out) + f'\n</div>\n<p class="note after-grid" id="doors-note">{self.label("doorsIntro")}</p>')

    # ---------------------------------------------------------------- 2. stack
    def stack(self) -> str:
        elevator = " ".join(self.t(self.fw[i]["oneLiner"]) for i in self.d["elevator"]["frameworkIds"])
        bands, seam = [], ""
        by_layer_src = [s["id"] for s in self.d["sources"] if s.get("layerId")]
        for layer in self.d["layers"]:
            if layer.get("isColumn"):
                chips = "".join(self.chip(c["id"]) for c in self.d["ai"]["column"])
                seam = (f'<aside class="seam" id="seam" aria-labelledby="h-seam"><h3 id="h-seam">{self.t(layer["name"])}</h3>'
                        f'<p class="q">{self.t(layer["question"])}</p><p class="one">{self.t(layer["oneLiner"])}</p>'
                        f'<div class="chips">{chips}</div></aside>')
                continue
            chips = "".join(self.chip(i) for i in layer["frameworkIds"])
            chips += "".join(self.chip(i) for i in by_layer_src if self.src[i]["layerId"] == layer["id"])
            sols = [s["id"] for s in self.d.get("solutions", []) if s.get("layerId") == layer["id"]]
            sol_html = ""
            if sols:
                sol_html = (f'<p class="small chips-label">{self.label("solutionsOnLayer")}</p>'
                            f'<div class="chips">{"".join(self.chip(i) for i in sols)}</div>')
            bands.append(f'<div class="band" id="layer-{esc(layer["id"])}"><h3><span class="num">{layer["order"]:02d}</span> '
                         f'<span class="lname">{self.t(layer["name"])}</span></h3><p class="q">{self.t(layer["question"])}</p>'
                         f'<p class="one">{self.t(layer["oneLiner"])}</p><div class="chips">{chips}</div>{sol_html}</div>')
        body = (f'<p class="section-intro">{self.label("stackIntro")}</p>\n<p class="elevator" id="elevator">{elevator}</p>\n<div class="section-x" id="section-x">'
                f'<div class="bands" id="bands">\n' + "\n".join(bands) + f"\n</div>\n{seam}</div>")
        return self.section("stack", body)

    # ---------------------------------------------------------------- 3. matrix
    def view_columns(self, view: str) -> list[tuple[str, str, bool]]:
        if view == "cisa":
            v = self.d["pillars"]["views"]["cisa"]
            return ([(p, self.pillar[p]["cisaName"], False) for p in v["pillars"]] +
                    [(p, self.pillar[p]["cisaName"], True) for p in v["crossCutting"]])
        return [(p, self.pillar[p]["dowName"], False) for p in self.d["pillars"]["views"]["dow"]]

    def cell(self, view: str, c: dict) -> str:
        lead, rest = first_sentence(c["text"])
        caps = c.get("capabilityIds") or []
        caps_span = ""
        if caps and view == "dow":
            caps_span = f'<span class="caps"><span class="vh">{self.label("capabilities")} </span>{esc(" ".join(caps))}</span>'
        more = f'<p class="rest">{self.t(rest)}</p>' if rest else ""
        more += f'<p class="cats">{self.label("categories")}: {esc(", ".join(c["categories"]))}</p>'
        if caps:
            names = "; ".join(esc(f'{i} {self.cap_name.get(i, "")}'.strip()) for i in caps)
            more += f'<p class="caps-list">{self.label("capabilities" if view == "dow" else "capabilitiesDow")}: {names}</p>'
        pillar = self.pillar[c["pillarId"]]["dowName" if view == "dow" else "cisaName"]
        return (f'<td class="cell" id="cell-{view}-{esc(c["pillarId"])}-{esc(c["functionId"])}">'
                f'<span class="pillar-label" aria-hidden="true">{self.t(pillar, hidden=True)}</span>'
                f'<details class="celld" open><summary>{caps_span}<span class="lead">{self.t(lead)}</span></summary>'
                f'<div class="more">{more}</div></details></td>')

    def matrix_table(self, view: str, cells: dict) -> str:
        cols = self.view_columns(view)
        cap_key = "matrixCaptionDow" if view == "dow" else "matrixCaptionCisa"
        chev = lambda d: (f'<svg viewBox="0 0 16 16" width="16" height="16" aria-hidden="true" focusable="false">'
                          f'<path d="{d}" fill="none" stroke="currentColor" stroke-width="2"/></svg>')
        head = (f'<th class="fn corner" scope="col"><span class="corner-label">{self.label("function")}</span>'
                f'<span class="colnav" hidden><button type="button" class="colbtn prev" aria-label="{self.label("previousColumn", hidden=True)}">{chev("M10 3 L5 8 L10 13")}</button>'
                f'<button type="button" class="colbtn next" aria-label="{self.label("nextColumn", hidden=True)}">{chev("M6 3 L11 8 L6 13")}</button></span></th>')
        for pid, name, cross in cols:
            head += f'<th scope="col">{self.t(name)}' + (f' <small>({self.label("crossCutting")})</small>' if cross else "") + "</th>"
        rows = []
        for fn in self.d["functions"]:
            row = f'<tr id="row-{view}-{esc(fn["id"])}"><th class="fn" scope="row"><span class="code">{esc(fn["id"])}</span> {self.t(fn["name"])}</th>'
            row += "".join(self.cell(view, cells[(pid, fn["id"])]) for pid, _, _ in cols)
            rows.append(row + "</tr>")
        return (f'<div class="matrix-view" id="matrix-{view}" data-view="{view}"><h3 class="matrix-caption" id="cap-{view}">{self.label(cap_key)}</h3><div class="matrix-frame">'
                f'<div class="matrix-wrap" tabindex="0" role="region" aria-labelledby="cap-{view}">'
                f'<table class="matrix" id="table-{view}" aria-labelledby="cap-{view}">'
                f"<thead><tr>{head}</tr></thead><tbody>\n" + "\n".join(rows) + "\n</tbody></table></div></div></div>")

    def matrix(self) -> str:
        cells = {(c["pillarId"], c["functionId"]): c for c in self.d["matrix"]["cells"]}
        control = (f'<div class="matrix-bar"><div class="matrix-control" id="matrix-control" role="group" aria-label="{self.label("pillarView", hidden=True)}" hidden>'
                   f'<button type="button" class="btn seg" data-view="dow" aria-pressed="true">{self.label("pillarViewDow", hidden=True)}</button>'
                   f'<button type="button" class="btn seg" data-view="cisa" aria-pressed="false">{self.label("pillarViewCisa", hidden=True)}</button></div>'
                   f'<button type="button" class="btn secondary" id="expand-all" aria-pressed="false" hidden data-expand="{self.label("expandAll", hidden=True)}" '
                   f'data-collapse="{self.label("collapseAll", hidden=True)}">{self.label("expandAll", hidden=True)}</button></div>')
        intro = (f'<p class="small matrix-intro">{self.label("matrixIntro")}</p>'
                 f'<p class="small matrix-jump">{self.label("matrixJump")}: <a href="#matrix-dow">{self.label("matrixCaptionDow")}</a>; '
                 f'<a href="#matrix-cisa">{self.label("matrixCaptionCisa")}</a>; <a href="#view-functions">{self.label("matrixJumpFunctions")}</a></p>'
                 f'<p class="small nojs-hint">{self.label("matrixHint")}</p>')
        # the matrix alone breaks out of the reading column, so the department's table still fits at 1280
        body = (intro + '\n<div class="matrix-out">' + control + "\n" + self.matrix_table("dow", cells) + "\n"
                + self.matrix_table("cisa", cells) + "</div>")
        return self.section("matrix", body)

    # ---------------------------------------------------------------- 4. functions
    def functions(self) -> str:
        cells = {(c["pillarId"], c["functionId"]): c for c in self.d["matrix"]["cells"]}
        cards = []
        for fn in self.d["functions"]:
            cats = "".join(f'<li><strong class="code">{esc(c["code"])}</strong> {self.t(c["name"])}</li>' for c in fn["categories"])
            rows = "".join(f'<li><strong>{self.t(p["name"])}:</strong> {self.t(first_sentence(cells[(p["id"], fn["id"])]["text"])[0])}</li>'
                           for p in self.d["pillars"]["canonical"] if (p["id"], fn["id"]) in cells)
            cards.append(f'<article class="fncard" id="fn-{esc(fn["id"])}"><h3><span class="code">{esc(fn["id"])}</span> {self.t(fn["name"])}</h3>'
                         f'<p class="q small">{self.t(fn["question"])}</p><p class="lbl">{self.label("categories")}</p><ul class="cat-list">{cats}</ul>'
                         f'<div class="lands"><p class="lbl">{self.label("whereZtLands")}</p><p>{self.t(fn["ztLanding"])}</p>'
                         f'<ul class="row-list">{rows}</ul></div></article>')
        return self.section("functions", '<div class="fn-grid">\n' + "\n".join(cards) + "\n</div>")

    # ---------------------------------------------------------------- 5. AI column
    def ai(self) -> str:
        chips = "".join(self.chip(c["id"]) for c in self.d["ai"]["column"])
        rows = "".join(f'<tr id="soc-{esc(r["functionId"])}"><th scope="row">{self.t(self.fn[r["functionId"]]["name"])}</th><td>{self.t(r["outcome"])}</td></tr>'
                       for r in self.d["ai"]["socProfile"])
        body = (f'<div id="ai-body"><div class="chips">{chips}</div><p class="ai-note">{self.t(self.d["ai"]["note"])}</p>'
                f'<h3>{self.label("socProfile")}</h3><table class="soc" id="soc"><thead><tr><th scope="col">{self.label("function")}</th>'
                f'<th scope="col">{self.label("outcome")}</th></tr></thead><tbody>{rows}</tbody></table></div>')
        return self.section("ai", body)

    # ---------------------------------------------------------------- 6. helper
    def helper(self) -> str:
        items = [f'<details class="qa" id="helper-{esc(h["id"])}"><summary><span>{self.t(h["question"])}</span></summary>'
                 f'<div class="body"><p>{self.t(h["answer"])}</p><p class="small">{self.label("basis")}: {self.ent_links(h["entityIds"])}</p></div></details>'
                 for h in self.d["helper"]]
        return self.section("helper", '<div class="helper-list">\n' + "\n".join(items) + "\n</div>")

    # ---------------------------------------------------------------- 7. sources
    def authority(self, a: dict) -> str:
        deadline = (f'{self.t(a["deadline"]["text"])} <small>({self.ent_link(a["deadline"]["sourceId"])})</small>'
                    if a.get("deadline") else self.label("noDeadline"))
        return ('<div class="auth"><dl class="kv">'
                f'<dt>{self.label("nature")}</dt><dd>{self.t(self.ui["nature"].get(a["nature"], a["nature"]))}</dd>'
                f'<dt>{self.label("binds")}</dt><dd>{"; ".join(self.t(self.ui["binds"].get(b, b)) for b in a["binds"])}</dd>'
                f'<dt>{self.label("deadline")}</dt><dd>{deadline}</dd>'
                f'<dt>{self.label("note")}</dt><dd>{self.tl(a["note"])} {self.status_badge(a.get("verification"))}{self.problem_note(a.get("verification"))}</dd>'
                "</dl></div>")

    def entity(self, e: dict) -> str:
        short = "" if e["shortName"] in e["name"] else f' <span class="short">({self.t(e["shortName"])})</span>'
        inner = [v for k, v in self.walk_verifications(e) if k != "$"]
        conflict = ""
        if e["verification"]["status"] != "conflict" and any(v.get("status") == "conflict" for v in inner):
            conflict = f'<span class="status conflict">{self.t(self.ui["status"]["conflict"])}: {self.label("hasConflictInside")}</span>'
        # the summary: the entry's title (a label), its badges and its citation line, a space between each, so the three
        # never run together where the summary is not a grid (print)
        p = [f'<details class="ent" id="ent-{esc(e["id"])}"><summary><span class="ent-title">{self.t(e["name"])}{short}</span> '
             f'<span class="badges">{" ".join(b for b in (self.status_badge(e["verification"]), conflict) if b)}</span> '
             f'<span class="cite">{self.cite(e["title"], e["edition"], e["date"], e["publisher"])}</span></summary><div class="body">',
             f'<p>{self.t(e["oneLiner"])}</p>']
        if e.get("answersQuestion"):
            p.append(f'<p><strong>{self.label("answers")}:</strong> {self.t(e["answersQuestion"])}</p>')
        if e.get("role"):
            p.append(f'<p><strong>{self.label("role")}:</strong> {self.t(e["role"])}</p>')
        if e.get("layerId"):
            # a layer's tag and its name; the AI column's tag is its name
            lay = self.layer[e["layerId"]]
            p.append(f'<p class="small">{self.layer_tag(e["layerId"]).rstrip() if lay.get("isColumn") else self.layer_tag(e["layerId"]) + self.t(lay["name"])}</p>')
        va = e.get("validatedAgainst")
        if va:
            p.append(f'<div class="validated"><p><strong>{self.label("validatedAgainst")}:</strong> {self.ent_link(va["entityId"])}. '
                     f'{self.t(va["scope"])} {self.status_badge(va.get("verification"))}</p>'
                     f'<p class="small">{self.tl(va["verification"].get("note"))}</p></div>')
        if e.get("adopterResponsibilities"):
            lis = "".join(f'<li>{self.t(r["text"])} {self.status_badge(r.get("verification"))}<br><span class="small">{self.tl(r["verification"].get("note"))}</span></li>'
                          for r in e["adopterResponsibilities"])
            p.append(f'<div class="adopter"><p><strong>{self.label("adopterResponsibilities")}</strong></p><ul>{lis}</ul></div>')
        p.append(self.authority(e["authority"]))
        p.append('<dl class="kv">')
        p.append(f'<dt>{self.label("publisher")}</dt><dd>{self.t(e["publisher"])}</dd>')
        if e.get("authors"):
            p.append(f'<dt>{self.label("authors")}</dt><dd>{", ".join(esc(a) for a in e["authors"])}</dd>')
        if e.get("license"):
            attr = f' <small>({self.label("attribution")})</small>' if e.get("attributionRequired") else ""
            p.append(f'<dt>{self.label("license")}</dt><dd>{esc(e["license"])}{attr}</dd>')
        p.append(f'<dt>{self.label("edition")}</dt><dd>{self.t(e["edition"])}</dd>')
        p.append(f'<dt>{self.label("date")}</dt><dd>{fmt_date(e["date"])}</dd>')
        p.append(f'<dt>{self.label("primary")}</dt><dd><a class="url" href="{esc(e["url"])}" rel="noreferrer">{esc(e["url"])}</a></dd>')
        p.append(f'<dt>{self.label("verification")}</dt><dd>{self.status_badge(e["verification"])} <span class="small">{self.tl(e["verification"].get("note"))}</span></dd>')
        p.append("</dl>")
        if e.get("documents"):
            p.append(f'<p class="small"><strong>{self.label("documents")}</strong></p><ul class="docs">')
            for doc in e["documents"]:
                note = f' <span class="small">{self.tl(doc["note"])}</span>' if doc.get("note") else ""
                authors = f' {self.label("authors")}: {esc("; ".join(doc["authors"]))}.' if doc.get("authors") else ""
                # a document badged Unverified or Conflict shows its verification note beside the badge, as the status key
                # promises (every address tried; both readings and a date), like an entry's authority note (session 11, SK-004)
                v = doc.get("verification") or {}
                shown = bool(v.get("note")) and v.get("status") in PROBLEM
                vnote = f' <span class="small">{self.tl(v["note"])}</span>' if shown else ""
                # the link to the primary, then the badge, its note, and the document's own note; where the note shown
                # gives the primary's address, print does not repeat it after the link (class in-note)
                in_note = ' class="in-note"' if shown and doc["url"] in self.tok(v["note"]) else ""
                p.append(f'<li>{self.cite(doc["title"], doc["edition"], doc["date"])}{authors} '
                         f'<a{in_note} href="{esc(doc["url"])}" rel="noreferrer">{self.label("primary")}</a> {self.status_badge(v or None)}{vnote}{note}</li>')
            p.append("</ul>")
        if e.get("note"):
            p.append(f'<p class="small">{self.tl(e["note"])}</p>')
        p.append("</div></details>")
        return "".join(p)

    def sources(self) -> str:
        groups = [("groupFrameworks", self.d["frameworks"]), ("groupSources", self.d["sources"]),
                  ("groupSolutions", self.d.get("solutions", []))]
        body = f'<p id="sources-intro" class="section-intro">{self.label("sourcesIntro")}</p>\n{self.status_key("status-key")}\n'
        for key, items in groups:
            if not items:
                continue
            body += (f'<h3 class="ent-group">{self.label(key)}</h3><div class="ent-list">\n' +
                     "\n".join(self.entity(e) for e in items) + "\n</div>\n")
        return self.section("sources", body)

    # ---------------------------------------------------------------- 8. glossary and about
    def glossary_entries(self) -> list[dict]:
        out = []
        for g in self.d.get("glossary", []):
            term = self.tok(g["term"], hidden=True)
            out.append({"term": term, "slug": slug(term), "expansion": self.tok(g["expansion"], hidden=True) if g.get("expansion") else None,
                        "forms": [self.tok(f, hidden=True) for f in g.get("forms", [])], "prefix": g.get("prefix", False),
                        "notAbbreviation": g.get("notAbbreviation", False), "wellKnown": g.get("wellKnown", False),
                        "nameFirst": g["term"] == "{{dow}}", "src": g})
        return sorted(out, key=lambda e: e["term"].lower())

    def glossary(self) -> str:
        rows = []
        for e in self.glossary_entries():
            g = e["src"]
            # the expansion carries an id: a label's abbreviation elsewhere on the page is described by it
            exp = f'<span class="gl-exp" id="{FirstUse.exp_id(e)}">{esc(e["expansion"])}</span>. ' if e["expansion"] else ""
            see = f' <span class="small">{self.label("glossarySee")}: {self.ent_links(g["entityIds"])}</span>' if g.get("entityIds") else ""
            rows.append(f'<div class="gl-entry" id="gl-{e["slug"]}"><dt><span class="gl-term">{esc(e["term"])}</span></dt>'
                        f'<dd>{exp}{self.t(g["oneLine"])}{see} {self.status_badge(g.get("verification"))}</dd></div>')
        body = (f'<p class="section-intro">{self.label("glossaryIntro")}</p>\n<dl class="glossary" id="glossary-list">\n'
                + "\n".join(rows) + "\n</dl>")
        return self.section("glossary", body)

    def about(self) -> str:
        counts = {"verified": 0, "authored": 0, "unverified": 0, "conflict": 0}

        def walk(n) -> None:
            if isinstance(n, list):
                for x in n:
                    walk(x)
            elif isinstance(n, dict):
                for k, v in n.items():
                    if k == "verification" and isinstance(v, dict) and v.get("status") in counts:
                        counts[v["status"]] += 1
                    walk(v)
        walk(self.d)
        meta = self.d["meta"]
        badges = "".join(f'<span class="status {k}">{self.t(self.ui["status"][k])} {n}</span>' for k, n in counts.items())
        body = (f'<div id="about-body"><p class="about-name"><strong>{esc(meta["name"])}</strong> <span class="small">{self.label("contentVersion")} {esc(meta["contentVersion"])}</span></p>'
                f'<p>{self.t(meta["about"]["notAffiliated"])}</p>'
                f'<p class="small" id="dow-note">{self.label("dowNote")}</p>'
                f'<p class="small">{self.t(self.dow["statusNote"])}</p>'
                f'<p>{self.t(meta["about"]["offline"])}</p>'
                f'<p>{self.t(meta["about"]["licensing"])}</p>'
                f'<p class="small">{self.label("counts")}:</p><div class="counts">{badges}</div>{self.status_key("status-key-about")}')
        if self.author:
            body += f'<p class="small made-by">{self.label("madeBy")} {esc(self.author)}</p>'
        body += f'<p class="small built-with">{self.t(meta["about"]["builtWith"])}</p>'
        # why the name, last in About so its heading starts a part of its own; the front door's version line links here.
        # The maker's photo sits beside the story from 768 pixels up and above it on phones, embedded as a data: URI
        # (part of the page, not a request); the battery pins the file and checks it carries no metadata
        if meta["about"].get("nameStory"):
            story = "".join(f"<p>{self.t(p)}</p>" for p in meta["about"]["nameStory"])
            photo = ""
            if PHOTO.is_file():
                data = PHOTO.read_bytes()
                w, h = jpeg_size(data)
                photo = (f'<img class="name-photo" src="data:image/jpeg;base64,{base64.b64encode(data).decode("ascii")}" '
                         f'alt="{self.label("aboutPhotoAlt")}" width="{w}" height="{h}">')
            body += (f'<h3 class="name-head" id="about-name">{self.label("whyNameHeading")}</h3>'
                     f'<div class="name-story">{photo}<div class="name-text">{story}</div></div>')
        return self.section("about", body + "</div>")

    @staticmethod
    def walk_verifications(node, path: str = "$"):
        if isinstance(node, dict):
            for k, v in node.items():
                if k == "verification" and isinstance(v, dict):
                    yield f"{path}.{k}", v
                yield from Renderer.walk_verifications(v, f"{path}.{k}")
        elif isinstance(node, list):
            for i, v in enumerate(node):
                yield from Renderer.walk_verifications(v, f"{path}[{i}]")

    def status_key(self, key_id: str) -> str:
        rows = "".join(f'<dt><span class="status {s}">{self.t(self.ui["status"][s])}</span></dt><dd>{self.label("statusKey" + s.capitalize())}</dd>'
                       for s in ("verified", "authored", "unverified", "conflict"))
        return f'<div class="status-key" id="{key_id}"><p class="small"><strong>{self.label("statusKeyTitle")}</strong></p><dl class="kv">{rows}</dl></div>'

    def section(self, key: str, body: str) -> str:
        # each heading carries its two-digit number in section order, set at build time
        n = self.sections.index(key) + 1
        return (f'<section id="view-{key}" class="view" aria-labelledby="h-{key}">\n'
                f'<div class="sec-head"><span class="sec-num" aria-hidden="true">{n:02d}</span><h2 id="h-{key}">{self.t(self.ui["sections"][key])}</h2></div>\n'
                f'{body}\n</section>\n')

    def render(self) -> dict[str, str]:
        chunks = [self.hero(), self.doors(), self.stack(), self.matrix(), self.functions(), self.ai(), self.helper(), self.sources()]
        if "glossary" in self.sections:
            chunks.append(self.glossary())
        chunks.append(self.about())
        # abbreviations are spelled out at their first use in running text in every section, from the glossary; the
        # header and the footer hold labels only
        entries = [e for e in self.glossary_entries() if e["forms"] and (e["expansion"] or e["notAbbreviation"])]
        fu = FirstUse(entries)
        main = "".join(fu.section(c) for c in chunks)
        pop = ""
        if "glossary" in self.sections:
            pop = (f'<div class="gl-pop" id="gl-pop" role="note" hidden><div class="gl-pop-body"></div>'
                   f'<a class="gl-pop-link" href="#view-glossary">{self.label("glossaryOpen", hidden=True)}</a></div>\n')
        return {"HEADER": fu.section(self.header()), "MAIN": main + pop, "FOOTER": fu.section(self.footer())}


# ---------------------------------------------------------------- the static render's texts (session 8)
def text_norm(s: str) -> str:
    """Whitespace collapsed, and the department's spelled-out name read as its abbreviation, so a first-use expansion
    of the department never makes a text look absent."""
    s = s.replace("Department of War (DoW)", "DoW").replace("Department of War", "DoW")
    return re.sub(r"\s+", " ", s).strip()


def split_first(s: str):
    """The door card's split: first sentence in the summary, the rest in the body (a plain string when nothing is left)."""
    first, rest = first_sentence(s)
    return (first, rest) if rest else s


def static_texts(d: dict) -> tuple[dict[str, list], dict[str, int]]:
    """The content texts the static render places on the page, by element id: what tools/check_web.py counts for
    static-render completeness, and, flattened by --texts, what the iOS app's parity test reads (session 8). Tokens
    resolved, before abbreviation expansion, normalised by text_norm. A door card's split text is a tuple: the first
    sentence on the card and the rest in its body."""
    dow = d["orgs"]["dow"]
    tok = lambda s: re.sub(r"\{\{\s*dow(?:\.([A-Za-z]+))?\s*\}\}", lambda m: str(dow.get(m.group(1), "")) if m.group(1) else dow["abbr"], s or "")
    x = lambda *parts: [text_norm(tok(p)) for p in parts if p]
    items: dict[str, list[str]] = {}
    counts = {"doors": 0, "door steps": 0, "landings": 0, "layers": 0, "frameworks": 0, "sources": 0, "solutions": 0,
              "helpers": 0, "functions": 0, "SOC Profile rows": 0, "DoW-view cells": 0, "CISA-view cells": 0}
    for door in d["doors"]:
        # the card shows the title, the first sentence of whoYouAre and a meta line; a door with no steps shows its
        # paragraph's first sentence as the meta line, and the rest of each sits in the body
        texts = x(door["title"])
        for s_ in (door["whoYouAre"], door.get("paragraph")):
            if s_:
                sp = split_first(text_norm(tok(s_)))
                texts.append(sp)
        for s in door.get("steps", []):
            texts += x(s["text"]); counts["door steps"] += 1
        for ld in door.get("landings") or []:
            texts += x(ld["label"], ld["text"]); counts["landings"] += 1
        items[f"door-{door['id']}"] = texts; counts["doors"] += 1
    ents = {e["id"]: e for e in d["frameworks"] + d["sources"] + d.get("solutions", [])}
    for layer in d["layers"]:
        if layer.get("isColumn"):
            items["seam"] = x(layer["name"], layer["question"], layer["oneLiner"]) + x(*[ents[c["id"]]["shortName"] for c in d["ai"]["column"]])
        else:
            chips = list(layer["frameworkIds"]) + [s["id"] for s in d["sources"] if s.get("layerId") == layer["id"]]
            chips += [s["id"] for s in d.get("solutions", []) if s.get("layerId") == layer["id"]]
            items[f"layer-{layer['id']}"] = x(layer["name"], layer["question"], layer["oneLiner"]) + x(*[ents[i]["shortName"] for i in chips])
        counts["layers"] += 1
    for kind, coll in (("frameworks", d["frameworks"]), ("sources", d["sources"]), ("solutions", d.get("solutions", []))):
        for e in coll:
            a = e["authority"]
            texts = x(e["name"], e["title"], e["publisher"], e["edition"], e["oneLiner"], e.get("answersQuestion"), e.get("role"),
                      a["note"], (a.get("deadline") or {}).get("text"), e["verification"].get("note"), e.get("note"), e["url"])
            for doc in e.get("documents", []):
                # an Unverified or Conflict document's verification note shows beside its badge (session 11, SK-004)
                v = doc.get("verification") or {}
                texts += x(doc["title"], doc.get("note"), v.get("note") if v.get("status") in PROBLEM else None)
            if e.get("validatedAgainst"):
                texts += x(e["validatedAgainst"]["scope"])
            for r in e.get("adopterResponsibilities", []):
                texts += x(r["text"])
            items[f"ent-{e['id']}"] = texts; counts[kind] += 1
    for h in d["helper"]:
        items[f"helper-{h['id']}"] = x(h["question"], h["answer"]); counts["helpers"] += 1
    for f in d["functions"]:
        items[f"fn-{f['id']}"] = x(f["name"], f["question"], f["ztLanding"]) + x(*[c["name"] for c in f["categories"]]); counts["functions"] += 1
    fn_name = {f["id"]: f["name"] for f in d["functions"]}
    for r in d["ai"]["socProfile"]:
        items[f"soc-{r['functionId']}"] = x(fn_name[r["functionId"]], r["outcome"]); counts["SOC Profile rows"] += 1
    items["view-ai"] = x(d["ai"]["note"])
    cells = {(c["pillarId"], c["functionId"]): c for c in d["matrix"]["cells"]}
    views = d["pillars"]["views"]
    for view, pillars, key in (("dow", views["dow"], "DoW-view cells"), ("cisa", views["cisa"]["pillars"] + views["cisa"]["crossCutting"], "CISA-view cells")):
        for p in pillars:
            for f in d["functions"]:
                items[f"cell-{view}-{p}-{f['id']}"] = x(cells[(p, f["id"])]["text"]); counts[key] += 1
    for g in d.get("glossary", []):
        term = tok(g["term"])
        items["gl-" + re.sub(r"[^a-z0-9]+", "-", term.lower()).strip("-")] = x(term, g.get("expansion"), g["oneLine"])
        counts["glossary entries"] = counts.get("glossary entries", 0) + 1
    items["elevator"] = x(*[ents[i]["oneLiner"] for i in d["elevator"]["frameworkIds"]])
    L = d["ui"]["labels"]
    # the front door (Session 7): the description, the eyebrow line and the two buttons
    items["intro"] = x(d["meta"]["description"], L["heroEyebrow"], L["heroPrimary"], L["heroSecondary"], L.get("whyName"))
    # the intro texts that moved (Session 7, section 4.4): the audience line, the plain definition of zero trust and the
    # note on steps and layer tags open and close the doors section; the department's note moved to About
    items["view-doors"] = x(L["audience"], L["ztPlain"], L["doorsIntro"])
    items["about-body"] = x(d["meta"]["about"]["notAffiliated"], d["meta"]["about"]["offline"], d["meta"]["about"].get("licensing"),
                            dow["statusNote"], L["dowNote"], d["meta"]["about"]["builtWith"], L.get("whyNameHeading"),
                            *d["meta"]["about"].get("nameStory", []))
    items["footer"] = x(L["footerLicenses"], L["pagesPrivacy"], L["pagesSupport"], L["sourceCode"])
    return items, counts


# where each static_texts element sits on the page, top to bottom: the front door, the doors, the stack, the matrix, the
# six functions, the AI column, the questions, Sources, the glossary, About and the footer
PAGE_ORDER = ("intro", "view-doors", "door-", "elevator", "layer-", "seam", "cell-dow-", "cell-cisa-", "fn-", "view-ai", "soc-",
              "helper-", "ent-", "gl-", "about-body", "footer")


def web_texts(d: dict) -> dict:
    """What --texts writes: the section order and the static render's content strings, flattened in page order (a
    door card's split text gives its two parts), for the iOS app's parity test."""
    items, _ = static_texts(d)
    rank = lambda k: next(i for i, pre in enumerate(PAGE_ORDER) if k == pre or (pre.endswith("-") and k.startswith(pre)))
    ordered = sorted(items, key=rank)  # a stable sort keeps each group in the content's order
    texts = [p for k in ordered for t in items[k] for p in ([t] if isinstance(t, str) else list(t))]
    sections = [s for s in SECTIONS if s != "glossary" or d.get("glossary")]
    return {"about": "Generated by tools/build_web.py --texts from content/stack.json; the battery regenerates and diffs it.",
            "contentVersion": d["meta"]["contentVersion"], "sections": sections, "texts": texts}


def page_css() -> str:
    """The plain pages share the app's type and theme tokens: the four faces, the token blocks at the top of styles.css
    (light, dark by preference, dark by choice), then web/src/page.css."""
    css = (SRC / "styles.css").read_text(encoding="utf-8")
    start, end = css.find(":root {"), css.find("\n[hidden] {")
    if start < 0 or end < start:
        sys.exit("styles.css: the theme token blocks were not found before the [hidden] rule")
    return font_css() + "\n" + css[start:end].rstrip("\n") + "\n" + (SRC / "page.css").read_text(encoding="utf-8").rstrip("\n")


def recheck_dates(node) -> list[str]:
    """Every dated recheckAfter in the content."""
    out = []
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "recheckAfter" and isinstance(v, str) and re.match(r"^\d{4}-\d{2}-\d{2}$", v):
                out.append(v)
            out += recheck_dates(v)
    elif isinstance(node, list):
        for v in node:
            out += recheck_dates(v)
    return out


def build_page(d: dict, key: str, author: str = "") -> bytes:
    """One plain page beside the app. Text from content (pages.<key>, meta, ui.labels), no script, no network."""
    r = Renderer(d, author)
    meta, page = d["meta"], d["pages"][key]
    body = [f'<h1>{r.t(page["title"])}</h1>']
    if key == "privacy":
        body.append(f'<p class="small">{r.label("pagesEffective")}: <time datetime="{esc(meta["builtOn"])}">{fmt_date(meta["builtOn"])}</time></p>')
    body += [f"<p>{r.tl(s)}</p>" for s in page["paragraphs"]]
    if key == "support":
        body.append(f'<p>{r.t(meta["about"]["notAffiliated"])}</p>')
        rows = [(r.label("contentVersion"), esc(meta["contentVersion"]))]
        due = sorted(x for x in recheck_dates(d) if x >= meta["builtOn"])
        rows.append((r.label("pagesNextRecheck"),
                     f'<time datetime="{due[0]}">{fmt_date(due[0])}</time>' if due else r.label("pagesNoRecheck")))
        body.append('<dl class="kv">' + "".join(f"<dt>{k}</dt><dd>{v}</dd>" for k, v in rows) + "</dl>")
    # abbreviations spelled out at first use, as in every section of the app; no links, the glossary lives in the app,
    # so a label's abbreviation is an abbr element with its expansion as the title
    entries = [e for e in r.glossary_entries() if e["forms"] and (e["expansion"] or e["notAbbreviation"])]
    fu = FirstUse(entries, link=False)
    main = fu.section("\n".join(body) + "\n")
    template = (SRC / "page.html").read_text(encoding="utf-8")
    replacements = {"{{LANG}}": "en", "{{TITLE}}": esc(page["title"]), "{{DESCRIPTION}}": esc(page["description"]),
                    "{{ICON}}": favicon(), "{{STYLES}}": page_css(), "{{MARK}}": mark_svg(), "{{NAME}}": esc(meta["name"]),
                    "{{BODY}}": main, "{{FOOTER}}": fu.section(r.footer(key))}
    for k, v in replacements.items():
        template = template.replace(k, v)
    if "{{" in template:
        sys.exit(f"{key}.html: template placeholder or render token left unreplaced")
    return template.encode("utf-8")


def social_tags(d: dict) -> str:
    """Link-preview tags. They load nothing in a reader's browser; only a crawler building a preview fetches the image.
    The preview's description is meta.pitch; the description tag for search engines stays meta.description."""
    meta = d["meta"]
    w, h = SOCIAL_SIZE
    tags = [("property", "og:title", meta["name"]), ("property", "og:description", meta["pitch"]), ("property", "og:type", "website"),
            ("property", "og:url", SITE), ("property", "og:image", f"{SITE}social-card.png"), ("property", "og:image:width", str(w)),
            ("property", "og:image:height", str(h)), ("name", "twitter:card", "summary_large_image")]
    return "\n".join(f'<meta {a}="{k}" content="{esc(v)}">' for a, k, v in tags)


def build_docs(index: bytes, stack: Path, docs: Path, author: str = "") -> list[Path]:
    """The project site for GitHub Pages: the app page byte for byte, the two plain pages, the social card, an empty .nojekyll."""
    d = json.loads(stack.read_text(encoding="utf-8"))
    docs.mkdir(parents=True, exist_ok=True)
    files = {"index.html": index, ".nojekyll": b""}
    files.update({f"{k}.html": build_page(d, k, author) for k in PAGES})
    files["social-card.png"] = SOCIAL_CARD.read_bytes()
    out = []
    for name, data in files.items():
        (docs / name).write_bytes(data)
        out.append(docs / name)
    return out


def build(author: str, stack: Path = STACK) -> bytes:
    raw = stack.read_bytes()
    text = raw.decode("utf-8")
    for bad in ("</", "<!--", "<script", "]]>"):
        if bad in text:
            sys.exit(f"refusing to embed: stack.json contains {bad!r}, which cannot sit inside a script element verbatim")
    d = json.loads(text)
    template = (SRC / "template.html").read_text(encoding="utf-8")
    styles = font_css() + "\n" + (SRC / "styles.css").read_text(encoding="utf-8").rstrip("\n")
    app = (SRC / "app.js").read_text(encoding="utf-8").rstrip("\n")
    head_js = (SRC / "head.js").read_text(encoding="utf-8").rstrip("\n")
    parts = Renderer(d, author).render()
    build_json = json.dumps({"author": author, "contentVersion": d["meta"]["contentVersion"]}, ensure_ascii=False, sort_keys=True)
    lang = "en"
    replacements = {"{{LANG}}": lang, "{{TITLE}}": esc(d["meta"]["name"]), "{{DESCRIPTION}}": esc(d["meta"]["description"]),
                    "{{ICON}}": favicon(), "{{SOCIAL}}": social_tags(d),
                    "{{HEAD_JS}}": head_js, "{{STYLES}}": styles, "{{HEADER}}": parts["HEADER"], "{{MAIN}}": parts["MAIN"],
                    "{{FOOTER}}": parts["FOOTER"], "{{BUILD_JSON}}": build_json}
    head, sep, tail = template.partition("{{STACK_JSON}}")
    if not sep:
        sys.exit("template lacks the {{STACK_JSON}} placeholder")
    for k, v in replacements.items():
        head = head.replace(k, v)
    tail = tail.replace("{{APP}}", app)
    out = head.encode("utf-8") + raw + tail.encode("utf-8")
    outside = head + tail
    if re.search(r"\{\{[A-Z_]+\}\}", outside) or "{{" in outside:
        sys.exit("template placeholder or render token left unreplaced")
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--author", default="", help="rendered on the About view and in the footer as the maker; defaults to empty")
    ap.add_argument("--out", default=str(OUT))
    ap.add_argument("--stack", default=str(STACK), help="content file to build from; defaults to content/stack.json")
    ap.add_argument("--pages", action="store_true", help="also write the project site under docs/ for GitHub Pages")
    ap.add_argument("--docs", default=str(DOCS), help="where --pages writes the site; defaults to docs/")
    ap.add_argument("--texts", help="also write the static render's content strings (before abbreviation expansion) to this "
                                    "JSON file, for the iOS app's parity test (ios/LensaticTests/Fixtures/web_texts.json)")
    args = ap.parse_args()
    data = build(args.author, Path(args.stack))
    Path(args.out).write_bytes(data)
    print(f"wrote {args.out}: {len(data)} bytes")
    if args.pages:
        for f in build_docs(data, Path(args.stack), Path(args.docs), args.author):
            print(f"wrote {f}: {f.stat().st_size} bytes")
    if args.texts:
        texts = web_texts(json.loads(Path(args.stack).read_text(encoding="utf-8")))
        Path(args.texts).write_text(json.dumps(texts, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print(f"wrote {args.texts}: {len(texts['texts'])} texts, {len(set(texts['texts']))} distinct, {len(texts['sections'])} sections")
    return 0


if __name__ == "__main__":
    sys.exit(main())
