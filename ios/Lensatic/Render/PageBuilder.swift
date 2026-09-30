import Foundation

/// Where a page is: the root list, a section, a pushed screen, or the glossary entry a link opens.
enum PageKey: Hashable, Sendable {
    case root
    case section(Section, PillarView)
    case route(Route)
    case glossaryEntry(String)
}

/// Builds every screen from the content, in the web page's order and with its words (tools/build_web.py), then runs
/// the first-use rule over the screen. Only the chrome between content strings (spaces, commas, parentheses) is
/// written here.
struct PageBuilder {
    let store: ContentStore

    func page(_ key: PageKey) -> Page {
        var b = Draft(store: store)
        var page: Page
        switch key {
        case .root: page = b.root()
        case .section(let s, let view): page = b.section(s, view: view)
        case .route(let r): page = b.route(r)
        case .glossaryEntry(let slug): page = b.glossaryEntry(slug)
        }
        page.texts = b.texts
        store.rules.apply(&page)
        return page
    }

    /// Every page the app can show, for the tests: the root, each section in both matrix views where it differs,
    /// every door, layer, entry and cell, and every glossary entry.
    func allKeys() -> [PageKey] {
        var keys: [PageKey] = [.root]
        for s in store.sections {
            keys.append(.section(s, .dow))
            if s == .matrix { keys.append(.section(s, .cisa)) }
        }
        keys += store.content.doors.map { .route(.door($0.id.rawValue)) }
        keys += store.content.layers.map { .route(.layer($0.id)) }
        keys += (store.frameworks + store.sources + store.solutions).map { .route(.entity($0.id)) }
        for view in PillarView.allCases {
            for col in store.columns(view) {
                for fn in store.content.functions { keys.append(.route(.cell(view, col.id, fn.id))) }
            }
        }
        keys += store.terms.map { .glossaryEntry($0.slug) }
        return keys
    }
}

/// One page being built: the spans it places and the log of content strings behind them.
private struct Draft {
    let store: ContentStore
    var texts: [String] = []

    var content: Content { store.content }
    func L(_ key: String) -> String { store.label(key) }

    // MARK: spans

    /// A content string, logged for the parity test.
    mutating func c(_ s: String, _ role: SpanRole = .running, _ style: SpanStyle = .plain, link: Target? = nil) -> Span {
        texts.append(s)
        return Span(s, role: role, style: style, link: link)
    }

    /// A short name in parentheses, one run of text as the web's span.short is one text node, so the first-use rule
    /// sees the open parenthesis (square brackets inside) and a name followed by its own form. The short name is logged.
    /// Beside an entry's title it is part of that title, a label (session 11).
    mutating func paren(_ short: String, _ role: SpanRole = .running) -> Span {
        texts.append(short)
        return Span("(\(short))", role: role)
    }

    /// A label from ui.labels, logged.
    mutating func l(_ key: String, _ role: SpanRole = .label, _ style: SpanStyle = .plain, link: Target? = nil) -> Span {
        c(L(key), role, style, link: link)
    }

    /// Chrome between content strings: never logged.
    func g(_ s: String, _ role: SpanRole = .running, _ style: SpanStyle = .plain, link: Target? = nil) -> Span {
        Span(s, role: role, style: style, link: link)
    }

    /// Note text with its URLs made tappable, logged whole.
    mutating func linked(_ s: String, _ style: SpanStyle = .plain) -> [Span] {
        texts.append(s)
        return Rules.linkify(s, style: style)
    }

    mutating func badge(_ v: Verification?) -> Badge? {
        guard let v else { return nil }
        return Badge(status: v.status, run: Run(g(Rules.badgeText(v, ui: content.ui), .label, .mono)))
    }

    /// Links to entries by their short names. Each names an entry, so it is a label (session 11, as the web's a.ref): it
    /// never takes an expansion and is described by the expansions of the abbreviations it holds.
    mutating func entityLinks(_ ids: [String]) -> [Span] {
        var out: [Span] = []
        for (i, id) in ids.enumerated() {
            guard let e = store.entities[id] else { continue }
            if i > 0 { out.append(g(", ")) }
            out.append(c(e.shortName, .label, .plain, link: .push(.entity(id))))
        }
        return out
    }

    mutating func chip(_ id: String) -> Chip? {
        guard let e = store.entities[id] else { return nil }
        return Chip(label: Run(c(e.shortName, .label)), target: .push(.entity(id)), kind: e.kind)
    }

    /// A layer's tag: Layer and its number; the AI column, beside the five layers rather than a sixth, is tagged with its
    /// name (session 11, as on the web).
    mutating func layerTag(_ id: String) -> Control? {
        guard let layer = store.layers[id] else { return nil }
        let label = layer.isColumn ? Run(c(layer.name, .label, .mono))
            : Run([l("layer", .label, .mono), g(" ", .label, .mono), g(String(layer.order), .hard, .mono)])
        return Control(label: label, target: .push(.layer(id)), identifier: "layer-tag-\(id)")
    }

    mutating func sectionHead(_ s: Section) -> Block {
        Block(.sectionHead(number: Run(g(store.sectionNumber(s), .label, .mono)), title: Run(c(store.sectionTitle(s), .label))))
    }

    // MARK: root

    mutating func root() -> Page {
        let rows = store.sections.map { s in
            NavRow(lead: Run(g(store.sectionNumber(s), .label, .mono)), title: Run(c(store.sectionTitle(s), .label)),
                   target: .section(s, anchor: nil), identifier: "section-\(s.rawValue)")
        }
        return Page(title: content.meta.name, blocks: [Block(.rows(rows))])
    }

    // MARK: sections

    mutating func section(_ s: Section, view: PillarView) -> Page {
        let blocks: [Block]
        switch s {
        case .doors: blocks = doors()
        case .stack: blocks = stack()
        case .matrix: blocks = matrix(view)
        case .functions: blocks = functions()
        case .ai: blocks = ai()
        case .helper: blocks = helper()
        case .sources: blocks = sourcesSection()
        case .glossary: blocks = glossary()
        case .about: blocks = about()
        }
        return Page(title: store.navTitle(s), blocks: blocks)
    }

    /// The front door, then the doors: the eyebrow, the name, the description, the two buttons and the version line
    /// that ends with Why the name; the audience line and the plain definition of zero trust; the four doors; the note.
    mutating func doors() -> [Block] {
        let meta = content.meta
        // the eyebrow as its phrases, each ending with the separator, so a narrow screen or a large text size wraps it only
        // between phrases (session 11); the whole label is logged
        let eyebrow = L("heroEyebrow")
        texts.append(eyebrow)
        let separator = L("metaSeparator"), joint = separator.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
        let phrases = eyebrow.components(separatedBy: separator)
        let eyebrowRuns = phrases.enumerated().map { i, p in Run(g(i < phrases.count - 1 ? p + joint : p, .label, .mono)) }
        var out: [Block] = [
            Block(.hero(eyebrow: eyebrowRuns, name: Run(c(meta.name, .label)), lede: Run(c(meta.description))), anchor: "intro"),
            Block(.controls([
                Control(label: Run(l("heroPrimary")), target: .anchor("doors"), prominent: true, identifier: "hero-primary"),
                Control(label: Run(l("heroSecondary")), target: .section(.stack, anchor: nil), identifier: "hero-secondary"),
            ])),
        ]
        // the version is its own link, as on the web, and a full-size target of its own rather than a link inside the line;
        // the comma after it stays with it, so a narrow screen breaks the line after the comma, never before it
        let version = Control(label: Run([l("contentVersion", .label, .mono), g(" ", .label, .mono), g(meta.contentVersion, .hard, .mono)]),
                              target: .section(.about, anchor: nil), identifier: "content-version")
        let line = Run([l("checkedThrough", .label, .mono), g(" ", .label, .mono), g(Rules.formatDate(store.latestCheck), .hard, .mono),
                        g(joint, .label, .mono)])
        out.append(Block(.versionLine(version: version, joiner: ",", line, why: Control(label: Run(l("whyName", .label, .mono)), target: .section(.about, anchor: "about-name"),
                                                    identifier: "why-name"))))
        out.append(sectionHead(.doors))
        out.append(Block(.text(Run(l("audience", .running)), .lede), anchor: "doors-audience"))
        out.append(Block(.text(Run(l("ztPlain", .running)), .note), anchor: "zt-plain"))
        var rows: [NavRow] = []
        for door in content.doors {
            let who = Rules.firstSentence(door.whoYouAre).first
            let metaLine = Rules.doorMeta(door, layerOrder: store.layers.mapValues(\.order), labels: content.ui.labels)
            // a door with no steps shows its paragraph's first sentence as its meta line: that is content, logged
            let metaSpan = door.steps.isEmpty ? c(metaLine, .label, .mono) : g(metaLine, .label, .mono)
            rows.append(NavRow(title: Run(c(door.title, .label, .strong)), lines: [Run(c(who))], meta: Run(metaSpan),
                               metaIsSentence: door.steps.isEmpty, target: .push(.door(door.id.rawValue)),
                               identifier: "door-\(door.id.rawValue)"))
        }
        out.append(Block(.rows(rows), anchor: "doors"))
        out.append(Block(.text(Run(l("doorsIntroApp", .running)), .note), anchor: "doors-note"))
        return out
    }

    mutating func stack() -> [Block] {
        var out = [sectionHead(.stack), Block(.text(Run(l("stackIntroApp", .running)), .body))]
        var elevator: [Span] = []
        for (i, id) in content.elevator.frameworkIds.enumerated() {
            guard let e = store.entities[id] else { continue }
            if i > 0 { elevator.append(g(" ")) }
            elevator.append(c(e.oneLiner))
        }
        out.append(Block(.text(Run(elevator), .elevator), anchor: "elevator"))
        let ordered = content.layers.filter { !$0.isColumn } + content.layers.filter(\.isColumn)
        let rows = ordered.map { layer in
            NavRow(lead: layer.isColumn ? nil : Run(g(String(format: "%02d", layer.order), .label, .mono)),
                   title: Run(c(layer.name, .label, .monoStrong)), lines: [Run(c(layer.question))], style: .layer,
                   target: .push(.layer(layer.id)), identifier: "layer-\(layer.id)")
        }
        out.append(Block(.rows(rows), anchor: "bands"))
        return out
    }

    /// The matrix, function by function (the six CSF functions in the content's order), each with the current view's
    /// pillar cells as rows; every row names its pillar.
    mutating func matrix(_ view: PillarView) -> [Block] {
        var out = [sectionHead(.matrix), Block(.text(Run(l("matrixIntroApp", .running)), .small))]
        let controls = [Control(label: Run(l("pillarViewDow")), target: .anchor("view-dow"), identifier: "pillar-view-dow"),
                        Control(label: Run(l("pillarViewCisa")), target: .anchor("view-cisa"), identifier: "pillar-view-cisa")]
        out.append(Block(.pillarViews(controls, selected: view == .dow ? 0 : 1), anchor: "matrix-control"))
        out.append(Block(.heading(Run(l(view == .dow ? "matrixCaptionDow" : "matrixCaptionCisa"))), anchor: "matrix-\(view.rawValue)"))
        for fn in content.functions {
            var group = [Block(.heading(Run([g(fn.id.rawValue, .hard, .monoStrong), g(" ", .label), c(fn.name, .label)])))]
            var rows: [NavRow] = []
            for col in store.columns(view) {
                guard let cell = store.cell(col.id, fn.id) else { continue }
                var lead = [c(col.name, .label, .monoStrong)]
                if col.crossCutting { lead += [g(" (", .label, .mono), l("crossCutting", .label, .mono), g(")", .label, .mono)] }
                let caps = view == .dow ? (cell.capabilityIds ?? []) : []
                var lines = [Run(c(Rules.firstSentence(cell.text).first))]
                if !caps.isEmpty { lines.insert(Run([g(L("capabilities") + " ", .label, .mono), g(caps.joined(separator: " "), .hard, .mono)]), at: 0) }
                rows.append(NavRow(title: Run(lead), lines: lines, target: .push(.cell(view, col.id, fn.id)),
                                   identifier: "cell-\(view.rawValue)-\(col.id)-\(fn.id.rawValue)"))
            }
            group.append(Block(.rows(rows)))
            out.append(Block(.group(group), anchor: "row-\(view.rawValue)-\(fn.id.rawValue)"))
        }
        return out
    }

    mutating func functions() -> [Block] {
        var out = [sectionHead(.functions)]
        for fn in content.functions {
            var card = [Block(.heading(Run([g(fn.id.rawValue, .hard, .monoStrong), g(" ", .label), c(fn.name, .label)]))),
                        Block(.text(Run(c(fn.question)), .question)),
                        Block(.text(Run(l("categories", .running, .mono)), .small))]
            card.append(Block(.bullets(fn.categories.map { Run([g($0.code, .running, .monoStrong), g(" "), c($0.name)]) })))
            card.append(Block(.text(Run(l("whereZtLands", .running, .mono)), .small)))
            card.append(Block(.text(Run(c(fn.ztLanding)), .body)))
            var rows: [Run] = []
            for p in content.pillars.canonical {
                guard let cell = store.cell(p.id, fn.id) else { continue }
                rows.append(Run([c(p.name, .running, .strong), g(": ", .running, .strong), c(Rules.firstSentence(cell.text).first)]))
            }
            card.append(Block(.bullets(rows)))
            out.append(Block(.group(card), anchor: "fn-\(fn.id.rawValue)"))
        }
        return out
    }

    mutating func ai() -> [Block] {
        var out = [sectionHead(.ai)]
        out.append(Block(.chips(content.ai.column.compactMap { chip($0.id) })))
        out.append(Block(.text(Run(c(content.ai.note)), .body), anchor: "ai-note"))
        out.append(Block(.heading(Run(l("socProfile")))))
        var rows: [KeyValue] = []
        for r in content.ai.socProfile {
            guard let fn = store.functions[r.functionId] else { continue }
            rows.append(KeyValue(key: Run(c(fn.name, .label, .strong)), value: Run(c(r.outcome))))
        }
        out.append(Block(.keyValues(rows), anchor: "soc"))
        return out
    }

    mutating func helper() -> [Block] {
        var items: [Disclosure] = []
        for h in content.helper {
            let basis = Run([l("basis", .running), g(": ")] + entityLinks(h.entityIds))
            items.append(Disclosure(summary: Run(c(h.question)), body: [Run(c(h.answer)), basis], identifier: "helper-\(h.id)"))
        }
        return [sectionHead(.helper), Block(.disclosures(items))]
    }

    mutating func statusKey() -> Block {
        let rows = Verification.Status.allCases.map { s -> (Badge, Run) in
            (Badge(status: s, run: Run(g(content.ui.status[s.rawValue] ?? s.rawValue, .label, .mono))),
             Run(l("statusKey" + s.rawValue.prefix(1).uppercased() + String(s.rawValue.dropFirst()), .running)))
        }
        return Block(.statusKey(title: Run(l("statusKeyTitle", .running, .strong)), rows: rows))
    }

    /// An entry's citation line: title, publisher, the edition as Rules.citeEdition gives it (left out where it repeats
    /// the title or the date, a descriptive one lowered), date.
    mutating func citeLine(_ e: Entity) -> Run {
        var spans = [c(e.title), g(". "), c(e.publisher), g(", ")]
        if let ed = Rules.citeEdition(title: e.title, edition: e.edition, date: e.date) { spans += [g(ed), g(", ")] }
        return Run(spans + [g(Rules.formatDate(e.date), .hard), g(".")])
    }

    mutating func entityBadges(_ e: Entity) -> [Badge] {
        var out = [badge(e.verification)].compactMap { $0 }
        if e.verification.status != .conflict && e.innerVerifications.contains(where: { $0.status == .conflict }) {
            out.append(Badge(status: .conflict, run: Run([g(content.ui.status["conflict"] ?? "", .label, .mono), g(": ", .label, .mono),
                                                             l("hasConflictInside", .label, .mono)])))
        }
        return out
    }

    mutating func sourcesSection() -> [Block] {
        var out = [sectionHead(.sources), Block(.text(Run(l("sourcesIntro", .running)), .body), anchor: "sources-intro"), statusKey()]
        for (key, items) in [("groupFrameworks", store.frameworks), ("groupSources", store.sources), ("groupSolutions", store.solutions)] where !items.isEmpty {
            out.append(Block(.heading(Run(l(key)))))
            var rows: [NavRow] = []
            for e in items {
                // the entry's title and short name name it: a label, as the web's summary title (session 11)
                var lines: [Run] = []
                if !e.name.contains(e.shortName) { lines.append(Run(paren(e.shortName, .label))) }
                lines.append(citeLine(e))
                rows.append(NavRow(title: Run(c(e.name, .label, .strong)), lines: lines, badges: entityBadges(e),
                                   target: .push(.entity(e.id)), identifier: "ent-row-\(e.id)"))
            }
            out.append(Block(.rows(rows)))
        }
        return out
    }

    mutating func glossary() -> [Block] {
        var items: [GlossaryItem] = []
        for t in store.terms {
            guard let g0 = content.glossary.first(where: { $0.term == t.term }) else { continue }
            items.append(glossaryItem(t, g0))
        }
        return [sectionHead(.glossary), Block(.text(Run(l("glossaryIntro", .running)), .body)), Block(.glossary(items), anchor: "glossary-list")]
    }

    mutating func glossaryItem(_ t: Rules.Term, _ entry: GlossaryEntry) -> GlossaryItem {
        var body: [Span] = []
        if let exp = t.expansion { body += [c(exp), g(". ")] }
        body.append(c(entry.oneLine))
        if !entry.entityIds.isEmpty { body += [g(" "), l("glossarySee", .running), g(": ")] + entityLinks(entry.entityIds) }
        return GlossaryItem(anchor: "gl-\(t.slug)", term: Run(c(t.term, .glossaryTerm, .monoStrong)), body: Run(body), badge: badge(entry.verification))
    }

    mutating func glossaryEntry(_ slug: String) -> Page {
        guard let t = store.terms.first(where: { $0.slug == slug }), let entry = content.glossary.first(where: { $0.term == t.term }) else {
            return Page(title: store.navTitle(.glossary), blocks: [])
        }
        let item = glossaryItem(t, entry)
        return Page(title: t.term, blocks: [
            Block(.glossary([item])),
            Block(.controls([Control(label: Run(l("glossaryOpen")), target: .section(.glossary, anchor: item.anchor), identifier: "glossary-open")])),
        ])
    }

    mutating func about() -> [Block] {
        let meta = content.meta
        var out = [sectionHead(.about)]
        out.append(Block(.aboutHeader(name: Run(c(meta.name, .running, .strong)), version: Run(g(store.appVersion, .hard, .mono)))))
        // the content version and the date it was released, labeled (session 11: Q12, Q23); every space in the mono face
        out.append(Block(.text(Run([l("contentVersion", .running, .mono), g(" ", .running, .mono), g(meta.contentVersion, .hard, .mono),
                                     g(L("metaSeparator"), .running, .mono), l("releasedOn", .running, .mono), g(" ", .running, .mono),
                                     g(Rules.formatDate(meta.builtOn), .hard, .mono)]), .small), anchor: "about-version"))
        out.append(Block(.text(Run(c(meta.about.notAffiliated)), .body)))
        out.append(Block(.text(Run(l("dowNote", .running)), .small), anchor: "dow-note"))
        out.append(Block(.text(Run(c(content.orgs.dow.statusNote)), .small)))
        out.append(Block(.text(Run(c(meta.about.offline)), .body)))
        out.append(Block(.text(Run(c(meta.about.licensing)), .body), anchor: "licensing"))
        out.append(Block(.text(Run([l("counts", .running), g(":")]), .small)))
        out.append(Block(.badges(Verification.Status.allCases.map { s in
            Badge(status: s, run: Run([g(content.ui.status[s.rawValue] ?? s.rawValue, .label, .mono), g(" \(store.counts[s] ?? 0)", .hard, .mono)]))
        }), anchor: "counts"))
        out.append(statusKey())
        if !store.maker.isEmpty {
            out.append(Block(.text(Run([l("madeBy", .running), g(" "), g(store.maker, .hard)]), .small), anchor: "made-by"))
        }
        out.append(Block(.text(Run(c(meta.about.builtWith)), .small)))
        out.append(Block(.links([
            Control(label: Run(l("pagesPrivacy")), target: .external(Site.privacy), identifier: "link-privacy"),
            Control(label: Run(l("pagesSupport")), target: .external(Site.support), identifier: "link-support"),
            Control(label: Run(l("sourceCode")), target: .external(Site.source), identifier: "link-source"),
        ]), anchor: "links"))
        out.append(Block(.text(Run(l("footerLicenses", .label, .mono)), .small)))
        if let story = meta.about.nameStory, !story.isEmpty {
            out.append(Block(.story(heading: Run(l("whyNameHeading")), photoAlt: L("aboutPhotoAlt"), paragraphs: story.map { Run(c($0)) }),
                             anchor: "about-name"))
        }
        return out
    }

    // MARK: pushed screens

    mutating func route(_ r: Route) -> Page {
        switch r {
        case .door(let id): return door(id)
        case .layer(let id): return layer(id)
        case .entity(let id): return entity(id)
        case .cell(let view, let pillar, let fn): return cell(view, pillar, fn)
        }
    }

    mutating func door(_ id: String) -> Page {
        guard let door = content.doors.first(where: { $0.id.rawValue == id }) else { return Page(title: "", blocks: []) }
        var out = [Block(.title(Run(c(door.title, .label))))]
        let who = Rules.firstSentence(door.whoYouAre)
        out.append(Block(.text(Run(who.rest.isEmpty ? [c(who.first)] : [c(who.first), g(" "), c(who.rest)]), .lede)))
        if let para = door.paragraph.value {
            // the whole paragraph: on the web a door with no steps shows its first sentence as the card's meta line, in
            // the same opened card as the rest; here the card and the door are two screens, so the door repeats it
            let split = Rules.firstSentence(para)
            let spans = split.rest.isEmpty ? [c(split.first)] : [c(split.first), g(" "), c(split.rest)]
            out.append(Block(.text(Run(spans), .body)))
        }
        if !door.steps.isEmpty {
            out.append(Block(.heading(Run(l("steps")))))
            let steps = door.steps.map { s in
                StepItem(tag: layerTag(s.layerId), text: Run(c(s.text)), links: Run(entityLinks(s.entityIds)))
            }
            out.append(Block(.steps(steps), anchor: "steps"))
        }
        for ld in door.landings ?? [] {
            out.append(Block(.heading(Run(c(ld.label, .label))), anchor: "landing-\(ld.id)"))
            out.append(Block(.text(Run([c(ld.text), g(" ")] + entityLinks(ld.entityIds)), .body)))
        }
        return Page(title: door.title, blocks: out)
    }

    mutating func layer(_ id: String) -> Page {
        guard let layer = store.layers[id] else { return Page(title: "", blocks: []) }
        var title = [c(layer.name, .label, .monoStrong)]
        if !layer.isColumn { title = [g(String(format: "%02d", layer.order), .hard, .monoStrong), g(" ", .label)] + title }
        var out = [Block(.title(Run(title))), Block(.text(Run(c(layer.question)), .question)), Block(.text(Run(c(layer.oneLiner)), .body))]
        if layer.isColumn {
            out.append(Block(.chips(content.ai.column.compactMap { chip($0.id) })))
        } else {
            let ids = layer.frameworkIds + store.sources.filter { $0.layerId == layer.id }.map(\.id)
            out.append(Block(.chips(ids.compactMap { chip($0) })))
            let sols = store.solutions.filter { $0.layerId == layer.id }
            if !sols.isEmpty {
                out.append(Block(.text(Run(l("solutionsOnLayer", .running)), .small)))
                out.append(Block(.chips(sols.compactMap { chip($0.id) })))
            }
        }
        return Page(title: layer.name, blocks: out)
    }

    mutating func authority(_ a: Authority) -> [KeyValue] {
        var deadline: [Span]
        if let d = a.deadline.value {
            deadline = [c(d.text), g(" (")] + entityLinks([d.sourceId]) + [g(")")]
        } else {
            deadline = [l("noDeadline", .running)]
        }
        let binds = a.binds.enumerated().flatMap { i, b in (i > 0 ? [g("; ")] : []) + [c(content.ui.binds[b.rawValue] ?? b.rawValue)] }
        var note = KeyValue(key: Run(l("note", .running, .strong)), value: Run(linked(a.note)), badges: [badge(a.verification)].compactMap { $0 })
        if [.conflict, .unverified].contains(a.verification.status) { note.extra = Run(linked(a.verification.note)) }
        return [KeyValue(key: Run(l("nature", .running, .strong)), value: Run(c(content.ui.nature[a.nature.rawValue] ?? a.nature.rawValue))),
                KeyValue(key: Run(l("binds", .running, .strong)), value: Run(binds)),
                KeyValue(key: Run(l("deadline", .running, .strong)), value: Run(deadline)),
                note]
    }

    /// An entry of Sources, as the web lays it out: the name, badges and citation, the one-liner, what it answers or
    /// its role, its layer, what it was assessed against and what an adopter still owns, the authority fields, the
    /// citation fields with the link to the primary, the documents, and the note.
    mutating func entity(_ id: String) -> Page {
        guard let e = store.entities[id] else { return Page(title: "", blocks: []) }
        // the entry's title and short name name it: labels, as the web's summary title, and, as there, described by the
        // expansions of their abbreviations rather than linked (session 11)
        var out = [Block(.title(Run(c(e.name, .describedLabel))))]
        if !e.name.contains(e.shortName) { out.append(Block(.text(Run(paren(e.shortName, .describedLabel)), .small))) }
        out.append(Block(.badges(entityBadges(e))))
        out.append(Block(.text(citeLine(e), .small), anchor: "cite"))
        out.append(Block(.text(Run(c(e.oneLiner)), .lede)))
        if let a = e.answersQuestion { out.append(Block(.text(Run([l("answers", .running, .strong), g(": ", .running, .strong), c(a)]), .body))) }
        if let r = e.role { out.append(Block(.text(Run([l("role", .running, .strong), g(": ", .running, .strong), c(r)]), .body))) }
        if let lid = e.layerId, let tag = layerTag(lid), let layer = store.layers[lid] {
            // the AI column's tag is its name, so its name is not repeated
            out.append(Block(.tagLine(tag, layer.isColumn ? nil : Run(c(layer.name)))))
        }
        if let va = e.validatedAgainst {
            var spans = [l("validatedAgainst", .running, .strong), g(": ", .running, .strong)] + entityLinks([va.entityId])
            spans += [g(". "), c(va.scope)]
            out.append(Block(.keyValues([KeyValue(key: Run(spans), value: Run(linked(va.verification.note)), badges: [badge(va.verification)].compactMap { $0 })]),
                             anchor: "validated"))
        }
        if let rs = e.adopterResponsibilities, !rs.isEmpty {
            out.append(Block(.text(Run(l("adopterResponsibilities", .running, .strong)), .body)))
            out.append(Block(.keyValues(rs.map { r in
                KeyValue(key: Run(c(r.text)), value: Run(linked(r.verification.note)), badges: [badge(r.verification)].compactMap { $0 })
            }), anchor: "adopter"))
        }
        out.append(Block(.keyValues(authority(e.authority)), anchor: "authority"))
        var kv = [KeyValue(key: Run(l("publisher", .running, .strong)), value: Run(c(e.publisher)))]
        if let authors = e.authors { kv.append(KeyValue(key: Run(l("authors", .running, .strong)), value: Run(g(authors.joined(separator: ", "))))) }
        if let lic = e.license {
            var v = [g(lic)]
            if e.attributionRequired == true { v += [g(" ("), l("attribution", .running), g(")")] }
            kv.append(KeyValue(key: Run(l("license", .running, .strong)), value: Run(v)))
        }
        kv.append(KeyValue(key: Run(l("edition", .running, .strong)), value: Run(c(e.edition))))
        kv.append(KeyValue(key: Run(l("date", .running, .strong)), value: Run(g(Rules.formatDate(e.date), .hard))))
        if let url = URL(string: e.url) {
            var value = Run(c(e.url, .hard, .url, link: .external(url)))
            // the address stays on screen, as on the web; VoiceOver names its site ("Primary: cisa.gov")
            if let host = url.host() { value.spoken = "\(L("primary")): \(host.hasPrefix("www.") ? String(host.dropFirst(4)) : host)" }
            kv.append(KeyValue(key: Run(l("primary", .running, .strong)), value: value))
        }
        kv.append(KeyValue(key: Run(l("verification", .running, .strong)), value: Run(linked(e.verification.note)), badges: [badge(e.verification)].compactMap { $0 }))
        out.append(Block(.keyValues(kv), anchor: "fields"))
        if let docs = e.documents, !docs.isEmpty {
            out.append(Block(.text(Run(l("documents", .running, .strong)), .body)))
            var items: [KeyValue] = []
            for doc in docs {
                var head = [c(doc.title), g(", ")]
                if let ed = Rules.citeEdition(title: doc.title, edition: doc.edition, date: doc.date) { head += [g(ed), g(", ")] }
                head += [g(Rules.formatDate(doc.date), .hard), g(".")]
                if let a = doc.authors { head += [g(" "), l("authors", .running), g(": "), g(a.joined(separator: "; ")), g(".")] }
                var value: [Span] = []
                if let url = URL(string: doc.url) { value.append(g(L("primary"), .label, .plain, link: .external(url))) }
                if let note = doc.note { value += [g(" ")] + linked(note) }
                var item = KeyValue(key: Run(head), value: Run(value), badges: [badge(doc.verification)].compactMap { $0 })
                // a document badged Unverified or Conflict shows its verification note beside the badge, as the status key
                // promises and as an authority's note does (session 11, SK-004)
                if [.conflict, .unverified].contains(doc.verification.status), !doc.verification.note.isEmpty {
                    item.extra = Run(linked(doc.verification.note))
                }
                items.append(item)
            }
            out.append(Block(.keyValues(items), anchor: "documents"))
        }
        if let note = e.note { out.append(Block(.text(Run(linked(note)), .small), anchor: "note")) }
        return Page(title: e.shortName, blocks: out)
    }

    mutating func cell(_ view: PillarView, _ pillarId: String, _ fnId: FunctionID) -> Page {
        guard let cell = store.cell(pillarId, fnId), let fn = store.functions[fnId],
              let col = store.columns(view).first(where: { $0.id == pillarId }) else { return Page(title: "", blocks: []) }
        var title = [c(col.name, .label)]
        if col.crossCutting { title += [g(" (", .label), l("crossCutting"), g(")", .label)] }
        var out = [Block(.title(Run(title))),
                   Block(.text(Run([g(fn.id.rawValue, .hard, .monoStrong), g(" ", .label, .mono), c(fn.name, .label, .mono)]), .small)),
                   Block(.text(Run(c(cell.text)), .body), anchor: "cell-text"),
                   Block(.text(Run([l("categories", .running, .strong), g(": ", .running, .strong), g(cell.categories.joined(separator: ", "), .hard, .mono)]), .small))]
        let caps = cell.capabilityIds ?? []
        if !caps.isEmpty {
            let names = caps.map { "\($0) \(store.capabilityNames[$0] ?? "")".trimmingCharacters(in: .whitespaces) }.joined(separator: "; ")
            // the capability names name things: a label, as the web's caps-list (session 11)
            out.append(Block(.text(Run([l(view == .dow ? "capabilities" : "capabilitiesDow", .label, .strong), g(": ", .label, .strong), g(names, .label)]), .small)))
        }
        return Page(title: col.name, blocks: out)
    }
}
