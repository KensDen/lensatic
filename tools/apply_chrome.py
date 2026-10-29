#!/usr/bin/env python3
"""Keep the Lensatic chrome current in the two hand-edited Agentic SecOps pages (Lensatic 2.0).

The Agentic SecOps landing (playbook/index.html) and the app's shell (playbook/Playbook/index.html, around the generated
script payload that playbook/Validation/build.cjs writes) are hand-edited sources in the playbook tree. Each carries two
marked regions that this tool owns:
  <style id="lx-shared">...</style>       hub/lensatic.css byte for byte, before the page's own styles, so the page's
                                          own tokens win wherever a name is shared (only --accent, with equal values)
  <!-- lx-bar --> ... <!-- /lx-bar -->    the umbrella bar from hub/site.json, right after <body>, with its theme toggle
  <!-- lx-theme --> ... <!-- /lx-theme -->  the shared theme script (hub/theme-head.js, Lensatic 2.0.2), before the page's
                                          first stylesheet, so the saved choice applies before first paint
and, in the landing and in the Zero Trust guide's page, the footer every Lensatic page shares (site review, 28 October
2026; build_web.site_footer: the version line, the policy, support and source links, the rights line and the fonts line):
  <!-- lx-foot --> ... <!-- /lx-foot -->
Usage: python3 tools/apply_chrome.py [--check]   (--check changes nothing and exits 1 if a region is missing or stale)
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import build_web as bw  # noqa: E402

# page, the bar's root (the way back up to /lensatic/), the active section
PAGES = ((ROOT / "playbook" / "index.html", "../"), (ROOT / "playbook" / "Playbook" / "index.html", "../../"))
STYLE_RE = re.compile(r'<style id="lx-shared">\n.*?\n</style>\n', re.S)
BAR_RE = re.compile(r"<!-- lx-bar -->\n.*?\n<!-- /lx-bar -->\n", re.S)
THEME_RE = re.compile(r"<!-- lx-theme -->\n.*?\n<!-- /lx-theme -->\n", re.S)
# the shared footer (site review, 28 October 2026): page, the way back up to /lensatic/, the section's own notice
FOOT_RE = re.compile(r"<!-- lx-foot -->\n.*?\n<!-- /lx-foot -->\n", re.S)
FOOT_PAGES = ((ROOT / "playbook" / "index.html", "../", "playbook/LICENSE"),
              (ROOT / "guides" / "zero-trust" / "index.html", "../../", "guides/zero-trust/LICENSE"))


def foot(root: str, notice: str) -> str:
    s = bw.umbrella()
    labels = bw.web_text.content(json.loads(bw.STACK.read_text(encoding="utf-8")))["ui"]["labels"]
    licence = s["repo"] + "/blob/main/" + notice
    return f"<!-- lx-foot -->\n{bw.site_footer(s, labels, root, licence)}\n<!-- /lx-foot -->\n"


def regions(root: str) -> tuple[str, str, str]:
    css = bw.SHARED_CSS.read_text(encoding="utf-8").rstrip("\n")
    style = f'<style id="lx-shared">\n{css}\n</style>\n'
    bar = f"<!-- lx-bar -->\n{bw.umbrella_bar(bw.umbrella(), root, 'playbook')}\n<!-- /lx-bar -->\n"
    theme = f"<!-- lx-theme -->\n{bw.theme_head()}\n<!-- /lx-theme -->\n"
    return style, bar, theme


def apply(text: str, root: str) -> str:
    style, bar, theme = regions(root)
    if THEME_RE.search(text):
        text = THEME_RE.sub(lambda m: theme, text, count=1)
    else:
        i = text.index("<style")   # before the page's first stylesheet
        text = text[:i] + theme + text[i:]
    if STYLE_RE.search(text):
        text = STYLE_RE.sub(lambda m: style, text, count=1)
    else:
        i = text.index("<style")   # before the page's first stylesheet
        text = text[:i] + style + text[i:]
    if BAR_RE.search(text):
        text = BAR_RE.sub(lambda m: bar, text, count=1)
    else:
        m = re.search(r"<body[^>]*>\n", text)
        text = text[:m.end()] + bar + text[m.end():]
    return text


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    stale = []
    for page, root in PAGES:
        text = page.read_text(encoding="utf-8")
        new = apply(text, root)
        if args.check:
            if len(STYLE_RE.findall(text)) != 1 or len(BAR_RE.findall(text)) != 1 or len(THEME_RE.findall(text)) != 1 or new != text:
                stale.append(str(page.relative_to(ROOT)))
        elif new != text:
            page.write_text(new, encoding="utf-8")
            print(f"apply_chrome: refreshed {page.relative_to(ROOT)}")
    for page, root, notice in FOOT_PAGES:
        text = page.read_text(encoding="utf-8")
        new = FOOT_RE.sub(lambda m: foot(root, notice), text, count=1)
        if args.check:
            if len(FOOT_RE.findall(text)) != 1 or new != text:
                stale.append(f"{page.relative_to(ROOT)} (footer)")
        elif new != text:
            page.write_text(new, encoding="utf-8")
            print(f"apply_chrome: refreshed the footer in {page.relative_to(ROOT)}")
    if args.check:
        print("apply_chrome: " + ("stale or missing in " + ", ".join(stale) if stale else "both Agentic SecOps pages carry the current chrome, and both footers are current"))
        return 1 if stale else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
