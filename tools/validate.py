#!/usr/bin/env python3
"""Lensatic battery validator.

Checks content/stack.json against content/schema/stack.schema.json and against
the content rules in README.md. Standard library only; if the
optional `jsonschema` package is importable it is used for the schema step,
otherwise a small built-in validator covering the keywords the schema uses runs
instead (and refuses any keyword it does not implement, so nothing is skipped
silently). Exit status 0 means green.

Forbidden-string sweep: no sweep term is stored in this file or anywhere else
in the repository, and neither is the forbidden word. Both load at run time
from a local, gitignored source, the first one present of:
  1. content/_sweep.txt        (hand-made list)
  2. tools/sweep_source.json   (names a local document and the patterns that
                                pull the terms and the forbidden word from it)
  3. tools/sweep.txt           (hand-made list)
  4. otherwise: fail with a clear message.
In a hand-made list, a line "forbidden: <word>" gives the forbidden word and
every other word is a sweep term. The sweep files themselves are exempt from
the sweep. Each term is also checked in rot13 form so an obfuscated copy fails
the battery.
"""
from __future__ import annotations

import codecs
import hashlib
import copy
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
STACK = CONTENT / "stack.json"
SCHEMA = CONTENT / "schema" / "stack.schema.json"
README = ROOT / "README.md"
SWEEP_FILE_CONTENT = CONTENT / "_sweep.txt"
SWEEP_FILE_TOOLS = ROOT / "tools" / "sweep.txt"
SWEEP_SOURCE = ROOT / "tools" / "sweep_source.json"
SWEEP_SCOPES = ["content", "web", "ios", "critique", "docs", "README.md", "LICENSE"]
# The two license files, each pinned by its SHA-256. LICENSE is the all-rights-reserved notice for Lensatic's own code
# and text, in the words the owner ruled on 27 Sep 2026 (session 7B), with that date filled in; it is in force from
# content 0.7.0 and is authored text, so it passes every check README.md passes. web/src/fonts/OFL.txt is the SIL Open
# Font License 1.1 from the @fontsource/ibm-plex-sans and @fontsource/ibm-plex-mono 5.3.0 packages: both packages' IBM
# copyright lines, then the license text the two share, verbatim (fetched 26 Sep 2026); as a verbatim legal text it is
# exempt from the em-dash and planning-vocabulary checks and from nothing else (the sweep and the forbidden-name check
# still read it). content/LICENSE, the CC BY 4.0 legal code that governed the text before content 0.7.0, must not
# return. Changing either pinned file on purpose means updating its hash here.
LICENSE_CODE = ROOT / "LICENSE"
LICENSE_CONTENT_RETIRED = CONTENT / "LICENSE"
LICENSE_FONTS = ROOT / "web" / "src" / "fonts" / "OFL.txt"
VERBATIM_LEGAL = {LICENSE_FONTS}
LICENSE_SHA256 = {
    "LICENSE": "346fc5f6573d822a43cf801952ffe6ee848476a5d495ce402130a0b62c725c7d",
    "web/src/fonts/OFL.txt": "1ce5a37e1ccedd87fc784122101278baddf7b1cd2aa57ccb3eaee6699c471e58",
}
ALL_RIGHTS_RESERVED = "LicenseRef-Lensatic-All-Rights-Reserved"
LICENSE_SPDX = {"code": (ALL_RIGHTS_RESERVED, "LICENSE"), "content": (ALL_RIGHTS_RESERVED, "LICENSE"), "fonts": ("OFL-1.1", "web/src/fonts/OFL.txt")}
# the name and page meta.licenses gives the two all-rights-reserved entries
LICENSE_ARR_ENTRY = {"name": "All rights reserved", "url": "https://github.com/KensDen/lensatic/blob/main/LICENSE"}
# The four IBM Plex faces the page embeds (latin subset, regular and bold), from the same packages, verified against
# the registry's dist.integrity and pinned here; web/src/fonts/ holds these and OFL.txt, nothing else.
FONT_SHA256 = {
    "web/src/fonts/ibm-plex-sans-latin-400-normal.woff2": "3b646991d30055a93a4ecc499713d4347953a74a947ecab435ab72070cbdab0e",
    "web/src/fonts/ibm-plex-sans-latin-700-normal.woff2": "42e7b0c143c19df9d99fd896e76b48f846edf0902d200bc29796b34d12c33aa7",
    "web/src/fonts/ibm-plex-mono-latin-400-normal.woff2": "08949f728dc52d528e69b1667d15c89a5686a4ee9a296ff90983985f99c380f7",
    "web/src/fonts/ibm-plex-mono-latin-700-normal.woff2": "4f84d86cfd060f4ded334358ff8a4c81d4db2ed5addd568359d693f44a87765a",
}
# the maker's photo beside Why the name in About (session 7D): the owner's photo, resized with sips to 1200 px on its
# longest side at quality 30 (the highest setting under 150 KB), every metadata segment stripped; pinned by SHA-256
ABOUT_PHOTO = ROOT / "web" / "src" / "about-photo.jpg"
ABOUT_PHOTO_SHA256 = "2ebe849baba484d5d3c500a0f83740f3e6385b1afc84a6ff7268a0537b53b83c"
CRITIQUE = ROOT / "critique"
BINARY_SUFFIXES = {".png", ".jpg", ".jpeg", ".gif", ".pdf", ".ico", ".icns", ".zip", ".woff", ".woff2", ".ttf"}

FUNCTION_IDS = ["GV", "ID", "PR", "DE", "RS", "RC"]
DOOR_IDS = ["federal-civilian", "dow", "defense-contractor", "other"]
DOW_REQUIRED = ["current", "abbr", "statutory", "basis", "verifiedOn", "renderRule", "statusNote"]
STATUSES = ("verified", "authored", "unverified", "conflict")
URL_RE = re.compile(r"https?://\S+")
EM_DASH = "—"
TOKEN_RE = re.compile(r"\{\{([^{}]*)\}\}")
# The forbidden word is never written into this repository: FORBIDDEN_WORD is read at run time from the local
# sweep source, like the sweep terms (see local_sweep_source below).
PROCESS_WORDS = ["handoff"]  # planning vocabulary that must not ship in content


# --------------------------------------------------------------------------- report
class Report:
    def __init__(self) -> None:
        self.failures: list[str] = []
        self.lines: list[str] = []

    def check(self, name: str, errors: list[str], info: str | None = None) -> None:
        if errors:
            self.failures.append(name)
            self.lines.append(f"FAIL  {name}")
            for e in errors[:30]:
                self.lines.append(f"      - {e}")
            if len(errors) > 30:
                self.lines.append(f"      ... and {len(errors) - 30} more")
        else:
            self.lines.append(f"PASS  {name}" + (f"  ({info})" if info else ""))

    def info(self, text: str) -> None:
        self.lines.append(f"info  {text}")


def fail_hard(msg: str) -> None:
    print(f"FAIL  {msg}")
    print("BATTERY RED")
    sys.exit(1)


# --------------------------------------------------------------------------- mini schema validator
_ANNOTATIONS = {"$schema", "$id", "title", "description", "$defs", "examples", "default", "$comment"}
_SUPPORTED = {"$ref", "type", "enum", "const", "properties", "required", "additionalProperties", "items",
              "minItems", "maxItems", "uniqueItems", "pattern", "minLength", "maxLength", "minimum",
              "maximum", "allOf", "anyOf"}


def _resolve_ref(ref: str, root: dict):
    if not ref.startswith("#/"):
        raise ValueError(f"built-in validator supports only local $ref, got {ref}")
    node = root
    for part in ref[2:].split("/"):
        node = node[part.replace("~1", "/").replace("~0", "~")]
    return node


def _type_ok(value, t: str) -> bool:
    if t == "object":
        return isinstance(value, dict)
    if t == "array":
        return isinstance(value, list)
    if t == "string":
        return isinstance(value, str)
    if t == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if t == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if t == "boolean":
        return isinstance(value, bool)
    if t == "null":
        return value is None
    raise ValueError(f"unknown type {t}")


def _canon(value) -> str:
    return json.dumps(value, sort_keys=True)


def mini_validate(inst, schema, root: dict, path: str, errs: list[str]) -> None:
    if schema is True:
        return
    if schema is False:
        errs.append(f"{path}: schema is false")
        return
    for key in schema:
        if key not in _SUPPORTED and key not in _ANNOTATIONS:
            raise ValueError(f"schema keyword not implemented by the built-in validator: {key!r} at {path}")
    if "$ref" in schema:
        mini_validate(inst, _resolve_ref(schema["$ref"], root), root, path, errs)
    if "type" in schema:
        types = schema["type"] if isinstance(schema["type"], list) else [schema["type"]]
        if not any(_type_ok(inst, t) for t in types):
            errs.append(f"{path}: expected type {types}, got {type(inst).__name__}")
            return
    if "enum" in schema and not any(_canon(inst) == _canon(e) for e in schema["enum"]):
        errs.append(f"{path}: {inst!r} is not one of {schema['enum']}")
    if "const" in schema and _canon(inst) != _canon(schema["const"]):
        errs.append(f"{path}: expected the constant {schema['const']!r}")
    if "allOf" in schema:
        for sub in schema["allOf"]:
            mini_validate(inst, sub, root, path, errs)
    if "anyOf" in schema:
        matched = False
        for sub in schema["anyOf"]:
            sub_errs: list[str] = []
            mini_validate(inst, sub, root, path, sub_errs)
            if not sub_errs:
                matched = True
                break
        if not matched:
            errs.append(f"{path}: matches none of the anyOf branches")
    if isinstance(inst, str):
        if "pattern" in schema and not re.search(schema["pattern"], inst):
            errs.append(f"{path}: {inst!r} does not match /{schema['pattern']}/")
        if "minLength" in schema and len(inst) < schema["minLength"]:
            errs.append(f"{path}: shorter than minLength {schema['minLength']}")
        if "maxLength" in schema and len(inst) > schema["maxLength"]:
            errs.append(f"{path}: longer than maxLength {schema['maxLength']}")
    if isinstance(inst, (int, float)) and not isinstance(inst, bool):
        if "minimum" in schema and inst < schema["minimum"]:
            errs.append(f"{path}: {inst} below minimum {schema['minimum']}")
        if "maximum" in schema and inst > schema["maximum"]:
            errs.append(f"{path}: {inst} above maximum {schema['maximum']}")
    if isinstance(inst, list):
        if "minItems" in schema and len(inst) < schema["minItems"]:
            errs.append(f"{path}: {len(inst)} items, minItems {schema['minItems']}")
        if "maxItems" in schema and len(inst) > schema["maxItems"]:
            errs.append(f"{path}: {len(inst)} items, maxItems {schema['maxItems']}")
        if schema.get("uniqueItems") and len({_canon(x) for x in inst}) != len(inst):
            errs.append(f"{path}: items are not unique")
        if "items" in schema:
            for i, item in enumerate(inst):
                mini_validate(item, schema["items"], root, f"{path}[{i}]", errs)
    if isinstance(inst, dict):
        props = schema.get("properties", {})
        for req in schema.get("required", []):
            if req not in inst:
                errs.append(f"{path}: missing required property {req!r}")
        for key, value in inst.items():
            if key in props:
                mini_validate(value, props[key], root, f"{path}.{key}", errs)
            elif "additionalProperties" in schema:
                extra = schema["additionalProperties"]
                if extra is False:
                    errs.append(f"{path}: unexpected property {key!r}")
                elif isinstance(extra, dict):
                    mini_validate(value, extra, root, f"{path}.{key}", errs)


def validate_schema(data, schema) -> tuple[list[str], str]:
    try:
        import jsonschema  # type: ignore

        validator = jsonschema.Draft202012Validator(schema)
        errs = [f"{'/'.join(str(p) for p in e.absolute_path) or '$'}: {e.message}" for e in validator.iter_errors(data)]
        return errs, f"jsonschema {jsonschema.__version__}"
    except ImportError:
        errs: list[str] = []
        mini_validate(data, schema, schema, "$", errs)
        return errs, "built-in validator"


# --------------------------------------------------------------------------- helpers
def walk_strings(node, path: str = "$"):
    if isinstance(node, str):
        yield path, node
    elif isinstance(node, dict):
        for k, v in node.items():
            yield from walk_strings(v, f"{path}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk_strings(v, f"{path}[{i}]")


def walk_verifications(node, path: str = "$"):
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "verification" and isinstance(v, dict):
                yield f"{path}.{k}", v
            yield from walk_verifications(v, f"{path}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk_verifications(v, f"{path}[{i}]")


def iter_text_files(scope: Path):
    if scope.is_file():
        yield scope
        return
    if not scope.exists():
        return
    for p in sorted(scope.rglob("*")):
        if p.is_file() and p.suffix.lower() not in BINARY_SUFFIXES and "__pycache__" not in p.parts:
            yield p


def jpeg_segments(data: bytes) -> tuple[list[str], tuple[int, int]]:
    """Every marker segment of a JPEG, in file order, by name (APPn, COM, DQT, SOFn, DHT, DRI, SOS), and its width and
    height from the frame header. The walk steps over the entropy-coded data after each SOS (stuffed FF00, RSTn and fill
    bytes), so a segment after a scan is seen too, and the file must end at EOI with nothing after it. Raises
    ValueError on anything else: a truncated file, trailing bytes, a segment that runs past the end, no scan."""
    if data[:2] != b"\xff\xd8":
        raise ValueError("not a JPEG")
    names, size, i, n = [], (0, 0), 2, len(data)
    while True:
        if i + 2 > n or data[i] != 0xFF:
            raise ValueError(f"no marker at byte {i}")
        m = data[i + 1]
        if m == 0xFF:  # a fill byte before a marker
            i += 1
            continue
        if m == 0xD9:
            if i + 2 != n:
                raise ValueError(f"{n - i - 2} bytes after the end of the image")
            if "SOS" not in names:
                raise ValueError("no scan")
            return names, size
        if i + 4 > n:
            raise ValueError(f"segment header at byte {i} runs past the end")
        length = int.from_bytes(data[i + 2:i + 4], "big")
        if length < 2 or i + 2 + length > n:
            raise ValueError(f"segment at byte {i} runs past the end")
        if 0xE0 <= m <= 0xEF:
            names.append(f"APP{m - 0xE0}")
        elif m == 0xFE:
            names.append("COM")
        elif 0xC0 <= m <= 0xCF and m not in (0xC4, 0xC8, 0xCC):
            names.append(f"SOF{m - 0xC0}")
            size = (int.from_bytes(data[i + 7:i + 9], "big"), int.from_bytes(data[i + 5:i + 7], "big"))
        else:
            names.append({0xDB: "DQT", 0xC4: "DHT", 0xDD: "DRI", 0xDA: "SOS"}.get(m, hex(m)))
        i += 2 + length
        if m == 0xDA:  # entropy-coded data runs to the next marker that is not a stuffed byte or a restart marker
            while True:
                if i + 1 >= n:
                    raise ValueError("the scan runs to the end of the file with no end-of-image marker")
                if data[i] == 0xFF and data[i + 1] != 0x00 and not 0xD0 <= data[i + 1] <= 0xD7:
                    break
                i += 1


def read_text(p: Path) -> str | None:
    try:
        return p.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return None


def read_local_list(p: Path) -> tuple[list[str], str]:
    """A hand-made list: a "forbidden: <word>" line gives the forbidden word; every other word is a sweep term."""
    terms: list[str] = []
    forbidden = ""
    for line in p.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if s.lower().startswith("forbidden:"):
            forbidden = s.split(":", 1)[1].strip()
            continue
        terms += [w.lower() for w in re.split(r"[\s,;]+", s) if w and w.lower() not in terms]
    return terms, forbidden


def read_local_source(p: Path) -> tuple[list[str], str]:
    """tools/sweep_source.json names a local document and the patterns that pull the sweep terms (every capture
    group, split on commas) and the forbidden word (the first capture group) from it. An optional exclude list names
    words the owner has ruled out of the sweep (the first, 27 Sep 2026, so About can explain the name); each must be
    one of the words the patterns pull, so a typo cannot pass silently."""
    spec = json.loads(p.read_text(encoding="utf-8"))
    doc = ROOT / spec["document"]
    if not doc.is_file():
        fail_hard(f"{p.relative_to(ROOT)} names a local document that is not here; cannot load the sweep terms")
    text = doc.read_text(encoding="utf-8")
    terms: list[str] = []
    for pat in spec["terms"]:
        m = re.search(pat, text)
        if not m:
            fail_hard(f"{p.relative_to(ROOT)}: a term pattern no longer matches its document")
        for group in m.groups():
            for w in group.split(","):
                w = w.strip().lower()
                if w and w not in terms:
                    terms.append(w)
    excluded = [w.strip().lower() for w in spec.get("exclude", [])]
    if any(w not in terms for w in excluded):
        fail_hard(f"{p.relative_to(ROOT)}: an excluded word is not one of the terms its patterns pull")
    terms = [w for w in terms if w not in excluded]
    m = re.search(spec["forbidden"], text)
    if not m:
        fail_hard(f"{p.relative_to(ROOT)}: the forbidden-word pattern no longer matches its document")
    return terms, m.group(1)


def local_sweep_source() -> tuple[list[str], str, str]:
    """Every sweep term and the forbidden word come from a run-time source; none is stored in the repository."""
    for p, reader in ((SWEEP_FILE_CONTENT, read_local_list), (SWEEP_SOURCE, read_local_source), (SWEEP_FILE_TOOLS, read_local_list)):
        if p.exists():
            terms, forbidden = reader(p)
            if not terms or not forbidden:
                fail_hard(f"{p.relative_to(ROOT)} must give at least one sweep term and the forbidden word")
            return terms, forbidden, str(p.relative_to(ROOT))
    fail_hard("no sweep source found: create content/_sweep.txt or tools/sweep.txt by hand (the sweep terms and a "
              "'forbidden: <word>' line), or tools/sweep_source.json; all three are gitignored and never committed.")
    return [], "", ""  # unreachable


def load_sweep_terms() -> tuple[list[str], str]:
    terms, _, src = local_sweep_source()
    return terms, f"{src} (at run time)"


FORBIDDEN_WORD = local_sweep_source()[1]


# --------------------------------------------------------------------------- checks
def main() -> int:
    rep = Report()

    # 1. JSON parses
    try:
        data = json.loads(STACK.read_text(encoding="utf-8"))
        rep.check("stack.json parses", [], f"{STACK.stat().st_size} bytes")
    except Exception as exc:  # noqa: BLE001
        rep.check("stack.json parses", [str(exc)])
        print("\n".join(rep.lines))
        print("BATTERY RED")
        return 1

    # 2. schema
    try:
        schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
        errs, engine = validate_schema(data, schema)
        rep.check("stack.json validates against stack.schema.json", errs, engine)
    except Exception as exc:  # noqa: BLE001
        rep.check("stack.json validates against stack.schema.json", [str(exc)])

    frameworks = data.get("frameworks", [])
    sources = data.get("sources", [])
    solutions = data.get("solutions", [])
    layers = data.get("layers", [])
    functions = data.get("functions", [])
    canonical = data.get("pillars", {}).get("canonical", [])
    views = data.get("pillars", {}).get("views", {})
    cells = data.get("matrix", {}).get("cells", [])
    doors = data.get("doors", [])
    helper = data.get("helper", [])
    ai = data.get("ai", {})
    elevator = data.get("elevator", {})
    orgs = data.get("orgs", {})

    fw_ids = [f.get("id") for f in frameworks]
    src_ids = [s.get("id") for s in sources]
    sol_ids = [s.get("id") for s in solutions]
    entity_ids = set(fw_ids) | set(src_ids) | set(sol_ids)
    layer_ids = [l.get("id") for l in layers]
    fn_ids = [f.get("id") for f in functions]
    pillar_ids = [p.get("id") for p in canonical]
    category_codes = {c.get("code") for f in functions for c in f.get("categories", [])}

    # ids unique across frameworks, sources, solutions, layers and pillars
    errs = []
    seen: dict[str, str] = {}
    for kind, items in (("frameworks", frameworks), ("sources", sources), ("solutions", solutions), ("layers", layers), ("pillars", canonical)):
        for it in items:
            i = it.get("id")
            if i in seen:
                errs.append(f"id {i!r} used by both {seen[i]} and {kind}")
            seen[i] = kind
    rep.check("ids are unique across frameworks, sources, solutions, layers and pillars", errs, f"{len(seen)} ids")

    # 3. oneLiner uniqueness and no restatement
    all_strings = list(walk_strings(data))
    one_liners: list[tuple[str, str]] = []
    for coll, items in (("frameworks", frameworks), ("sources", sources), ("solutions", solutions), ("layers", layers)):
        for i, it in enumerate(items):
            if isinstance(it.get("oneLiner"), str):
                one_liners.append((f"$.{coll}[{i}].oneLiner", it["oneLiner"]))
    errs = []
    texts = [t for _, t in one_liners]
    for p, t in one_liners:
        if texts.count(t) > 1:
            errs.append(f"duplicate oneLiner at {p}: {t[:60]!r}")
    for p, t in one_liners:
        for q, s in all_strings:
            if q != p and t in s:
                errs.append(f"oneLiner from {p} restated at {q}")
    rep.check("every oneLiner is unique and appears nowhere else", errs, f"{len(one_liners)} one-liners")

    # 4. provenance and verification statuses (four statuses; each with its own rule)
    errs = []
    counts = {s: 0 for s in STATUSES}
    for coll, items in (("frameworks", frameworks), ("sources", sources), ("solutions", solutions)):
        for i, it in enumerate(items):
            for field in ("publisher", "title", "edition", "date", "url"):
                if not it.get(field):
                    errs.append(f"$.{coll}[{i}] ({it.get('id')}): missing {field}")
            status = (it.get("verification") or {}).get("status")
            if status not in STATUSES:
                errs.append(f"$.{coll}[{i}] ({it.get('id')}): verification.status {status!r} invalid")
            else:
                counts[status] += 1
            if it.get("attributionRequired") and not it.get("license"):
                errs.append(f"$.{coll}[{i}] ({it.get('id')}): attributionRequired without a license field")
    total = {s: 0 for s in STATUSES}
    for p, v in walk_verifications(data):
        s = v.get("status")
        if s not in STATUSES:
            errs.append(f"{p}: status {s!r} invalid")
            continue
        total[s] += 1
        if s == "verified" and (v.get("method") != "primary-fetch" or not v.get("verifiedOn")):
            errs.append(f"{p}: verified records must carry method primary-fetch and a verifiedOn date")
        if s == "authored":
            if v.get("method") != "synthesis" or v.get("verifiedOn") is not None:
                errs.append(f"{p}: authored records must carry method synthesis and verifiedOn null")
            if not v.get("basisIds"):
                errs.append(f"{p}: authored records must name at least one basisId")
            for b in v.get("basisIds") or []:
                if b not in entity_ids:
                    errs.append(f"{p}: basisId {b!r} does not resolve")
        if s == "unverified" and not URL_RE.search(v.get("note") or ""):
            errs.append(f"{p}: unverified records must record at least one URL tried in the note")
    fmt = lambda c: " / ".join(f"{k} {c[k]}" for k in STATUSES)
    rep.check("provenance fields present and verification statuses valid", errs, f"entries: {fmt(counts)}")
    rep.info(f"all verification objects: {fmt(total)}")

    # 5. authority
    errs = []
    for coll, items in (("frameworks", frameworks), ("sources", sources), ("solutions", solutions)):
        for i, it in enumerate(items):
            a = it.get("authority")
            if not isinstance(a, dict):
                errs.append(f"$.{coll}[{i}] ({it.get('id')}): missing authority")
                continue
            if not a.get("binds"):
                errs.append(f"$.{coll}[{i}] ({it.get('id')}): authority.binds is empty")
            d = a.get("deadline")
            if isinstance(d, dict) and d.get("sourceId") not in entity_ids:
                errs.append(f"$.{coll}[{i}] ({it.get('id')}): deadline.sourceId {d.get('sourceId')!r} does not resolve")
    rep.check("every framework, source and solution has an authority object with non-empty binds", errs)

    # 5b. solutions: implementation vehicles, measured against a model, never listed as frameworks
    errs = []
    for i, it in enumerate(solutions):
        sid = it.get("id")
        if it.get("layerId") not in layer_ids:
            errs.append(f"$.solutions[{i}] ({sid}): layerId {it.get('layerId')!r} does not resolve")
        va = it.get("validatedAgainst") or {}
        if va.get("entityId") not in set(fw_ids) | set(src_ids):
            errs.append(f"$.solutions[{i}] ({sid}): validatedAgainst.entityId {va.get('entityId')!r} is not a framework or source")
        if not it.get("adopterResponsibilities"):
            errs.append(f"$.solutions[{i}] ({sid}): adopterResponsibilities is empty")
        for l in layers:
            if sid in l.get("frameworkIds", []):
                errs.append(f"solution {sid} is listed in layer {l.get('id')}.frameworkIds")
        if (it.get("authority") or {}).get("nature") != "service":
            errs.append(f"$.solutions[{i}] ({sid}): authority.nature must be service")
    for coll, items in (("frameworks", frameworks), ("sources", sources)):
        for i, it in enumerate(items):
            a = it.get("authority") or {}
            if a.get("nature") == "service" or "adopters" in (a.get("binds") or []):
                errs.append(f"$.{coll}[{i}] ({it.get('id')}): the service nature and the adopters value belong to solutions")
    rep.check("solutions: layer resolves, validated against a framework or source, adopter responsibilities present", errs,
              f"{len(solutions)} solution{'s' if len(solutions) != 1 else ''}")

    # 6. matrix
    errs = []
    if len(cells) != 48:
        errs.append(f"{len(cells)} cells, expected 48")
    pairs: dict[tuple, int] = {}
    cap_ids = {cap.get("id") for p in canonical for cap in p.get("capabilities", [])}
    dow_pillars = set(views.get("dow", []))
    sentences: dict[str, int] = {}
    cross = 0
    for i, c in enumerate(cells):
        key = (c.get("pillarId"), c.get("functionId"))
        pairs[key] = pairs.get(key, 0) + 1
        if c.get("pillarId") not in pillar_ids:
            errs.append(f"cell[{i}]: pillarId {c.get('pillarId')!r} not canonical")
        if c.get("functionId") not in fn_ids:
            errs.append(f"cell[{i}]: functionId {c.get('functionId')!r} not a function")
        for code in c.get("categories", []):
            if code not in category_codes:
                errs.append(f"cell[{i}] ({key}): category {code!r} is not defined in functions")
        if c.get("pillarId") in dow_pillars and "capabilityIds" not in c:
            errs.append(f"cell[{i}] ({key}): DoW-view cell without capabilityIds")
        if c.get("pillarId") not in dow_pillars and c.get("capabilityIds"):
            errs.append(f"cell[{i}] ({key}): capabilityIds on a cell outside the DoW view")
        own = {cap.get("id") for p in canonical if p.get("id") == c.get("pillarId") for cap in p.get("capabilities", [])}
        for cap in c.get("capabilityIds") or []:
            if cap not in cap_ids:
                errs.append(f"cell[{i}] ({key}): capabilityId {cap!r} is not in the pillar capability lists")
            elif cap not in own:
                cross += 1
        for sent in re.split(r"(?<=[.!?])\s+", (c.get("text") or "").strip()):
            norm = re.sub(r"\W+", " ", sent.lower()).strip()
            if len(norm) < 20:
                continue
            if norm in sentences:
                errs.append(f"cell[{i}] ({key}) shares a sentence with cell[{sentences[norm]}]")
            else:
                sentences[norm] = i
    for key, n in pairs.items():
        if n > 1:
            errs.append(f"pair {key} appears {n} times")
    rep.check("matrix: exactly 48 unique (pillar, function) cells that resolve; no shared sentences; capability ids resolve", errs,
              f"{len(cap_ids)} capabilities listed, {cross} cross-pillar citations")

    # 7. pillar views
    errs = []
    dow_view = views.get("dow", [])
    cisa_p = views.get("cisa", {}).get("pillars", [])
    cisa_x = views.get("cisa", {}).get("crossCutting", [])
    if len(dow_view) != 7:
        errs.append(f"dow view has {len(dow_view)} ids, expected 7")
    if len(cisa_p) != 5 or len(cisa_x) != 3:
        errs.append(f"cisa view has {len(cisa_p)} + {len(cisa_x)} ids, expected 5 + 3")
    for v in dow_view + cisa_p + cisa_x:
        if v not in pillar_ids:
            errs.append(f"view id {v!r} is not canonical")
    if len(set(cisa_p) & set(cisa_x)):
        errs.append("cisa pillars and crossCutting overlap")
    if set(dow_view) | set(cisa_p) | set(cisa_x) != set(pillar_ids):
        errs.append("union of the two views is not the full canonical set")
    rep.check("pillar views: dow 7, cisa 5 + 3, union is all 8 canonical ids", errs)

    # 8. doors
    errs = []
    if [d.get("id") for d in doors] != DOOR_IDS:
        errs.append(f"door ids are {[d.get('id') for d in doors]}, expected {DOOR_IDS}")
    for d in doors:
        steps = d.get("steps", [])
        if len(steps) > 7:
            errs.append(f"door {d.get('id')}: {len(steps)} steps, maximum 7")
        for lnd in d.get("landings") or []:
            for e in lnd.get("entityIds", []):
                if e not in entity_ids:
                    errs.append(f"door {d.get('id')} landing {lnd.get('id')}: entityId {e!r} does not resolve")
        if [s.get("order") for s in steps] != list(range(1, len(steps) + 1)):
            errs.append(f"door {d.get('id')}: step order is not 1..n")
        for s in steps:
            if s.get("layerId") not in layer_ids:
                errs.append(f"door {d.get('id')} step {s.get('order')}: layerId {s.get('layerId')!r} does not resolve")
            for e in s.get("entityIds", []):
                if e not in entity_ids:
                    errs.append(f"door {d.get('id')} step {s.get('order')}: entityId {e!r} does not resolve")
        if d.get("id") == "other" and not d.get("paragraph"):
            errs.append("door other: paragraph is required")
    rep.check("doors: at most seven steps each, every entityId and layerId resolves", errs)

    # 9. sweep (plain and rot13 forms)
    terms, source_desc = load_sweep_terms()
    probes = [(t, t) for t in terms] + [(codecs.encode(t, "rot13"), t) for t in terms]
    exempt = {SWEEP_FILE_CONTENT.resolve(), SWEEP_FILE_TOOLS.resolve()}
    errs = []
    scanned = 0
    for scope in SWEEP_SCOPES:
        for p in iter_text_files(ROOT / scope):
            if p.resolve() in exempt:
                continue
            text = read_text(p)
            if text is None:
                rep.info(f"sweep skipped non-utf8 file {p.relative_to(ROOT)}")
                continue
            scanned += 1
            rel = p.relative_to(ROOT)
            for probe, t in probes:
                if probe in str(rel).lower():
                    errs.append(f"{rel}: file name contains sweep term #{terms.index(t) + 1}")
            for ln, line in enumerate(text.lower().splitlines(), 1):
                for probe, t in probes:
                    if probe in line:
                        errs.append(f"{rel}:{ln}: contains sweep term #{terms.index(t) + 1}" + ("" if probe == t else " (rot13 form)"))
    rep.check("sweep list clean across content/, web/, ios/, critique/, docs/, README.md, LICENSE", errs,
              f"{scanned} files, {len(terms)} terms, loaded from {source_desc}")

    # 10. em dash
    errs = []
    for p in list(iter_text_files(CONTENT)) + list(iter_text_files(CRITIQUE)) + [README, LICENSE_CODE]:
        if p in VERBATIM_LEGAL:
            continue  # verbatim legal text
        if not p.exists():
            if p != LICENSE_CODE:  # the licenses check reports a missing LICENSE
                errs.append(f"{p.relative_to(ROOT)} is missing")
            continue
        text = read_text(p)
        if text is None:
            continue
        for ln, line in enumerate(text.splitlines(), 1):
            if EM_DASH in line:
                errs.append(f"{p.relative_to(ROOT)}:{ln}: em dash")
    rep.check("no em dash (U+2014) in content/, critique/, README.md or LICENSE", errs)

    # 10b. critique/ holds at least one review record
    critique_files = [p for p in iter_text_files(CRITIQUE) if p.name != ".gitkeep"]
    rep.check("critique/ holds at least one review record", [] if critique_files else ["critique/ has no file besides .gitkeep"],
              f"{len(critique_files)} file{'s' if len(critique_files) != 1 else ''}")

    # 11. the forbidden word, and planning vocabulary in content
    errs = []
    lower_hits = []
    process_hits = []
    for p in list(iter_text_files(CONTENT)) + list(iter_text_files(CRITIQUE)) + [README, LICENSE_CODE, LICENSE_FONTS]:
        if not p.exists():
            continue
        text = read_text(p)
        if text is None:
            continue
        for ln, line in enumerate(text.splitlines(), 1):
            if FORBIDDEN_WORD in line:
                errs.append(f"{p.relative_to(ROOT)}:{ln}")
            elif FORBIDDEN_WORD.lower() in line.lower():
                lower_hits.append(f"{p.relative_to(ROOT)}:{ln}")
            if (p.is_relative_to(CONTENT) or p == LICENSE_CODE) and p not in VERBATIM_LEGAL:
                for w in PROCESS_WORDS:
                    if w in line.lower():
                        process_hits.append(f"{p.relative_to(ROOT)}:{ln}: {w!r}")
    rep.check("no occurrence of the forbidden word in content/, critique/, README.md, LICENSE or web/src/fonts/OFL.txt", errs)
    if lower_hits:
        rep.info(f"lower-case generic use of the word (allowed) at: {', '.join(lower_hits)}")
    rep.check("no planning vocabulary in content/ or LICENSE", process_hits)

    # 12. orgs.dow and the department name
    errs = []
    dow = orgs.get("dow", {})
    for f in DOW_REQUIRED:
        if not dow.get(f):
            errs.append(f"orgs.dow.{f} missing or empty")
    if "Department of Defense" not in str(dow.get("statusNote", "")):
        errs.append("orgs.dow.statusNote must say the statutory title remains Department of Defense")
    rest = copy.deepcopy(data)
    rest.get("orgs", {}).pop("dow", None)
    rest_strings = list(walk_strings(rest))
    current = str(dow.get("current", ""))
    abbr = str(dow.get("abbr", ""))
    slug = current.lower().replace(" ", "-")
    for p, s in rest_strings:
        if current and current in s:
            errs.append(f"hard-coded department name at {p}")
        if abbr and re.search(r"\b" + re.escape(abbr) + r"\b", s):
            errs.append(f"hard-coded abbreviation outside a token at {p}")
        if slug and slug in s.lower() and not p.endswith(".url"):
            errs.append(f"hyphenated department name outside a url field at {p}")
    token_count = 0
    allowed_fields = set(dow.keys())
    for p, s in all_strings:
        for tok in TOKEN_RE.findall(s):
            token_count += 1
            parts = tok.strip().split(".")
            if parts[0] != "dow" or len(parts) > 2 or (len(parts) == 2 and parts[1] not in allowed_fields):
                errs.append(f"unknown render token {{{{{tok}}}}} at {p}")
    rep.check("orgs.dow complete; department name appears only via orgs.dow and {{dow}} tokens", errs,
              f"{token_count} tokens")

    # 13. referential integrity across the model
    errs = []
    if fn_ids != FUNCTION_IDS:
        errs.append(f"functions are {fn_ids}, expected {FUNCTION_IDS}")
    if [l.get("order") for l in layers] != list(range(1, 7)):
        errs.append("layer order is not 1..6")
    if sum(1 for l in layers if l.get("isColumn")) != 1:
        errs.append("exactly one layer must have isColumn true")
    for l in layers:
        for fid in l.get("frameworkIds", []):
            if fid not in fw_ids:
                errs.append(f"layer {l.get('id')}: frameworkId {fid!r} does not resolve")
    for f in frameworks:
        if f.get("layerId") not in layer_ids:
            errs.append(f"framework {f.get('id')}: layerId {f.get('layerId')!r} does not resolve")
        else:
            layer = next(l for l in layers if l.get("id") == f.get("layerId"))
            if f.get("id") not in layer.get("frameworkIds", []):
                errs.append(f"framework {f.get('id')} is not listed in layer {layer.get('id')}.frameworkIds")
    for h in helper:
        if h.get("layerId") not in layer_ids:
            errs.append(f"helper {h.get('id')}: layerId does not resolve")
        for e in h.get("entityIds", []):
            if e not in entity_ids:
                errs.append(f"helper {h.get('id')}: entityId {e!r} does not resolve")
    for c in ai.get("column", []):
        if c.get("id") not in entity_ids:
            errs.append(f"ai.column id {c.get('id')!r} does not resolve to a framework or source")
    for s_ in sources:
        if s_.get("layerId") and s_.get("layerId") not in layer_ids:
            errs.append(f"source {s_.get('id')}: layerId {s_.get('layerId')!r} does not resolve")
    meta = data.get("meta", {})
    changelog = meta.get("changelog") or []
    if not changelog or changelog[-1].get("version") != meta.get("contentVersion"):
        errs.append("meta.changelog must end with the entry for the current contentVersion")
    if not str(schema.get("$id", "")).endswith(":" + str(meta.get("contentVersion"))):
        errs.append("schema $id suffix must equal meta.contentVersion")
    if [r.get("functionId") for r in ai.get("socProfile", [])] != FUNCTION_IDS:
        errs.append("ai.socProfile rows must be the six functions in order")
    for e in data.get("meta", {}).get("sources", []):
        if e not in entity_ids:
            errs.append(f"meta.sources id {e!r} does not resolve")
    for o in elevator.get("omits", []):
        if o not in layer_ids:
            errs.append(f"elevator.omits {o!r} is not a layer")
    for fid in elevator.get("frameworkIds", []):
        if fid not in fw_ids:
            errs.append(f"elevator.frameworkIds {fid!r} does not resolve")
        else:
            fw = next(f for f in frameworks if f.get("id") == fid)
            if fw.get("layerId") in elevator.get("omits", []):
                errs.append(f"elevator names {fid} but omits its layer {fw.get('layerId')}")
    if elevator.get("text") is not None:
        errs.append("elevator.text must be null (rendering derives it)")
    rep.check("referential integrity: layers, frameworks, helper, ai, meta, elevator", errs)

    # 14. glossary: terms and forms unique, entity ids resolve, abbreviations carry an expansion
    errs = []
    glossary = data.get("glossary", [])
    terms_seen: dict[str, int] = {}
    forms_seen: dict[str, str] = {}
    g_counts = {s: 0 for s in STATUSES}
    for i, g in enumerate(glossary):
        term = g.get("term")
        if term in terms_seen:
            errs.append(f"glossary[{i}]: term {term!r} repeats glossary[{terms_seen[term]}]")
        terms_seen[term] = i
        for f in g.get("forms", []):
            if f in forms_seen:
                errs.append(f"glossary[{i}] ({term}): form {f!r} already belongs to {forms_seen[f]!r}")
            forms_seen[f] = term
        if g.get("notAbbreviation"):
            if g.get("expansion") is not None:
                errs.append(f"glossary[{i}] ({term}): a name marked notAbbreviation takes a null expansion")
        elif g.get("forms") and not g.get("expansion"):
            errs.append(f"glossary[{i}] ({term}): an abbreviation with forms needs an expansion")
        for e in g.get("entityIds", []):
            if e not in entity_ids:
                errs.append(f"glossary[{i}] ({term}): entityId {e!r} does not resolve")
        st = (g.get("verification") or {}).get("status")
        if st in g_counts:
            g_counts[st] += 1
    rep.check("glossary: terms and forms unique, entity ids resolve, abbreviations carry an expansion", errs,
              f"{len(glossary)} entries: " + " / ".join(f"{k} {g_counts[k]}" for k in STATUSES))

    # 15. licenses: meta names both files, both exist and hold the pinned text, and the retired CC BY legal code stays gone
    errs = []
    lic = data.get("meta", {}).get("licenses", {})
    for part, (spdx, rel) in LICENSE_SPDX.items():
        entry = lic.get(part) or {}
        if entry.get("spdx") != spdx or entry.get("file") != rel:
            errs.append(f"meta.licenses.{part} must name {spdx} in {rel}")
        if spdx == ALL_RIGHTS_RESERVED:
            for k, want in LICENSE_ARR_ENTRY.items():
                if entry.get(k) != want:
                    errs.append(f"meta.licenses.{part}.{k} must be {want!r}")
    for rel in LICENSE_SHA256:
        f = ROOT / rel
        if not f.is_file():
            errs.append(f"{rel} is missing")
        elif hashlib.sha256(f.read_bytes()).hexdigest() != LICENSE_SHA256[rel]:
            errs.append(f"{rel} is not the pinned text (SHA-256 {hashlib.sha256(f.read_bytes()).hexdigest()[:12]})")
    if LICENSE_CONTENT_RETIRED.exists():
        errs.append(f"{LICENSE_CONTENT_RETIRED.relative_to(ROOT)} exists; the CC BY 4.0 legal code governs nothing in the current tree")
    rep.check("licenses: LICENSE (all rights reserved) and web/src/fonts/OFL.txt (OFL 1.1) present, named in meta.licenses, pinned by SHA-256",
              errs, " / ".join(f"{rel} {LICENSE_SHA256[rel][:12]}" for rel in LICENSE_SHA256) + f"; {LICENSE_CONTENT_RETIRED.relative_to(ROOT)} absent")

    # 15b. fonts: the four embedded faces, pinned; web/src/fonts/ holds them and the license, nothing else
    errs = []
    font_dir = ROOT / "web" / "src" / "fonts"
    for rel, want in FONT_SHA256.items():
        f = ROOT / rel
        if not f.is_file():
            errs.append(f"{rel} is missing")
        elif hashlib.sha256(f.read_bytes()).hexdigest() != want:
            errs.append(f"{rel} is not the pinned face (SHA-256 {hashlib.sha256(f.read_bytes()).hexdigest()[:12]})")
    allowed = set(FONT_SHA256) | {"web/src/fonts/OFL.txt"}
    for f in sorted(font_dir.rglob("*")) if font_dir.is_dir() else []:
        if f.is_file() and f.relative_to(ROOT).as_posix() not in allowed:
            errs.append(f"{f.relative_to(ROOT).as_posix()} is not one of the pinned font files")
    rep.check("fonts: the four IBM Plex faces in web/src/fonts/ are the pinned files by SHA-256, beside OFL.txt and nothing else", errs,
              " / ".join(f"{Path(rel).name} {h[:12]}" for rel, h in FONT_SHA256.items()))

    # 15c. the About photo (session 7D): the pinned file, 1200 px on its longest side, with no metadata segment
    errs, detail = [], ""
    if not ABOUT_PHOTO.is_file():
        errs.append("web/src/about-photo.jpg is missing")
    else:
        photo = ABOUT_PHOTO.read_bytes()
        digest = hashlib.sha256(photo).hexdigest()
        if digest != ABOUT_PHOTO_SHA256:
            errs.append(f"web/src/about-photo.jpg is not the pinned file (SHA-256 {digest[:12]})")
        try:
            segs, (w, h) = jpeg_segments(photo)
            meta = [x for x in segs if x.startswith("APP") or x == "COM"]
            if meta:
                errs.append(f"web/src/about-photo.jpg carries metadata segments: {' '.join(meta)}")
            if max(w, h) != 1200:
                errs.append(f"web/src/about-photo.jpg is {w} x {h}, expected 1200 px on its longest side")
            detail = f"{w} x {h}, {len(photo)} bytes, {' '.join(segs)}, SHA-256 {digest[:12]}"
        except ValueError as exc:
            errs.append(f"web/src/about-photo.jpg: {exc}")
    rep.check("about photo: web/src/about-photo.jpg is the pinned file by SHA-256, a whole JPEG that ends at its end-of-image marker, "
              "1200 px on its longest side, with no metadata segment anywhere (no APPn, no COM)", errs, detail)

    # 16. no overdue recheck: the support page says no content release goes out while a recheck is overdue. A content
    # release is the last changelog entry, and meta.builtOn must carry its date, so the test runs on the release date.
    errs = []
    meta_ = data.get("meta", {})
    built = str(meta_.get("builtOn", ""))
    last = (meta_.get("changelog") or [{}])[-1]
    if built != last.get("date"):
        errs.append(f"meta.builtOn {built} is not the date of the last changelog entry ({last.get('version')}, {last.get('date')})")
    dated = [(p, s) for p, s in walk_strings(data) if p.endswith(".recheckAfter") and re.fullmatch(r"\d{4}-\d{2}-\d{2}", s)]
    for p, s in dated:
        if s < built:
            errs.append(f"{p}: recheck was due {s}, before this release ({built}); recheck it and reset the date")
    rep.check("recheck dates: none overdue on the release date (meta.builtOn, which is the last changelog date)", errs,
              f"{len(dated)} dated, next {min((s for _, s in dated if s >= built), default='none scheduled')}")

    print("\n".join(rep.lines))
    if rep.failures:
        print(f"BATTERY RED ({len(rep.failures)} failing check{'s' if len(rep.failures) != 1 else ''})")
        return 1
    print("BATTERY GREEN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
