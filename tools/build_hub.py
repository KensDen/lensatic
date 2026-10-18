#!/usr/bin/env python3
"""Build the Lensatic umbrella pages and publish the two moved sections into docs/ (Lensatic 2.0).

Writes, from sources inside this repository only:
  docs/index.html            the hub: top bar, hero, the three section tiles, About (ending on where the name comes from), footer
  docs/guides/index.html     the guides index: one tile per guide (Zero Trust is the first)
  docs/shared/lensatic.css   hub/lensatic.css byte for byte, the field system's one shared file
  docs/sitemap.xml           the hub, the map, the guides index, the Zero Trust guide, the Playbook landing and app
  docs/guides/zero-trust/    the Zero Trust guide's published files, copied from guides/zero-trust/ byte for byte
  docs/playbook/             the Agentic SecOps landing, app, documents, deck, diagrams and card, copied from playbook/

The map's pages (docs/maps/index.html, docs/privacy.html, docs/support.html, docs/social-card-v2.png, docs/.nojekyll)
are written by tools/build_web.py --pages, not here.

The hub and the guides index follow the map's own rules: no script, no resource loading (the type and the marks are
embedded), no storage, the theme from prefers-color-scheme. Text comes from hub/site.json and content/stack.json; counts
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
GUIDES = ROOT / "guides"
PLAYBOOK = ROOT / "playbook"
DOCS = ROOT / "docs"

# what each moved section publishes: everything its pages link to, nothing from its build or validation trees
ZT_FILES = ("index.html", "icon.svg", "icon-512.png", "apple-touch-icon.png", "favicon-32.png", "social-card.png")
ZT_PDF = re.compile(r"^\d{8}_ZT_(Study_Guide|Quick_Reference_[A-Za-z_]+)_v\d+\.\d+(?:\.\d+)?\.pdf$")
PLAYBOOK_FILES = ("index.html", "social-card.png", "Playbook/index.html")
PLAYBOOK_DIRS = ("Documents", "Deck", "Diagrams")


def esc(s: str) -> str:
    return html.escape(s, quote=True)


def site() -> dict:
    return json.loads(SITE_JSON.read_text(encoding="utf-8"))


def stack() -> dict:
    return json.loads(bw.STACK.read_text(encoding="utf-8"))


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
        "guides": plural(len(s["guides"]), "guide"),
        "playbook": f"{plural(pb['actions'], 'action')} · {plural(pb['resources'], 'resource')} · {plural(pb['glossary'], 'glossary term')}",
    }


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
    """Each section's own mark, at its existing art: the compass, the slashed zero, the APT_UNICORN emblem."""
    if key == "maps":
        return f'<span class="{cls} lx-tile" aria-hidden="true">{compass(32)}</span>'
    if key == "guides":
        return f'<img class="{cls}" src="{zt_mark()}" alt="" width="44" height="44">'
    return f'<img class="{cls}" src="{emblem()}" alt="" width="44" height="44">'


def bar(s: dict, root: str, active: str | None, brand_mark: bool = True) -> str:
    """The shared top bar, one implementation for every page: tools/build_web.py's umbrella_bar."""
    return bw.umbrella_bar(s, root, active, brand_mark)


def footer(s: dict, d: dict, root: str) -> str:
    L = d["ui"]["labels"]
    return ('<footer class="lx-foot"><div class="lx-foot-in">'
            f'<p class="lx-version">{esc(s["name"])} {esc(s["version"])}, {esc(s["dateText"])}</p>'
            f'<ul><li><a href="{root}privacy.html">{esc(L["pagesPrivacy"])}</a></li><li><a href="{root}support.html">{esc(L["pagesSupport"])}</a></li>'
            f'<li><a href="{esc(s["repo"])}">{esc(L["sourceCode"])}</a></li></ul></div></footer>')


def styles() -> str:
    return bw.font_css() + "\n" + SHARED_CSS.read_text(encoding="utf-8").rstrip("\n") + "\n" + HUB_CSS


# page-level rules for the hub and the guides index, on the shared tokens; the chrome itself is in hub/lensatic.css
HUB_CSS = """.lx-hero-lines { margin: var(--s-5) 0 0; padding: 0; list-style: none; display: grid; gap: var(--s-2); max-width: 46rem; }
.lx-hero-lines li { padding-left: var(--s-4); border-left: 3px solid var(--line-strong); color: var(--fg); }
.lx-hero-lines li.maps { border-left-color: var(--sec-maps); }
.lx-hero-lines li.guides { border-left-color: var(--sec-guides); }
.lx-hero-lines li.playbook { border-left-color: var(--sec-playbook); }
.lx-guide-meta { display: grid; gap: var(--s-2); margin: 0; }
.lx-guide-meta dt { font-family: var(--mono); font-size: 0.8125rem; font-weight: 700; letter-spacing: 0.08em; text-transform: uppercase; color: var(--fg-2); }
.lx-guide-meta dd { margin: 0 0 var(--s-2); }
.lx-refs { display: flex; flex-wrap: wrap; gap: 0 var(--s-4); margin: 0; padding: 0; list-style: none; }
.lx-refs a { display: inline-flex; align-items: center; min-height: 44px; }
.lx-about p { color: var(--fg); }
.lx-name-head { margin: var(--s-6) 0 var(--s-3); font-size: 1.25rem; line-height: 1.3; }
.lx-name-story { display: grid; gap: var(--s-3) var(--s-5); }
.lx-name-text p:first-child { margin-top: 0; }
.lx-name-photo { display: block; width: 100%; height: auto; border: 1px solid var(--line); border-radius: var(--card-radius); }
@media (min-width: 768px) { .lx-name-story { grid-template-columns: minmax(0, 2fr) minmax(0, 3fr); align-items: start; } }"""


def head(s: dict, title: str, description: str, url: str, image_alt: str) -> str:
    card = s["site"] + bw.SOCIAL_NAME  # the hub card, published by tools/build_web.py --pages
    tags = [("property", "og:title", title), ("property", "og:description", description), ("property", "og:type", "website"),
            ("property", "og:url", url), ("property", "og:image", card), ("property", "og:image:width", "1200"),
            ("property", "og:image:height", "630"), ("property", "og:image:alt", image_alt), ("name", "twitter:card", "summary_large_image")]
    meta = "\n".join(f'<meta {a}="{k}" content="{esc(v)}">' for a, k, v in tags)
    return ("<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">\n"
            "<meta name=\"color-scheme\" content=\"light dark\">\n<meta name=\"referrer\" content=\"no-referrer\">\n"
            f"<link rel=\"icon\" href=\"{bw.favicon()}\">\n<title>{esc(title)}</title>\n"
            f"<meta name=\"description\" content=\"{esc(description)}\">\n<link rel=\"canonical\" href=\"{esc(url)}\">\n{meta}\n"
            f"<style>\n{styles()}\n</style>\n</head>\n")


def first_use(r: "bw.Renderer"):
    """Abbreviations spelled out at their first use in each section, by the map's own rule for its plain pages (no glossary
    links here; a label's abbreviation becomes an abbr element with its expansion as the title)."""
    entries = [e for e in r.glossary_entries() if e["forms"] and (e["expansion"] or e["notAbbreviation"])]
    return bw.FirstUse(entries, link=False)


def name_story(r: "bw.Renderer", about: dict) -> str:
    """Where the name comes from, as the Framework Maps About panel tells it: its heading, the maker's compass photo and
    meta.about.nameStory, from content/stack.json and ui.labels, never restated. The photo is web/src/about-photo.jpg
    byte for byte, embedded as a data: URI as on the map (part of the page, not a request), with the map's alt text."""
    data = bw.PHOTO.read_bytes()
    w, h = bw.jpeg_size(data)
    photo = (f'<img class="lx-name-photo" src="data:image/jpeg;base64,{base64.b64encode(data).decode("ascii")}" '
             f'alt="{r.label("aboutPhotoAlt")}" width="{w}" height="{h}">')
    story = "".join(f"<p>{r.t(p)}</p>" for p in about["nameStory"])
    return (f'<h3 class="lx-name-head" id="about-name">{r.label("whyNameHeading")}</h3>'
            f'<div class="lx-name-story">{photo}<div class="lx-name-text">{story}</div></div>')


def hub_page(s: dict, d: dict) -> str:
    r = bw.Renderer(d, "")
    fu = first_use(r)
    c = counts(s, d)
    about = d["meta"]["about"]
    hero_lines = "".join(f'<li class="{x["key"]}">{esc(x["hero"])}</li>' for x in s["sections"])
    tiles = []
    for x in s["sections"]:
        tiles.append(f'<li class="lx-tile-card {x["key"]}">{section_icon(x["key"], "lx-icon")}'
                     f'<h3>{esc(x["name"])}</h3><p>{esc(x["line"])}</p><p class="lx-count">{esc(c[x["key"]])}</p>'
                     f'<p class="lx-actions"><a class="lx-btn lx-primary" href="{x["path"]}">{esc(x["open"])}</a></p></li>')
    kicker = " · ".join(x["name"] for x in s["sections"])
    hero = (f'<header class="lx-hero"><div class="lx-wrap lx-head">{tile("lx-mark lx-tile")}'
            f'<p class="lx-eyebrow">{esc(kicker)}</p><h1>{esc(s["name"])}</h1>'
            f'<p class="lx-standfirst">{esc(d["meta"]["tagline"])}</p><ul class="lx-hero-lines">{hero_lines}</ul></div></header>\n')
    sections = (f'<section class="lx-wrap lx-section" aria-labelledby="sections-h"><h2 id="sections-h" class="lx-vh">{esc(kicker)}</h2>'
                f'<ul class="lx-tiles">{"".join(tiles)}</ul></section>\n')
    about_html = (f'<section class="lx-wrap lx-section lx-about" id="about" aria-labelledby="about-h"><h2 id="about-h">{esc(s["aboutLabel"])}</h2>'
                  + "".join(name_story(r, about) if k == "nameStory" else f"<p>{r.t(about[k])}</p>" for k in s["aboutBlocks"]) + "</section>\n")
    body = (f'<body class="lx-page">\n<a class="lx-skip" href="#main">{r.label("skip")}</a>\n{bar(s, "./", None)}\n<main id="main">\n'
            f'{fu.section(hero)}{fu.section(sections)}{fu.section(about_html)}'
            f'</main>\n{footer(s, d, "./")}\n</body>\n</html>\n')
    return head(s, s["name"], d["meta"]["pitch"], s["site"], f'{s["name"]}: {kicker}') + body


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
    return head(s, f'{s["name"]} · {sec["name"]}', sec["line"], s["site"] + sec["path"], f'{s["name"]}: {sec["name"]}') + body


def sitemap(s: dict) -> str:
    pages = ["", "maps/", "guides/", "guides/zero-trust/", "playbook/", "playbook/Playbook/"]
    rows = "".join(f'  <url><loc>{s["site"]}{p}</loc><lastmod>{s["date"]}</lastmod></url>\n' for p in pages)
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


def build(docs: Path) -> list[str]:
    s, d = site(), stack()
    written = {"index.html": hub_page(s, d).encode("utf-8"), "guides/index.html": guides_page(s, d).encode("utf-8"),
               "sitemap.xml": sitemap(s).encode("utf-8")}
    for rel, src in published().items():
        if not src.is_file():
            sys.exit(f"build_hub: {src.relative_to(ROOT)} is missing")
        written[rel] = src.read_bytes()
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
