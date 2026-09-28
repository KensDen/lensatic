import Foundation

/// Every transformation the web build applies to content, done the same way from the same data (tools/build_web.py):
/// department tokens, dates, first sentences, plain URLs in notes, status badges, the door meta line, the latest
/// check date, the verification counts, and the first-use rule for abbreviations with its department, well-known,
/// not-an-abbreviation, prefix, plural and bracket cases. This is the one type that holds them; each has a test.
struct Rules: Sendable {
    // MARK: tokens

    static let tokenPattern = try! NSRegularExpression(pattern: #"\{\{\s*dow(?:\.([A-Za-z]+))?\s*\}\}"#)

    /// `{{dow}}` renders the abbreviation and `{{dow.<field>}}` the field; an unknown field renders empty, as the web does.
    static func resolveTokens(_ s: String, department: [String: String]) -> String {
        let ns = s as NSString
        var out = "", pos = 0
        for m in tokenPattern.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: pos, length: m.range.location - pos))
            let field = m.range(at: 1)
            out += field.location == NSNotFound ? (department["abbr"] ?? "") : (department[ns.substring(with: field)] ?? "")
            pos = m.range.location + m.range.length
        }
        return out + ns.substring(from: pos)
    }

    /// The content with every token resolved, once, at load: the JSON tree's strings are resolved and the tree decodes
    /// again, strictly. Returns the resolved tree too, for the walks below.
    static func resolved(_ data: Data, department: [String: String]) throws -> (Content, Any) {
        func walk(_ node: Any) -> Any {
            if let s = node as? String { return resolveTokens(s, department: department) }
            if let a = node as? [Any] { return a.map(walk) }
            if let d = node as? [String: Any] { return d.mapValues(walk) }
            return node
        }
        let tree = walk(try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]))
        let again = try JSONSerialization.data(withJSONObject: tree, options: [.sortedKeys])
        return (try Strict.decode(Content.self, from: again), tree)
    }

    // MARK: source formatting

    static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static let datePattern = try! NSRegularExpression(pattern: #"^(\d{4})(?:-(\d{2})(?:-(\d{2}))?)?$"#)

    /// 2026 stays 2026, 2026-09 is Sep 2026, 2026-09-09 is 9 Sep 2026; anything else is shown as it is.
    static func formatDate(_ iso: String?) -> String {
        let s = iso ?? ""
        let ns = s as NSString
        guard let m = datePattern.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return s }
        var out = ns.substring(with: m.range(at: 1))
        if m.range(at: 2).location != NSNotFound, let month = Int(ns.substring(with: m.range(at: 2))), (1...12).contains(month) {
            out = "\(months[month - 1]) \(out)"
        }
        if m.range(at: 3).location != NSNotFound, let day = Int(ns.substring(with: m.range(at: 3))) {
            out = "\(day) \(out)"
        }
        return out
    }

    private static let sentencePattern = try! NSRegularExpression(pattern: #"^(.*?[.!?])(\s|$)"#)

    /// The first sentence and the rest, split where the web splits: at the first `.`, `!` or `?` followed by a space or the end.
    static func firstSentence(_ s: String) -> (first: String, rest: String) {
        let ns = s as NSString
        guard let m = sentencePattern.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return (s, "") }
        let first = ns.substring(with: m.range(at: 1))
        return (first, ns.substring(from: m.range(at: 1).length).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static let urlPattern = try! NSRegularExpression(pattern: #"https?://[^\s<>"]+"#)

    /// Note text with its plain URLs made into links, trailing prose punctuation left outside the link.
    static func linkify(_ s: String, style: SpanStyle = .plain) -> [Span] {
        let ns = s as NSString
        var out: [Span] = [], pos = 0
        for m in urlPattern.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            var url = ns.substring(with: m.range)
            var tail = ""
            while let last = url.last, ".,;:)".contains(last) {
                tail = String(last) + tail
                url.removeLast()
            }
            let lead = ns.substring(with: NSRange(location: pos, length: m.range.location - pos))
            if !lead.isEmpty { out.append(Span(lead, style: style)) }
            if let target = URL(string: url) {
                out.append(Span(url, role: .hard, style: .url, link: .external(target)))
            } else {
                out.append(Span(url, style: style))
            }
            if !tail.isEmpty { out.append(Span(tail, style: style)) }
            pos = m.range.location + m.range.length
        }
        if pos < ns.length { out.append(Span(ns.substring(from: pos), style: style)) }
        return out
    }

    /// A status badge's words: the status, the date it was checked (verified only) and the recheck date if any.
    static func badgeText(_ v: Verification, ui: UIText) -> String {
        var txt = ui.status[v.status.rawValue] ?? v.status.rawValue
        if v.status == .verified, let on = v.verifiedOn {
            txt += ", \(ui.labels["verifiedOn"] ?? "") \(formatDate(on))"
        }
        if let after = v.recheckAfter {
            txt += ", \(ui.labels["recheckAfter"] ?? "") \(formatDate(after))"
        }
        return txt
    }

    /// The door card's meta line: the step count and the layers its steps touch; for a door with no steps, the first
    /// sentence of its paragraph (which then leaves the body).
    static func doorMeta(_ door: Door, layerOrder: [String: Int], labels L: [String: String]) -> String {
        guard !door.steps.isEmpty else { return firstSentence(door.paragraph.value ?? "").first }
        let layers = Set(door.steps.compactMap { layerOrder[$0.layerId] }).sorted()
        let count = door.steps.count == 1 ? (L["doorMetaStep"] ?? "") : (L["doorMetaSteps"] ?? "").replacingOccurrences(of: "{n}", with: String(door.steps.count))
        let list = layers.map(String.init).joined(separator: L["listSeparator"] ?? ", ")
        let which = (layers.count == 1 ? (L["doorMetaLayer"] ?? "") : (L["doorMetaLayers"] ?? "")).replacingOccurrences(of: "{list}", with: list)
        return count + (L["metaSeparator"] ?? " · ") + which
    }

    /// The newest date any source was checked, over the stack's own records (the glossary's spelling checks are not source checks).
    static func latestCheck(_ tree: Any) -> String {
        var dates: [String] = []
        let iso = try! NSRegularExpression(pattern: #"^\d{4}-\d{2}-\d{2}$"#)
        func walk(_ n: Any) {
            if let a = n as? [Any] { a.forEach(walk) }
            if let d = n as? [String: Any] {
                for (k, v) in d {
                    if k == "verifiedOn", let s = v as? String, iso.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) != nil {
                        dates.append(s)
                    }
                    walk(v)
                }
            }
        }
        if let top = tree as? [String: Any] { walk(top.filter { $0.key != "glossary" }) }
        return dates.max() ?? ""
    }

    /// How many verification records carry each status, over the whole content.
    static func verificationCounts(_ tree: Any) -> [Verification.Status: Int] {
        var counts: [Verification.Status: Int] = [.verified: 0, .authored: 0, .unverified: 0, .conflict: 0]
        func walk(_ n: Any) {
            if let a = n as? [Any] { a.forEach(walk) }
            if let d = n as? [String: Any] {
                for (k, v) in d {
                    if k == "verification", let rec = v as? [String: Any], let s = rec["status"] as? String, let st = Verification.Status(rawValue: s) {
                        counts[st, default: 0] += 1
                    }
                    walk(v)
                }
            }
        }
        walk(tree)
        return counts
    }

    static func slug(_ term: String) -> String {
        let lowered = term.lowercased()
        var out = "", dash = false
        for ch in lowered.unicodeScalars {
            if ("a"..."z").contains(ch) || ("0"..."9").contains(ch) {
                if dash && !out.isEmpty { out += "-" }
                out.unicodeScalars.append(ch)
                dash = false
            } else {
                dash = true
            }
        }
        return out
    }

    // MARK: glossary and the first-use rule

    struct Term: Sendable {
        let term: String
        let slug: String
        let expansion: String?
        let forms: [String]
        let prefix: Bool
        let notAbbreviation: Bool
        let wellKnown: Bool
        let nameFirst: Bool

        /// Whether the app ever spells this entry out: not a name, and not a term every reader knows.
        var spells: Bool { !(expansion ?? "").isEmpty && !notAbbreviation && !wellKnown }
    }

    /// The glossary as the web lists it: tokens resolved, sorted by term. `rawTerms` are the terms before resolution;
    /// the entry whose term is the department token is spelled out name first.
    static func terms(_ glossary: [GlossaryEntry], rawTerms: [String]) -> [Term] {
        zip(glossary, rawTerms).map { g, raw in
            Term(term: g.term, slug: slug(g.term), expansion: g.expansion.value, forms: g.forms, prefix: g.prefix ?? false,
                 notAbbreviation: g.notAbbreviation ?? false, wellKnown: g.wellKnown ?? false,
                 nameFirst: raw.range(of: #"^\{\{\s*dow\s*\}\}$"#, options: .regularExpression) != nil)
        }.sorted { $0.term.lowercased() < $1.term.lowercased() }
    }

    let byForm: [String: Term]
    let pattern: NSRegularExpression?
    static let designation = try! NSRegularExpression(pattern: #"(?:/([A-Z][A-Za-z]+))?\s?\d+(?:[-/:]\d+)*"#)

    /// The first-use rule over these glossary entries: those with forms and either an expansion or the
    /// not-an-abbreviation mark, as the web build selects them.
    init(terms: [Term]) {
        var byForm: [String: Term] = [:]
        var plain: [String] = [], prefix: [String] = []
        for t in terms where !t.forms.isEmpty && (t.expansion != nil || t.notAbbreviation) {
            for f in t.forms {
                byForm[f] = t
                if t.prefix { prefix.append(f) } else { plain.append(f) }
            }
        }
        func formPattern(_ forms: [String], prefix: Bool) -> String {
            let after = prefix ? "(?![A-Za-z])" : "(?![A-Za-z0-9])"
            let alts = forms.sorted { $0.count > $1.count }.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
            return "(?<![A-Za-z0-9.])(?:\(alts))\(after)"
        }
        var pats: [String] = []
        if !plain.isEmpty { pats.append(formPattern(plain, prefix: false)) }
        if !prefix.isEmpty { pats.append(formPattern(prefix, prefix: true)) }
        self.byForm = byForm
        pattern = pats.isEmpty ? nil : try! NSRegularExpression(pattern: pats.joined(separator: "|"))
    }

    /// True where a form sits in parentheses right after its own name: the words before the parenthesis end with the
    /// expansion's last words (up to three), as in DoD Cyber Defense Command (DCDC).
    static func namesItself(before: String, after: String, expansion: String) -> Bool {
        guard before.hasSuffix("("), after.hasPrefix(")") else { return false }
        let want = Array(expansion.lowercased().split(whereSeparator: \.isWhitespace).map(String.init).suffix(3))
        let words = try! NSRegularExpression(pattern: "[a-z0-9'-]+")
        let head = String(before.dropLast()).lowercased()
        let found = words.matches(in: head, range: NSRange(location: 0, length: (head as NSString).length)).map { (head as NSString).substring(with: $0.range) }
        return Array(found.suffix(want.count)) == want
    }

    /// The running state of one screen: which terms have had their first use, and the text read so far.
    struct Scope {
        var handled: Set<String> = []
        var seen = ""
    }

    /// Spell out each abbreviation at its first use in running text on one screen. In running text, the first match
    /// of each glossary form gets its expansion after it unless the expansion already appeared on the screen; where
    /// links are allowed the form links to its glossary entry. A label never takes an expansion and never counts as a
    /// first use: its forms link to the glossary, or, inside a control, describe the control. Names and well-known
    /// terms are linked at their first use and never spelled out. The department is spelled out name first.
    func apply(_ page: inout Page) {
        var scope = Scope()
        page.visitRuns { run, interactive in
            var segments: [Segment] = []
            var described: [String] = []
            for span in run.spans {
                let nolink = interactive || span.link != nil
                switch span.role {
                case .hard:
                    scope.seen += span.text
                    segments.append(.text(span.text, span.style, span.link))
                case .glossaryTerm:
                    if let t = byForm[span.text.trimmingCharacters(in: .whitespaces)] { scope.handled.insert(t.term) }
                    scope.seen += span.text
                    segments.append(.text(span.text, span.style, span.link))
                case .label:
                    segments += label(span, nolink: nolink, described: &described)
                case .running:
                    segments += running(span, nolink: nolink, scope: &scope)
                }
            }
            run.segments = segments
            var once = Set<String>()
            run.described = described.filter { once.insert($0).inserted }
        }
    }

    private func matches(_ s: String) -> [NSTextCheckingResult] {
        guard let pattern else { return [] }
        return pattern.matches(in: s, range: NSRange(location: 0, length: (s as NSString).length))
    }

    private func designationEnd(_ ns: NSString, at end: Int) -> (end: Int, inner: Term?)? {
        guard let des = Rules.designation.firstMatch(in: ns as String, options: [.anchored], range: NSRange(location: end, length: ns.length - end)) else { return nil }
        let g = des.range(at: 1)
        let inner = g.location == NSNotFound ? nil : byForm[ns.substring(with: g)]
        return (des.range.location + des.range.length, inner)
    }

    private func label(_ span: Span, nolink: Bool, described: inout [String]) -> [Segment] {
        let ns = span.text as NSString
        var out: [Segment] = [], pos = 0
        func text(_ a: Int, _ b: Int) { if b > a { out.append(.text(ns.substring(with: NSRange(location: a, length: b - a)), span.style, span.link)) } }
        for m in matches(span.text) {
            guard m.range.location >= pos, let t = byForm[ns.substring(with: m.range)] else { continue }
            var end = m.range.location + m.range.length
            var found = [t]
            if t.prefix, let des = designationEnd(ns, at: end) {
                if let inner = des.inner { found.append(inner) }
                end = des.end
            }
            let exps = found.filter(\.spells).compactMap(\.expansion)
            described += exps
            if nolink {
                text(pos, end)
            } else {
                text(pos, m.range.location)
                out.append(.term(ns.substring(with: m.range), slug: t.slug, span.style))
                text(m.range.location + m.range.length, end)
            }
            pos = end
        }
        text(pos, ns.length)
        return out
    }

    private func running(_ span: Span, nolink: Bool, scope: inout Scope) -> [Segment] {
        let ns = span.text as NSString
        var out: [Segment] = [], pos = 0
        func sub(_ a: Int, _ b: Int) -> String { b > a ? ns.substring(with: NSRange(location: a, length: b - a)) : "" }
        func text(_ s: String) { if !s.isEmpty { out.append(.text(s, span.style, span.link)) } }
        for m in matches(span.text) {
            let start = m.range.location, formEnd = m.range.location + m.range.length
            guard start >= pos else { continue }  // inside a designation already taken, as IEC in ISO/IEC 27001
            let form = ns.substring(with: m.range)
            guard let t = byForm[form], !scope.handled.contains(t.term) else { continue }
            scope.handled.insert(t.term)
            if t.notAbbreviation || t.wellKnown {
                if !nolink {
                    text(sub(pos, start))
                    out.append(.term(form, slug: t.slug, span.style))
                    scope.seen += sub(pos, formEnd)
                    pos = formEnd
                }
                continue
            }
            guard let expansion = t.expansion else { continue }
            let before = scope.seen + sub(0, start)
            if before.lowercased().contains(expansion.lowercased()) { continue }
            if Rules.namesItself(before: before, after: sub(formEnd, ns.length), expansion: expansion) { continue }
            var end = formEnd
            var expansions = [expansion]
            if t.prefix, let des = designationEnd(ns, at: formEnd) {
                end = des.end
                if let inner = des.inner, !scope.handled.contains(inner.term), inner.spells, let innerExp = inner.expansion {
                    scope.handled.insert(inner.term)
                    if !before.lowercased().contains(innerExp.lowercased()) { expansions.append(innerExp) }
                }
            }
            if form.hasSuffix("s") && !t.term.hasSuffix("s") && !expansions[0].hasSuffix("s") { expansions[0] += "s" }
            let opened = sub(0, start)
            let (o, c) = opened.filter { $0 == "(" }.count > opened.filter { $0 == ")" }.count ? ("[", "]") : ("(", ")")
            let spelled = expansions.joined(separator: " and ")
            let token = sub(start, end)
            let linked: Segment = nolink ? .text(token, span.style, span.link) : .term(token, slug: t.slug, span.style)
            text(sub(pos, start))
            if t.nameFirst {
                out += [.expansion("\(spelled) \(o)", span.style, span.link), linked, .expansion(c, span.style, span.link)]
                scope.seen += sub(pos, start) + "\(spelled) \(o)\(token)\(c)"
            } else {
                out += [linked, .expansion(" \(o)\(spelled)\(c)", span.style, span.link)]
                scope.seen += sub(pos, end) + " \(o)\(spelled)\(c)"
            }
            pos = end
        }
        text(sub(pos, ns.length))
        scope.seen += sub(pos, ns.length)
        return out
    }
}
