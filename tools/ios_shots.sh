#!/usr/bin/env bash
# Screenshots of the iOS app for review (session 8, section 4.4; the redesign's screens from R3): every screen of the
# redesign, on the largest iPhone and the largest iPad simulator available, in light and dark, at the default text size
# and at accessibility-extra-large. Files are <device>_<screen>_<appearance>_<size>.png. Needs Xcode; first builds the
# app (Debug, which opens a screen by the launch arguments AppModel documents: -LensaticDoor, -LensaticChecked,
# -LensaticTab, -LensaticExplore, -LensaticNav, -LensaticSources, -LensaticQuery, -LensaticChangesViewed) into
# .tmp/DerivedData, incrementally.
#
# With --store (session 9, section 5): the App Store screenshots, plain screens with no overlay, frame or caption, on
# the 6.3-inch iPhone App Store Connect requires (24 October 2026: the newest "iPhone NN Pro" from the 16 on, else the
# newest plain iPhone from the 17 on) and the largest iPad. On each device, one at a time: the status bar set to 9:41,
# a full battery, full signal and no carrier name; dark appearance, the redesign's own (R3; the light theme is R4); the
# default text size; eight screens in the store's order (the welcome screen, My Path with its countdown, Explore's stack,
# a Framework card, its Sources sheet, Search, the Library, a play read summary first). Each capture
# loses its alpha channel (tools/png_opaque.swift, which refuses a file with any pixel that is not opaque) and must then
# be, by sips, exactly Apple's size for its display (iPhone 6.3-inch 1206 x 2622, iPad 13-inch 2064 x 2752), RGB with no alpha.
# Files are <nn>_<device>_<screen>.png; ios/store/screenshots.json lists each file's order, device, display, screen, size,
# SHA-256, and the SHA-256 of its pixels below the status bar (tools/check_listing.py holds no two alike, so a screen
# taken twice fails). The images stay out of the repository.
# Usage: tools/ios_shots.sh [output folder]           (default handoffs/session8-work/shots)
#        tools/ios_shots.sh --store [output folder]   (default handoffs/session9-work/store-shots)
set -euo pipefail
cd "$(dirname "$0")/.."
STORE=0
if [ "${1:-}" = "--store" ]; then STORE=1; shift; fi
if [ "$STORE" = 1 ]; then OUT="${1:-handoffs/session9-work/store-shots}"; else OUT="${1:-handoffs/session8-work/shots}"; fi
DERIVED=.tmp/DerivedData
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Lensatic.app"
BUNDLE=io.github.kensden.lensatic
SCREENS="start path changes stack matrix functions layer ai card sources search library guide chapter plays play glossary sources-list about"
STORE_SCREENS="start path stack card sources search library play"
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
' "$1"
}

# open one screen: the app starts fresh on it, the department's trailhead picked with two steps done and What Changed
# cleared (the changes shot shows it from the release before), so every shot shows the same path
open_screen() {
  local udid="$1" screen="$2"
  local path=(-LensaticResetProgress -LensaticDoor dow -LensaticChecked 1,2 -LensaticChangesViewed "$RELEASE")
  xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
  case "$screen" in
    start) xcrun simctl launch "$udid" "$BUNDLE" -LensaticResetProgress >/dev/null ;;
    path) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" >/dev/null ;;
    changes) xcrun simctl launch "$udid" "$BUNDLE" -LensaticResetProgress -LensaticDoor dow -LensaticChecked 1,2 \
               -LensaticChangesViewed "$PREVIOUS" -LensaticNav changes >/dev/null ;;
    stack) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticTab explore >/dev/null ;;
    matrix|functions) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticTab explore -LensaticExplore "$screen" >/dev/null ;;
    layer) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticNav layer/l3 >/dev/null ;;
    ai) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticNav layer/l6 >/dev/null ;;
    card) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticNav entity/dod-zt-strategy >/dev/null ;;
    sources) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticNav entity/dod-zt-strategy -LensaticSources >/dev/null ;;
    search) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticTab search -LensaticQuery overlays >/dev/null ;;
    library) xcrun simctl launch "$udid" "$BUNDLE" "${path[@]}" -LensaticTab library >/dev/null ;;
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

# the content release, from What Changed's list (content/changes.json); the changes shot clears the list at release 0,
# so every item shows as new
RELEASE="$(python3 -c 'import json; print(json.load(open("content/changes.json"))["contentVersion"])')"
PREVIOUS=0

# a failed step never leaves booted a simulator this script booted; one it did not boot is never touched
BOOTED=""
trap 'if [ -n "$BOOTED" ]; then xcrun simctl shutdown "$BOOTED" >/dev/null 2>&1 || true; fi' EXIT

for kind in iphone ipad; do
  if [ "$STORE" = 1 ] && [ "$kind" = iphone ]; then read -r UDID NAME <<< "$(pick iphone63)"; else read -r UDID NAME <<< "$(pick $kind)"; fi
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
        for screen in $SCREENS; do
          open_screen "$UDID" "$screen"
          sleep 3
          xcrun simctl io "$UDID" screenshot "$OUT/${SLUG}_${screen}_${appearance}_${size}.png" >/dev/null 2>&1
        done
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
