#!/usr/bin/env python3
"""Battery checks for the Lensatic umbrella (Lensatic 2.0, 18 October 2026): the parts of docs/ the map's checks do not
own, and the field system that ties the sections together.

  sync        docs/ holds published copies only: a fresh tools/build_hub.py run into .tmp/ is byte-identical to the
              hub, the guides index, the shared stylesheet, the sitemap and every published copy of guides/zero-trust/
              and playbook/ in docs/; every file in docs/ is written by tools/build_web.py --pages or tools/build_hub.py
  chrome      the two Agentic SecOps pages carry the current chrome (tools/apply_chrome.py --check); the map and the Zero
              Trust guide carry the umbrella bar from hub/site.json and the shared stylesheet byte for byte, and the guide
              the shared footer; the guide's embedded stylesheet and bar are the live files, not stale snapshots
  tokens      the map's tokens (web/src/styles.css) and the Agentic SecOps app's equal the field system's values
  contrast    the field system meets WCAG AA in both themes: every text colour on every surface 4.5, the focus ring and
              the mark 3
  links       every relative link and source in every HTML page under docs/ resolves to a file in docs/, and every
              fragment to an id on its page
  loads       the hub, the guides index, the map, privacy, support and the Zero Trust guide load nothing from another
              origin (no remote script, stylesheet, image, font, frame or import)
  dashes      no em or en dash in any file the umbrella wrote (hub/, the umbrella's tools, its published pages)
  counts      the hub's Agentic SecOps counts equal the canon playbook/Validation/ripple_check.cjs derives
  sitemap     docs/sitemap.xml lists the hub, the map, the guides index, the Zero Trust guide, the landing and the app
  sweep       with LENSATIC_PRIVATE_SWEEP set to the owner's private list, no term appears in a file the umbrella wrote
              (counts only, never the terms); without it, one SKIP line
Usage: python3 tools/check_umbrella.py
"""
from __future__ import annotations

import html.parser
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import build_web as bw  # noqa: E402
import build_hub as bh  # noqa: E402
import validate as V  # noqa: E402  (the battery's report format)

DOCS = ROOT / "docs"
TMP = ROOT / ".tmp"
DASH = re.compile("[" + chr(0x2013) + chr(0x2014) + "]")
UMBRELLA_WRITTEN = ["hub/lensatic.css", "hub/site.json", "hub/DESIGN.md", "tools/build_hub.py", "tools/apply_chrome.py",
                    "tools/check_umbrella.py", "docs/index.html", "docs/guides/index.html", "docs/shared/lensatic.css", "docs/sitemap.xml"]
SHARED = ("bg", "bg-2", "fg", "fg-2", "line", "line-strong", "accent", "accent-fg", "link", "focus", "bad", "tile-bg", "tile-fg")
NO_REMOTE = ["docs/index.html", "docs/guides/index.html", "docs/maps/index.html", "docs/privacy.html", "docs/support.html",
             "docs/guides/zero-trust/index.html"]


def block(css: str, selector: str) -> dict[str, str]:
    i = css.find(selector + " {")
    if i < 0:
        return {}
    return dict(re.findall(r"--([a-z0-9-]+):\s*([^;]+);", css[i:css.index("}", i)]))


def themes(css: str, light_sel: str, dark_sel: str) -> tuple[dict, dict]:
    return block(css, light_sel), block(css, dark_sel)


def lum(h: str) -> float:
    r, g, b = (int(h[k:k + 2], 16) / 255 for k in (1, 3, 5))
    f = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def ratio(a: str, b: str) -> float:
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


class Links(html.parser.HTMLParser):
    """Collects ids, every href and src, and the remote loads (by element), ignoring script and style bodies."""
    LOADS = {("script", "src"), ("link", "href"), ("img", "src"), ("img", "srcset"), ("iframe", "src"), ("source", "src"),
             ("source", "srcset"), ("video", "src"), ("audio", "src"), ("embed", "src"), ("object", "data")}

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.ids, self.refs, self.remote = set(), [], []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if a.get("id"):
            self.ids.add(a["id"])
        if tag == "a" and a.get("name"):
            self.ids.add(a["name"])
        for k in ("href", "src"):
            if a.get(k) is not None:
                self.refs.append((tag, k, a[k], a.get("rel", "")))
        for t, k in self.LOADS:
            v = a.get(k)
            if tag == t and v and re.match(r"^(?:https?:)?//", v.strip()):
                if tag == "link" and a.get("rel", "") in ("canonical",):
                    continue
                self.remote.append(f"<{tag} {k}={v[:60]}>")


def parse(path: Path) -> Links:
    p = Links()
    p.feed(path.read_text(encoding="utf-8", errors="replace"))
    return p


def main() -> int:
    rep = V.Report()
    s, d = bh.site(), bh.stack()

    # ---- sync
    errs = []
    TMP.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=TMP) as td:
        fresh = Path(td) / "docs"
        written = bh.build(fresh)
        for rel in written:
            a, b = fresh / rel, DOCS / rel
            if not b.is_file():
                errs.append(f"docs/{rel} missing; run tools/build_hub.py")
            elif a.read_bytes() != b.read_bytes():
                errs.append(f"docs/{rel} differs from its source or a fresh build")
    sys.path.insert(0, str(ROOT / "tools"))
    import check_web as cw  # noqa: E402
    stray = [q.relative_to(DOCS).as_posix() for q in DOCS.rglob("*") if q.is_file() and q.name != ".DS_Store"
             and q.relative_to(DOCS).as_posix() not in written and not cw.map_owned(q.relative_to(DOCS).as_posix())]
    errs += [f"docs/{q} is written by neither build" for q in stray]
    rep.check("sync: docs/ holds published copies only; a fresh build_hub.py run is byte-identical to the hub, guides index, shared "
              "stylesheet, sitemap and every published copy, and every file is accounted for", errs, f"{len(written)} umbrella files")

    # ---- chrome
    errs = []
    r = subprocess.run([sys.executable, str(ROOT / "tools" / "apply_chrome.py"), "--check"], capture_output=True, text=True)
    if r.returncode:
        errs.append(r.stdout.strip())
    css = bw.SHARED_CSS.read_text(encoding="utf-8").rstrip("\n")
    wrapper = bw.OUT.read_text(encoding="utf-8")
    if wrapper.count(bw.umbrella_bar(s, "../", "maps", brand_mark=False)) != 1:
        errs.append("web/lensatic.html: the umbrella bar is missing or stale")
    if css not in wrapper:
        errs.append("web/lensatic.html: the shared stylesheet is missing or stale")
    zt = (ROOT / "guides" / "zero-trust" / "index.html").read_text(encoding="utf-8")
    if zt.count(bw.umbrella_bar(s, "../../", "guides")) != 1:
        errs.append("guides/zero-trust/index.html: the umbrella bar is missing or stale (refresh the guide's snapshot and rebuild it)")
    if css not in zt:
        errs.append("guides/zero-trust/index.html: the shared stylesheet is missing or stale (refresh the guide's snapshot and rebuild it)")
    foot = bh.footer(s, d, "../../")
    if foot[:-len("</footer>")] not in zt:
        errs.append("guides/zero-trust/index.html: the shared footer is missing or stale")
    rep.check("chrome: the Agentic SecOps landing and app, the map and the Zero Trust guide carry the current umbrella bar and shared "
              "stylesheet (and the guide the shared footer)", errs)

    # ---- tokens
    errs = []
    lx_light, lx_dark = themes(css, ":root", ':root[data-theme="dark"]')
    styles = (bw.SRC / "styles.css").read_text(encoding="utf-8")
    m_light, m_dark = themes(styles, ":root", ':root[data-theme="dark"]')
    for theme, lx, m in (("light", lx_light, m_light), ("dark", lx_dark, m_dark)):
        for k in SHARED:
            if m.get(k, "").upper() != lx.get(k, "").upper():
                errs.append(f"map {theme} --{k} {m.get(k)} != field system {lx.get(k)}")
        if m.get("seam", "").upper() != lx["bg-2"].upper() or m.get("chip-bg", "").upper() != lx["bg"].upper():
            errs.append(f"map {theme}: --seam is not --bg-2 or --chip-bg is not --bg")
    app = (ROOT / "playbook" / "Playbook" / "index.html").read_text(encoding="utf-8")
    a_dark, a_light = block(app, ':root, :root[data-theme="dark"]'), block(app, ':root[data-theme="light"]')
    pairs = {"app-bg": "bg", "surface": "bg-2", "surface-border": "line", "text-primary": "fg", "text-secondary": "fg-2",
             "accent": "accent", "danger": "bad", "team-purple": "sec-playbook", "on-accent": "accent-fg"}
    for theme, a, lx in (("light", a_light, lx_light), ("dark", a_dark, lx_dark)):
        for ak, lk in pairs.items():
            if a.get(ak, "").strip().upper() != lx.get(lk, "").upper():
                errs.append(f"app {theme} --{ak} {a.get(ak)} != field system --{lk} {lx.get(lk)}")
    rep.check("tokens: the map's and the Agentic SecOps app's colours are the field system's values in both themes", errs)

    # ---- contrast
    errs, worst = [], 99.0
    for theme, lx in (("light", lx_light), ("dark", lx_dark)):
        for surf in ("bg", "bg-2", "bg-3"):
            for fg in ("fg", "fg-2", "link", "accent", "bad", "sec-maps", "sec-guides", "sec-playbook"):
                r_ = ratio(lx[fg], lx[surf]); worst = min(worst, r_)
                if r_ < 4.5:
                    errs.append(f"{theme}: --{fg} on --{surf} {r_:.2f}")
        for a_, b_, floor in (("accent-fg", "accent", 4.5), ("focus", "bg", 3.0), ("focus", "bg-2", 3.0), ("tile-fg", "tile-bg", 3.0)):
            if ratio(lx[a_], lx[b_]) < floor:
                errs.append(f"{theme}: --{a_} on --{b_} {ratio(lx[a_], lx[b_]):.2f} under {floor}")
    rep.check("contrast: every field-system text colour on every surface meets 4.5 in both themes; the focus ring and the mark 3", errs,
              f"lowest text pair {worst:.2f}")

    # ---- links
    errs, n_links = [], 0
    pages = sorted(DOCS.rglob("*.html"))
    parsed = {p: parse(p) for p in pages}
    for p, pr in parsed.items():
        for tag, k, v, rel in pr.refs:
            v = v.strip()
            if not v or re.match(r"^(?:[a-z][a-z0-9+.-]*:|//)", v, re.I):
                continue
            n_links += 1
            path, _, frag = v.partition("#")
            target = (p.parent / path).resolve() if path else p
            if path and target.is_dir():
                target = target / "index.html"
            if not target.is_file() or not target.is_relative_to(DOCS.resolve()):
                errs.append(f"{p.relative_to(DOCS)}: {v} does not resolve")
                continue
            if frag and target.suffix == ".html":
                ids = parsed.get(target, None)
                ids = ids.ids if ids else parse(target).ids
                if frag not in ids and not frag.startswith(":~:"):
                    errs.append(f"{p.relative_to(DOCS)}: {v} names no id on its page")
    rep.check("links: every relative link and source in every page under docs/ resolves inside docs/, and every fragment to an id", errs,
              f"{n_links} relative references in {len(pages)} pages")

    # ---- loads
    errs = []
    for rel in NO_REMOTE:
        p = ROOT / rel
        pr = parsed.get(p.resolve()) or parse(p)
        errs += [f"{rel}: {x}" for x in pr.remote]
        text = p.read_text(encoding="utf-8")
        for m in re.finditer(r"url\(\s*['\"]?(?:https?:)?//|@import\s", text):
            errs.append(f"{rel}: {text[m.start():m.start() + 40]!r}")
    rep.check("loads: the hub, the guides index, the map, privacy, support and the Zero Trust guide load nothing from another origin", errs,
              f"{len(NO_REMOTE)} pages")

    # ---- dashes
    errs = []
    for rel in UMBRELLA_WRITTEN:
        p = ROOT / rel
        if p.is_file():
            for ln, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
                if DASH.search(line):
                    errs.append(f"{rel}:{ln}")
    rep.check("dashes: no em or en dash in any file the umbrella wrote", errs, f"{len(UMBRELLA_WRITTEN)} files")

    # ---- counts
    errs = []
    r = subprocess.run(["node", str(ROOT / "playbook" / "Validation" / "ripple_check.cjs")], capture_output=True, text=True)
    m = re.search(r"derived canon (\d+)/(\d+)/(\d+)", r.stdout)
    pc = bh.playbook_counts()
    if not m:
        errs.append("ripple_check printed no derived canon")
    elif (int(m[1]), int(m[2]), int(m[3])) != (pc["actions"], pc["resources"], pc["glossary"]):
        errs.append(f"hub {pc} != ripple_check {m.group(0)}")
    hub = (DOCS / "index.html").read_text(encoding="utf-8")
    want = bh.counts(s, d)
    errs += [f"the hub does not state {v!r}" for v in want.values() if v not in hub]
    rep.check("counts: the hub states the counts read from their sources, and the Agentic SecOps counts equal ripple_check's derived canon",
              errs, " | ".join(want.values()))

    # ---- sitemap
    sm = (DOCS / "sitemap.xml").read_text(encoding="utf-8")
    locs = re.findall(r"<loc>([^<]+)</loc>", sm)
    want_locs = [s["site"] + p for p in bh.SITEMAP_PAGES]
    errs = [] if locs == want_locs else [f"sitemap lists {locs}"]
    page_of = lambda rel: DOCS / rel if rel.endswith(".html") else DOCS / rel / "index.html"
    errs += [f"{u} has no page in docs/" for u in locs if not page_of(u[len(s["site"]):]).is_file()]
    rep.check("sitemap: docs/sitemap.xml lists the hub, the map, the guides index, the Zero Trust guide, the landing, the app, privacy and support, each a page in docs/", errs)

    # ---- sweep
    src = os.environ.get("LENSATIC_PRIVATE_SWEEP")
    if src and Path(src).is_file():
        terms = [l.strip() for l in Path(src).read_text(encoding="utf-8").splitlines() if l.strip() and not l.lstrip().startswith("#")]
        hits = 0
        for rel in UMBRELLA_WRITTEN + ["hub/site.json"]:
            p = ROOT / rel
            if p.is_file():
                t = re.sub(r"data:[a-z/+.-]+;base64,[A-Za-z0-9+/=]+", "", p.read_text(encoding="utf-8"))
                hits += sum(len(re.findall(re.escape(x), t, re.I)) for x in terms)
        rep.check("sweep: the owner's private list finds nothing in the files the umbrella wrote", [f"{hits} hit(s)"] if hits else [],
                  f"{len(terms)} terms, counts only")
    else:
        rep.lines.append("SKIP  sweep: LENSATIC_PRIVATE_SWEEP is not set to the owner's private list (it is never stored in this repository)")

    print("\n".join(rep.lines))
    if rep.failures:
        print(f"UMBRELLA RED ({len(rep.failures)} failing check{'s' if len(rep.failures) != 1 else ''})")
        return 1
    print("UMBRELLA GREEN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
