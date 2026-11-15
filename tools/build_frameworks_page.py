#!/usr/bin/env python3
"""The website's frameworks page (Lensatic 2.0, Round 3): docs/maps/frameworks/index.html, built from the same folder the
iOS app's framework navigator reads, content/frameworks/, so the site and the app say the same words.

Every framework is a card in the catalog's order, under the catalog's groups: what it is for, before what it says; who it
binds, how it is assessed, how big it is and where it sits; its dated deadlines; the top level of its structure, with how
much of it the app shows; its baselines; how many of the Agentic SecOps plays touch it; its sources, each with the day it
was last checked; and the publisher's terms, with any notice the publisher requires wherever its material is shown. Then
the written comparisons, the answers to where other standards land, and the self-checks by name. Nothing is typed here:
every word comes from the folder, from content/stack.json (the layers' names, the status words, the entries a card rests
on) or from hub/site.json (the section's name), and every count is computed.

The page is a plain page beside the map, on the plain pages' template and stylesheet with its own additions
(web/src/frameworks.css). It carries no script but the shared top bar's theme scripts, loads nothing, and prints whole: its
own printout limit is in tools/check_web.py, apart from the map's, which this page does not touch.

tools/build_web.py --pages writes it with the map's other pages; tools/check_web.py holds it to a fresh build and to the
folder.

Usage: python3 tools/build_frameworks_page.py            print the page's size and counts (the page is written by --pages)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import build_web as bw  # noqa: E402  (the site's chrome, the first-use rule, the plain pages' template)

DIR = ROOT / "content" / "frameworks"
PLAYS = ROOT / "playbook" / "app" / "plays.json"
CSS = bw.SRC / "frameworks.css"
PATH = f"{bw.MAPS_KEY}/frameworks/index.html"
ROOT_REL = "../../"   # from docs/maps/frameworks/ to the site's root


def load(name: str) -> dict:
    return json.loads((DIR / f"{name}.json").read_text(encoding="utf-8"))


def grouped(n: int) -> str:
    return f"{n:,}"


class Page:
    def __init__(self, d: dict, author: str = "") -> None:
        self.d = d
        self.r = bw.Renderer(d, author)
        self.cat = load("catalog")
        self.L = self.cat["labels"]
        self.fws = {i: load(i) for i in self.cat["frameworks"]}
        self.links = load(self.cat["plays"]) if self.cat.get("plays") else {"plays": []}
        self.play_count = len(json.loads(PLAYS.read_text(encoding="utf-8"))["plays"]) if PLAYS.exists() else 0
        self.layers = sorted(d["layers"], key=lambda l: l["order"])
        self.entities = {e["id"]: e for kind in ("frameworks", "sources", "solutions") for e in d[kind]}
        self.sep = bw.esc(d["ui"]["labels"]["metaSeparator"])

    # ---- words
    def t(self, s: str) -> str:
        return self.r.t(s)

    def label(self, key: str, **fill) -> str:
        s = self.L[key]
        for k, v in fill.items():
            s = s.replace("{" + k + "}", str(v))
        return self.t(s)

    def sits(self, f: dict) -> str:
        """Where a framework sits, in the app's words (AppModel.sitsLabel): "Layer 4, Controls", "Layers 1, 4 and 5",
        the column's name, "Adversary column"."""
        on = [l for l in self.layers if l["id"] in f["sits"]["layers"]]
        rows, cols = [l for l in on if not l["isColumn"]], [l for l in on if l["isColumn"]]
        parts = []
        if len(rows) == 1:
            parts.append(f'{self.d["ui"]["labels"]["layer"]} {rows[0]["order"]}, {rows[0]["shortName"]}')
        elif rows:
            n = [str(l["order"]) for l in rows]
            parts.append(f'{self.L["layers"]} {", ".join(n[:-1])} and {n[-1]}')
        parts += [l["name"] for l in cols]
        if not f["compliance"]:
            parts.append(self.L["adversaryColumn"])
        return ", ".join(parts)

    def checked(self, v: dict) -> str:
        status = self.d["ui"]["status"].get(v["status"], v["status"])
        if not v.get("verifiedOn"):
            return bw.esc(status)
        return (f'{bw.esc(status)}{self.sep}{bw.esc(self.d["ui"]["labels"]["verifiedOn"])} '
                f'<time datetime="{v["verifiedOn"]}">{bw.fmt_date(v["verifiedOn"])}</time>')

    def source(self, s: dict) -> str:
        """One source: its title as a link, then publisher, edition and date, and the day it was last checked. A label:
        a publisher's title takes no spell-out."""
        date = bw.fmt_date(s["date"]) if len(s["date"]) == 10 else bw.esc(s["date"])
        pdf = f' <a class="url" href="{bw.esc(s["pdf"])}" rel="noreferrer">{self.label("openPDF")}</a>' if s.get("pdf") else ""
        return (f'<li class="ref"><a href="{bw.esc(s["url"])}" rel="noreferrer">{self.t(s["title"])}</a>{bw.pdf_tag(bw.opens_pdf(s))}{pdf}'
                f'<span class="fw-cite">{self.t(s["publisher"])}{self.sep}{self.t(s["edition"])}{self.sep}{date}</span>'
                f'<span class="fw-checked">{self.checked(s["verification"])}</span></li>')

    # ---- a card
    def card(self, f: dict) -> str:
        L, out = self.L, []
        out.append(f'<article class="fw" id="fw-{f["id"]}" style="--tone: {f["color"]["light"]}; --tone-d: {f["color"]["dark"]}">')
        out.append(f'<h3>{self.t(f["name"])}</h3><p class="fw-kind ref">{self.t(f["kind"])}</p>')
        out.append(f'<p class="fw-purpose">{self.t(f["purpose"])}</p><p>{self.t(f["what"])}</p>')
        if f.get("note") or not f["nodes"]:
            out.append(f'<p class="note">{self.t(f.get("note") or L["cardOnly"])}</p>')
        if not f["compliance"]:
            out.append(f'<p class="fw-flag">{self.label("notCompliance")}</p>')
        for dl in self.deadlines(f):
            out.append(f'<p class="fw-due"><span class="ref">{self.label("countdown")}</span> <strong>{self.t(dl["label"])}</strong>{self.sep}'
                       f'<time datetime="{dl["date"]}">{bw.fmt_date(dl["date"])}</time>{self.sep}{self.t(dl["binds"])}</p>')
        size = self.sep.join(f'{grouped(s["count"])} {self.t(s["unit"])}' for s in f["size"])
        facts = [(L["binds"], f["binds"]["short"], f["binds"]["line"]), (L["verified"], f["verifiedBy"]["short"], f["verifiedBy"]["line"]),
                 (L["sits"], self.sits(f), f["sits"]["line"])]
        out.append('<dl class="fw-facts">' + "".join(
            f'<div><dt>{self.t(k)}</dt><dd><strong class="ref">{self.t(short)}</strong> {self.t(line)}</dd></div>' for k, short, line in facts)
            + f'<div><dt>{self.t(L["size"])}</dt><dd><strong class="ref">{size}</strong></dd></div></dl>')
        out.append(self.structure(f))
        touching = [p for p in self.links["plays"] if any(l["frameworkId"] == f["id"] for l in p["links"])]
        if touching:
            out.append(f'<p class="fw-plays"><span class="ref">{self.label("playsOn")}</span> '
                       f'{self.label("playsOnLineOne" if len(touching) == 1 else "playsOnLine", n=len(touching), m=self.play_count)}.</p>')
        # the stack entry's own citation first, in the same shape, as the app's screen has it
        srcs = []
        e = self.entities.get(f.get("entityId", ""))
        if e:
            srcs.append({k: e.get(k) for k in ("publisher", "title", "edition", "date", "url", "pdf", "verification")})
        srcs += f["sources"]
        out.append(f'<h4>{self.label("sources")}</h4><ul class="fw-sources">' + "".join(self.source(s) for s in srcs) + "</ul>")
        terms = f["terms"]
        out.append(f'<h4>{self.label("terms")}</h4><p class="fw-terms">{self.t(terms["line"])}</p>')
        if terms["notice"]:
            out.append(f'<p class="fw-notice ref">{self.t(terms["notice"])}</p>')
        if terms["url"]:
            out.append(f'<p class="fw-terms-link"><a class="url" href="{bw.esc(terms["url"])}" rel="noreferrer">{self.label("openTerms")}</a></p>')
        out.append("</article>")
        return "".join(out)

    def deadlines(self, f: dict) -> list[dict]:
        """A card's dated deadlines, as the app lists them (FrameworkLibrary.deadlines): its own, and its stack entry's
        unless the card already carries that day in its own words."""
        out = [{"date": d["date"], "label": d["label"], "binds": d["binds"]} for d in f["deadlines"]]
        e = self.entities.get(f.get("entityId", ""))
        due = ((e or {}).get("authority", {}).get("deadline") or {}).get("due") if e else None
        if due and all(x["date"] != due["date"] for x in out):
            binds = ", ".join(self.d["ui"]["binds"][b] for b in e["authority"]["binds"] if b in self.d["ui"]["binds"])
            out.append({"date": due["date"], "label": due["label"], "binds": binds})
        return sorted(out, key=lambda x: x["date"])

    def structure(self, f: dict) -> str:
        """The top of a framework's structure, a list for each level that has top-level elements (the app's
        FrameworkDetailView.topLevels: the levels with elements beneath them first), then how much the app shows, then
        the baselines with their counts."""
        if not f["nodes"] or f["depth"] is None:
            return ""
        kids: dict[str, int] = {}
        for n in f["nodes"]:
            for p in n["parents"]:
                kids[p] = kids.get(p, 0) + 1
        roots = [n for n in f["nodes"] if not n["parents"]]
        groups = [(lv, [n for n in roots if n["level"] == lv["id"]]) for lv in f["levels"]]
        groups = [g for g in groups if g[1]]
        groups = [g for g in groups if any(kids.get(n["id"]) for n in g[1])] + [g for g in groups if not any(kids.get(n["id"]) for n in g[1])]
        out = []
        for lv, nodes in groups:
            head = self.L["structure"] if len(groups) == 1 else f'{self.L["structure"]}: {len(nodes)} {lv["name"] if len(nodes) == 1 else lv["plural"]}'
            rows = []
            for n in nodes:
                ident = f'<span class="fw-id">{self.t(n["id"])}</span> ' if lv.get("identified", True) else ""
                count = f' <span class="fw-n">{kids[n["id"]]}</span>' if kids.get(n["id"]) else ""
                rows.append(f'<li class="ref">{ident}{self.t(n.get("title") or n.get("text") or n["id"])}{count}</li>')
            out.append(f'<h4>{self.t(head)}</h4><ul class="fw-nodes">{"".join(rows)}</ul>')
        d = f["depth"]
        line = self.label("shownOf", shown=grouped(d["shown"]), of=grouped(d["of"]), unit=d["unit"])
        out.append(f'<p class="fw-depth">{line}{(" " + self.t(d["why"])) if d["why"] else ""}</p>')
        if f["sets"]:
            rows = "".join(f'<li><span class="ref">{self.t(s["name"])}</span> <span class="fw-n">{grouped(len(s["members"]))}</span>'
                           + (f'<span class="fw-set-line">{self.t(s["line"])}</span>' if s.get("line") else "") + "</li>" for s in f["sets"])
            foot = f.get("setsLine") or (self.L["baselinesOn"].replace("{name}", self.fws[f["sets"][0]["of"]]["shortName"]) if f["sets"][0]["of"] in self.fws else "")
            out.append(f'<h4>{self.t(f.get("setsTitle") or self.L["baselines"])}</h4><ul class="fw-sets">{rows}</ul>'
                       + (f'<p class="fw-depth">{self.t(foot)}</p>' if foot else ""))
        return "".join(out)

    # ---- the page
    def body(self) -> str:
        cat, L = self.cat, self.L
        # every element the app lists, at every level: each has its own screen there
        elements = sum(len(f["nodes"]) for f in self.fws.values())
        maps = next(x for x in bw.umbrella()["sections"] if x["key"] == bw.MAPS_KEY)
        out = [f'<p class="fw-eyebrow ref"><a href="../">{bw.esc(maps["name"])}</a></p><h1>{self.label("pageTitle")}</h1>',
               f'<p class="fw-lede">{self.t(cat["intro"])}</p>',
               f'<p>{self.label("pageDeeper", elements=grouped(elements), count=len(self.fws))}</p>',
               f'<p class="small">{self.label("pageSourcesChecked")}: <time datetime="{cat["checkedOn"]}">{bw.fmt_date(cat["checkedOn"])}</time></p>']
        groups = [g for g in cat["groups"] if any(f["group"] == g["id"] for f in self.fws.values())]
        jump = [(f'group-{g["id"]}', g["name"]) for g in groups] + [("compare", L["compare"]), ("lands", L["landsTitle"]), ("checks", L["checks"])]
        out.append(f'<nav class="fw-jump" aria-label="{self.label("pageOn")}"><ul>' + "".join(f'<li><a href="#{i}">{self.t(n)}</a></li>' for i, n in jump) + "</ul></nav>")
        for g in groups:
            cards = [f for f in self.fws.values() if f["group"] == g["id"]]
            out.append(f'<section class="fw-group" id="group-{g["id"]}" aria-labelledby="group-{g["id"]}-h"><h2 id="group-{g["id"]}-h">{self.t(g["name"])} '
                       f'<span class="fw-n">{len(cards)}</span></h2><p class="note">{self.t(g["line"])}</p>'
                       + "".join(self.card(f) for f in cards) + "</section>")
        # the written comparisons
        rows = []
        for cid in cat["compares"]:
            c = load(cid)
            a, b = self.fws[c["a"]], self.fws[c["b"]]
            na, nb = c.get("aName") or a["shortName"], c.get("bName") or b["shortName"]
            table = "".join(f'<tr><th scope="row">{self.t(r["label"])}</th><td>{self.t(r["a"])}</td><td>{self.t(r["b"])}</td></tr>' for r in c["rows"])
            rows.append(f'<article class="fw fw-compare" id="{cid}"><h3>{self.t(na)} {self.label("with")} {self.t(nb)}</h3><p class="fw-purpose">{self.t(c["verdict"])}</p>'
                        f'<div class="fw-scroll"><table><thead><tr><td></td><th scope="col">{self.t(na)}</th><th scope="col">{self.t(nb)}</th></tr></thead><tbody>{table}</tbody></table></div>'
                        f'<h4>{self.label("howTheyConnect")}</h4><p>{self.t(c["connect"])}</p><h4>{self.label("noScoreTitle")}</h4><p>{self.t(c["noScore"])}</p></article>')
        out.append(f'<section class="fw-group" id="compare" aria-labelledby="compare-h"><h2 id="compare-h">{self.label("compare")} <span class="fw-n">{len(rows)}</span></h2>'
                   f'<p class="note">{self.label("compareIntro")}</p>{"".join(rows)}<p class="note">{self.label("compareMore")}</p></section>')
        # where other standards land
        lands = []
        for l in cat["lands"]:
            on = ", ".join(f'<a href="#fw-{i}">{self.t(self.fws[i]["shortName"])}</a>' for i in l["frameworkIds"])
            lands.append(f'<article class="fw" id="land-{l["id"]}"><h3>{self.t(l["name"])}</h3><p class="fw-kind ref">{self.t(l["owner"])}</p><p>{self.t(l["what"])}</p>'
                         f'<p>{self.t(l["lands"])}</p><p class="fw-plays"><span class="ref">{self.label("landsOn")}</span> <span class="ref">{on}</span></p>'
                         f'<h4>{self.label("sources")}</h4><ul class="fw-sources">{self.source(l["source"])}</ul></article>')
        out.append(f'<section class="fw-group" id="lands" aria-labelledby="lands-h"><h2 id="lands-h">{self.label("landsTitle")}</h2>'
                   f'<p class="note">{self.label("landsLine")}</p>{"".join(lands)}</section>')
        # the self-checks, by name: they are the app's
        checks = "".join(f'<li><strong class="ref">{self.t(c["title"])}</strong> <span class="ref"><a href="#fw-{c["frameworkId"]}">{self.t(self.fws[c["frameworkId"]]["shortName"])}</a></span>'
                         f'<span class="fw-set-line">{self.t(c["line"])}</span></li>' for c in (load(i) for i in cat["checks"]))
        out.append(f'<section class="fw-group" id="checks" aria-labelledby="checks-h"><h2 id="checks-h">{self.label("checks")}</h2>'
                   f'<p class="note">{self.label("pageChecksLine")}</p><ul class="fw-sets fw-checks">{checks}</ul>'
                   f'<p class="note">{self.label("checkNotAssessment")}</p></section>')
        return "\n".join(out) + "\n"

    def build(self) -> bytes:
        d, L = self.d, self.L
        entries = [e for e in self.r.glossary_entries() if e["forms"] and (e["expansion"] or e["notAbbreviation"])]
        # abbreviations spelled out at first use, as on the plain pages: no links, the glossary lives on the map
        main = bw.FirstUse(entries, link=False).section(self.body())
        css = bw.page_css() + "\n" + CSS.read_text(encoding="utf-8").rstrip("\n")
        tags = [("property", "og:title", L["pageTabTitle"]), ("property", "og:description", L["pageDescription"]), ("property", "og:type", "website"),
                ("property", "og:url", f"{bw.SITE}{bw.MAPS_KEY}/frameworks/"), ("name", "twitter:card", "summary")]
        # no canonical link element: like the plain pages, the page carries no link element at all (the offline rule)
        social = "\n".join(f'<meta {a}="{k}" content="{bw.esc(v)}">' for a, k, v in tags)
        template = (bw.SRC / "page.html").read_text(encoding="utf-8")
        fill = {"{{LANG}}": "en", "{{TITLE}}": bw.esc(L["pageTabTitle"]), "{{DESCRIPTION}}": bw.esc(L["pageDescription"]), "{{ICON}}": bw.favicon(),
                "{{STYLES}}": css, "{{THEME_HEAD}}": bw.theme_head(), "{{BAR}}": bw.umbrella_bar(bw.umbrella(), ROOT_REL, bw.MAPS_KEY),
                "{{SOCIAL}}": social, "{{BODY}}": main, "{{FOOTER}}": bw.site_footer(bw.umbrella(), d["ui"]["labels"], ROOT_REL) + "\n"}
        for k, v in fill.items():
            template = template.replace(k, v)
        if "{{" in template:
            sys.exit("frameworks page: a template placeholder or render token was left unreplaced")
        return template.encode("utf-8")


def build(d: dict, author: str = "") -> bytes:
    return Page(d, author).build()


def main() -> int:
    d = json.loads(bw.STACK.read_text(encoding="utf-8"))
    page = Page(d)
    data = page.build()
    print(f"{PATH}: {len(data)} bytes, {len(page.fws)} frameworks, {len(page.cat['compares'])} comparisons, {len(page.cat['lands'])} landings "
          f"(written by tools/build_web.py --pages)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
