#!/usr/bin/env bash
# Screenshots of the iOS app for review (session 8, section 4.4): every section, the section list, and About opened at
# Why the name, on the largest iPhone and the largest iPad simulator available, in light and dark, at the default text
# size and at accessibility-extra-large. Files are <device>_<screen>_<appearance>_<size>.png. Needs Xcode; first builds
# the app (Debug, which opens a screen by launch argument) into .tmp/DerivedData, incrementally.
#
# With --store (session 9, section 5): the App Store screenshots, plain screens with no overlay, frame or caption. On
# each device, one at a time: the status bar set to 9:41, a full battery, full signal and no carrier name; light
# appearance; the default text size; eight screens in the store's order (the start screen, the doors from the top, on
# iPad with the list hidden so the shot is not the start screen again, a door opened to its steps, the stack, the matrix,
# the AI column, Sources, About at Why the name). Each capture loses its alpha
# channel (tools/png_opaque.swift, which refuses a file with any pixel that is not opaque) and must then be, by sips,
# exactly Apple's size for its display (iPhone 6.9-inch 1320 x 2868, iPad 13-inch 2064 x 2752), RGB with no alpha.
# Files are <nn>_<device>_<screen>.png; store/screenshots.json lists each file's order, device, display, screen, size,
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
SCREENS="root doors stack matrix functions ai helper sources glossary about about-name"
STORE_SCREENS="start doors door-steps stack matrix ai sources about-name"
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
# on the newest iOS runtime, as "udid name"
pick() {
  xcrun simctl list devices available -j | python3 -c '
import json, re, sys
kind = sys.argv[1]
devs = json.load(sys.stdin)["devices"]
prefix = "iPhone" if kind == "iphone" else "iPad"
rts = sorted((r for r in devs if ".iOS-" in r and any(d["name"].startswith(prefix) for d in devs[r])),
             key=lambda r: [int(x) for x in re.findall(r"\d+", r.split("iOS-")[1])])
cands = [d for d in devs[rts[-1]] if d["name"].startswith(prefix)]
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

# open one screen: the app starts fresh on it (Debug reads -LensaticScreen, -LensaticAnchor, -LensaticPush and
# -LensaticDetailOnly)
open_screen() {
  local udid="$1" screen="$2"
  xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
  case "$screen" in
    root|start) xcrun simctl launch "$udid" "$BUNDLE" >/dev/null ;;
    about-name) xcrun simctl launch "$udid" "$BUNDLE" -LensaticScreen about -LensaticAnchor about-name >/dev/null ;;
    door-steps) xcrun simctl launch "$udid" "$BUNDLE" -LensaticScreen doors -LensaticPush lensatic:/door/federal-civilian >/dev/null ;;
    doors) if [ "$STORE" = 1 ] && [ "$kind" = ipad ]; then xcrun simctl launch "$udid" "$BUNDLE" -LensaticScreen doors -LensaticDetailOnly >/dev/null
           else xcrun simctl launch "$udid" "$BUNDLE" -LensaticScreen doors >/dev/null; fi ;;
    *) xcrun simctl launch "$udid" "$BUNDLE" -LensaticScreen "$screen" >/dev/null ;;
  esac
}

# a failed step never leaves booted a simulator this script booted; one it did not boot is never touched
BOOTED=""
trap 'if [ -n "$BOOTED" ]; then xcrun simctl shutdown "$BOOTED" >/dev/null 2>&1 || true; fi' EXIT

for kind in iphone ipad; do
  read -r UDID NAME <<< "$(pick $kind)"
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
    xcrun simctl ui "$UDID" appearance light
    xcrun simctl ui "$UDID" content_size large
    n=0
    for screen in $STORE_SCREENS; do
      n=$((n + 1))
      open_screen "$UDID" "$screen"
      sleep 6  # the launch, the scroll to a heading and the bar's settling are over well before this
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
      *_iPhone-*) want="1320 2868 RGB no " ;;
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
displays = {"iPhone": ("iPhone 6.9-inch display", 1320, 2868), "iPad": ("iPad 13-inch display", 2064, 2752)}
shots = []
for kind in ("iPhone", "iPad"):
    for f in sorted(out.glob(f"*_{kind}-*.png")):
        order, device, screen = re.fullmatch(r"(\d\d)_([^_]+)_(.+)\.png", f.name).groups()
        display, w, h = displays[kind]
        shots.append({"order": int(order), "device": device, "display": display, "screen": screen, "file": f.name,
                      "width": w, "height": h, "sha256": hashlib.sha256(f.read_bytes()).hexdigest(), "contentSha256": content[f.name]})
doc = {"about": "The App Store screenshots, taken by tools/ios_shots.sh --store and kept out of the repository; "
                "tools/check_listing.py checks this list.", "screenshots": shots}
Path("store/screenshots.json").write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"wrote store/screenshots.json: {len(shots)} screenshots")
PY
else
  for f in "$OUT"/*.png; do
    printf '%s  %s x %s\n' "$f" "$(sips -g pixelWidth "$f" | awk '/pixelWidth/ {print $2}')" "$(sips -g pixelHeight "$f" | awk '/pixelHeight/ {print $2}')"
  done
fi
