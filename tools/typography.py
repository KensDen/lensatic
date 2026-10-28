"""Curly quotes for Lensatic's own text (R6, the owner's ruling of 28 October 2026: curly quotes everywhere on the site and
in the app). One rule, used by the content check and by tools/build_library.py for the app's guide and plays:
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
