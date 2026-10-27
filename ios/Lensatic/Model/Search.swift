import Foundation

/// One search across the app (the redesign, R2; the top of Widget.dc.html): frameworks and the other entries, the steps
/// on the reader's path, the guide's chapters, the plays and the glossary. Results come back grouped by kind, in that
/// order, and ranked inside each group.
struct SearchIndex: Sendable {
    enum Kind: Int, CaseIterable, Sendable, Comparable {
        case framework, step, guide, play, term

        static func < (a: Kind, b: Kind) -> Bool { a.rawValue < b.rawValue }
    }

    /// What a result opens.
    enum Opens: Hashable, Sendable {
        case nav(Nav)
        case step(Door.ID, Int)
        case glossary(String)
    }

    struct Item: Sendable, Identifiable {
        let kind: Kind
        let id: String
        let title: String
        let subtitle: String
        /// Short names, designations and forms: matched as strongly as the title, never shown.
        let aliases: [String]
        /// The rest of the item's words, matched weakly.
        let body: String
        let opens: Opens
        /// Every field folded once, when the index is built, so a keystroke only compares.
        let folded: Folded

        init(kind: Kind, id: String, title: String, subtitle: String, aliases: [String], body: String, opens: Opens) {
            self.kind = kind
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.aliases = aliases
            self.body = body
            self.opens = opens
            folded = Folded(title: SearchIndex.fold(title), aliases: aliases.map(SearchIndex.fold), subtitle: SearchIndex.fold(subtitle),
                            body: SearchIndex.fold(body))
        }
    }

    struct Folded: Sendable {
        let title: String
        let aliases: [String]
        let subtitle: String
        let body: String
    }

    struct Group: Sendable {
        let kind: Kind
        let results: [Item]
    }

    let items: [Item]

    init(items: [Item]) { self.items = items }

    /// Every searchable item: the entries, the steps of the reader's trailhead, the guide's chapters, the plays and
    /// the glossary's terms.
    init(store: ContentStore, library: Library, door: Door?, labels: Labels) {
        var out: [Item] = []
        let sep = store.label("metaSeparator")
        for e in store.frameworks + store.sources + store.solutions {
            let lead = store.layerTag(e.layerId) ?? labels.source
            out.append(Item(kind: .framework, id: "entity:\(e.id)", title: e.displayName, subtitle: lead + sep + e.shortSummary,
                            aliases: [e.shortName, e.title, e.name], body: [e.oneLiner, e.answersQuestion ?? "", e.role ?? "", e.publisher].joined(separator: " "),
                            opens: .nav(.entity(e.id))))
        }
        if let door {
            for s in door.steps {
                let names = s.entityIds.compactMap { store.entities[$0]?.shortName }
                out.append(Item(kind: .step, id: "step:\(door.id.rawValue):\(s.order)", title: "\(labels.step) \(s.order): \(s.title)",
                                subtitle: door.shortTitle, aliases: names, body: s.text, opens: .step(door.id, s.order)))
            }
        }
        for c in library.guide.chapters {
            out.append(Item(kind: .guide, id: "chapter:\(c.id)", title: c.displayTitle, subtitle: library.site.guideName, aliases: [c.part].compactMap { $0 },
                            body: ([c.summary ?? ""] + c.blocks.map(\.searchText)).joined(separator: " "), opens: .nav(.chapter(c.id))))
        }
        for g in library.plays.groups {
            for p in library.plays(in: g) {
                out.append(Item(kind: .play, id: "play:\(p.id)", title: p.name, subtitle: g.label, aliases: [p.title],
                                body: ([p.subtitle, p.summary ?? ""] + p.blocks.map(\.searchText)).joined(separator: " "), opens: .nav(.play(p.id))))
            }
        }
        for t in store.terms {
            guard let entry = store.content.glossary.first(where: { $0.term == t.term }) else { continue }
            out.append(Item(kind: .term, id: "term:\(t.slug)", title: t.term, subtitle: t.expansion ?? entry.oneLine, aliases: t.forms,
                            body: entry.oneLine, opens: .glossary(t.slug)))
        }
        items = out
    }

    /// The words a screen needs that are not content: the kind names and the step and source labels.
    struct Labels: Sendable {
        var step = "Step"
        var source = "Source"
    }

    // MARK: matching

    /// Lower case, without accents, every run of other characters one space.
    static func fold(_ s: String) -> String {
        let folded = s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        var out = String.UnicodeScalarView()
        var gap = true
        for u in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(u) {
                out.append(u)
                gap = false
            } else if !gap {
                out.append(" ")
                gap = true
            }
        }
        var text = String(out)
        if text.hasSuffix(" ") { text.removeLast() }
        return text
    }

    /// How well a word matches a field: the whole field, a whole word in it, the start of a word, or anywhere.
    static func match(_ word: String, in field: String) -> Int {
        guard !field.isEmpty else { return 0 }
        if field == word { return 4 }
        let padded = " \(field) "
        if padded.contains(" \(word) ") { return 3 }
        if padded.contains(" \(word)") { return 2 }
        return field.contains(word) ? 1 : 0
    }

    /// The score of one item for a query, or nil when a word of the query is in none of its fields. A title match
    /// outweighs any number of body matches; within the title, a whole word outweighs a start, and a start outweighs a
    /// match inside a word. A query that is the whole title, or its first words, ranks first.
    static func score(_ item: Item, words: [String], phrase: String) -> Int? {
        let f = item.folded
        let title = f.title, aliases = f.aliases, subtitle = f.subtitle, body = f.body
        var total = 0
        for w in words {
            let head = max(match(w, in: title), aliases.map { match(w, in: $0) }.max() ?? 0)
            let sub = match(w, in: subtitle)
            let rest = match(w, in: body)
            guard head + sub + rest > 0 else { return nil }
            total += head * 100 + sub * 10 + rest
        }
        if title == phrase || aliases.contains(phrase) { total += 1000 } else if title.hasPrefix(phrase + " ") { total += 500 }
        return total
    }

    /// For a chapter or a play matched in its body rather than its title, the words around the first match, so a
    /// result says why it is there.
    static func excerpt(_ item: Item, query: String, width: Int = 90) -> String? {
        guard item.kind == .guide || item.kind == .play else { return nil }
        let words = fold(query).split(separator: " ").map(String.init)
        guard let first = words.first, !words.allSatisfy({ item.folded.title.contains($0) }) else { return nil }
        let body = item.body as NSString
        let hit = body.range(of: first, options: [.caseInsensitive, .diacriticInsensitive])
        guard hit.location != NSNotFound else { return nil }
        var start = max(0, hit.location - width / 3), end = min(body.length, hit.location + width)
        while start > 0, !CharacterSet.whitespaces.contains(UnicodeScalar(body.character(at: start - 1)) ?? " ") { start -= 1 }
        while end < body.length, !CharacterSet.whitespaces.contains(UnicodeScalar(body.character(at: end)) ?? " ") { end += 1 }
        let text = body.substring(with: NSRange(location: start, length: end - start)).trimmingCharacters(in: .whitespaces)
        return (start > 0 ? "\u{2026}" : "") + text + (end < body.length ? "\u{2026}" : "")
    }

    /// The results for a query, grouped by kind, best first inside each group; between equal scores the shorter title
    /// (the closer match) first, then the content's order.
    func search(_ query: String) -> [Group] {
        let phrase = SearchIndex.fold(query)
        let words = phrase.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        var hits: [(Item, Int, Int)] = []
        for (i, item) in items.enumerated() {
            if let s = SearchIndex.score(item, words: words, phrase: phrase) { hits.append((item, s, i)) }
        }
        return Kind.allCases.compactMap { kind in
            let found = hits.filter { $0.0.kind == kind }.sorted {
                $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.title.count != $1.0.title.count ? $0.0.title.count < $1.0.title.count : $0.2 < $1.2
            }.map(\.0)
            return found.isEmpty ? nil : Group(kind: kind, results: found)
        }
    }
}
