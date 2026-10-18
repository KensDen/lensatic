#!/usr/bin/env python3
"""Keep the Lensatic chrome current in the two hand-edited Agentic SecOps pages (Lensatic 2.0).

The Agentic SecOps landing (playbook/index.html) and the app's shell (playbook/Playbook/index.html, around the generated
script payload that playbook/Validation/build.cjs writes) are hand-edited sources in the playbook tree. Each carries two
marked regions that this tool owns:
  <style id="lx-shared">...</style>       hub/lensatic.css byte for byte, before the page's own styles, so the page's
                                          own tokens win wherever a name is shared (only --accent, with equal values)
  <!-- lx-bar --> ... <!-- /lx-bar -->    the umbrella bar from hub/site.json, right after <body>
Usage: python3 tools/apply_chrome.py [--check]   (--check changes nothing and exits 1 if a region is missing or stale)
"""
from __future__ import annotations

import argparse
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


def regions(root: str) -> tuple[str, str]:
    css = bw.SHARED_CSS.read_text(encoding="utf-8").rstrip("\n")
    style = f'<style id="lx-shared">\n{css}\n</style>\n'
    bar = f"<!-- lx-bar -->\n{bw.umbrella_bar(bw.umbrella(), root, 'playbook')}\n<!-- /lx-bar -->\n"
    return style, bar


def apply(text: str, root: str) -> str:
    style, bar = regions(root)
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
            style, bar = regions(root)
            if len(STYLE_RE.findall(text)) != 1 or len(BAR_RE.findall(text)) != 1 or new != text:
                stale.append(str(page.relative_to(ROOT)))
        elif new != text:
            page.write_text(new, encoding="utf-8")
            print(f"apply_chrome: refreshed {page.relative_to(ROOT)}")
    if args.check:
        print("apply_chrome: " + ("stale or missing in " + ", ".join(stale) if stale else "both Agentic SecOps pages carry the current chrome"))
        return 1 if stale else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
