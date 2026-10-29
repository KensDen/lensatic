"""The website's own wording where it differs from the shared content (site review, 28 October 2026).

content/stack.json, hub/site.json and the guide page that rebuilds guides/zero-trust/app/guide.json ship inside build
1.0 (4) of the app, which is in App Review, so they stay byte for byte as they are. The site review's wording changes
for text that lives in those files are applied here, at render time, by tools/build_web.py and tools/build_hub.py, and
the site checks read the same copies. The embedded content on the map stays content/stack.json byte for byte.

Move each change into its content file in the first content release after build 1.0 (4) clears review, then delete it
here; the app and the site then read the same words again. Owner's ruling, 28 October 2026: overrides for all."""
from __future__ import annotations

import copy

# the trailheads by the app's names and in its order (item 1): each door's shortTitle, the order of the app's welcome
# screen (ios/Lensatic/Views/Screens/WelcomeView.swift, Door.ID.welcomeOrder)
DOOR_ORDER = ["dow", "federal-civilian", "defense-contractor", "state-local", "industry-academia"]

# ui.labels and ui.nav of content/stack.json: Title Case on buttons (item 12), the map's section bar (item 7)
LABELS = {
    "heroPrimary": "Find Your Trailhead",
    "heroSecondary": "See the Stack",
    "expandAll": "Expand All",
    "collapseAll": "Collapse All",
    "backToTop": "Back to Top",
    "pillarViewDow": "{{dow}} Model: 7 Pillars",
    "pillarViewCisa": "CISA Model: 5 Pillars Plus 3 Cross-Cutting",
}
NAV = {"about": "About Maps"}

# the plain pages' tab titles (item 16d); each page's heading stays the content's
PAGE_TITLES = {"privacy": "Lensatic · Privacy Policy", "support": "Lensatic · Support"}

# glossary spell-outs in lowercase where the expansion is not a proper name, a product or a document title (item 16a)
GLOSSARY = {
    "IL": "impact level",
    "PMO": "program management office",
    "CIO": "chief information officer",
    "URL": "uniform resource locator",
    "SOAR": "security orchestration, automation and response",
    "SIEM": "security information and event management",
    "PDP": "policy decision point",
    "PAM": "privileged access management",
    "DLP": "data loss prevention",
    "SDN": "software-defined networking",
    "EDR": "endpoint detection and response",
    "XDR": "extended detection and response",
    "MFA": "multi-factor authentication",
    "UEM": "unified endpoint management",
    "MDM": "mobile device management",
    "ICAM": "identity, credential and access management",
    "IR": "incident response",
}

# hub/site.json: the hub's hero caption (items 8 and 10), Title Case on buttons (item 12), the PDF labels (item 14)
HERO_STORY = ["My lensatic compass, oriented to map north."]
SITE_LABELS = {
    "pdfStudyGuide": "Study Guide (PDF)",
    "pdfDoW": "Quick Reference: DoW (PDF)",
    "pdfFederalCivilian": "Quick Reference: Federal Civilian (PDF)",
    "pdfPrivateSector": "Quick Reference: Private Sector (PDF)",
}
GUIDE_OPEN = {"zero-trust": "Open the Zero Trust Guide"}
NOT_FOUND_BACK = "Open the Lensatic Hub"


def content(d: dict) -> dict:
    """A copy of content/stack.json as the website renders it."""
    d = copy.deepcopy(d)
    rank = {k: i for i, k in enumerate(DOOR_ORDER)}
    d["doors"].sort(key=lambda x: rank.get(x["id"], len(rank)))
    for door in d["doors"]:
        door["title"] = door.get("shortTitle") or door["title"]
    d["ui"]["labels"].update(LABELS)
    d["ui"]["nav"].update(NAV)
    for e in d["glossary"]:
        if e["term"] in GLOSSARY:
            e["expansion"] = GLOSSARY[e["term"]]
    return d


def site(s: dict) -> dict:
    """A copy of hub/site.json as the website renders it."""
    s = copy.deepcopy(s)
    s["heroStory"] = list(HERO_STORY)
    s["labels"].update(SITE_LABELS)
    for g in s["guides"]:
        if g["key"] in GUIDE_OPEN:
            g["open"] = GUIDE_OPEN[g["key"]]
    s["notFound"]["back"] = NOT_FOUND_BACK
    return s
