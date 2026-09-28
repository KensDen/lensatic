#!/usr/bin/env python3
"""Write the iOS app's colour sets from the web's theme tokens (session 8, section 2.7).

Reads the token blocks at the top of web/src/styles.css, the same blocks the pages build copies: the paper theme
(:root) gives each colour's light value and the dial theme (:root[data-theme="dark"]) its dark value. A token that is
not six-digit hex in both (the translucent --fade, --shadow, and the sizes and type stacks) is skipped. One .colorset
per token, named after it, under ios/Lensatic/Resources/Assets.xcassets/Colors/, sRGB; any other colour set there is
removed. Deterministic: the output depends only on styles.css, so the battery regenerates into .tmp/ and diffs.

Usage: python3 tools/gen_ios_colors.py [--out DIR]
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STYLES = ROOT / "web" / "src" / "styles.css"
OUT = ROOT / "ios" / "Lensatic" / "Resources" / "Assets.xcassets" / "Colors"
HEX = re.compile(r"#([0-9A-Fa-f]{6})")
INFO = {"author": "xcode", "version": 1}


def block(css: str, selector: str) -> dict[str, str]:
    """The custom properties declared in the first rule whose selector is exactly this one."""
    i = css.find(selector + " {")
    if i < 0:
        sys.exit(f"styles.css: no {selector} block")
    body = css[i:css.index("}", i)]
    return dict(re.findall(r"--([a-z0-9-]+):\s*([^;]+);", body))


def component(hex6: str, k: int) -> str:
    return f"0x{hex6[k:k + 2].upper()}"


def colour(hex6: str) -> dict:
    return {"color-space": "srgb", "components": {"alpha": "1.000", "blue": component(hex6, 4), "green": component(hex6, 2),
                                                  "red": component(hex6, 0)}}


def dump(obj: dict) -> str:
    return json.dumps(obj, indent=2, sort_keys=True) + "\n"


def tokens() -> list[tuple[str, str, str]]:
    css = STYLES.read_text(encoding="utf-8")
    light, dark = block(css, ":root"), block(css, ':root[data-theme="dark"]')
    out = []
    for name, value in light.items():
        lm, dm = HEX.fullmatch(value.strip()), HEX.fullmatch(dark.get(name, "").strip())
        if lm and dm:
            out.append((name, lm.group(1), dm.group(1)))
    if not out:
        sys.exit("styles.css: no six-digit hex token found in both themes")
    return out


def write(out: Path) -> list[str]:
    out.mkdir(parents=True, exist_ok=True)
    made = []
    for name, light, dark in tokens():
        d = out / f"{name}.colorset"
        d.mkdir(exist_ok=True)
        (d / "Contents.json").write_text(dump({
            "colors": [{"color": colour(light), "idiom": "universal"},
                       {"appearances": [{"appearance": "luminosity", "value": "dark"}], "color": colour(dark), "idiom": "universal"}],
            "info": INFO}), encoding="utf-8")
        made.append(d.name)
    (out / "Contents.json").write_text(dump({"info": INFO}), encoding="utf-8")
    for stale in out.iterdir():
        if stale.is_dir() and stale.name not in made:
            shutil.rmtree(stale)
    return made


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(OUT), help="where to write the colour sets; defaults to the app's asset catalogue")
    args = ap.parse_args()
    made = write(Path(args.out))
    print(f"wrote {len(made)} colour sets to {args.out}: {', '.join(n.removesuffix('.colorset') for n in made)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
