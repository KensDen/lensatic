#!/usr/bin/env python3
"""Battery checks for the iOS app (session 8, section 4.5).

On every machine: the colour sets and web_texts.json equal fresh generations; nothing under ios/ names a forbidden API
(web views, networking, stored defaults or scene state, file writes, third-party modules, analytics or crash
reporting, or anything the privacy manifest would have to declare); the only outside addresses in the Swift sources
are the policy, support and source links; every font call scales with Dynamic Type; the four TrueType faces and
their OFL.txt are the pinned files and every face is registered; the app carries no copy of content/stack.json or
web/src/about-photo.jpg and references both by path; the privacy manifest and Info.plist hold exactly their values;
the icon is the pinned 1024 by 1024 PNG with no alpha; the mark is web/src/mark.svg byte for byte; no em dash, no
forbidden word and no email address in the app's text files.

Where Xcode works (xcodebuild -version succeeds): the committed project equals a fresh XcodeGen generation from
ios/project.yml, and the app builds and passes its unit and UI tests on the newest iPhone simulator. Elsewhere that
stage prints one SKIP line with the reason, so the battery still runs without Xcode.

Usage: python3 tools/check_ios.py [--no-xcode]
"""
from __future__ import annotations

import argparse
import filecmp
import hashlib
import json
import plistlib
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import validate as V  # noqa: E402  (the forbidden word, the report format)

IOS = ROOT / "ios"
APP = IOS / "Lensatic"
PROJECT_YML = IOS / "project.yml"
XCODEPROJ = IOS / "Lensatic.xcodeproj"
INFO = APP / "Info.plist"
PRIVACY = APP / "Resources" / "PrivacyInfo.xcprivacy"
ASSETS = APP / "Resources" / "Assets.xcassets"
FONTS = APP / "Resources" / "Fonts"
ICON = ASSETS / "AppIcon.appiconset" / "AppIcon-1024.png"
MARK = ASSETS / "Mark.imageset" / "mark.svg"
FIXTURE = IOS / "LensaticTests" / "Fixtures" / "web_texts.json"
TMP = ROOT / ".tmp" / "ios-check"
XCODEGEN = ROOT / ".tmp" / "xcodegen" / "bin" / "xcodegen"
BATTERY_DERIVED = ROOT / ".tmp" / "DerivedData-battery"
BUILD_TEST_TIMEOUT = 1800  # seconds: a failing test must turn the battery red, never hang it

# IBM's own four TrueType faces, byte for byte from IBM's release archives for @ibm/plex-sans 1.1.0 and @ibm/plex-mono
# 2.5.0 (session 11: nothing converted, subset or renamed; session 8's conversion is retired), and IBM's licence beside them
FONT_PINS = {
    "IBMPlexSans-Regular.ttf": "975dcda37d80f038dcd143c22e33ca2d97a0cc5a929aace1c749153b0fe1afa5",
    "IBMPlexSans-Bold.ttf": "9e6c74a889a700d707613d24548fe4ffa6bc59559a0689d2cf9e133bdcdafb2f",
    "IBMPlexMono-Regular.ttf": "7c6fbddca4b700be918f5f6183d9bd4464fa427fe435f0b480d77fe2bb8c5a43",
    "IBMPlexMono-Bold.ttf": "74e5eedcfa4596497d34e19023cabdabd3a8c852b903007a5654a59591a72ffb",
    "OFL.txt": "7e6b2818edbd8f6a01ae80641cc8f16a51080d08fb4e532be3a0b6f74adb07da",
}
# the glyph render on the dial background, its metadata chunks dropped, pixels unchanged (session 8, section 2.6)
ICON_SHA256 = "cb9930c2ccad4ecffbb42b7426536725a24a3da693477798006ba78e4a16db41"
# the only outside addresses the Swift sources may name (the privacy policy's claim; check_web.py pins the same three)
POLICY_LINKS = ("https://kensden.github.io/lensatic/privacy.html", "https://kensden.github.io/lensatic/support.html",
                "https://github.com/KensDen/lensatic")
# section 3.7, and section 2.4's promise that the privacy manifest has nothing to declare (file timestamps, disk space,
# system boot time, the active keyboards, stored defaults): each pattern is matched in code, never in comments
FORBIDDEN = {
    "a web view": r"WKWebView|SFSafariViewController",
    "networking": r"URLSession|NSURLConnection|\bimport\s+Network\b|CFNetwork|nw_connection",
    "stored defaults or scene state": r"UserDefaults|AppStorage|SceneStorage",
    "a file write (FileManager)": r"FileManager|\.write\s*\(\s*to\s*:|createFile|FileHandle",
    "analytics or crash reporting": r"MXMetricManager|MetricKit|ASIdentifierManager|ATTrackingManager|AdSupport|AppTrackingTransparency",
    "a file timestamp": r"(?i)(creation|modification|contentModification|contentAccess|attributeModification)Date|fileModificationDate|attributesOfItem|getattrlist|\bf?stat\s*\(",
    "disk space": r"(?i)volume(Available|Total)Capacity|systemFreeSize|systemSize",
    "system boot time": r"systemUptime|mach_absolute_time|kern\.boottime",
    "the active keyboards": r"activeInputModes|UITextInputMode",
}
ALLOWED_IMPORTS = {"Foundation", "SwiftUI", "UIKit", "Observation", "CryptoKit", "XCTest"}
EM_DASH_SUFFIXES = {".swift", ".yml", ".plist", ".xcprivacy", ".json"}
PRIVACY_VALUES = {"NSPrivacyTracking": False, "NSPrivacyTrackingDomains": [], "NSPrivacyCollectedDataTypes": [], "NSPrivacyAccessedAPITypes": []}
INFO_VALUES = {
    "CFBundleDisplayName": "Lensatic",
    "CFBundleShortVersionString": "$(MARKETING_VERSION)",
    "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
    "ITSAppUsesNonExemptEncryption": False,
    "UILaunchScreen": {},
    "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft",
                                         "UIInterfaceOrientationLandscapeRight"],
    "UISupportedInterfaceOrientations~ipad": ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
                                              "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"],
    "UIAppFonts": [n for n in FONT_PINS if n.endswith(".ttf")],
}
PROJECT_SETTINGS = {"PRODUCT_BUNDLE_IDENTIFIER": "io.github.kensden.lensatic", "MARKETING_VERSION": '"1.0"',
                    "CURRENT_PROJECT_VERSION": '"1"', "TARGETED_DEVICE_FAMILY": '"1,2"', "CODE_SIGN_STYLE": "Automatic"}


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def tracked_files(root: Path) -> list[Path]:
    return sorted(p for p in root.rglob("*") if p.is_file() and "xcuserdata" not in p.parts and p.name != ".DS_Store")


def tree_diff(a: Path, b: Path) -> list[str]:
    """Paths that differ between two trees, or exist in only one (xcuserdata and .DS_Store left out)."""
    ra = {p.relative_to(a) for p in tracked_files(a)} if a.is_dir() else set()
    rb = {p.relative_to(b) for p in tracked_files(b)} if b.is_dir() else set()
    out = [f"only in the committed tree: {p}" for p in sorted(ra - rb)] + [f"only in the fresh generation: {p}" for p in sorted(rb - ra)]
    out += [f"differs: {p}" for p in sorted(ra & rb) if not filecmp.cmp(a / p, b / p, shallow=False)]
    return out


def target_block(yml: str, name: str) -> str:
    """One target's lines under targets: in project.yml, up to the next target or top-level key."""
    m = re.search(r"^targets:[ \t]*\n(.*?)(?=^\S|\Z)", yml, re.M | re.S)
    m = re.search(rf"^  {re.escape(name)}:[ \t]*\n(.*?)(?=^  \S|\Z)", m.group(1) if m else "", re.M | re.S)
    return m.group(1) if m else ""


def swift_sources(root: Path = IOS) -> list[Path]:
    return sorted(root.rglob("*.swift"))


def strip_comments(text: str) -> str:
    """Swift source without its comments, so a comment that names an API is not a use of it. String literals are kept
    whole (a // or /* inside a string is not a comment); line breaks are kept, so offsets still map to lines."""
    out, i, n = [], 0, len(text)
    while i < n:
        if text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
        elif text.startswith("/*", i):
            depth, i = 1, i + 2
            while i < n and depth:
                if text.startswith("/*", i):
                    depth, i = depth + 1, i + 2
                elif text.startswith("*/", i):
                    depth, i = depth - 1, i + 2
                else:
                    out.append("\n" if text[i] == "\n" else "")
                    i += 1
        elif text[i] == '"' or (text[i] == "#" and re.match(r'#+"', text[i:])):
            m = re.match(r'(#*)("""|")', text[i:])
            hashes, quote = m.group(1), m.group(2)
            end = quote + hashes
            j = i + len(m.group(0))
            while j < n and not text.startswith(end, j):
                j += 2 if (text[j] == "\\" and not hashes) else 1
            j = min(n, j + len(end))
            out.append(text[i:j])
            i = j
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def call_args(text: str, start: int) -> str:
    """The argument list of the call whose opening parenthesis is at start."""
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
    return text[start:]


def png_chunks(data: bytes) -> list[tuple[bytes, bytes]]:
    out, i = [], 8
    while i < len(data):
        n = struct.unpack(">I", data[i:i + 4])[0]
        out.append((data[i + 4:i + 8], data[i + 8:i + 8 + n]))
        i += 12 + n
    return out


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


# --------------------------------------------------------------------------- the static checks
def check_static(rep) -> None:
    # generated files equal fresh generations
    shutil.rmtree(TMP, ignore_errors=True)
    TMP.mkdir(parents=True)
    gen = run([sys.executable, str(ROOT / "tools" / "gen_ios_colors.py"), "--out", str(TMP / "Colors")])
    errs = [gen.stderr.strip()[:200]] if gen.returncode else tree_diff(ASSETS / "Colors", TMP / "Colors")
    rep.check("iOS colour sets equal a fresh tools/gen_ios_colors.py run from the styles.css tokens", errs,
              f"{len(list((ASSETS / 'Colors').glob('*.colorset')))} colour sets")
    texts = run([sys.executable, str(ROOT / "tools" / "build_web.py"), "--author", "Ken Connell", "--out", str(TMP / "page.html"),
                 "--texts", str(TMP / "web_texts.json")])
    errs = [texts.stderr.strip()[:200]] if texts.returncode else ([] if filecmp.cmp(FIXTURE, TMP / "web_texts.json", shallow=False)
                                                                  else [f"{FIXTURE.relative_to(ROOT)} is stale; run: python3 tools/build_web.py --author \"Ken Connell\" "
                                                                        f"--out .tmp/page.html --texts {FIXTURE.relative_to(ROOT)}"])
    n = len(json.loads(FIXTURE.read_text(encoding="utf-8"))["texts"]) if FIXTURE.exists() else 0
    rep.check("web_texts.json equals a fresh tools/build_web.py --texts run", errs, f"{n} texts")

    # section 3.7: forbidden names, modules, outside addresses
    errs, urls = [], 0
    for p in swift_sources():
        code = strip_comments(p.read_text(encoding="utf-8"))
        rel = p.relative_to(ROOT)
        for what, pattern in FORBIDDEN.items():
            for m in re.finditer(pattern, code):
                errs.append(f"{rel}:{code.count(chr(10), 0, m.start()) + 1}: {what} ({m.group(0)})")
        for m in re.finditer(r"^\s*(?:@testable\s+)?import\s+([A-Za-z_][A-Za-z0-9_]*)", code, re.M):
            if m.group(1) not in ALLOWED_IMPORTS and m.group(1) != "Lensatic":
                errs.append(f"{rel}: imports {m.group(1)}, which is not one of Apple's frameworks the app uses")
        if p.is_relative_to(APP):  # the shipped app; the tests' sample addresses never leave the test bundle
            for m in re.finditer(r"[A-Za-z][A-Za-z0-9+.-]*://[^\s\"'\\)]*", code):
                urls += 1
                if m.group(0) not in POLICY_LINKS:
                    errs.append(f"{rel}: names the address {m.group(0)[:60]}")
    for bad in ("Package.swift", "Package.resolved", "Podfile", "Cartfile"):
        errs += [f"{p.relative_to(ROOT)}: a package manifest" for p in IOS.rglob(bad)]
    yml = PROJECT_YML.read_text(encoding="utf-8") if PROJECT_YML.exists() else ""
    if re.search(r"^\s*packages\s*:", yml, re.M):
        errs.append("ios/project.yml has a packages: entry")
    rep.check("no web view, networking, stored defaults or scene state, FileManager, package, analytics or crash reporting, "
              "and no API the privacy manifest would declare, anywhere under ios/; the app's Swift sources name no outside address "
              "but the policy, support and source links", errs, f"{len(swift_sources())} Swift files, {urls} addresses in the app")

    # section 3.8: every font scales with Dynamic Type
    errs = []
    for p in swift_sources(APP):
        code = strip_comments(p.read_text(encoding="utf-8"))
        rel = p.relative_to(ROOT)
        if re.search(r"\.system\s*\(\s*size\s*:", code):
            errs.append(f"{rel}: a fixed system font size")
        for m in re.finditer(r"(?:Font)?\.custom\s*\(", code):
            if "relativeTo:" not in call_args(code, m.end() - 1):
                errs.append(f"{rel}: Font.custom without relativeTo:")
        for m in re.finditer(r"UIFont\s*\(\s*name\s*:", code):
            if "UIFontMetrics" not in code[m.end():m.end() + 200]:
                errs.append(f"{rel}: a UIFont not scaled by UIFontMetrics")
        if re.search(r"UIFont\.(?:systemFont|boldSystemFont|monospacedSystemFont)\s*\(\s*ofSize", code):
            errs.append(f"{rel}: a fixed UIKit font size")
    rep.check("type: no fixed font size; every Font.custom call passes relativeTo:, every UIFont is scaled by UIFontMetrics", errs)

    # section 3.9: the fonts
    errs = []
    present = sorted(p.name for p in FONTS.iterdir() if p.is_file() and p.name != ".DS_Store") if FONTS.is_dir() else []
    if present != sorted(FONT_PINS):
        errs.append(f"ios/Lensatic/Resources/Fonts/ holds {present}, expected {sorted(FONT_PINS)}")
    for name, want in FONT_PINS.items():
        p = FONTS / name
        if p.exists() and sha(p) != want:
            errs.append(f"{name}: SHA-256 {sha(p)[:12]} is not the pinned {want[:12]}")
    if (FONTS / "OFL.txt").exists() and not filecmp.cmp(FONTS / "OFL.txt", ROOT / "web" / "src" / "fonts" / "OFL.txt", shallow=False):
        errs.append("ios/Lensatic/Resources/Fonts/OFL.txt is not web/src/fonts/OFL.txt byte for byte")
    info = plistlib.loads(INFO.read_bytes()) if INFO.exists() else {}
    for name in (n for n in FONT_PINS if n.endswith(".ttf")):
        if name not in info.get("UIAppFonts", []):
            errs.append(f"{name} is not registered under UIAppFonts")
        if name not in yml:
            errs.append(f"{name} is not listed in ios/project.yml")
    rep.check("fonts: the four IBM Plex TrueType faces and OFL.txt are the pinned files by SHA-256, and every face is under UIAppFonts",
              errs, f"{len(FONT_PINS)} files")

    # section 2.5 and 3.6: content and the photo by reference only
    errs = []
    refs = {ROOT / "content" / "stack.json": "../content/stack.json", ROOT / "web" / "src" / "about-photo.jpg": "../web/src/about-photo.jpg"}
    want = {sha(src): src.name for src in refs}
    for p in tracked_files(IOS):
        if p.name in {src.name for src in refs} or sha(p) in want:
            errs.append(f"{p.relative_to(ROOT)}: a copy of {want.get(sha(p), p.name)}")
    app_yml = target_block(yml, "Lensatic")
    for src, path in refs.items():
        if not re.search(r"path:\s*" + re.escape(path) + r"\s*\n\s*buildPhase:\s*resources", app_yml):
            errs.append(f"ios/project.yml does not reference {path} as a resource of the Lensatic target")
    rep.check("no copy of content/stack.json or web/src/about-photo.jpg under ios/; the app target in ios/project.yml references both "
              "by path as resources", errs)

    # sections 2.2 to 2.4: the manifest, Info.plist and the project settings
    errs = []
    privacy = plistlib.loads(PRIVACY.read_bytes()) if PRIVACY.exists() else None
    if privacy != PRIVACY_VALUES:
        errs.append(f"PrivacyInfo.xcprivacy holds {privacy}, expected {PRIVACY_VALUES}")
    for k, v in INFO_VALUES.items():
        if info.get(k) != v:
            errs.append(f"Info.plist {k} is {info.get(k)!r}, expected {v!r}")
    for k in info:
        if k.endswith("UsageDescription") or k in ("NSAppTransportSecurity", "UIRequiresFullScreen"):
            errs.append(f"Info.plist carries {k}")
    for k, v in PROJECT_SETTINGS.items():
        if not re.search(rf"^\s*{k}:\s*{re.escape(v)}\s*$", yml, re.M):
            errs.append(f"ios/project.yml does not set {k}: {v}")
    if not re.search(r'deploymentTarget:\s*\n\s*iOS:\s*"17\.0"', yml):
        errs.append("ios/project.yml does not set the deployment target to iOS 17.0")
    rep.check("PrivacyInfo.xcprivacy holds exactly the section 2.4 values; Info.plist holds the section 2.3 keys and no usage "
              "description, no transport exception, no full-screen requirement; project.yml holds the section 2.2 settings", errs,
              f"{len(info)} Info.plist keys")

    # section 2.6 and 2.8: the icon and the mark
    errs = []
    if not ICON.exists():
        errs.append("the icon is missing")
    else:
        data = ICON.read_bytes()
        chunks = png_chunks(data)
        w, h, depth, ctype = struct.unpack(">IIBB", chunks[0][1][:10])
        if (w, h) != (1024, 1024):
            errs.append(f"the icon is {w} x {h}")
        if ctype not in (0, 2) or any(t == b"tRNS" for t, _ in chunks):
            errs.append(f"the icon has an alpha channel (colour type {ctype})")
        if not any(t == b"sRGB" for t, _ in chunks):
            errs.append("the icon is not tagged sRGB")
        if sha(ICON) != ICON_SHA256:
            errs.append(f"the icon's SHA-256 {sha(ICON)[:12]} is not the pinned {ICON_SHA256[:12]}")
        contents = json.loads((ICON.parent / "Contents.json").read_text(encoding="utf-8"))
        if [(i.get("filename"), i.get("size"), i.get("platform")) for i in contents.get("images", [])] != [(ICON.name, "1024x1024", "ios")]:
            errs.append("AppIcon.appiconset does not hold exactly the one 1024 image")
    if not MARK.exists() or not filecmp.cmp(MARK, ROOT / "web" / "src" / "mark.svg", shallow=False):
        errs.append("the Mark image set is not web/src/mark.svg byte for byte")
    else:
        props = json.loads((MARK.parent / "Contents.json").read_text(encoding="utf-8")).get("properties", {})
        if props != {"preserves-vector-representation": True, "template-rendering-intent": "template"}:
            errs.append(f"the Mark image set's properties are {props}")
    rep.check("icon: the pinned 1024 x 1024 sRGB PNG with no alpha, the only image in AppIcon; the mark is web/src/mark.svg, vector, template",
              errs, ICON_SHA256[:12])

    # the house rules in the app's own text files
    errs = []
    scanned = 0
    for p in tracked_files(IOS):
        if p.suffix.lower() in V.BINARY_SUFFIXES or p.suffix == ".png":
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        scanned += 1
        rel = p.relative_to(ROOT)
        if p.suffix in EM_DASH_SUFFIXES or p.name.endswith(".pbxproj"):
            errs += [f"{rel}:{ln}: em dash" for ln, line in enumerate(text.splitlines(), 1) if "—" in line]
        if p.name != "OFL.txt":
            errs += [f"{rel}:{ln}: the forbidden word" for ln, line in enumerate(text.splitlines(), 1) if V.FORBIDDEN_WORD in line]
        for m in re.finditer(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}", text):
            errs.append(f"{rel}: an email address")
    rep.check("no em dash in the app's .swift, .yml, .plist, .xcprivacy, .json and project files; no forbidden word and no "
              "email address in any of its text files", sorted(set(errs)), f"{scanned} text files")


# --------------------------------------------------------------------------- the Xcode stage
def xcode_available() -> tuple[bool, str]:
    try:
        p = run(["xcodebuild", "-version"])
    except FileNotFoundError:
        return False, "xcodebuild is not on PATH"
    if p.returncode != 0:
        return False, (p.stderr.strip().splitlines() or ["xcodebuild -version failed"])[0][:160]
    return True, " ".join(p.stdout.split()[:2])


def newest_iphone() -> tuple[str, str] | None:
    """The newest iPhone on the newest iOS runtime: the highest model number, its standard size (the shortest name)."""
    p = run(["xcrun", "simctl", "list", "devices", "available", "-j"])
    if p.returncode:
        return None
    devices = json.loads(p.stdout)["devices"]
    runtimes = sorted((r for r in devices if ".iOS-" in r and any(d["name"].startswith("iPhone") for d in devices[r])),
                      key=lambda r: [int(x) for x in re.findall(r"\d+", r.split("iOS-")[1])])
    if not runtimes:
        return None
    phones = [d for d in devices[runtimes[-1]] if d["name"].startswith("iPhone")]
    gen = lambda d: int((re.search(r"iPhone (\d+)", d["name"]) or [0, 0])[1])
    phones.sort(key=lambda d: (-gen(d), len(d["name"]), d["name"]))
    return (phones[0]["name"], phones[0]["udid"]) if phones else None


def check_xcode(rep) -> None:
    ok, why = xcode_available()
    if not ok:
        rep.lines.append(f"SKIP  iOS Xcode stage (project generation, build and test): {why}")
        return
    # the committed project equals a fresh XcodeGen generation from project.yml, made in a copy so nothing in ios/ is rewritten
    xcodegen = shutil.which("xcodegen") or (str(XCODEGEN) if XCODEGEN.exists() else None)
    errs, version = [], ""
    if not xcodegen:
        errs.append("XcodeGen is not available: put xcodegen on PATH or unpack the release into .tmp/xcodegen/ (README, iOS app)")
    else:
        version = run([xcodegen, "--version"]).stdout.strip()
        work = TMP / "gen" / ROOT.name  # the same folder name above ios/ as the checkout
        shutil.rmtree(work.parent, ignore_errors=True)
        shutil.copytree(IOS, work / "ios", ignore=shutil.ignore_patterns("Lensatic.xcodeproj", "xcuserdata", "build", ".DS_Store"))
        for rel in ("content/stack.json", "web/src/about-photo.jpg", "tools/validate.py"):  # what project.yml references outside ios/
            (work / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / rel, work / rel)
        g = run([xcodegen, "generate", "--spec", str(work / "ios" / "project.yml"), "--quiet"])
        if g.returncode:
            errs.append(f"xcodegen failed: {(g.stderr or g.stdout).strip()[:200]}")
        else:
            errs += tree_diff(XCODEPROJ, work / "ios" / "Lensatic.xcodeproj")
            if not filecmp.cmp(INFO, work / "ios" / "Lensatic" / "Info.plist", shallow=False):
                errs.append("ios/Lensatic/Info.plist differs from a fresh generation")
    rep.check("ios/Lensatic.xcodeproj and Info.plist equal a fresh XcodeGen generation from ios/project.yml", errs, version)

    # build and test on the newest iPhone simulator, the long step
    phone = newest_iphone()
    if not phone:
        rep.check("the app builds and its unit and UI tests pass on the newest iPhone simulator", ["no iPhone simulator is available"])
        return
    name, udid = phone
    results = TMP / "battery.xcresult"
    shutil.rmtree(results, ignore_errors=True)
    shutil.rmtree(BATTERY_DERIVED, ignore_errors=True)  # a full build every run, so no warning hides in an up-to-date file
    was_booted = udid in run(["xcrun", "simctl", "list", "devices", "booted"]).stdout
    run(["xcrun", "simctl", "boot", udid])
    run(["xcrun", "simctl", "bootstatus", udid, "-b"])
    cmd = ["xcodebuild", "-project", str(XCODEPROJ), "-scheme", "Lensatic", "-destination", f"platform=iOS Simulator,id={udid}",
           "-derivedDataPath", str(BATTERY_DERIVED), "-resultBundlePath", str(results), "build", "test"]
    try:
        p = run(cmd, timeout=BUILD_TEST_TIMEOUT)
        log, code = p.stdout + p.stderr, p.returncode
    except subprocess.TimeoutExpired as exc:
        run(["pkill", "-f", "xcodebuild -project " + str(XCODEPROJ)])
        log = (exc.stdout or b"").decode("utf-8", "replace") if isinstance(exc.stdout, bytes) else (exc.stdout or "")
        code = f"timed out after {BUILD_TEST_TIMEOUT} s"
    if not was_booted:  # a simulator the battery booted is shut down again, so no test process outlives the run
        run(["xcrun", "simctl", "shutdown", udid])
    (TMP / "xcodebuild.log").write_text(log, encoding="utf-8")
    warnings = sorted({l.strip() for l in log.splitlines() if ": warning: " in l and "/ios/Lensatic/" in l})
    # each test bundle's own summary: the unit tests, then the UI tests
    bundles = re.findall(r"Test Suite '(Lensatic\w*Tests)\.xctest' (?:passed|failed) at [^\n]*\n\s*Executed (\d+) tests?, with "
                         r"(?:(\d+) tests? skipped and )?(\d+) failures?", log)
    summary = "; ".join(f"{b}: {n} tests, {f} failed" + (f", {s} skipped" if s else "") for b, n, s, f in bundles) or "no test summary"
    errs = [] if code == 0 else [f"xcodebuild: {code if isinstance(code, str) else f'exit {code}'} ({summary}); see .tmp/ios-check/xcodebuild.log"]
    errs += [f"warning in the app target: {w[:160]}" for w in warnings]
    rep.check("the app builds with no warning in the app target and its unit and UI tests pass on the newest iPhone simulator", errs,
              f"{name}: {summary}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-xcode", action="store_true", help="run the static checks only")
    args = ap.parse_args()
    rep = V.Report()
    check_static(rep)
    if args.no_xcode:
        rep.lines.append("SKIP  iOS Xcode stage (project generation, build and test): --no-xcode")
    else:
        check_xcode(rep)
    print("\n".join(rep.lines))
    if rep.failures:
        print(f"iOS RED ({len(rep.failures)} failing check{'s' if len(rep.failures) != 1 else ''})")
        return 1
    print("iOS GREEN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
