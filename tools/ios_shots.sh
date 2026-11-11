#!/usr/bin/env bash
# Screenshots of the iOS app for review (session 8, section 4.4; the redesign's screens from R3): every screen of the
# redesign, on the largest iPhone, the largest iPad and (since build 6) the 390 x 844 iPhone 17e simulator, in light and
# dark, at the default text size and at accessibility-extra-large. Files are <device>_<screen>_<appearance>_<size>.png. Needs Xcode; first builds the
# app (Debug, which opens a screen by the launch arguments AppModel documents: -LensaticDoor, -LensaticChecked,
# -LensaticTab, -LensaticExplore, -LensaticNav, -LensaticSources, -LensaticQuery, -LensaticChangesViewed) into
# .tmp/DerivedData, incrementally.
#
# The empty states (v1.1 groundwork, 9 November 2026): every run also shoots the states the screens above never reach,
# in the same four variants, on the largest iPhone and on the 390 x 844 iPhone 17e: Search before any query on a fresh
# install and with recent searches, Home with Saved empty and with two items, My Path on each of the five
# trailheads with no step checked, My Path with every step checked and with no trailhead picked, and, on a fresh install,
# Home (the first screen since build 6) and the trailhead question its Framework Maps door opens. A fresh install is a
# real one: the app is removed and installed again before the shot. Files are <device>_state-<state>_<appearance>_<size>.png.
# With --states, a run shoots the empty states only.
#
# With --store (session 9, section 5): the App Store screenshots, plain screens with no overlay, frame or caption, on
# the 6.3-inch iPhone App Store Connect requires (24 October 2026: the newest "iPhone NN Pro" from the 16 on, else the
# newest plain iPhone from the 17 on) and the largest iPad. On each device, one at a time: the status bar set to 9:41,
# a full battery, full signal and no carrier name; dark appearance, the redesign's own (R3; the light theme is R4); the
# default text size; eight screens in the store's order (Home with its three doors, My Path with its countdown, Explore's
# stack, a Framework card, its Sources sheet, Search, the Field Guide, a play read summary first). Each capture
# loses its alpha channel (tools/png_opaque.swift, which refuses a file with any pixel that is not opaque) and must then
# be, by sips, exactly Apple's size for its display (iPhone 6.3-inch 1206 x 2622, iPad 13-inch 2064 x 2752), RGB with no alpha.
# Files are <nn>_<device>_<screen>.png; ios/store/screenshots.json lists each file's order, device, display, screen, size,
# SHA-256, and the SHA-256 of its pixels below the status bar (tools/check_listing.py holds no two alike, so a screen
# taken twice fails). The images stay out of the repository.
# Usage: tools/ios_shots.sh [output folder]           (default handoffs/session8-work/shots)
#        tools/ios_shots.sh --states [output folder]  (the empty states only; default handoffs/session8-work/shots)
#        tools/ios_shots.sh --store [output folder]   (default handoffs/session9-work/store-shots)
set -euo pipefail
cd "$(dirname "$0")/.."
STORE=0
STATES_ONLY=0
if [ "${1:-}" = "--store" ]; then STORE=1; shift; fi
if [ "${1:-}" = "--states" ]; then STATES_ONLY=1; shift; fi
if [ "$STORE" = 1 ]; then OUT="${1:-handoffs/session9-work/store-shots}"; else OUT="${1:-handoffs/session8-work/shots}"; fi
DERIVED=.tmp/DerivedData
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Lensatic.app"
BUNDLE=io.github.kensden.lensatic
GROUP=group.io.github.kensden.lensatic
SCREENS="start question home path changes stack matrix functions layer ai card sources search guide chapter plays play glossary sources-list about"
STORE_SCREENS="home path stack card sources search guide play"
# the empty states: one My Path per trailhead (path-<door>), in the content's order, then the rest
DOORS="$(python3 -c 'import json; print(" ".join(d["id"] for d in json.load(open("content/stack.json"))["doors"]))')"
STATES="home-fresh question-fresh search-fresh search-recent home-saved-empty home-saved-two path-none $(for d in $DOORS; do printf 'path-%s ' "$d"; done)path-all-done"
# the 390 x 844 iPhone the empty states are also shot on
SMALL_IPHONE="iPhone 17e"
OPAQUE=.tmp/png_opaque
mkdir -p "$OUT" .tmp
export TMPDIR="$(pwd)/.tmp/"

# always build (incremental, quick when nothing changed), so the shots never show an older app
xcodebuild -project ios/Lensatic.xcodeproj -scheme Lensatic -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED" build >/dev/null
if [ "$STORE" = 1 ]; then
  xcrun swiftc -O -module-cache-path .tmp/swift-module-cache -o "$OPAQUE" tools/png_opaque.swift
  rm -f "$OUT"/*.png
fi

# the largest iPhone (newest generation, Pro Max before Plus before Pro) and the largest iPad (most inches, newest chip)
# on the newest iOS runtime, as "udid name"; iphone63 is the store's 6.3-inch iPhone (1206 x 2622): the newest
# "iPhone NN Pro" from the 16 on, else the newest plain "iPhone NN" from the 17 on
pick() {
  xcrun simctl list devices available -j | python3 -c '
import json, re, sys
kind = sys.argv[1]
devs = json.load(sys.stdin)["devices"]
prefix = "iPad" if kind == "ipad" else "iPhone"
rts = sorted((r for r in devs if ".iOS-" in r and any(d["name"].startswith(prefix) for d in devs[r])),
             key=lambda r: [int(x) for x in re.findall(r"\d+", r.split("iOS-")[1])])
cands = [d for d in devs[rts[-1]] if d["name"].startswith(prefix)]
if kind == "small":
    best = next((d for d in cands if d["name"] == sys.argv[2]), None)
    if not best:
        sys.exit(f"no {sys.argv[2]} simulator on the newest runtime")
    print(best["udid"], best["name"])
    sys.exit(0)
if kind == "iphone63":
    def gen63(n):
        m = re.fullmatch(r"iPhone (\d+)( Pro)?", n)
        return (int(m[1]) >= 16, int(m[1]), 1) if m and m[2] else (int(m[1]) >= 17, int(m[1]), 0) if m else (False, 0, 0)
    cands = [d for d in cands if gen63(d["name"])[0]]
    if not cands:
        sys.exit("no 6.3-inch iPhone simulator (iPhone 16 Pro or later, or iPhone 17 or later) on the newest runtime")
    best = max(cands, key=lambda d: gen63(d["name"]))
    print(best["udid"], best["name"])
    sys.exit(0)
def key(d):
    n = d["name"]
    if kind == "iphone":
        gen = int((re.search(r"iPhone (\d+)", n) or [0, 0])[1])
        return (gen, 3 if "Pro Max" in n else 2 if "Plus" in n else 1 if "Pro" in n else 0)
    inches = float((re.search(r"(\d+(?:\.\d+)?)-inch", n) or [0, 0])[1])
    chip = int((re.search(r"\((?:M|A)(\d+)", n) or [0, 0])[1])
    return (inches, chip)
best = max(cands, key=key)
print(best["udid"], best["name"])
' "$1" "${2:-}"
}

# open one screen: the app starts fresh on it, the department's trailhead picked with two steps done and What Changed
# cleared (the changes shot shows it from the release before), so every shot shows the same path
open_screen() {
  local udid="$1" screen="$2"
  local path=(-LensaticResetProgress -LensaticDoor dow -LensaticChecked 1,2 -LensaticChangesViewed "$RELEASE")
  xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
  case "$screen" in
    # the first screen with no trailhead (Home since build 6), and the trailhead question over it
    start) xcrun simctl launch "$udid" "$BUNDLE" -LensaticResetProgress >/dev/null ;;
    question) xcrun simctl launch "$udid" "$BUNDLE" -LensaticResetProgress -LensaticPick >/dev/null ;;
    home) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticTab home >/dev/null ;;
    path) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticTab path >/dev/null ;;
    changes) xcrun simctl launch "$udid" "$BUNDLE" -LensaticResetProgress -LensaticDoor dow -LensaticChecked 1,2 \
               -LensaticChangesViewed "$PREVIOUS" -LensaticNav changes >/dev/null ;;
    stack) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticTab explore >/dev/null ;;
    matrix|functions) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticTab explore -LensaticExplore "$screen" >/dev/null ;;
    layer) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticNav layer/l3 >/dev/null ;;
    ai) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticNav layer/l6 >/dev/null ;;
    card) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticNav entity/dod-zt-strategy >/dev/null ;;
    sources) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticNav entity/dod-zt-strategy -LensaticSources >/dev/null ;;
    search) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticTab search -LensaticQuery overlays >/dev/null ;;
    guide) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticNav guide >/dev/null ;;
    chapter) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticNav chapter/part-1 >/dev/null ;;
    plays) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticNav plays >/dev/null ;;
    play) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticNav play/containment >/dev/null ;;
    glossary) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticNav glossary-list >/dev/null ;;
    sources-list) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticNav sources >/dev/null ;;
    about) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticNav about >/dev/null ;;
    *) echo "unknown screen $screen" >&2; exit 1 ;;
  esac
}

# open one empty state, as open_screen does a screen; a fresh state removes the app and installs it again first
open_state() {
  local udid="$1" state="$2"
  local base=(-LensaticResetProgress -LensaticChangesViewed "$RELEASE")
  xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
  case "$state" in
    home-fresh|question-fresh|search-fresh)
      # the progress lives in the app group's container, which the simulator keeps through an uninstall; a device
      # removes it with the group's last app, so the fresh install empties it first
      local group
      group="$(xcrun simctl get_app_container "$udid" "$BUNDLE" "$GROUP" 2>/dev/null || true)"
      if [ -n "$group" ] && [ -d "$group" ]; then find "$group" -mindepth 1 -delete; fi
      xcrun simctl uninstall "$udid" "$BUNDLE"
      xcrun simctl install "$udid" "$APP"
      if [ "$state" = home-fresh ]; then xcrun simctl launch "$udid" "$BUNDLE" >/dev/null
      elif [ "$state" = question-fresh ]; then xcrun simctl launch "$udid" "$BUNDLE" -LensaticPick >/dev/null
      else xcrun simctl launch "$udid" "$BUNDLE" -LensaticDoor dow -LensaticChangesViewed "$RELEASE" -LensaticTab search >/dev/null; fi
      sleep 2 ;;  # a first launch takes longer
    search-recent) xcrun simctl launch "$udid" "$BUNDLE" "${base[@]}" -LensaticDoor dow -LensaticTab search \
                     -LensaticRecent "zero trust,CMMC,SP 800-207" >/dev/null ;;
    # Home scrolled to its Saved section
    home-saved-empty) xcrun simctl launch "$udid" "$BUNDLE" "${base[@]}" -LensaticDoor dow -LensaticTab home \
                        -LensaticScrollTo home-saved >/dev/null ;;
    home-saved-two) xcrun simctl launch "$udid" "$BUNDLE" "${base[@]}" -LensaticDoor dow -LensaticTab home \
                      -LensaticScrollTo home-saved -LensaticSaved entity:dod-zt-strategy,play:containment >/dev/null ;;
    # My Path before a trailhead is picked
    path-none) xcrun simctl launch "$udid" "$BUNDLE" "${base[@]}" -LensaticTab path >/dev/null ;;
    path-all-done) xcrun simctl launch "$udid" "$BUNDLE" "${base[@]}" -LensaticDoor dow -LensaticChecked "$(steps dow)" -LensaticTab path >/dev/null ;;
    path-*) xcrun simctl launch "$udid" "$BUNDLE" "${base[@]}" -LensaticDoor "${state#path-}" -LensaticTab path >/dev/null ;;
    *) echo "unknown state $state" >&2; exit 1 ;;
  esac
}

# a trailhead's step numbers, 1 to its count, as -LensaticChecked takes them
steps() {
  python3 -c 'import json, sys; d = next(x for x in json.load(open("content/stack.json"))["doors"] if x["id"] == sys.argv[1]); print(",".join(str(i + 1) for i in range(len(d["steps"]))))' "$1"
}

# the content release, from What Changed's list (content/changes.json); the changes shot clears the list at the oldest
# release the list names (R4: a real release, never "0", which the screen would print), so every later item shows as new
RELEASE="$(python3 -c 'import json; print(json.load(open("content/changes.json"))["contentVersion"])')"
PREVIOUS="$(python3 -c 'import json; print(min((i["release"] for i in json.load(open("content/changes.json"))["items"]), key=lambda v: [int(x) for x in v.split(".")]))')"

# a failed step never leaves booted a simulator this script booted; one it did not boot is never touched
BOOTED=""
trap 'if [ -n "$BOOTED" ]; then xcrun simctl shutdown "$BOOTED" >/dev/null 2>&1 || true; fi' EXIT

# the store's devices; otherwise the largest iPhone, the largest iPad (screens only) and the small iPhone (build 6: the
# screens as well as the states, so every screen is seen at 390 x 844)
if [ "$STORE" = 1 ]; then KINDS="iphone ipad"; elif [ "$STATES_ONLY" = 1 ]; then KINDS="iphone small"; else KINDS="iphone ipad small"; fi
for kind in $KINDS; do
  if [ "$STORE" = 1 ] && [ "$kind" = iphone ]; then read -r UDID NAME <<< "$(pick iphone63)"
  elif [ "$kind" = small ]; then read -r UDID NAME <<< "$(pick small "$SMALL_IPHONE")"
  else read -r UDID NAME <<< "$(pick $kind)"; fi
  [ -n "$UDID" ] || exit 1  # pick has said why on stderr
  # one device at a time: none booted and no test process left over before this one boots
  if xcrun simctl list devices booted | grep -qE "iPhone|iPad" || pgrep -x xcodebuild >/dev/null || ps -Ao args | grep -q "[s]imruntime.*testmanagerd"; then
    echo "another simulator or a test process is still running; shut it down first" >&2
    exit 1
  fi
  SLUG="$(echo "$NAME" | tr -d '()' | tr ' ' '-')"
  echo "== $NAME ($UDID)"
  xcrun simctl boot "$UDID" 2>/dev/null || true
  BOOTED="$UDID"
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  xcrun simctl install "$UDID" "$APP"
  if [ "$STORE" = 1 ]; then
    xcrun simctl status_bar "$UDID" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
      --cellularMode active --cellularBars 4 --operatorName '' --batteryState discharging --batteryLevel 100
    xcrun simctl ui "$UDID" appearance dark
    xcrun simctl ui "$UDID" content_size large
    n=0
    for screen in $STORE_SCREENS; do
      n=$((n + 1))
      open_screen "$UDID" "$screen"
      sleep 6  # the launch, a sheet's rise and the bar's settling are over well before this
      FILE="$OUT/$(printf '%02d' "$n")_${SLUG}_${screen}.png"
      xcrun simctl io "$UDID" screenshot --type=png "$FILE" >/dev/null 2>&1
      "$OPAQUE" "$FILE"
    done
  else
    xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 >/dev/null 2>&1 || true
    for appearance in light dark; do
      xcrun simctl ui "$UDID" appearance "$appearance"
      for size in default accessibility-extra-large; do
        if [ "$size" = default ]; then xcrun simctl ui "$UDID" content_size large; else xcrun simctl ui "$UDID" content_size "$size"; fi
        if [ "$STATES_ONLY" = 0 ]; then
          for screen in $SCREENS; do
            open_screen "$UDID" "$screen"
            sleep 3
            xcrun simctl io "$UDID" screenshot "$OUT/${SLUG}_${screen}_${appearance}_${size}.png" >/dev/null 2>&1
          done
        fi
        if [ "$kind" != ipad ]; then
          for state in $STATES; do
            open_state "$UDID" "$state"
            sleep 3
            xcrun simctl io "$UDID" screenshot "$OUT/${SLUG}_state-${state}_${appearance}_${size}.png" >/dev/null 2>&1
          done
        fi
      done
    done
  fi
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl ui "$UDID" appearance light
  xcrun simctl ui "$UDID" content_size large
  xcrun simctl status_bar "$UDID" clear >/dev/null 2>&1 || true
  xcrun simctl shutdown "$UDID"
  BOOTED=""
done

echo "== screenshots in $OUT"
if [ "$STORE" = 1 ]; then
  # each capture exactly its display's size, RGB, no alpha, by sips; then the list with sizes and hashes
  for f in "$OUT"/*.png; do
    props="$(sips -g pixelWidth -g pixelHeight -g space -g hasAlpha "$f" | awk 'NR > 1 {printf "%s ", $2}')"
    case "$(basename "$f")" in
      *_iPhone-*) want="1206 2622 RGB no " ;;
      *_iPad-*) want="2064 2752 RGB no " ;;
      *) want="?" ;;
    esac
    if [ "$props" != "$want" ]; then echo "WRONG $f: $props(expected $want)" >&2; exit 1; fi
    echo "$f  $props"
  done
  python3 - "$OUT" "$OPAQUE" <<'PY'
import hashlib, json, re, subprocess, sys
from pathlib import Path
out = Path(sys.argv[1])
files = sorted(out.glob("*.png"))
content = {Path(line.split("  ", 1)[1]).name: line.split("  ", 1)[0]
           for line in subprocess.run([sys.argv[2], "--content", *map(str, files)], capture_output=True, text=True, check=True).stdout.splitlines()}
displays = {"iPhone": ("iPhone 6.3-inch display", 1206, 2622), "iPad": ("iPad 13-inch display", 2064, 2752)}
shots = []
for kind in ("iPhone", "iPad"):
    for f in sorted(out.glob(f"*_{kind}-*.png")):
        order, device, screen = re.fullmatch(r"(\d\d)_([^_]+)_(.+)\.png", f.name).groups()
        display, w, h = displays[kind]
        shots.append({"order": int(order), "device": device, "display": display, "screen": screen, "file": f.name,
                      "width": w, "height": h, "sha256": hashlib.sha256(f.read_bytes()).hexdigest(), "contentSha256": content[f.name]})
doc = {"about": "The App Store screenshots, taken by tools/ios_shots.sh --store and kept out of the repository; "
                "tools/check_listing.py checks this list.", "screenshots": shots}
Path("ios/store/screenshots.json").write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"wrote ios/store/screenshots.json: {len(shots)} screenshots")
PY
else
  for f in "$OUT"/*.png; do
    printf '%s  %s x %s\n' "$f" "$(sips -g pixelWidth "$f" | awk '/pixelWidth/ {print $2}')" "$(sips -g pixelHeight "$f" | awk '/pixelHeight/ {print $2}')"
  done
fi
