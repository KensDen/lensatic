#!/usr/bin/env bash
# Screenshots of the iOS app for review (session 8, section 4.4): every section, the section list, and About opened at
# Why the name, on the largest iPhone and the largest iPad simulator available, in light and dark, at the default text
# size and at accessibility-extra-large. Files are <device>_<screen>_<appearance>_<size>.png. Needs Xcode; builds the
# app (Debug, which opens a screen by launch argument) into .tmp/DerivedData if it is not built yet. Session 9 reuses
# this for the App Store sizes.
# Usage: tools/ios_shots.sh [output folder]   (default handoffs/session8-work/shots)
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-handoffs/session8-work/shots}"
DERIVED=.tmp/DerivedData
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Lensatic.app"
BUNDLE=io.github.kensden.lensatic
SCREENS="root doors stack matrix functions ai helper sources glossary about about-name"
mkdir -p "$OUT" .tmp
export TMPDIR="$(pwd)/.tmp/"

# always build (incremental, quick when nothing changed), so the shots never show an older app
xcodebuild -project ios/Lensatic.xcodeproj -scheme Lensatic -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED" build >/dev/null

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
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  xcrun simctl install "$UDID" "$APP"
  xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 >/dev/null 2>&1 || true
  for appearance in light dark; do
    xcrun simctl ui "$UDID" appearance "$appearance"
    for size in default accessibility-extra-large; do
      if [ "$size" = default ]; then xcrun simctl ui "$UDID" content_size large; else xcrun simctl ui "$UDID" content_size "$size"; fi
      for screen in $SCREENS; do
        xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
        case "$screen" in
          root) xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null ;;
          about-name) xcrun simctl launch "$UDID" "$BUNDLE" -LensaticScreen about -LensaticAnchor about-name >/dev/null ;;
          *) xcrun simctl launch "$UDID" "$BUNDLE" -LensaticScreen "$screen" >/dev/null ;;
        esac
        sleep 3
        xcrun simctl io "$UDID" screenshot "$OUT/${SLUG}_${screen}_${appearance}_${size}.png" >/dev/null 2>&1
      done
    done
  done
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl ui "$UDID" appearance light
  xcrun simctl ui "$UDID" content_size large
  xcrun simctl status_bar "$UDID" clear >/dev/null 2>&1 || true
  xcrun simctl shutdown "$UDID"
done

echo "== screenshots in $OUT"
for f in "$OUT"/*.png; do
  printf '%s  %s x %s\n' "$f" "$(sips -g pixelWidth "$f" | awk '/pixelWidth/ {print $2}')" "$(sips -g pixelHeight "$f" | awk '/pixelHeight/ {print $2}')"
done
