#!/usr/bin/env bash
# Lensatic battery: runs the validator and the repo-level checks. Exit 0 = green.
set -uo pipefail
cd "$(dirname "$0")/.."
# temporary files stay inside the repo (Session rules in README.md): Python and Node honor TMPDIR, and .tmp/ is gitignored
mkdir -p .tmp
export TMPDIR="$(pwd)/.tmp/"
export PYTHONDONTWRITEBYTECODE=1
echo "== Lensatic battery =="
RED=0
python3 tools/validate.py || RED=1
# the single-file wrapper: build determinism, embedded JSON hash, offline and wall checks, id skeleton (Session 3, section 5)
if [ -f web/lensatic.html ]; then
  python3 tools/check_web.py || RED=1
else
  echo "FAIL  web/lensatic.html missing; run tools/build_web.py"; RED=1
fi
# handoffs/ is local working history and must never be tracked (amendment, 9 Sep 2026)
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [ -n "$(git ls-files handoffs)" ]; then
    echo "FAIL  handoffs/ is tracked by git"; RED=1
  else
    echo "PASS  git ls-files handoffs is empty"
  fi
  if [ -n "$(git ls-files content/_sweep.txt tools/sweep.txt tools/sweep_source.json)" ]; then
    echo "FAIL  a sweep-term file is tracked by git"; RED=1
  else
    echo "PASS  no sweep-term file is tracked"
  fi
  # containment (Session rules in README.md): git status shows only repo paths, nothing stray, and the tools name no path outside the repo
  STRAY="$(git status --porcelain --untracked-files=all | grep '^??' | grep -v '^?? handoffs/' || true)"
  CHANGED="$(git status --porcelain | grep -vc '^??' || true)"
  if [ -n "$STRAY" ]; then
    echo "FAIL  containment: untracked files outside handoffs/ (stage, ignore or remove them)"; echo "$STRAY" | sed 's/^/      - /'; RED=1
  else
    echo "PASS  containment: git status lists $CHANGED changed tracked path(s), no stray untracked files outside handoffs/"
  fi
  case "$TMPDIR" in
    "$(pwd)/.tmp/") git check-ignore -q .tmp/probe && echo "PASS  containment: battery temp files go to .tmp/ inside the repo, which git ignores" || { echo "FAIL  containment: .tmp/ is not ignored"; RED=1; } ;;
    *) echo "FAIL  containment: TMPDIR is outside the repo"; RED=1 ;;
  esac
  if [ -n "$(git ls-files -s | awk '$1 == "120000"')" ]; then
    echo "FAIL  containment: a tracked symlink could point outside the repo"; RED=1
  elif grep -rqIE '/Users/|/home/|~/|/private/|/var/folders|/tmp/' --exclude=battery.sh --exclude-dir=__pycache__ tools web/src; then
    echo "FAIL  containment: a tool names a user or temp path outside the repo"; grep -rnIE '/Users/|/home/|~/|/private/|/var/folders|/tmp/' --exclude=battery.sh --exclude-dir=__pycache__ tools web/src | sed 's/^/      - /'; RED=1
  else
    echo "PASS  containment: no tracked symlinks; tools and sources name no user or temp path outside the repo (browser binaries only)"
  fi
fi
for d in web ios critique; do
  [ -d "$d" ] && echo "PASS  $d/ present" || { echo "FAIL  $d/ missing"; RED=1; }
done
if [ "$RED" = "0" ]; then echo "== BATTERY GREEN =="; else echo "== BATTERY RED =="; fi
exit $RED
