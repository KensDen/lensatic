"""Curly quotes for Lensatic's own text (R6, the owner's ruling of 28 October 2026: curly quotes everywhere on the site and
in the app). One rule, used by the content check, by tools/build_library.py for the app's guide and plays, and by
curl_html for the site's hand-edited pages (the Zero Trust guide, the Agentic SecOps diagrams and executive summary), which
tools/check_umbrella.py holds to it on every page under docs/:
a quote mark at the start of a text or after a space, an opening bracket, a slash or a dash opens (left quote); every
other one closes, and a straight apostrophe inside or after a word becomes the right single quote, the apostrophe.
Web addresses are left as they are."""
from __future__ import annotations

import re

URL = re.compile(r"https?://\S+")
OPENS_AFTER = " \t\n([{/—–-"
# the keys whose values are identifiers, addresses, dates or formats, never prose
NOT_PROSE = {"id", "url", "href", "src", "date", "verifiedOn", "recheckAfter", "status", "method", "basisIds", "entityIds",
             "layerId", "pillarView", "functionId", "pillarId", "kind", "type", "file", "image", "slug", "path", "key",
             "renderRule", "release", "released", "contentVersion", "builtOn", "version", "$id", "$schema", "pattern"}


def curl(text: str) -> str:
    out, pos = [], 0
    for m in URL.finditer(text):
        out.append(_curl(text[pos:m.start()], text[m.start() - 1] if m.start() else ""))
        out.append(m.group(0))
        pos = m.end()
    out.append(_curl(text[pos:], text[pos - 1] if pos else ""))
    return "".join(out)


def _curl(s: str, before: str) -> str:
    chars = list(s)
    for i, c in enumerate(chars):
        if c not in "'\"":
            continue
        prev = chars[i - 1] if i else before
        opening = prev == "" or prev in OPENS_AFTER
        if c == '"':
            chars[i] = "“" if opening else "”"
        else:
            chars[i] = "‘" if opening else "’"
    return "".join(chars)


# an HTML page's prose: text outside these elements, tags, attributes and comments (the site's hand-edited pages)
NOT_PROSE_TAGS = {"script", "style", "code", "pre", "kbd", "samp", "textarea", "template", "svg"}
INLINE_TAGS = {"a", "abbr", "b", "bdi", "bdo", "cite", "data", "dfn", "em", "i", "mark", "q", "s", "small", "span",
               "strong", "sub", "sup", "time", "u", "var", "tspan"}
SVG_TEXT_TAGS = {"text", "tspan", "title", "desc"}
TOKEN = re.compile(r"<!--[\s\S]*?-->|<![^>]*>|<[^>]*>|[^<]+")
TAG = re.compile(r"<(/?)([A-Za-z][A-Za-z0-9-]*)")


def curl_html(src: str) -> str:
    """An HTML page with its prose curled and everything else (tags, attributes, comments, code, scripts, styles) byte
    for byte. Text inside an SVG is prose only within its text, tspan, title and desc elements. A quote right after an
    inline tag takes the text before that tag as its context; after any other tag it is at the start of a text."""
    out, stack, before = [], [], ""
    for m in TOKEN.finditer(src):
        tok = m.group(0)
        t = TAG.match(tok)
        if tok.startswith("<"):
            if t:
                closing, name = t.group(1) == "/", t.group(2).lower()
                if closing:
                    if name in stack:
                        while stack and stack.pop() != name:
                            pass
                elif not tok.endswith("/>") and name not in {"br", "hr", "img", "input", "link", "meta", "wbr", "col",
                                                             "area", "base", "embed", "source", "track"}:
                    stack.append(name)
                if name not in INLINE_TAGS:
                    before = ""
            out.append(tok)
            continue
        skip = any(n in NOT_PROSE_TAGS for n in stack)
        if skip and "svg" in stack and stack[-1] in SVG_TEXT_TAGS and not any(
                n in NOT_PROSE_TAGS - {"svg"} for n in stack):
            skip = False
        if skip:
            out.append(tok)
            continue
        new = curl(before + tok)[len(before):] if before else curl(tok)
        out.append(new)
        if tok.strip():
            before = tok[-1]
        elif tok:
            before = " "
    return "".join(out)


def straight_html(src: str) -> int:
    """How many straight quote marks the page's prose still holds (outside web addresses)."""
    return sum(1 for a, b in zip(src, curl_html(src)) if a != b)


def curl_tree(node, key: str | None = None):
    """Every prose string in a JSON tree, curled; identifier, address and date fields left alone."""
    if isinstance(node, dict):
        return {k: (v if k in NOT_PROSE else curl_tree(v, k)) for k, v in node.items()}
    if isinstance(node, list):
        return [curl_tree(v, key) for v in node]
    if isinstance(node, str):
        return curl(node)
    return node


def straight(node, key: str | None = None, path: str = "$"):
    """The paths of prose strings that still hold a straight quote mark (outside web addresses)."""
    if isinstance(node, dict):
        for k, v in node.items():
            if k not in NOT_PROSE:
                yield from straight(v, k, f"{path}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from straight(v, key, f"{path}[{i}]")
    elif isinstance(node, str) and re.search(r"['\"]", URL.sub("", node)):
        yield path
