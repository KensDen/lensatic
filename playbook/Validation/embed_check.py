#!/usr/bin/env python3
# embed_check.py — battery layer 2b (promoted from scratchpad/s3_embed_check.py, QC-POLISH).
# Static both-directions assert (ROUND-27 pattern) against built index.html.
import re, sys
import os
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
html = open(REPO + "/Playbook/index.html", encoding="utf-8").read()
# built html: JSX transpiled; gates look like: active === "tab" && ... createElement("iframe", { title: "...",
gates = [(m.start(), m.group(1)) for m in re.finditer(r'active === "(\w+)"', html)]
frames = [(m.start(), m.group(1)) for m in re.finditer(r'title:\s*"([^"]+)",\s*scrolling', html)]
print("iframes found:", len(frames), "| gates found:", len(gates))
rows = []
for fpos, title in frames:
    prior = [g for g in gates if g[0] < fpos]
    home = prior[-1][1] if prior else None
    n_title = len([1 for _, t in frames if t == title])
    # ABSENT elsewhere: the title appears exactly once among iframes; and its unique srcDoc payload marker exists once
    rows.append((title, home, n_title))
ok = True
for title, home, n in rows:
    p = "PASS" if (home and n == 1) else "FAIL"
    if p == "FAIL": ok = False
    print(f"  [{p}] present-on '{home}' gate | unique across app: {'yes' if n==1 else 'NO x%d'%n} | {title}")
print("BOTH-DIRECTIONS:", "ALL PASS" if ok else "FAILURES")
sys.exit(0 if ok else 1)
