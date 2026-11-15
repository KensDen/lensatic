#!/usr/bin/env python3
"""Run the local sweep over a new framework's names before any of them reaches the repository (Lensatic 2.0, Round 2).

Round 1 found that the sweep list can match a public framework's own name only after the work was done. This runs the
same sweep, with the same terms and the same plain and rot13 forms as tools/validate.py, over files that are not in the
repository yet: a publisher's data file, a table extracted from a PDF, a draft card. It prints what the validator
prints, a term's number and the place, never a term. It reads local files only.

Usage: python3 tools/sweep_names.py <file> [<file> ...]      exit 1 if any file holds a sweep term
"""
from __future__ import annotations

import codecs
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import validate as V  # noqa: E402  (the terms, read at run time and never stored)


def main() -> int:
    terms, _ = V.load_sweep_terms()
    probes = [(t, k + 1, "") for k, t in enumerate(terms)] + [(codecs.encode(t, "rot13"), k + 1, " (rot13 form)") for k, t in enumerate(terms)]
    red = 0
    for name in sys.argv[1:]:
        p = Path(name)
        try:
            lines = p.read_text(encoding="utf-8").lower().splitlines()
        except (OSError, UnicodeDecodeError) as exc:
            print(f"FAIL  {p.name}: cannot be read as text ({type(exc).__name__})")
            red = 1
            continue
        hits: dict[str, list[int]] = {}
        for n, line in enumerate(lines, 1):
            for probe, number, form in probes:
                if probe in line:
                    hits.setdefault(f"sweep term #{number}{form}", []).append(n)
        if hits:
            red = 1
            for what, where in hits.items():
                print(f"FAIL  {p.name}: {what} on {len(where)} line(s), first at line {where[0]}")
        else:
            print(f"PASS  {p.name}: no sweep term in {len(lines)} lines")
    return red


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sys.exit(main())
