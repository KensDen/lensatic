#!/usr/bin/env python3
"""Build the Lensatic umbrella pages and publish the two moved sections into docs/ (Lensatic 2.0).

Writes, from sources inside this repository only:
  docs/index.html            the hub: top bar, hero, the three section tiles, About (ending on where the name comes from), footer
  docs/guides/index.html     the guides index: one tile per guide (Zero Trust is the first)
  docs/shared/lensatic.css   hub/lensatic.css byte for byte, the field system's one shared file
  docs/sitemap.xml           the hub, the map, the guides index, the Zero Trust guide, the Playbook landing and app
  docs/404.html              the page GitHub Pages serves for a missing address under /lensatic/: the bar, a line and a link
                             to the hub, every link absolute because it is served at any depth (gauntlet question 33)
  docs/guides/zero-trust/    the Zero Trust guide's published files, copied from guides/zero-trust/ byte for byte
  docs/playbook/             the Agentic SecOps landing, app, documents, deck, diagrams and card, copied from playbook/

The map's pages (docs/maps/index.html, docs/privacy.html, docs/support.html, docs/social-card-v2.png, docs/.nojekyll)
are written by tools/build_web.py --pages, not here.

The hub and the guides index follow the map's own rules: no resource loading (the type and the marks are embedded), and
the theme from prefers-color-scheme until a reader picks one. Since Lensatic 2.0.2 their only script is the shared theme
pair every page with the umbrella bar carries (hub/theme-head.js in the head, hub/theme-bar.js with the bar's toggle),
and their only storage is that choice, the localStorage key lensatic-theme. Text comes from hub/site.json and content/stack.json; counts
are read from their sources, never typed: frameworks and glossary terms from content/stack.json, guides from
hub/site.json's guides list, and the Agentic SecOps actions, resources and glossary terms from its JSX by the same
parse as playbook/Validation/ripple_check.cjs. Deterministic: the output depends only on the inputs.

Usage: python3 tools/build_hub.py [--docs DIR]
"""
from __future__ import annotations

import argparse
import base64
import html
import json
import re
import shutil
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import build_web as bw  # noqa: E402  (the map's builder: its fonts, mark, tile icon and token renderer are reused)

HUB = ROOT / "hub"
SITE_JSON = HUB / "site.json"
SHARED_CSS = HUB / "lensatic.css"
EMBLEM = HUB / "marks" / "apt-unicorn-emblem.webp"   # the Agentic SecOps emblem, the landing's own file, resized by CSS only
# the maker's compass photos (R5; the v1.1 set since R6, oriented to map north), cropped around the compass, sized, in sRGB
# and with every metadata segment stripped, embedded as data: URIs like every other image here: the compass at an angle
# on a world map beside the hero's text, and the compass on the open map under Why the name (29 October 2026: why.jpg, the
# banner's framing whole, 2176 wide for the card row's 68rem at 2x). hub/photos/close.jpg, the compass close up, is kept
# beside them for the social cards and is not published yet.
HERO_PHOTO = HUB / "photos" / "hero.jpg"
WHY_PHOTO = HUB / "photos" / "why.jpg"
GUIDES = ROOT / "guides"
PLAYBOOK = ROOT / "playbook"
DOCS = ROOT / "docs"

# what each moved section publishes: everything its pages link to, nothing from its build or validation trees
ZT_FILES = ("index.html", "icon.svg", "icon-512.png", "apple-touch-icon.png", "favicon-32.png", "social-card.png")
# the pages the sitemap lists, under the site address (privacy and support since gauntlet question 38)
SITEMAP_PAGES = ("", "maps/", "guides/", "guides/zero-trust/", "playbook/", "playbook/Playbook/", "privacy.html", "support.html")
ZT_PDF = re.compile(r"^\d{8}_ZT_(Study_Guide|Quick_Reference_[A-Za-z_]+)_v\d+\.\d+(?:\.\d+)?\.pdf$")
PLAYBOOK_FILES = ("index.html", "social-card-v2.png", "Playbook/index.html")  # the card renamed in Lensatic 2.0.2
PLAYBOOK_DIRS = ("Documents", "Deck", "Diagrams")


def esc(s: str) -> str:
    return html.escape(s, quote=True)


def site() -> dict:
    return bw.web_text.site(json.loads(SITE_JSON.read_text(encoding="utf-8")))


def stack() -> dict:
    return bw.web_text.content(json.loads(bw.STACK.read_text(encoding="utf-8")))


def playbook_counts() -> dict[str, int]:
    """The Agentic SecOps canon, parsed exactly as playbook/Validation/ripple_check.cjs parses it."""
    jsx = (PLAYBOOK / "Playbook" / "agentic-secops-teaming.jsx").read_text(encoding="utf-8")
    actions = sum(len(re.findall(rf'phase:\s*"{p}"', jsx)) for p in ("Now", "Next", "Later"))
    r0 = jsx.find("\n  resources: {")
    r1 = jsx.find("\n    ],\n  },", r0)
    resources = len(re.findall(r'^\s*\{\s*(?:sub:\s*"[^"]*",\s*)?name:\s*"', jsx[r0:r1], re.M))
    f0 = re.search(r"^  fluency: \{", jsx, re.M).start()
    f1 = jsx.find("\n  learningpath: {", f0)
    glossary = len(re.findall(r'\{\s*term:\s*"', jsx[f0:f1 if f1 > 0 else f0 + 60000]))
    if not (actions and resources and glossary):
        sys.exit("playbook counts: the JSX canon could not be parsed")
    return {"actions": actions, "resources": resources, "glossary": glossary}


def plural(n: int, one: str, many: str | None = None) -> str:
    return f"{n} {one if n == 1 else (many or one + 's')}"


def counts(s: dict, d: dict) -> dict[str, str]:
    pb = playbook_counts()
    return {
        "maps": f"{plural(len(d['frameworks']), 'framework')} · {plural(len(d['glossary']), 'glossary term')}",
        "guides": guide_shape(),
        "playbook": f"{plural(pb['actions'], 'action')} · {plural(pb['resources'], 'resource')} · {plural(pb['glossary'], 'glossary term')}",
    }


def guide_shape() -> str:
    """The Field Guides card's stat (site review, 28 October 2026): the Zero Trust guide's weeks and tracks, read from the
    app's copy of the guide (guides/zero-trust/app/guide.json), and its PDFs, found in its tree."""
    g = json.loads((GUIDES / "zero-trust" / "app" / "guide.json").read_text(encoding="utf-8"))
    weeks = max(w["week"] for w in g["core"] + [w for t in g["tracks"] for w in t["weeks"]])
    return f'{plural(weeks, "week")} · {plural(len(g["tracks"]), "track")} · {plural(len(guide_pdfs("zero-trust")), "PDF")}'


def count_html(text: str) -> str:
    """A count line with each number kept beside its noun, "89 glossary terms" never breaking after the 89, and each dot
    kept with the count after it, so no line ends with a dot (site review, 28 October 2026)."""
    parts = text.split(" · ")
    return " ".join(f'<span class="lx-nw">{"· " if i else ""}{esc(x)}</span>' for i, x in enumerate(parts))


def compass(size: int = 20) -> str:
    return bw.mark_svg(size, "lx-compass")


def tile(cls: str = "lx-tile") -> str:
    return f'<span class="{cls}" aria-hidden="true">{compass()}</span>'


def data_uri(path: Path, mime: str) -> str:
    return f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def zt_mark() -> str:
    return data_uri(GUIDES / "zero-trust" / "icon.svg", "image/svg+xml")


def emblem() -> str:
    return data_uri(EMBLEM, "image/webp")


def section_icon(key: str, cls: str) -> str:
    """Each section's own mark, at its existing art: the compass, the slashed zero, the APT_UNICORN emblem. The compass
    and (since Lensatic 2.0.2) the emblem sit in the dark rounded-square tile the slashed zero's own art is drawn on."""
    if key == "maps":
        return f'<span class="{cls} lx-tile" aria-hidden="true">{compass(32)}</span>'
    if key == "guides":
        return f'<img class="{cls}" src="{zt_mark()}" alt="" width="44" height="44">'
    return f'<span class="{cls} lx-tile" aria-hidden="true"><img src="{emblem()}" alt="" width="32" height="32"></span>'


def bar(s: dict, root: str, active: str | None, brand_mark: bool = True) -> str:
    """The shared top bar, one implementation for every page: tools/build_web.py's umbrella_bar."""
    return bw.umbrella_bar(s, root, active, brand_mark)


def footer(s: dict, d: dict, root: str, licence: str | None = None) -> str:
    """The shared footer, one implementation for every page: tools/build_web.py's site_footer (the version line, the
    policy, support and source links, the rights line linked to the root LICENSE or a section's own notice, and the
    typefaces' licence; site review, 28 October 2026)."""
    return bw.site_footer(s, d["ui"]["labels"], root, licence)


def styles() -> str:
    return bw.font_css() + "\n" + SHARED_CSS.read_text(encoding="utf-8").rstrip("\n") + "\n" + HUB_CSS


# page-level rules for the hub and the guides index, on the shared tokens; the chrome itself is in hub/lensatic.css
HUB_CSS = """.lx-hero-lines { margin: var(--s-5) 0 0; padding: 0; list-style: none; display: grid; gap: var(--s-2); max-width: 46rem; }
.lx-hero-lines li { padding-left: var(--s-4); border-left: 3px solid var(--line-strong); color: var(--fg); }
.lx-hero-lines li.maps { border-left-color: var(--sec-maps); }
.lx-hero-lines li.guides { border-left-color: var(--sec-guides); }
.lx-hero-lines li.playbook { border-left-color: var(--sec-playbook); }
.lx-start { margin: var(--s-4) 0 0; }
.lx-page .lx-start a.lx-btn { background: var(--sec-maps); border-color: var(--sec-maps); color: var(--on-sec-maps); }  /* the start leads into Framework Maps (QC rulings, Q22) */
.lx-404 { min-height: 100vh; display: flex; flex-direction: column; }  /* the footer meets the bottom of a short screen (QC rulings, Q18) */
.lx-404 > main { flex: 1 0 auto; }
.lx-404 .lx-head .lx-actions { margin-top: var(--s-4); }  /* as far below the line as the hub's start button (site review, item 15) */
.lx-nw { white-space: nowrap; }
.lx-guide-meta { display: grid; gap: var(--s-2); margin: 0; }
.lx-guide-meta dt { font-family: var(--mono); font-size: 0.8125rem; font-weight: 700; letter-spacing: 0.08em; text-transform: uppercase; color: var(--fg-2); }
.lx-guide-meta dd { margin: 0 0 var(--s-2); }
.lx-refs { display: flex; flex-wrap: wrap; gap: 0 var(--s-4); margin: 0; padding: 0; list-style: none; }
.lx-refs a { display: inline-flex; align-items: center; min-height: 44px; }
.lx-about p { color: var(--fg); }
.lx-byline { margin: var(--s-2) 0 0; color: var(--fg-2); }
.lx-byline a { display: inline-flex; align-items: center; min-height: 44px; color: var(--link); }
/* Why the name (29 October 2026): its own section before About, the heading plain text like About's, the photo below it
   at the About column's width and left edge, whole (the compass and its cord loop uncropped), nothing set over it */
.lx-why-photo { margin: 0 0 var(--s-4); max-width: 44rem; }
.lx-why-photo img { display: block; box-sizing: border-box; width: 100%; height: auto; border: 1px solid var(--line); border-radius: var(--card-radius); }
.lx-name-text p:first-child { margin-top: 0; }
/* from 900 pixels (Ken's pick from the mock-up, 29 October 2026): Why the name and About span the card row's width, edge to
   edge with the three cards, their dividers too (drawn at the content's width, not the padded section's); the longer lines
   read at a larger size and leading, and no paragraph ends on a lone word. Below 900 nothing changes */
@media (min-width: 900px) {
  .lx-why, .lx-about { border-top: 0; background: linear-gradient(var(--line), var(--line)) no-repeat center top / calc(100% - 2 * var(--s-4)) 1px; }
  .lx-why > h2, .lx-about > h2 { font-size: 1.75rem; }
  .lx-why-photo, .lx-why p, .lx-about p { max-width: none; }
  .lx-why p, .lx-about p { font-size: 1.1875rem; line-height: 1.7; text-wrap: pretty; }
}
.lx-hero-grid { display: grid; gap: 0 var(--s-6); }
.lx-hero-photo { margin: var(--s-5) 0 0; max-width: 30rem; }
.lx-hero-photo img { display: block; width: 100%; height: auto; aspect-ratio: 4 / 3; object-fit: cover; object-position: 50% 40%; border: 1px solid var(--line); border-radius: var(--card-radius); }
.lx-hero-photo figcaption { margin-top: var(--s-2); color: var(--fg-2); }
@media (min-width: 900px) {
  .lx-hero-grid { grid-template-columns: minmax(0, 3fr) minmax(0, 2fr); grid-template-areas: "text photo" "more photo"; align-items: start; }
  .lx-hero-text { grid-area: text; } .lx-hero-more { grid-area: more; } .lx-hero-photo { grid-area: photo; margin-top: var(--s-2); }
  .lx-hero-photo img { aspect-ratio: auto; }
}"""


def head(s: dict, title: str, description: str, url: str, image_alt: str) -> str:
    card = s["site"] + bw.SOCIAL_NAME  # the hub card, published by tools/build_web.py --pages
    tags = [("property", "og:title", title), ("property", "og:description", description), ("property", "og:type", "website"),
            ("property", "og:url", url), ("property", "og:image", card), ("property", "og:image:width", "1200"),
            ("property", "og:image:height", "630"), ("property", "og:image:alt", image_alt), ("name", "twitter:card", "summary_large_image")]
    meta = "\n".join(f'<meta {a}="{k}" content="{esc(v)}">' for a, k, v in tags)
    return ("<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">\n"
            "<meta name=\"color-scheme\" content=\"light dark\">\n<meta name=\"referrer\" content=\"no-referrer\">\n"
            f"<link rel=\"icon\" href=\"{bw.favicon()}\">\n<title>{esc(title)}</title>\n{bw.theme_head()}\n"
            f"<meta name=\"description\" content=\"{esc(description)}\">\n<link rel=\"canonical\" href=\"{esc(url)}\">\n{meta}\n"
            f"<style>\n{styles()}\n</style>\n</head>\n")


def first_use(r: "bw.Renderer"):
    """Abbreviations spelled out at their first use in each section, by the map's own rule for its plain pages (no glossary
    links here; a label's abbreviation becomes an abbr element with its expansion as the title)."""
    entries = [e for e in r.glossary_entries() if e["forms"] and (e["expansion"] or e["notAbbreviation"])]
    return bw.FirstUse(entries, link=False)


def photo(path: Path, cls: str, alt: str) -> str:
    """One of the maker's photos, embedded as a data: URI (part of the page, not a request), with its true size."""
    data = path.read_bytes()
    w, h = bw.jpeg_size(data)
    return f'<img class="{cls}" src="data:image/jpeg;base64,{base64.b64encode(data).decode("ascii")}" alt="{esc(alt)}" width="{w}" height="{h}">'


def name_story(r: "bw.Renderer", about: dict, s: dict) -> str:
    """Where the name comes from: its own section before About (29 October 2026), so the story comes before the legal
    text. The heading (ui.labels.whyNameHeading) is plain text like About's and keeps the #about-name anchor the map links
    to; the photo of the compass on the open map (hub/site.json bannerAlt) follows at the column's width, then the story,
    meta.about.nameStory, word for word."""
    story = "".join(f"<p>{r.t(p)}</p>" for p in about["nameStory"])
    return (f'<section class="lx-wrap lx-section lx-why" aria-labelledby="about-name"><h2 id="about-name">{r.label("whyNameHeading")}</h2>'
            f'<figure class="lx-why-photo">{photo(WHY_PHOTO, "lx-why-img", s["bannerAlt"])}</figure>'
            f'<div class="lx-name-text">{story}</div></section>\n')


def byline(s: dict) -> str:
    """Who made it, under the hub's lede, linked to the maker's site (hub/site.json byline; gauntlet question 62)."""
    b = s["byline"]
    return f'<p class="lx-byline">{esc(b["text"][: -len(b["name"])])}<a href="{esc(b["href"])}">{esc(b["name"])}</a></p>'


def card_alt(s: dict) -> str:
    """The one description of the shared hub card, used wherever a page previews it (the hub, the guides index, the map)."""
    return f'{s["name"]}: {s["cardBand"]["line"]}'


def hub_page(s: dict, d: dict) -> str:
    r = bw.Renderer(d, "")
    fu = first_use(r)
    c = counts(s, d)
    about = d["meta"]["about"]
    hero_lines = "".join(f'<li class="{x["key"]}">{esc(x["hero"])}</li>' for x in s["sections"])
    tiles = []
    for x in s["sections"]:
        tiles.append(f'<li class="lx-tile-card {x["key"]}">{section_icon(x["key"], "lx-icon")}'
                     f'<h3>{esc(x["name"])}</h3><p>{esc(x["line"])}</p><p class="lx-count">{count_html(c[x["key"]])}</p>'
                     f'<p class="lx-actions"><a class="lx-btn lx-primary" href="{x["path"]}">{esc(x["open"])}</a></p></li>')
    kicker = " · ".join(x["name"] for x in s["sections"])
    # the eyebrow breaks only before a dot, which stays with the name after it: a phone shows whole section names, and no
    # line ends with a dot (QC, 24 October 2026; site review, 28 October 2026)
    eyebrow = " · ".join(x["name"].replace(" ", " ") for x in s["sections"])
    # the compass beside the text (R5): a caption under the photo that wraps where it falls (site review, 28 October
    # 2026; the story itself is in About); on a phone it follows the byline, and the section lines and the start button
    # come after it
    story = esc(" ".join(s["heroStory"]))
    hero = (f'<header class="lx-hero"><div class="lx-wrap lx-head lx-hero-grid"><div class="lx-hero-text">{tile("lx-mark lx-tile")}'
            f'<p class="lx-eyebrow">{esc(eyebrow)}</p><h1>{esc(s["name"])}</h1>'
            f'<p class="lx-standfirst">{esc(d["meta"]["tagline"])}</p>{byline(s)}</div>'
            f'<figure class="lx-hero-photo">{photo(HERO_PHOTO, "lx-hero-img", s["heroPhotoAlt"])}<figcaption>{story}</figcaption></figure>'
            f'<div class="lx-hero-more"><ul class="lx-hero-lines">{hero_lines}</ul>'
            f'<p class="lx-actions lx-start"><a class="lx-btn" href="maps/#view-doors">{r.label("heroPrimary")}</a></p></div></div></header>\n')
    sections = (f'<section class="lx-wrap lx-section" aria-labelledby="sections-h"><h2 id="sections-h" class="lx-vh">{esc(kicker)}</h2>'
                f'<ul class="lx-tiles">{"".join(tiles)}</ul></section>\n')
    why_html = name_story(r, about, s) if "nameStory" in s["aboutBlocks"] else ""
    about_html = (f'<section class="lx-wrap lx-section lx-about" id="about" aria-labelledby="about-h"><h2 id="about-h">{esc(s["aboutLabel"])}</h2>'
                  + "".join(f"<p>{r.t(about[k])}</p>" for k in s["aboutBlocks"] if k != "nameStory") + "</section>\n")
    body = (f'<body class="lx-page">\n<a class="lx-skip" href="#main">{r.label("skip")}</a>\n{bar(s, "./", None)}\n<main id="main">\n'
            f'{fu.section(hero)}{fu.section(sections)}{fu.section(why_html)}{fu.section(about_html)}'
            f'</main>\n{footer(s, d, "./")}\n</body>\n</html>\n')
    return head(s, s["name"], d["meta"]["pitch"], s["site"], card_alt(s)) + body


def guide_pdfs(key: str) -> dict[str, str]:
    """The guide's PDFs by kind, found in its tree (the newest edition of each, by file name)."""
    out: dict[str, str] = {}
    for p in sorted((GUIDES / key).glob("*.pdf")):
        m = ZT_PDF.match(p.name)
        if m:
            out[m.group(1)] = p.name
    return out


def guides_page(s: dict, d: dict) -> str:
    r = bw.Renderer(d, "")
    fu = first_use(r)
    sec = next(x for x in s["sections"] if x["key"] == "guides")
    tiles = []
    for g in s["guides"]:
        pdfs = guide_pdfs(g["key"])
        L = s["labels"]
        refs = [(f'{g["path"]}{pdfs[k]}', L[label]) for k, label in
                (("Study_Guide", "pdfStudyGuide"), ("Quick_Reference_DoW", "pdfDoW"),
                 ("Quick_Reference_Federal_Civilian", "pdfFederalCivilian"), ("Quick_Reference_Private_Sector", "pdfPrivateSector")) if k in pdfs]
        nb = g["notebook"]
        tiles.append(
            f'<li class="lx-tile-card guides">{section_icon("guides", "lx-icon")}<h3>{esc(g["name"])}</h3><p>{esc(g["line"])}</p>'
            f'<dl class="lx-guide-meta"><dt>{esc(L["guideShape"])}</dt><dd>{esc(g["shape"])}</dd>'
            f'<dt>{esc(L["guideTracks"])}</dt><dd>{esc(", ".join(g["tracks"]))}</dd>'
            f'<dt>{esc(L["guideReferences"])}</dt><dd>{esc(g["references"])}<ul class="lx-refs">'
            + "".join(f'<li><a href="{h}">{esc(t)}</a></li>' for h, t in refs) + '</ul></dd>'
            f'<dt>{esc(L["guideNotebook"])}</dt><dd><a href="{esc(nb["url"])}">{esc(nb["name"])}</a>. {esc(nb["line"])}</dd></dl>'
            f'<p class="lx-actions"><a class="lx-btn lx-primary" href="{g["path"]}">{esc(g["open"])}</a></p></li>')
    top = (f'<header class="lx-wrap lx-head">{section_icon("guides", "lx-mark")}<p class="lx-eyebrow">{esc(sec["name"])}</p>'
           f'<h1>{esc(sec["name"])}</h1><p class="lx-standfirst">{esc(sec["line"])}</p></header>\n')
    listing = (f'<section class="lx-wrap lx-section" aria-labelledby="guides-h"><h2 id="guides-h" class="lx-vh">{esc(sec["name"])}</h2>'
               f'<ul class="lx-tiles">{"".join(tiles)}</ul></section>\n')
    body = (f'<body class="lx-page lx-guides">\n<a class="lx-skip" href="#main">{r.label("skip")}</a>\n{bar(s, "../", "guides")}\n<main id="main">\n'
            f'{fu.section(top)}{fu.section(listing)}</main>\n{footer(s, d, "../")}\n</body>\n</html>\n')
    return head(s, f'{s["name"]} · {sec["name"]}', sec["line"], s["site"] + sec["path"], card_alt(s)) + body


def not_found_page(s: dict, d: dict) -> str:
    """docs/404.html: GitHub Pages serves it for any missing address under the site, at that address, so every link and
    the bar's root are absolute. Not in the sitemap, and marked noindex."""
    r = bw.Renderer(d, "")
    nf, root = s["notFound"], s["site"]
    title = f'{s["name"]} · {nf["title"]}'
    head_html = ("<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
                 "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">\n"
                 "<meta name=\"color-scheme\" content=\"light dark\">\n<meta name=\"referrer\" content=\"no-referrer\">\n"
                 f"<meta name=\"robots\" content=\"noindex\">\n<link rel=\"icon\" href=\"{bw.favicon()}\">\n<title>{esc(title)}</title>\n"
                 f"{bw.theme_head()}\n<style>\n{styles()}\n</style>\n</head>\n")
    top = (f'<header class="lx-wrap lx-head">{tile("lx-mark lx-tile")}<p class="lx-eyebrow">{esc(nf["eyebrow"])}</p>'
           f'<h1>{esc(nf["title"])}</h1><p class="lx-standfirst">{esc(nf["line"])}</p>'
           f'<p class="lx-actions"><a class="lx-btn lx-primary" href="{esc(root)}">{esc(nf["back"])}</a></p></header>\n')
    body = (f'<body class="lx-page lx-404">\n<a class="lx-skip" href="#main">{r.label("skip")}</a>\n{bar(s, root, None)}\n<main id="main">\n'
            f'{top}</main>\n{footer(s, d, root)}\n</body>\n</html>\n')
    return head_html + body


MONTHS = ("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December")


def playbook_date() -> str:
    """The Agentic SecOps release date: the first line of playbook/README.md's version history ("- v5.4.2, 24 October 2026: ...")."""
    m = re.search(r"^- v[\d.]+, (\d{1,2}) (\w+) (\d{4}):", (PLAYBOOK / "README.md").read_text(encoding="utf-8"), re.M)
    return f"{m.group(3)}-{MONTHS.index(m.group(2)) + 1:02d}-{int(m.group(1)):02d}"


def sitemap(s: dict, d: dict) -> str:
    """Each page's own date (QC rulings, Q20): the content's builtOn for the map and the plain pages, the playbook's release
    date for its landing and app, the site date for the rest."""
    pages = SITEMAP_PAGES
    own = {"maps/": d["meta"]["builtOn"], "privacy.html": d["meta"]["builtOn"], "support.html": d["meta"]["builtOn"],
           "playbook/": playbook_date(), "playbook/Playbook/": playbook_date()}
    rows = "".join(f'  <url><loc>{s["site"]}{p}</loc><lastmod>{own.get(p, s["date"])}</lastmod></url>\n' for p in pages)
    return f'<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n{rows}</urlset>\n'


def published() -> dict[str, Path]:
    """Published path under docs/ -> its source file in the section's own tree."""
    out: dict[str, Path] = {}
    zt = GUIDES / "zero-trust"
    for name in ZT_FILES:
        out[f"guides/zero-trust/{name}"] = zt / name
    for p in sorted(zt.glob("*.pdf")):
        if ZT_PDF.match(p.name):
            out[f"guides/zero-trust/{p.name}"] = p
    for name in PLAYBOOK_FILES:
        out[f"playbook/{name}"] = PLAYBOOK / name
    for d in PLAYBOOK_DIRS:
        for p in sorted((PLAYBOOK / d).rglob("*")):
            if p.is_file() and p.name != ".DS_Store":
                out[f"playbook/{p.relative_to(PLAYBOOK).as_posix()}"] = p
    out["shared/lensatic.css"] = SHARED_CSS
    return out


# the web copy of each Agentic SecOps diagram gains a way back and the umbrella's tab-title prefix (site review, 28 October
# 2026, item 6). The files in playbook/Diagrams/ stay as they are: the app embeds the same figures, and its twins must
# equal them (playbook/Validation/sync_check.cjs), so the change is made here, on the way to docs/.
DIAGRAM_BACK_CSS = ('<style id="lx-back-style">.lx-back{display:inline-flex;align-items:center;gap:6px;min-height:44px;margin:-12px 0 6px;'
                    'font-family:var(--mono);font-size:12px;letter-spacing:.08em;color:var(--accent);text-decoration:none}'
                    '.lx-back:hover{text-decoration:underline}.lx-back:focus-visible{outline:3px solid var(--accent);outline-offset:2px}'
                    '@media print{.lx-back{display:none}}</style>')


def diagram_for_web(src: bytes, name: str) -> bytes:
    """A diagram's web copy: "Lensatic · " before its tab title, and a small link back to the Agentic SecOps landing at the
    top of the poster's own column, in the diagram's own type and accent."""
    t = src.decode("utf-8")
    poster = '<body>\n<div class="poster">'
    for tag in ("<title>", "</head>", poster):
        if t.count(tag) != 1:
            sys.exit(f"build_hub: playbook/Diagrams/{name} has {t.count(tag)} {tag!r}, expected one")
    t = t.replace("<title>", "<title>Lensatic · ", 1).replace("</head>", DIAGRAM_BACK_CSS + "\n</head>", 1)
    return t.replace(poster, poster + '\n<a class="lx-back" href="../"><span aria-hidden="true">←</span> Agentic SecOps</a>', 1).encode("utf-8")


def build(docs: Path) -> list[str]:
    s, d = site(), stack()
    written = {"index.html": hub_page(s, d).encode("utf-8"), "guides/index.html": guides_page(s, d).encode("utf-8"),
               "sitemap.xml": sitemap(s, d).encode("utf-8"), "404.html": not_found_page(s, d).encode("utf-8")}
    for rel, src in published().items():
        if not src.is_file():
            sys.exit(f"build_hub: {src.relative_to(ROOT)} is missing")
        data = src.read_bytes()
        written[rel] = diagram_for_web(data, src.name) if rel.startswith("playbook/Diagrams/") and rel.endswith(".html") else data
    for rel, data in written.items():
        p = docs / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)
    return sorted(written)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--docs", default=str(DOCS), help="where to write; defaults to docs/")
    args = ap.parse_args()
    files = build(Path(args.docs))
    print(f"build_hub: wrote {len(files)} files under {args.docs}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
