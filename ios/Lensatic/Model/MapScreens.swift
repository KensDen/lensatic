import Foundation

// The map's screens as text (the redesign, R2): each builds its runs in reading order from the content and passes them
// once through the first-use rule, so an abbreviation is spelled out at its first use in running text on that screen and
// linked to its glossary entry. Rows and buttons are drawn from plain names; their prose runs are marked interactive, so
// nothing inside a control is linked. The views draw these; the tests read them.

/// Collects one screen's runs and hands back where each one is.
struct ProseBuilder {
    private(set) var prose = Prose()

    @discardableResult
    mutating func add(_ spans: [Span], interactive: Bool = false) -> Int { prose.add(spans, interactive: interactive) }

    @discardableResult
    mutating func text(_ s: String, _ role: SpanRole = .running, _ style: SpanStyle = .plain, interactive: Bool = false) -> Int {
        prose.add([Span(s, role: role, style: style)], interactive: interactive)
    }

    func applied(_ rules: Rules, linksWellKnown: Bool = false) -> Prose {
        var p = prose
        rules.apply(&p, linksWellKnown: linksWellKnown)
        return p
    }
}

/// Explore's Stack: the five layers and the AI column.
struct StackScreen {
    let layers: [Layer]
    let column: Layer?

    init(store: ContentStore) {
        layers = store.content.layers.filter { !$0.isColumn }.sorted { $0.order < $1.order }
        column = store.content.layers.first(where: \.isColumn)
    }

    /// The short names a layer's card lists: its frameworks, then the other entries placed on it.
    static func names(_ layer: Layer, store: ContentStore) -> [String] {
        entryIds(layer, store: store).compactMap { store.entities[$0]?.shortName }
    }

    /// A layer's entries in order: its frameworks, then the sources placed on it; the AI column's as the content lists them.
    static func entryIds(_ layer: Layer, store: ContentStore) -> [String] {
        if layer.isColumn { return store.content.ai.column.map(\.id) }
        return layer.frameworkIds + store.sources.filter { $0.layerId == layer.id }.map(\.id)
    }
}

/// A layer opened from Explore: its question and line, its entries, the solutions measured against it, and the
/// questions the map answers at that layer. The AI column adds its note and the worked example of a Profile.
struct LayerScreen {
    struct Helper {
        let id: String
        let question: Int
        let answer: Int
        let entityIds: [String]
    }

    let layer: Layer
    let prose: Prose
    let question: Int
    let oneLiner: Int
    let note: Int?
    /// The rest of the AI column's note after its first sentence, one tap down.
    let noteRest: Int?
    let soc: [(function: String, outcome: Int)]
    let socTitle: Int?
    let entryIds: [String]
    let solutionIds: [String]
    let helpers: [Helper]

    init?(store: ContentStore, id: String) {
        guard let layer = store.layers[id] else { return nil }
        self.layer = layer
        var b = ProseBuilder()
        question = b.text(layer.question)
        oneLiner = b.text(layer.oneLiner)
        entryIds = StackScreen.entryIds(layer, store: store)
        solutionIds = store.solutions.filter { $0.layerId == id }.map(\.id)
        if layer.isColumn {
            let parts = Rules.firstSentence(store.content.ai.note)
            note = b.text(parts.first)
            noteRest = parts.rest.isEmpty ? nil : b.text(parts.rest)
            socTitle = b.text(store.label("socProfile"), .label)
            soc = store.content.ai.socProfile.compactMap { r in
                store.functions[r.functionId].map { ($0.name, b.text(r.outcome)) }
            }
        } else {
            note = nil
            noteRest = nil
            socTitle = nil
            soc = []
        }
        helpers = store.content.helper.filter { $0.layerId == id }.map { h in
            Helper(id: h.id, question: b.text(h.question, interactive: true), answer: b.text(h.answer), entityIds: h.entityIds)
        }
        // AI links to its glossary entry on the AI column's screen only (session 17)
        prose = b.applied(store.rules, linksWellKnown: layer.isColumn)
    }
}

/// Explore's Matrix in one of its two views: the six functions in turn, each with a row per pillar that gives the
/// cell's first sentence and opens the cell.
struct MatrixScreen {
    struct Row {
        let pillar: String
        let name: String
        let crossCutting: Bool
        let capabilities: [String]
        let line: Int
    }

    let view: PillarView
    let prose: Prose
    let functions: [(function: CSFFunction, rows: [Row])]

    init(store: ContentStore, view: PillarView) {
        self.view = view
        var b = ProseBuilder()
        functions = store.content.functions.map { fn in
            (fn, store.columns(view).compactMap { col -> Row? in
                guard let cell = store.cell(col.id, fn.id) else { return nil }
                return Row(pillar: col.id, name: col.name, crossCutting: col.crossCutting, capabilities: view == .dow ? (cell.capabilityIds ?? []) : [],
                           line: b.text(Rules.firstSentence(cell.text).first, interactive: true))
            })
        }
        prose = b.applied(store.rules)
    }
}

/// One cell of the matrix: the pillar, the function, the cell's text, its CSF categories and, in the department's
/// view, its capabilities.
struct CellScreen {
    let prose: Prose
    let title: String
    let function: CSFFunction
    let text: Int
    let categories: [String]
    let capabilities: [String]

    init?(store: ContentStore, view: PillarView, pillar: String, function id: FunctionID) {
        guard let cell = store.cell(pillar, id), let fn = store.functions[id],
              let col = store.columns(view).first(where: { $0.id == pillar }) else { return nil }
        var b = ProseBuilder()
        title = col.crossCutting ? "\(col.name) (\(store.label("crossCutting")))" : col.name
        function = fn
        text = b.text(cell.text)
        categories = cell.categories
        capabilities = (cell.capabilityIds ?? []).map { "\($0) \(store.capabilityNames[$0] ?? "")".trimmingCharacters(in: .whitespaces) }
        prose = b.applied(store.rules)
    }
}

/// Explore's Functions: the six CSF functions, each with its question, its categories, where zero trust lands in it,
/// and the first sentence of each pillar's cell.
struct FunctionsScreen {
    struct Card {
        let function: CSFFunction
        let question: Int
        let landing: Int
        let pillars: [(name: String, line: Int)]
    }

    let prose: Prose
    let cards: [Card]

    init(store: ContentStore) {
        var b = ProseBuilder()
        cards = store.content.functions.map { fn in
            let q = b.text(fn.question)
            let landing = b.text(fn.ztLanding)
            let rows = store.content.pillars.canonical.compactMap { p -> (String, Int)? in
                guard let cell = store.cell(p.id, fn.id) else { return nil }
                return (p.name, b.text(Rules.firstSentence(cell.text).first))
            }
            return Card(function: fn, question: q, landing: landing, pillars: rows)
        }
        prose = b.applied(store.rules)
    }
}

/// The glossary (Library, Reference): every term with its expansion, its plain sentence and the entries it names; an
/// entry carries a badge only where its spelling could not be confirmed (session 20).
struct GlossaryScreen {
    struct Item {
        let slug: String
        let term: Int
        let body: Int
        let entityIds: [String]
        let status: Verification?
    }

    let prose: Prose
    let intro: Int?
    let items: [Item]

    init(store: ContentStore, only slug: String? = nil) {
        var b = ProseBuilder()
        intro = slug == nil ? b.text(store.label("glossaryIntro")) : nil
        var out: [Item] = []
        for t in store.terms where slug == nil || t.slug == slug {
            guard let entry = store.content.glossary.first(where: { $0.term == t.term }) else { continue }
            let term = b.add([Span(t.term, role: .glossaryTerm, style: .monoStrong)])
            var body: [Span] = []
            if let exp = t.expansion { body += [Span(exp), Span(". ")] }
            body.append(Span(entry.oneLine))
            out.append(Item(slug: t.slug, term: term, body: b.add(body), entityIds: entry.entityIds,
                            status: entry.verification.status == .verified ? nil : entry.verification))
        }
        items = out
        prose = b.applied(store.rules)
    }
}

/// All sources (Library, Reference): the introduction, then the frameworks, the other sources and the solutions, each
/// with its citation line and its check.
struct SourcesScreen {
    struct Group {
        let title: String
        let entries: [(entity: Entity, cite: Int)]
    }

    let prose: Prose
    let intro: Int
    let groups: [Group]

    init(store: ContentStore) {
        var b = ProseBuilder()
        intro = b.text(store.label("sourcesIntro"))
        groups = [("groupFrameworks", store.frameworks), ("groupSources", store.sources), ("groupSolutions", store.solutions)]
            .filter { !$0.1.isEmpty }
            .map { key, items in
                Group(title: store.label(key), entries: items.map { e in (e, b.add(SourcesScreen.cite(e), interactive: true)) })
            }
        prose = b.applied(store.rules)
    }

    /// An entry's citation line: title, publisher, the edition as Rules.citeEdition gives it, date.
    static func cite(_ e: Entity) -> [Span] {
        var spans = [Span(e.title), Span(". "), Span(e.publisher), Span(", ")]
        if let ed = Rules.citeEdition(title: e.title, edition: e.edition, date: e.date) { spans += [Span(ed), Span(", ")] }
        return spans + [Span(Rules.formatDate(e.date), role: .hard), Span(".")]
    }
}

/// Why "Lensatic" (Library, Reference): the story of the name with the maker's photo, the versions and the release
/// date, the wayfinder line, what the map is and is not, how it was checked and built, and the links.
struct AboutScreen {
    let prose: Prose
    let name: String
    let version: String
    let paragraphs: [Int]
    let small: [Int]
    let counts: [(status: Verification.Status, label: String, count: Int)]
    let madeBy: String?
    let builtWith: Int
    let storyHeading: String
    let story: [Int]
    let photoAlt: String

    init(store: ContentStore) {
        let meta = store.content.meta
        var b = ProseBuilder()
        name = meta.name
        let sep = store.label("metaSeparator")
        version = [store.appVersion, "\(store.label("contentVersion")) \(meta.contentVersion)",
                   "\(store.label("releasedOn")) \(Rules.formatDate(meta.builtOn))"].filter { !$0.isEmpty }.joined(separator: sep)
        // the story leads the screen, so its runs come first and take the first uses
        storyHeading = store.label("whyNameHeading")
        story = (meta.about.nameStory ?? []).map { b.text($0) }
        paragraphs = [b.text(meta.wayfinder), b.text(meta.about.notAffiliated)]
        small = [b.text(store.label("dowNote")), b.text(store.content.orgs.dow.statusNote), b.text(meta.about.offline), b.text(meta.about.licensing)]
        counts = Verification.Status.allCases.map { ($0, store.content.ui.status[$0.rawValue] ?? $0.rawValue, store.counts[$0] ?? 0) }
        madeBy = store.maker.isEmpty ? nil : "\(store.label("madeBy")) \(store.maker)"
        builtWith = b.text(meta.about.builtWith)
        photoAlt = store.label("aboutPhotoAlt")
        prose = b.applied(store.rules)
    }
}

extension MapScreens {
    /// Every map screen the app can show, by name, for the tests: each layer, the matrix in both views, every
    /// cell, the functions, the glossary and each of its entries, the sources and About.
    static func all(_ store: ContentStore) -> [(String, Prose)] {
        var out: [(String, Prose)] = []
        for l in store.content.layers { if let s = LayerScreen(store: store, id: l.id) { out.append(("layer \(l.id)", s.prose)) } }
        for v in PillarView.allCases {
            out.append(("matrix \(v.rawValue)", MatrixScreen(store: store, view: v).prose))
            for col in store.columns(v) {
                for fn in store.content.functions {
                    if let c = CellScreen(store: store, view: v, pillar: col.id, function: fn.id) { out.append(("cell \(v.rawValue) \(col.id) \(fn.id.rawValue)", c.prose)) }
                }
            }
        }
        out.append(("functions", FunctionsScreen(store: store).prose))
        out.append(("glossary", GlossaryScreen(store: store).prose))
        for t in store.terms { out.append(("glossary \(t.slug)", GlossaryScreen(store: store, only: t.slug).prose)) }
        out.append(("sources", SourcesScreen(store: store).prose))
        out.append(("about", AboutScreen(store: store).prose))
        return out
    }
}

enum MapScreens {}
