import SwiftUI

/// One framework (Lensatic 2.0, Round 1): what it is for, before what it says; the countdown where it has a dated
/// deadline; the card's facts in full, who it binds, how it is verified, how big it is and where it sits; then its real
/// structure, its baselines, the check and the comparisons that use it, the frameworks it connects to, and its sources
/// and terms. A system inset-grouped list on the app's own surfaces.
struct FrameworkDetailView: View {
    @Environment(AppModel.self) private var model
    let id: String
    var today = Date()

    var body: some View {
        let L = model.frameworks
        if let f = L.byId[id], let graph = L.graphs[id] {
            let deadline = L.upcoming(f, store: model.store, today: today)
            ListScreen(eyebrow: L.group(f.group)?.name, eyebrowColor: f.tone, title: f.name, identifier: "framework-screen", saves: .framework(f.id)) {
                SwiftUI.Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 10) {
                            FrameworkTile(framework: f)
                            Eyebrow(text: f.kind, color: f.tone, small: true)
                        }
                        Text(f.purpose).font(DS.style(.headline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("framework-purpose")
                        Text(f.what).font(DS.style(.subheadline)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                        // what the screen does not show, said at the top and not left for the reader to find out
                        if let note = f.note ?? (f.nodes.isEmpty ? L.label("cardOnly") : nil) {
                            Label {
                                Text(note).font(DS.style(.subheadline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "info.circle").foregroundStyle(f.tone).accessibilityHidden(true)
                            }
                            .accessibilityIdentifier("framework-note")
                        }
                        if !f.compliance {
                            Label(L.label("notCompliance"), systemImage: "exclamationmark.circle")
                                .font(DS.style(.footnote).weight(.semibold)).foregroundStyle(f.tone)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("framework-not-compliance")
                        }
                    }
                    .padding(.vertical, 4)
                }
                if let deadline, let days = deadline.days(from: today) {
                    SwiftUI.Section {
                        CountdownCard(deadline: deadline, days: days, tone: f.tone, eyebrow: L.label("countdown"), radius: LxCard.inList(18))
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color.clear)
                            .accessibilityIdentifier("framework-countdown")
                    }
                }
                SwiftUI.Section {
                    FactRow(label: L.label("binds"), short: f.binds.short, line: f.binds.line)
                    FactRow(label: L.label("verified"), short: f.verifiedBy.short, line: f.verifiedBy.line)
                    FactRow(label: L.label("size"), short: f.size.map { "\(Rules.grouped($0.count)) \($0.unit)" }.joined(separator: model.store.label("metaSeparator")), line: nil)
                    HStack(alignment: .top, spacing: 12) {
                        FactRow(label: L.label("sits"), short: model.sitsLabel(f), line: f.sits.line)
                        StackGlyph(framework: f, width: 34).padding(.top, 4)
                    }
                    .accessibilityElement(children: .combine)
                    // one layer model (Round 2): each layer it sits on opens that layer of the map, where this card is listed too
                    ForEach(model.store.content.layers.filter { f.sits.layers.contains($0.id) }.sorted { $0.order < $1.order }, id: \.id) { layer in
                        NavigationLink(value: Nav.layer(layer.id)) {
                            TileRow(icon: layer.isColumn ? RowIcon.aiColumn : RowIcon.layer(layer.order),
                                    title: layer.isColumn ? TitleCase.apply(layer.name) : "\(model.store.label("layer")) \(layer.order): \(TitleCase.apply(layer.name))",
                                    subtitle: L.label("onTheStack"))
                        }
                        .accessibilityIdentifier("framework-layer-\(layer.id)")
                    }
                } header: {
                    ListNote(L.label("atAGlance"))
                }
                if !graph.roots.isEmpty, let depth = f.depth.value {
                    // the top of the structure, a section for each level that has one (FedRAMP has its indicator themes
                    // and its rulesets); the level that holds more beneath it comes first, and the last says how much is shown
                    let tops = FrameworkDetailView.topLevels(f, graph)
                    ForEach(Array(tops.enumerated()), id: \.element.level.id) { i, top in
                        SwiftUI.Section {
                            ForEach(top.nodes) { node in NodeRow(framework: f, graph: graph, node: node) }
                        } header: {
                            ListNote(tops.count == 1 ? L.label("structure") : "\(L.label("structure")): \(top.nodes.count) \(top.nodes.count == 1 ? top.level.name : top.level.plural)")
                        } footer: {
                            if i == tops.count - 1 { ListNote(FrameworkDetailView.depthLine(depth, labels: L)).accessibilityIdentifier("framework-depth") }
                        }
                    }
                }
                if !f.sets.isEmpty {
                    SwiftUI.Section {
                        ForEach(f.sets) { set in
                            NavigationLink(value: Nav.baseline(f.id, set.id)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(set.name).font(DS.style(.body)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                        Text(Rules.grouped(set.members.count)).font(DS.style(.body)).foregroundStyle(Palette.fg2)
                                    }
                                    if let line = set.line {
                                        Text(line).font(DS.style(.footnote)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("baseline-row-\(set.id)")
                        }
                    } header: {
                        ListNote(f.setsTitle ?? L.label("baselines"))
                    } footer: {
                        if let line = f.setsLine {
                            ListNote(line)
                        } else if let host = f.sets.first.flatMap({ L.byId[$0.of] }) {
                            ListNote(L.label("baselinesOn").replacingOccurrences(of: "{name}", with: host.shortName))
                        }
                    }
                }
                let checks = L.checks(on: f.id), comparisons = L.comparisons(with: f.id)
                SwiftUI.Section {
                    ForEach(checks) { check in
                        NavigationLink(value: Nav.check(check.id)) {
                            TileRow(icon: ("checklist", .green), title: checks.count == 1 ? L.label("checkYourself") : (check.short ?? check.title), subtitle: check.line)
                        }
                        .accessibilityIdentifier(checks.count == 1 ? "framework-check" : "framework-check-\(check.id)")
                    }
                    ForEach(comparisons) { c in
                        if let other = L.byId[c.a == f.id ? c.b : c.a] {
                            NavigationLink(value: Nav.compare(c.id)) {
                                TileRow(icon: ("rectangle.split.2x1.fill", .indigo),
                                        title: c.a == c.b ? (c.title ?? "\(c.aName ?? "") \(L.label("with")) \(c.bName ?? "")") : "\(L.label("compareWith")) \(other.shortName)")
                            }
                            .accessibilityIdentifier("framework-compare-\(c.id)")
                        }
                    }
                    // Round 2: this card beside any other, picked in Compare
                    Button { model.compareA = f.id; model.compareB = nil; model.showFrameworks(.compare) } label: {
                        HStack(spacing: 8) {
                            TileRow(icon: ("rectangle.split.2x1", .indigo), title: L.label("compareAnother"))
                            Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("framework-compare-any")
                } header: {
                    ListNote(L.label("useIt"))
                }
                if !f.related.isEmpty || f.chapterId != nil {
                    SwiftUI.Section {
                        if let chapter = f.chapterId.flatMap({ model.library.guide.chapter($0) }) {
                            NavigationLink(value: Nav.chapter(chapter.id)) {
                                TileRow(icon: RowIcon.guide, title: chapter.displayTitle, subtitle: L.label("inFieldGuide"))
                            }
                            .accessibilityIdentifier("framework-chapter")
                        }
                        ForEach(f.related, id: \.id) { r in
                            if let other = L.byId[r.id] { FrameworkRow(framework: other, line: r.line) }
                        }
                    } header: {
                        ListNote(L.label("connects"))
                    }
                }
                SwiftUI.Section {
                    if let entity = f.entityId.flatMap({ model.store.entities[$0] }) {
                        // the stack entry's own citation, in the same shape as the framework's sources, then the way to its card
                        SourceRows(source: Framework.SourceRecord(id: entity.id, publisher: entity.publisher, title: entity.title, edition: entity.edition,
                                                                  date: entity.date, url: entity.url, pdf: entity.pdf, verification: entity.verification), tone: f.tone)
                        NavigationLink(value: Nav.entity(entity.id)) {
                            TileRow(icon: RowIcon.maps, title: L.label("onTheMap"), subtitle: L.label("onTheMapLine"))
                        }
                        .accessibilityIdentifier("framework-entity")
                    }
                    ForEach(f.sources) { s in SourceRows(source: s, tone: f.tone) }
                } header: {
                    ListNote(L.label("sources"))
                }
                SwiftUI.Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(f.terms.line).font(DS.style(.subheadline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                        if let notice = f.terms.notice.value {
                            Text(notice).font(DS.style(.footnote)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("framework-notice")
                        }
                    }
                    .padding(.vertical, 2)
                    if let url = f.terms.url.value.flatMap(URL.init(string:)) {
                        Button { Reader.open(url) } label: {
                            Text(L.label("openTerms")).font(DS.style(.body)).foregroundStyle(Palette.link)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("framework-terms-link")
                    }
                } header: {
                    ListNote(L.label("terms"))
                }
            }
        }
    }

    /// The structure's top nodes by level, the levels with nodes beneath them first.
    static func topLevels(_ f: Framework, _ graph: FrameworkLibrary.Graph) -> [(level: Framework.Level, nodes: [Framework.Node])] {
        let groups = f.levels.compactMap { lv -> (level: Framework.Level, nodes: [Framework.Node])? in
            let nodes = graph.roots.filter { $0.level == lv.id }
            return nodes.isEmpty ? nil : (lv, nodes)
        }
        func deep(_ g: (level: Framework.Level, nodes: [Framework.Node])) -> Bool { g.nodes.contains { !graph.children(of: $0.id).isEmpty } }
        return groups.filter(deep) + groups.filter { !deep($0) }
    }

    /// "106 of 106 Subcategories", and why when the app shows fewer than the publisher has.
    static func depthLine(_ d: Framework.Depth, labels L: FrameworkLibrary) -> String {
        let count = L.label("shownOf").replacingOccurrences(of: "{shown}", with: Rules.grouped(d.shown))
            .replacingOccurrences(of: "{of}", with: Rules.grouped(d.of)).replacingOccurrences(of: "{unit}", with: d.unit)
        return [count, d.why.value].compactMap { $0 }.joined(separator: " ")
    }
}

/// A card fact in full: its label, the card's two or three words, and the sentence behind them.
struct FactRow: View {
    let label: String
    let short: String
    let line: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(DS.style(.footnote)).foregroundStyle(Palette.fg2)
            Text(short).font(DS.style(.headline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            if let line { Text(line).font(DS.style(.subheadline)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// A node as a row: its identifier as the publisher prints it, its title or sentence, and how many it holds; opens it.
struct NodeRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let framework: Framework
    let graph: FrameworkLibrary.Graph
    let node: Framework.Node
    /// The count of what the node holds, shown where the row sits in its own structure; a row in a baseline or under a
    /// crosswalk leaves it out, since the number is the catalog's, not the list's.
    var counts = true

    var body: some View {
        let kids = counts ? graph.children(of: node.id).count : 0
        NavigationLink(value: Nav.node(framework.id, node.id)) {
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))) {
                if graph.identified(node) { NodeBadge(id: node.id, tone: framework.tone) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(graph.line(node)).font(DS.style(.body)).foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                    // a row that carries both a title and a note says the note (an activity's level, a task's level)
                    if let note = node.note, node.title != nil, graph.children(of: node.id).isEmpty {
                        Text(note).font(DS.style(.footnote)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if kids > 0, !typeSize.isAccessibilitySize {
                    Text("\(kids)").font(DS.style(.body)).foregroundStyle(Palette.fg2)
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("node-row-\(node.id)")
    }
}

/// One node of a framework's structure: its identifier and the publisher's words, the nodes under it, and its
/// connections: the nodes a published crosswalk points it at, the baselines that select it, and the nodes elsewhere that
/// point at it.
struct NodeView: View {
    @Environment(AppModel.self) private var model
    let frameworkId: String
    let nodeId: String

    var body: some View {
        let L = model.frameworks
        if let f = L.byId[frameworkId], let graph = L.graphs[frameworkId], let node = graph.node(nodeId) {
            let level = graph.level(node.level)
            let kids = graph.children(of: node.id)
            // where the node sits: the framework, its level, and for a deeper node the one above it ("CISA ZTMM · Stage · Authentication")
            let parent = node.parents.first.flatMap { graph.node($0) }
            let above = graph.identified(node) ? nil : parent.flatMap { p in graph.identified(p) ? nil : p.title }
            ListScreen(eyebrow: dotted([f.shortName, node.title == nil && graph.identified(node) ? nil : level?.name, above].compactMap { $0 }, separator: model.store.label("metaSeparator")),
                       eyebrowColor: f.tone,
                       // a node the publisher gives only a sentence is named by its level: "Subcategory GV.OC-01"; one at a
                       // level the publisher does not number is named by its title alone
                       title: !graph.identified(node) ? (node.title ?? "") : node.title.map { "\(node.id) \($0)" } ?? "\(level?.name ?? "") \(node.id)",
                       identifier: "node-screen") {
                if node.text != nil || node.note != nil {
                    SwiftUI.Section {
                        VStack(alignment: .leading, spacing: 6) {
                            if let text = node.text {
                                Text(text).font(DS.style(.body)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("node-text")
                            }
                            if let note = node.note {
                                Text(note).font(DS.style(.subheadline).weight(.semibold)).foregroundStyle(f.tone)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("node-note")
                            }
                        }
                        .padding(.vertical, 4)
                    } footer: {
                        if node.text != nil, let s = f.sources.first { ListNote(dotted([s.publisher, s.edition], separator: model.store.label("metaSeparator"))) }
                    }
                }
                // a set this node stands for (CMMC's Level 2 is the set of that name): the way to its members
                ForEach(f.sets.filter { $0.id == node.id }) { set in
                    SwiftUI.Section {
                        NavigationLink(value: Nav.baseline(f.id, set.id)) {
                            HStack {
                                Text(set.title ?? set.name).font(DS.style(.body)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Text(Rules.grouped(set.members.count)).font(DS.style(.body)).foregroundStyle(Palette.fg2)
                            }
                        }
                        .accessibilityIdentifier("node-set-\(set.id)")
                    }
                }
                if !kids.isEmpty {
                    // the children, grouped by level where a node holds more than one (a control's enhancements)
                    ForEach(f.levels.filter { lv in kids.contains { $0.level == lv.id } }, id: \.id) { lv in
                        let rows = kids.filter { $0.level == lv.id }
                        SwiftUI.Section {
                            ForEach(rows) { NodeRow(framework: f, graph: graph, node: $0) }
                        } header: {
                            ListNote("\(rows.count) \(rows.count == 1 ? lv.name : lv.plural)")
                        }
                    }
                }
                ForEach(Array(f.crosswalks.enumerated()), id: \.offset) { _, walk in
                    if let targets = walk.map[node.id], let host = L.byId[walk.to], let hostGraph = L.graphs[walk.to] {
                        SwiftUI.Section {
                            if !walk.isListed {
                                // identifiers of a standard Lensatic does not list: shown as the source prints them, opening nothing
                                VStack(alignment: .leading, spacing: 8) {
                                    FlowBadges(ids: targets, tone: host.tone)
                                    Text(L.label("unlistedLine").replacingOccurrences(of: "{name}", with: host.shortName))
                                        .font(DS.style(.footnote)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, 2)
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("node-unlisted-\(walk.to)")
                                NavigationLink(value: Nav.framework(host.id)) {
                                    HStack(spacing: 12) {
                                        FrameworkTile(framework: host, base: 30)
                                        Text(keepDesignations(host.shortName)).font(DS.style(.body)).foregroundStyle(.primary)
                                    }
                                }
                                .accessibilityIdentifier("node-unlisted-open-\(walk.to)")
                            }
                            ForEach(walk.isListed ? targets : [], id: \.self) { t in
                                if let target = hostGraph.node(t) {
                                    NodeRow(framework: host, graph: hostGraph, node: target, counts: false)
                                } else {
                                    VStack(alignment: .leading, spacing: 2) {
                                        NodeBadge(id: t, tone: host.tone)
                                        Text(L.label("notInCatalog")).font(DS.style(.footnote)).foregroundStyle(Palette.fg2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityIdentifier("node-unresolved-\(t)")
                                }
                            }
                        } header: {
                            ListNote("\(walk.edition): \(targets.count) \(walk.relations(targets.count))")
                        } footer: {
                            if let s = f.sources.first(where: { $0.id == walk.sourceId }) {
                                ListNote(dotted([s.publisher, SourceRows.checked(s.verification, store: model.store, labels: L)], separator: model.store.label("metaSeparator")))
                            }
                        }
                    }
                }
                // a node Lensatic lists by title says where its text is, and every node ends in the way to its source
                if let s = f.sources.first {
                    SwiftUI.Section {
                        if node.text == nil, f.terms.shows == .titles, graph.identified(node) {
                            Text(L.label("textAtSource")).font(DS.style(.subheadline)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("node-text-at-source")
                        }
                        SourceRows(source: s, tone: f.tone)
                    } header: {
                        ListNote(L.label("sources"))
                    }
                }
                let memberships = L.memberships(of: node.id, in: f.id)
                if !memberships.isEmpty {
                    SwiftUI.Section {
                        ForEach(Array(memberships.enumerated()), id: \.offset) { _, m in
                            NavigationLink(value: Nav.baseline(m.framework.id, m.set.id)) {
                                HStack(spacing: 12) {
                                    FrameworkTile(framework: m.framework, base: 30)
                                    Text(m.set.title ?? "\(m.framework.shortName) \(m.set.name)").font(DS.style(.body)).foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .accessibilityIdentifier("membership-\(m.framework.id)-\(m.set.id)")
                        }
                    } header: {
                        ListNote(memberships.allSatisfy { $0.set.title == nil } ? L.label("inBaselines") : L.label("inSets"))
                    }
                }
                ForEach(Array(L.referrers(to: node.id, in: f.id).enumerated()), id: \.offset) { _, r in
                    if let from = L.graphs[r.framework.id] {
                        SwiftUI.Section {
                            ForEach(r.nodes.compactMap { from.node($0) }) { NodeRow(framework: r.framework, graph: from, node: $0, counts: false) }
                        } header: {
                            ListNote("\(L.label("referencedBy")) \(r.framework.shortName): \(r.nodes.count)")
                        }
                    }
                }
            }
        }
    }
}

/// A baseline: a named selection of another framework's nodes, grouped by that framework's top level, each group with
/// its count. Says how many of how many it selects.
struct BaselineView: View {
    @Environment(AppModel.self) private var model
    let frameworkId: String
    let setId: String

    var body: some View {
        let L = model.frameworks
        if let f = L.byId[frameworkId], let set = f.sets.first(where: { $0.id == setId }), let host = L.byId[set.of], let graph = L.graphs[set.of] {
            let groups = graph.grouped(set.members)
            ListScreen(eyebrow: f.shortName, eyebrowColor: f.tone, title: set.title ?? "\(set.name) \(L.label("baseline"))", identifier: "baseline-screen") {
                SwiftUI.Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(BaselineView.countLine(set, host: host, graph: graph, labels: L)).font(DS.style(.headline)).foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("baseline-count")
                        if let line = set.line {
                            Text(line).font(DS.style(.subheadline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("baseline-line")
                        }
                        if let s = f.sources.first(where: { $0.id == set.sourceId }) {
                            Text(dotted([s.publisher, s.edition, SourceRows.checked(s.verification, store: model.store, labels: L)], separator: model.store.label("metaSeparator")))
                                .font(DS.style(.footnote)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)
                }
                ForEach(groups, id: \.top.id) { group in
                    SwiftUI.Section {
                        ForEach(group.nodes) { NodeRow(framework: host, graph: graph, node: $0, counts: false) }
                    } header: {
                        ListNote("\(graph.name(group.top)): \(group.nodes.count)")
                            .accessibilityIdentifier("baseline-group-\(group.top.id)")
                    }
                }
            }
        }
    }

    /// "410 of 1,014 controls and enhancements in SP 800-53".
    static func countLine(_ set: Framework.NodeSet, host: Framework, graph: FrameworkLibrary.Graph, labels L: FrameworkLibrary) -> String {
        guard let depth = host.depth.value else { return Rules.grouped(set.members.count) }
        var of = depth.of, name = host.shortName
        // a set drawn from one edition of its host (CMMC's levels, from SP 800-171 Revision 2) is counted against that
        // edition, not against every edition the file holds
        let tops = Set(set.members.compactMap { graph.top(of: $0) })
        if tops.count == 1, let top = tops.first.flatMap({ graph.node($0) }), !graph.identified(top), let title = top.title {
            let levels = Set(set.members.compactMap { graph.node($0)?.level })
            of = graph.descendants(of: top.id).filter { levels.contains($0.level) }.count
            name = "\(host.shortName) \(title)"
        }
        return L.label("baselineCount").replacingOccurrences(of: "{n}", with: Rules.grouped(set.members.count))
            .replacingOccurrences(of: "{of}", with: Rules.grouped(of)).replacingOccurrences(of: "{unit}", with: depth.unit)
            .replacingOccurrences(of: "{name}", with: name)
    }
}

/// Identifiers as chips that wrap onto as many lines as they need (the references to a standard Lensatic does not list).
struct FlowBadges: View {
    let ids: [String]
    let tone: Color

    var body: some View {
        FlowLayout {
            ForEach(ids, id: \.self) { NodeBadge(id: $0, tone: tone) }
        }
    }
}
