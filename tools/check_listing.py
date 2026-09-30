#!/usr/bin/env python3
"""Battery checks for the App Store listing (session 9, section 4.2).

store/app-store.json holds every field the owner pastes into App Store Connect, and nothing secret; store/app-store.md
is its copy sheet, generated from it by this tool; store/screenshots.json lists the store screenshots, which
tools/ios_shots.sh --store takes and which stay out of the repository.

The checks: every field is present and no other; the length limits (name 30, subtitle 30, promotional text 170,
keywords 100, description, review notes and what's new 4,000), counted in UTF-16 units, so the compass emoji counts
as two, the stricter count; the store name, the subtitle and the description's opening paragraph are the settled
text, and so are the tagline, the pitch and the wayfinder line in content/stack.json; the promotional text and the
description equal fresh builds from the content; the keywords are drawn from the settled candidates, separated by
commas with no space after them, share no word with the name or subtitle and each appear in the content's text, not
only inside an address; the listing
rules, checked case-insensitively on the listing's own fields only (the content legitimately says "leadership
funds"): category Reference, never Education, no training, course, lesson, certification-prep or leadership
language, no lenses framing and never "multi-lensatic", no promise words, no other app or product named, and the
maker named only in the copyright line; no emoji outside the promotional text and the description's opening
paragraph; the three addresses are the site's own pages and their files exist in docs/; the secondary category is none
and the availability is the United States only, on iPhone and iPad (the owner's decisions of 29 September 2026); the
version, the devices, the encryption answer and the privacy answer agree with the app; the README's tagline and
wayfinder lines equal the content fields;
the copy sheet equals a fresh generation; the screenshot list names eight screens per device, in the settled order, at
Apple's sizes, no two alike in their files or below their status bars; and no em dash, forbidden word or email address
in store/.
The sweep covers store/ in validate.py.

Usage: python3 tools/check_listing.py [--write]
  --write  rebuild the promotional text and the description in store/app-store.json from content/stack.json, then
           store/app-store.md from store/app-store.json
"""
from __future__ import annotations

import argparse
import json
import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import build_web as B  # noqa: E402  (the section order and the department tokens, as the page renders them)
import validate as V  # noqa: E402  (the forbidden word, the report format)

STORE = ROOT / "store"
LISTING = STORE / "app-store.json"
SHEET = STORE / "app-store.md"
SHOTS = STORE / "screenshots.json"
STACK = ROOT / "content" / "stack.json"
README = ROOT / "README.md"
DOCS = ROOT / "docs"
INFO = ROOT / "ios" / "Lensatic" / "Info.plist"
PRIVACY = ROOT / "ios" / "Lensatic" / "Resources" / "PrivacyInfo.xcprivacy"
PROJECT_YML = ROOT / "ios" / "project.yml"

# the settled wording (the owner's decisions of 27 and 28 September 2026), verbatim. Only the App Store says
# "Lensatic Cyber"; everywhere else says "Lensatic".
STORE_NAME = "Lensatic Cyber"
SUBTITLE = "A compass for cyber frameworks"
TAGLINE = "Federal cyber frameworks are thick woods. Lensatic is the compass."
PITCH = ("Federal cyber frameworks are thick woods. Lensatic is the compass: find where you stand, see which framework "
         "applies, and take a bearing on your next waypoint.")
WAYFINDER = ("Lensatic is a wayfinder, not a crosswalk. It guides you, showing which framework answers which question and how "
             "the trails converge, so you know your bearing before you step into a control catalog or navigate the cyber "
             "assurance terrain.")
COMPASS = "\U0001F9ED"
OPENING = ("The federal cyber framework landscape is thick woods: overlapping rules, shifting requirements, and a dozen "
           "trails that all look alike. Lensatic Cyber is the compass that shows where you stand and which way to head "
           f"next. {COMPASS}")
WHATS_INSIDE = "What's inside"
KEYWORD_CANDIDATES = ("zero trust", "NIST", "CSF", "800-53", "800-207", "800-171", "CMMC", "RMF", "FedRAMP", "CISA", "compliance",
                      "cybersecurity", "federal", "framework", "controls", "reference", "governance")

SITE = "https://kensden.github.io/lensatic/"
URLS = {"supportUrl": (SITE + "support.html", "support.html"), "marketingUrl": (SITE, "index.html"),
        "privacyPolicyUrl": (SITE + "privacy.html", "privacy.html")}
# the fields, in the order App Store Connect shows them to the owner, with their limits; None has no length limit
FIELDS = {"name": 30, "subtitle": 30, "promotionalText": 170, "description": 4000, "keywords": 100, "supportUrl": None,
          "marketingUrl": None, "privacyPolicyUrl": None, "copyright": None, "primaryCategory": None, "secondaryCategory": None,
          "price": None, "availability": None, "ageRating": None, "privacyNutrition": None, "exportCompliance": None,
          "reviewNotes": 4000, "version": None, "whatsNew": 4000}
# the owner's decisions of 29 September 2026: no secondary category; the United States only; iPhone and iPad at launch
PINNED = {"name": STORE_NAME, "subtitle": SUBTITLE, "copyright": "2026 Ken Connell", "primaryCategory": "Reference",
          "secondaryCategory": None, "price": "Free", "privacyNutrition": "Data Not Collected",
          "availability": {"countriesOrRegions": ["United States"], "devices": ["iPhone", "iPad"],
                           "appleSiliconMacAvailability": "cleared", "appleVisionProAvailability": "cleared"},
          "ageRating": {"contentCategories": "None", "unrestrictedWebAccess": False, "userGeneratedContent": False,
                        "messagingAndChat": False, "advertising": False, "socialMedia": False, "parentalControls": "None",
                        "ageAssurance": "None", "medicalOrWellness": "None", "rating": "4+"}}
# the review notes carry the support route (session 11, Q22)
REVIEW_SUPPORT = ("Support is through the public issues page linked from the support page, where the app goes by Lensatic, "
                  "its name outside the App Store; the app collects no data.")
# two items of What's inside carry a gloss (session 11, Q24); the department renders through its token
GLOSS = {"doors": ", one each for federal civilian agencies, {{dow.current}} components, defense contractors, and everyone else",
         "sources": ": every framework and source on the stack, with its publisher, a link to the primary, and its verification "
                    "status with its date"}
FAMILY = {"1": "iPhone", "2": "iPad"}  # TARGETED_DEVICE_FAMILY's numbers
MAKER_SURNAME = "Connell"  # the maker is named in the copyright line only
NULLABLE = ("secondaryCategory", "whatsNew")  # null: no secondary category, and not used for a first version

# the listing rules, matched case-insensitively on the listing's fields
BANNED = (
    ("education framing (the category is Reference, never Education)", r"\beducation(al)?\b"),
    ("training language", r"\btrain(s|ed|ing|ings|er|ers)?\b"),
    ("course language", r"\bcourses?\b"),
    ("lesson language", r"\blessons?\b"),
    ("certification-prep language", r"\b(certification|cert|exam)[\s\-\u2010-\u2015]*prep\w*"),
    ("leadership language", r"\bleader(s|ship)?\b"),
    ("the lenses framing", r"\blenses\b"),
    ("the phrase multi-lensatic", r"multi[\s\-\u2010-\u2015]*lensatic"),
    ("a promise word (reliable)", r"\breliab\w*"),
    ("a promise word (true north)", r"\btrue[\s\-\u2010-\u2015]*north\b"),
    ("a promise word (authoritative)", r"\bauthoritativ\w*"),
    ("a promise word (official)", r"\bofficial\w*"),
    ("a promise word (endorsed)", r"\bendors\w*"),
    ("a promise word (guaranteed)", r"\bguarant\w*"),
)
# the tools the About credits and the host: products the listing must not name (the content's solutions are added)
OTHER_PRODUCTS = ("Claude", "GitHub")
EMOJI_RE = re.compile("[\U0001F000-\U0001FAFF\u2300-\u23ff\u25fd\u25fe\u2600-\u27bf\u2b00-\u2bff\ufe0f\u200d\u20e3]")
EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}")

# the store screenshots (section 5): eight screens per device, in this order, at Apple's required sizes
STORE_SCREENS = ("start", "doors", "door-steps", "stack", "matrix", "ai", "sources", "about-name")
DISPLAYS = {"iPhone": ("iPhone 6.9-inch display", 1320, 2868), "iPad": ("iPad 13-inch display", 2064, 2752)}

# the copy sheet's headings: App Store Connect's names for the fields, and a note where the value needs one
HEADINGS = {"name": "Name", "subtitle": "Subtitle", "promotionalText": "Promotional Text", "description": "Description",
            "keywords": "Keywords", "supportUrl": "Support URL", "marketingUrl": "Marketing URL",
            "privacyPolicyUrl": "Privacy Policy URL", "copyright": "Copyright", "primaryCategory": "Primary Category",
            "secondaryCategory": "Secondary Category", "price": "Price", "availability": "Availability",
            "ageRating": "Age Rating", "privacyNutrition": "App Privacy", "exportCompliance": "Export Compliance",
            "reviewNotes": "App Review Notes", "version": "Version", "whatsNew": "What's New in This Version"}
NOTES = {"name": "The App Store name only; everywhere else the app is Lensatic.",
         "secondaryCategory": "None, by the owner's decision: leave it empty.",
         "price": "The price schedule's base price.",
         "availability": "Pricing and Availability: the United States only, by the owner's decision. In Pricing and "
                         "Availability, clear Make this app available under Apple Silicon Mac Availability and Make this app "
                         "available on Apple Vision Pro, so the store offers the app on iPhone and iPad only; each has its eight "
                         "screenshots.",
         "ageRating": "The answers to the age rating questionnaire: every content category None; no unrestricted web "
                      "access; no user-generated content; no messaging and chat, advertising or social media; parental "
                      "controls, age assurance and medical or wellness topics none; giving 4+.",
         "privacyNutrition": "The App Privacy answer: the app collects no data.",
         "exportCompliance": "The app uses no non-exempt encryption; Info.plist says so with ITSAppUsesNonExemptEncryption set to NO.",
         "whatsNew": "Not used for a first version."}


def units(s: str) -> int:
    """Length in UTF-16 code units: an emoji outside the basic plane counts as two."""
    return len(s.encode("utf-16-le")) // 2


def load(p: Path):
    return json.loads(p.read_text(encoding="utf-8"))


def resolve(d: dict, s: str) -> str:
    """Department tokens as the page renders them: dow is the abbreviation, dow.<field> the field."""
    dow = d["orgs"]["dow"]
    return B.TOKEN_RE.sub(lambda m: str(dow.get(m.group(1), "")) if m.group(1) else dow["abbr"], s)


def as_store(s: str) -> str:
    """The app's name as the store says it: "Lensatic" (capitalized, a word) becomes "Lensatic Cyber"; the compass
    ("a lensatic compass") keeps its word."""
    return re.sub(r"\bLensatic\b(?! Cyber)", STORE_NAME, s)


def build_promotional(d: dict) -> str:
    return f"{as_store(d['meta']['pitch'])} {COMPASS}"


def build_description(d: dict) -> str:
    """The settled opening; the wayfinder line; meta.description; What's inside, the section titles in the page's
    order; the offline line; the not-affiliated sentence; the first paragraph of Why the name."""
    meta, titles = d["meta"], d["ui"]["sections"]
    order = [s for s in B.SECTIONS if s != "glossary" or d.get("glossary")]
    inside = "\n".join([WHATS_INSIDE] + [f"- {resolve(d, titles[s])}{resolve(d, GLOSS.get(s, ''))}" for s in order])
    parts = [OPENING, as_store(resolve(d, meta["wayfinder"])), resolve(d, meta["description"]), inside,
             resolve(d, meta["about"]["offline"]), resolve(d, meta["about"]["notAffiliated"]),
             as_store(resolve(d, meta["about"]["nameStory"][0]))]
    return "\n\n".join(parts)


def sheet(listing: dict) -> str:
    """The copy sheet: one heading per field, the text in a code block and its length."""
    out = [f"# {listing.get('name', STORE_NAME)}: App Store Connect copy sheet", "",
           "Generated by `python3 tools/check_listing.py --write` from `store/app-store.json`, the listing's source of "
           "truth; the battery checks that this file equals a fresh generation. Each field's text is in its own block, "
           "ready to copy. Lengths are counted in UTF-16 units, the stricter count, so the compass emoji counts as two.", ""]
    for key in FIELDS:
        value = listing.get(key)
        out.append(f"## {HEADINGS[key]} (`{key}`)")
        out.append("")
        if key in NOTES:
            out += [NOTES[key], ""]
        if value is None:
            out += ["No value.", ""]
            continue
        if isinstance(value, dict):
            show = lambda v: v if isinstance(v, str) else ", ".join(v) if isinstance(v, list) and all(isinstance(x, str) for x in v) else json.dumps(v)  # noqa: E731
            text = "\n".join(f"{k}: {show(v)}" for k, v in value.items())
        else:
            text = str(value)
        out += ["```text", text, "```", ""]
        if isinstance(value, str):
            limit = FIELDS[key]
            out += [f"{units(value)} characters" + (f" (limit {limit:,})" if limit else ""), ""]
    return "\n".join(out).rstrip("\n") + "\n"


def strings(node, path: str = "$"):
    if isinstance(node, dict):
        for k, v in node.items():
            yield from strings(v, f"{path}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from strings(v, f"{path}[{i}]")
    elif isinstance(node, str):
        yield path, node


# --------------------------------------------------------------------------- the checks
def check(rep) -> None:
    try:
        d = load(STACK)
        listing = load(LISTING)
    except Exception as exc:  # noqa: BLE001
        rep.check("store/app-store.json and content/stack.json parse", [str(exc)])
        return
    meta = d["meta"]

    # every field, no other, in the settled order
    errs = [f"missing field {k}" for k in FIELDS if k not in listing] + [f"unexpected field {k}" for k in listing if k not in FIELDS]
    if not errs and list(listing) != list(FIELDS):
        errs.append(f"fields out of order: {list(listing)}")
    errs += [f"{k} is empty" for k in FIELDS if k in listing and k not in NULLABLE
             and (listing[k] is None or listing[k] in ([], {}) or (isinstance(listing[k], str) and not listing[k].strip()))]
    rep.check("store/app-store.json holds every App Store Connect field the owner pastes, in order, and no other", errs,
              f"{len(FIELDS)} fields")

    # the length limits
    errs, sizes = [], []
    for k, limit in FIELDS.items():
        v = listing.get(k)
        if limit and isinstance(v, str):
            sizes.append(f"{k} {units(v)}/{limit}")
            if units(v) > limit:
                errs.append(f"{k} is {units(v)} characters, over the limit of {limit}")
    rep.check("length limits: name 30, subtitle 30, promotional text 170, keywords 100, description, review notes and "
              "what's new 4,000 (UTF-16 units)", errs, ", ".join(sizes))

    # the settled text, in the listing and in the content
    errs = []
    for k, want in (("tagline", TAGLINE), ("pitch", PITCH), ("wayfinder", WAYFINDER)):
        if meta.get(k) != want:
            errs.append(f"meta.{k} in content/stack.json is not the settled text")
    for k in ("name", "subtitle"):
        if listing.get(k) != PINNED[k]:
            errs.append(f"{k} is {listing.get(k)!r}, not the settled {PINNED[k]!r}")
    paras = str(listing.get("description", "")).split("\n\n")
    if paras[0] != OPENING:
        errs.append("the description's opening paragraph is not the settled text")
    if len(paras) < 2 or paras[1] != as_store(WAYFINDER):
        errs.append("the description's second paragraph is not the wayfinder line with the store name")
    if listing.get("promotionalText") != f"{as_store(PITCH)} {COMPASS}":
        errs.append("the promotional text is not the pitch with the store name, a space and the compass")
    if listing.get("promotionalText") != build_promotional(d):
        errs.append("the promotional text is not a fresh build from meta.pitch; run tools/check_listing.py --write")
    if listing.get("description") != build_description(d):
        errs.append("the description is not a fresh build from content/stack.json; run tools/check_listing.py --write")
    rep.check("the settled text: the store name, the subtitle, the description's opening paragraph, and the tagline, pitch "
              "and wayfinder in content; the promotional text and the description are fresh builds from the content", errs,
              f"description {len(paras)} paragraphs")

    # the keywords
    errs = []
    kw = str(listing.get("keywords", ""))
    terms = kw.split(",")
    if ", " in kw or kw != kw.strip() or any(t != t.strip() or not t for t in terms):
        errs.append("keywords must be comma-separated with no space after a comma and no empty term")
    lowered = [t.strip().lower() for t in terms]
    errs += [f"keyword {t!r} is repeated" for t in sorted({t for t in lowered if lowered.count(t) > 1})]
    allowed = {c.lower() for c in KEYWORD_CANDIDATES}
    errs += [f"keyword {t!r} is not one of the settled candidates (no other app's or company's name)" for t in terms if t.strip().lower() not in allowed]
    stem = lambda w: w[:-1] if w.endswith("s") and len(w) > 3 else w  # noqa: E731  (frameworks and framework are one word)
    taken = {stem(w) for w in re.findall(r"[a-z0-9-]+", f"{STORE_NAME} {SUBTITLE}".lower())}
    for t in terms:
        for w in re.findall(r"[a-z0-9-]+", t.lower()):
            if stem(w) in taken:
                errs.append(f"keyword {t!r} repeats the word {w!r} from the name or subtitle")
    text = V.URL_RE.sub(" ", STACK.read_text(encoding="utf-8")).lower()  # a keyword inside an address does not count
    errs += [f"keyword {t!r} does not appear in the content's text" for t in terms
             if t.strip() and not re.search(r"(?<![a-z0-9])" + re.escape(t.strip().lower()) + r"(?![a-z0-9])", text)]
    rep.check("keywords: from the settled candidates, comma-separated with no space after a comma, no word of the name or "
              "subtitle, each found in the content's text (addresses left out)", errs, f"{len(terms)} keywords, {units(kw)} characters: {kw}")

    # the listing rules, on the listing's own fields
    errs = []
    fields = list(strings(listing))
    if listing.get("primaryCategory") != "Reference":
        errs.append(f"primaryCategory is {listing.get('primaryCategory')!r}, not Reference")
    sec = listing.get("secondaryCategory")
    if sec is not None and (not isinstance(sec, str) or sec.lower() in ("education", "reference")):
        errs.append(f"secondaryCategory is {sec!r}: a secondary category is never Education or the primary")
    for p, s in fields:
        for why, pattern in BANNED:
            for m in re.finditer(pattern, s, re.I):
                errs.append(f"{p}: {why}: {m.group(0)!r}")
    products = list(OTHER_PRODUCTS) + [x for sol in d.get("solutions", []) for x in (sol.get("name"), sol.get("shortName")) if x]
    for p, s in fields:
        if p.split(".")[-1] in URLS:
            continue  # an address names its host
        for name in products:
            if re.search(r"(?<![A-Za-z0-9])" + re.escape(name) + r"(?![A-Za-z0-9])", s, re.I):
                errs.append(f"{p}: names another product ({name})")
        if p != "$.copyright" and MAKER_SURNAME.lower() in s.lower():
            errs.append(f"{p}: names the maker, who appears only in the copyright line")
    rep.check("listing rules: category Reference, never Education; no training, course, lesson, certification-prep or "
              "leadership language; no lenses framing or multi-lensatic; no promise words; no other product named; the maker "
              "only in the copyright line (case-insensitive, listing fields only)", errs, f"{len(fields)} strings")

    # emoji: only in the promotional text and the description's opening paragraph
    errs = []
    for p, s in fields:
        if p == "$.promotionalText":
            continue
        if p == "$.description":
            s = "\n\n".join(s.split("\n\n")[1:])
        for m in EMOJI_RE.finditer(s):
            errs.append(f"{p}: emoji U+{ord(m.group(0)):04X}" + (" (the description, after its opening paragraph)" if p == "$.description" else ""))
    rep.check("no emoji outside the promotional text and the description's opening paragraph (none in the name, subtitle "
              "or keywords)", errs)

    # the addresses, the version and the app's answers
    errs = []
    avail = listing.get("availability") if isinstance(listing.get("availability"), dict) else {}
    names = lambda v: v if isinstance(v, list) and all(isinstance(x, str) for x in v) else []  # noqa: E731
    for k, (url, file) in URLS.items():
        if listing.get(k) != url:
            errs.append(f"{k} is {listing.get(k)!r}, expected {url!r}")
        if not (DOCS / file).is_file():
            errs.append(f"{k}: docs/{file} does not exist")
    for k in ("copyright", "secondaryCategory", "price", "availability", "privacyNutrition", "ageRating"):
        if listing.get(k) != PINNED[k]:
            errs.append(f"{k} is {listing.get(k)!r}, expected {PINNED[k]!r}")
    try:
        info = plistlib.loads(INFO.read_bytes())
        privacy = plistlib.loads(PRIVACY.read_bytes())
        project = PROJECT_YML.read_text(encoding="utf-8")
        m = re.search(r'^\s*MARKETING_VERSION:\s*"?([^"\s]+)"?\s*$', project, re.M)
        if listing.get("version") != (m.group(1) if m else None):
            errs.append(f"version {listing.get('version')!r} is not the app's MARKETING_VERSION ({m.group(1) if m else 'missing'})")
        # the devices the listing launches on are the devices the app builds for
        fams = re.findall(r'^\s*TARGETED_DEVICE_FAMILY:\s*"?([0-9,]+)"?\s*$', project, re.M)
        builds = [FAMILY.get(n, n) for n in fams[0].split(",")] if len(fams) == 1 else None
        devices = avail.get("devices")
        if builds is None:
            errs.append(f"ios/project.yml sets TARGETED_DEVICE_FAMILY {len(fams)} times, expected once (the app target)")
        elif devices != builds:
            errs.append(f"availability.devices {devices!r} is not what the app builds for (TARGETED_DEVICE_FAMILY {fams[0]}: {builds!r})")
        if listing.get("exportCompliance") != {"usesNonExemptEncryption": info.get("ITSAppUsesNonExemptEncryption")} \
                or info.get("ITSAppUsesNonExemptEncryption") is not False:
            errs.append("exportCompliance does not match ITSAppUsesNonExemptEncryption false in Info.plist")
        if privacy.get("NSPrivacyCollectedDataTypes") != [] or privacy.get("NSPrivacyTracking") is not False:
            errs.append("privacyNutrition says Data Not Collected, but the privacy manifest declares collection or tracking")
    except Exception as exc:  # noqa: BLE001
        errs.append(f"reading the app's settings: {exc}")
    if REVIEW_SUPPORT not in str(listing.get("reviewNotes", "")):
        errs.append("reviewNotes do not carry the support sentence")
    if listing.get("version") == "1.0" and listing.get("whatsNew") is not None:
        errs.append("whatsNew is set for a first version")
    rep.check("the support, marketing and privacy addresses are the site's own pages and exist in docs/; copyright, secondary "
              "category (none), price, availability, age rating and privacy answer as settled; version, devices, encryption "
              "and privacy agree with the app", errs,
              f"version {listing.get('version')}; {', '.join(names(avail.get('countriesOrRegions')))} only, on "
              f"{' and '.join(names(avail.get('devices')))}")

    # the README carries the tagline and the wayfinder line from content
    errs = []
    lines = README.read_text(encoding="utf-8").split("\n")
    if lines[:4] != ["# Lensatic", "", meta.get("tagline"), ""]:
        errs.append("the README does not open with its title and, on its own line under it, meta.tagline")
    if len(lines) < 5 or meta.get("wayfinder", "\0") not in lines[4]:
        errs.append("the README's opening paragraph does not carry meta.wayfinder")
    top = "\n".join(lines[:lines.index("## License")] if "## License" in lines else lines)
    if resolve(d, meta.get("about", {}).get("notAffiliated", "\0")) not in top.split("\n"):
        errs.append("the README's top section does not carry the not-affiliated line, from content, on its own line")
    rep.check("README: the tagline on its own line under the title, the wayfinder line in the opening paragraph and the "
              "not-affiliated line in the top section, from content", errs)

    # the copy sheet
    fresh = sheet(listing)
    have = SHEET.read_text(encoding="utf-8") if SHEET.is_file() else None
    rep.check("store/app-store.md equals a fresh generation from store/app-store.json",
              [] if have == fresh else ["store/app-store.md is missing" if have is None else "store/app-store.md is stale; run tools/check_listing.py --write"],
              f"{len(FIELDS)} headings")

    # the screenshot list
    errs = []
    try:
        shots = load(SHOTS)["screenshots"]
    except FileNotFoundError:
        shots, errs = [], ["store/screenshots.json is missing; run tools/ios_shots.sh --store"]
    except Exception as exc:  # noqa: BLE001
        shots, errs = [], [f"store/screenshots.json: {exc}"]
    by_device: dict[str, list[dict]] = {}
    for s in shots:
        by_device.setdefault(str(s.get("device")), []).append(s)
    kinds = sorted(dev.split("-")[0] for dev in by_device)
    if not errs and kinds != ["iPad", "iPhone"]:
        errs.append(f"devices {sorted(by_device)}: expected one iPhone and one iPad")
    for dev, items in by_device.items():
        kind = dev.split("-")[0]
        display, w, h = DISPLAYS.get(kind, ("?", 0, 0))
        if [s.get("screen") for s in items] != list(STORE_SCREENS) or [s.get("order") for s in items] != list(range(1, 9)):
            errs.append(f"{dev}: screens {[s.get('screen') for s in items]}, expected {list(STORE_SCREENS)} in order 1 to 8")
        for s in items:
            if s.get("file") != f"{s.get('order', 0):02d}_{dev}_{s.get('screen')}.png":
                errs.append(f"{dev}: file {s.get('file')!r} is not <nn>_<device>_<screen>.png")
            if (s.get("display"), s.get("width"), s.get("height")) != (display, w, h):
                errs.append(f"{s.get('file')}: {s.get('display')} {s.get('width')} x {s.get('height')}, expected {display} {w} x {h}")
            for k in ("sha256", "contentSha256"):
                if not re.fullmatch(r"[0-9a-f]{64}", str(s.get(k))):
                    errs.append(f"{s.get('file')}: no {k}")
    # two captures of one screen differ in their files, and can in a status bar icon, but not below the status bar
    for k, what in (("sha256", "file"), ("contentSha256", "content")):
        hashes = [s.get(k) for s in shots]
        errs += [f"two screenshots share the {what} SHA-256 {x[:12]}" for x in sorted({x for x in hashes if x and hashes.count(x) > 1})]
    rep.check("store/screenshots.json: eight screens per device (start, doors, a door's steps, stack, matrix, AI column, "
              "sources, About at Why the name) at Apple's sizes (iPhone 6.9-inch 1320 x 2868, iPad 13-inch 2064 x 2752), "
              "each with the SHA-256 of its file and of its pixels below the status bar, no two alike", errs, f"{len(shots)} screenshots")

    # the house rules in store/
    errs, scanned = [], 0
    for p in sorted(STORE.rglob("*")) if STORE.is_dir() else []:
        if not p.is_file() or p.name == ".DS_Store":
            continue
        scanned += 1
        text = p.read_text(encoding="utf-8", errors="replace")
        rel = p.relative_to(ROOT)
        errs += [f"{rel}:{ln}: em dash" for ln, line in enumerate(text.splitlines(), 1) if "\u2014" in line]
        errs += [f"{rel}:{ln}: the forbidden word" for ln, line in enumerate(text.splitlines(), 1) if V.FORBIDDEN_WORD in line]
        errs += [f"{rel}: an email address" for _ in EMAIL_RE.finditer(text)]
    rep.check("no em dash, forbidden word or email address in store/", sorted(set(errs)), f"{scanned} files")


def write() -> None:
    d = load(STACK)
    listing = load(LISTING)
    listing["promotionalText"] = build_promotional(d)
    listing["description"] = build_description(d)
    LISTING.write_text(json.dumps(listing, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    SHEET.write_text(sheet(listing), encoding="utf-8")
    print(f"wrote {LISTING.relative_to(ROOT)} (promotional text and description from content) and {SHEET.relative_to(ROOT)}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="rebuild the derived fields and the copy sheet")
    args = ap.parse_args()
    if args.write:
        write()
    rep = V.Report()
    check(rep)
    print("\n".join(rep.lines))
    if rep.failures:
        print(f"LISTING RED ({len(rep.failures)} failing check{'s' if len(rep.failures) != 1 else ''})")
        return 1
    print("LISTING GREEN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
