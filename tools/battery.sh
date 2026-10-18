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
# the iOS app (Session 8, section 4.5): static checks everywhere; project generation, build and tests where Xcode works.
# LENSATIC_NO_XCODE=1 runs the static checks only, for a machine where Xcode is installed but cannot run unattended (for
# example while its first-launch setup waits for an administrator); the stage then prints its SKIP line.
python3 tools/check_ios.py ${LENSATIC_NO_XCODE:+--no-xcode} || RED=1
# the App Store listing (Session 9, section 4.2): the fields and their limits, the settled wording, the listing rules,
# the copy sheet and the screenshot list
python3 tools/check_listing.py || RED=1
# Lensatic 2.0 (18 October 2026): the umbrella. tools/check_umbrella.py holds the hub, the guides index, the published copies
# of the moved sections and the field system; LENSATIC_PRIVATE_SWEEP may name the owner's private sweep list for its sweep
python3 tools/check_umbrella.py || RED=1
# the Agentic SecOps section keeps its own seven-layer battery (decision 4), run in its own tree; its browser layers need
# its dev dependencies (npm install in playbook/, see playbook/README.md) and a Chrome it can find (CHROME_PATH)
if [ -d playbook/node_modules ]; then
  if [ -z "${CHROME_PATH:-}" ]; then
    for c in "${LENSATIC_CHROME:-}" "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" "/Applications/Chromium.app/Contents/MacOS/Chromium"; do
      [ -n "$c" ] && [ -x "$c" ] && { export CHROME_PATH="$c"; break; }
    done
  fi
  PB_OUT="$(cd playbook && node Validation/battery.cjs 2>&1)"; PB_CODE=$?
  printf '%s\n' "$PB_OUT" | grep -E '\[(sync|ripple|statics|docs|embed|render|anchor) *\]|FAILURE|ALL GREEN' | sed 's/^/      /'
  if [ "$PB_CODE" = "0" ]; then echo "PASS  playbook/: the Agentic SecOps battery is ALL GREEN"; else echo "FAIL  playbook/: the Agentic SecOps battery is red"; RED=1; fi
else
  echo "FAIL  playbook/node_modules is missing: run npm install in playbook/ before the battery (see playbook/README.md)"; RED=1
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
for d in content web tools ios hub guides playbook docs critique; do
  [ -d "$d" ] && echo "PASS  $d/ present" || { echo "FAIL  $d/ missing"; RED=1; }
done
if [ "$RED" = "0" ]; then echo "== BATTERY GREEN =="; else echo "== BATTERY RED =="; fi
exit $RED
