import SwiftUI

/// One honest comparison (Lensatic 2.0, Round 1): the same questions asked of each framework, purpose, who must follow
/// it, how it is assessed, where it sits and how big it is; how the two connect; and where their elements overlap, counted
/// from a crosswalk the publisher itself prints. No score: two frameworks on different layers are not stricter or looser
/// than each other, and the screen says so.
struct CompareView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The two cards, and the comparison the content writes for them where it has one (Round 2: any two cards compare;
    /// a named comparison adds its own verdict, its rows and how the two connect).
    let a: String
    let b: String
    let named: Comparison?

    /// A named comparison, by its id.
    init(id: String, in L: FrameworkLibrary) {
        let c = L.comparison(id)
        a = c?.a ?? ""
        b = c?.b ?? ""
        named = c
    }

    /// Any two cards, in the order picked; the named comparison of the two, where there is one, keeps its own order.
    init(a: String, b: String, in L: FrameworkLibrary) {
        if let c = L.named(a, b) {
            self.a = c.a
            self.b = c.b
            named = c
        } else {
            self.a = a
            self.b = b
            named = nil
        }
    }

    var body: some View {
        let L = model.frameworks
        if let fa = L.byId[a], let fb = L.byId[b] {
            let overlap = model.screen("overlap-\(a)-\(b)") { L.overlap(a, b) }
            let wide = sizeClass == .regular && !typeSize.isAccessibilitySize
            let nameA = named?.aName ?? fa.shortName, nameB = named?.bName ?? fb.shortName
            ListScreen(eyebrow: L.label("compare"), eyebrowColor: Palette.fg2,
                       title: "\(nameA) \(L.label("with")) \(nameB)", identifier: "compare-screen") {
                SwiftUI.Section {
                    VStack(alignment: .leading, spacing: 10) {
                        ComparePair(a: fa, b: fb, nameA: named?.aName, nameB: named?.bName)
                        if let verdict = named?.verdict {
                            Text(verdict).font(DS.style(.headline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("compare-verdict")
                        }
                    }
                    .padding(.vertical, 4)
                }
                SwiftUI.Section {
                    ForEach(rows(fa, fb), id: \.label) { row in CompareRow(row: row, a: fa, b: fb, nameA: nameA, nameB: nameB, wide: wide) }
                    if a != b {
                        CompareRow(row: .init(label: L.label("sits"), a: model.sitsLabel(fa), b: model.sitsLabel(fb)), a: fa, b: fb, nameA: nameA, nameB: nameB, wide: wide)
                        CompareRow(row: .init(label: L.label("size"), a: CompareView.size(fa), b: CompareView.size(fb)), a: fa, b: fb, nameA: nameA, nameB: nameB, wide: wide)
                    }
                } header: {
                    ListNote(L.label("sideBySide"))
                }
                SwiftUI.Section {
                    Text(connect(fa, fb)).font(DS.style(.body)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 4)
                        .accessibilityIdentifier("compare-connect")
                } header: {
                    ListNote(L.label("howTheyConnect"))
                }
                if let overlap {
                    SwiftUI.Section {
                        Text(named?.overlapLine ?? L.label("overlapGeneric").replacingOccurrences(of: "{publisher}", with: publisher(overlap)))
                            .font(DS.style(.subheadline)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 2)
                        ForEach(overlap.rows) { row in OverlapRow(row: row, overlap: overlap) }
                        Text(CompareView.reachedLine(overlap, labels: L)).font(DS.style(.subheadline).weight(.semibold)).foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 2)
                            .accessibilityIdentifier("compare-reached")
                    } header: {
                        ListNote(L.label("whereTheyOverlap"))
                    } footer: {
                        if let s = overlap.from.sources.first(where: { $0.id == overlap.crosswalk.sourceId }) {
                            ListNote(dotted([s.publisher, overlap.crosswalk.edition, SourceRows.checked(s.verification, store: model.store, labels: L)],
                                            separator: model.store.label("metaSeparator")))
                        }
                    }
                } else if a == b, let line = named?.overlapLine {
                    // two parts of one framework: how much of each of its sets its own crosswalk names
                    let sets = L.setOverlap(fa)
                    if !sets.isEmpty, let walk = fa.crosswalks.first, let host = L.byId[walk.to] {
                        SwiftUI.Section {
                            Text(line).font(DS.style(.subheadline)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                                .padding(.vertical, 2)
                            ForEach(sets) { o in
                                NavigationLink(value: Nav.baseline(fa.id, o.selection.id)) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(o.selection.name).font(DS.style(.body)).foregroundStyle(.primary)
                                        Text(L.label("setOverlapRow").replacingOccurrences(of: "{n}", with: Rules.grouped(o.named))
                                            .replacingOccurrences(of: "{m}", with: Rules.grouped(o.selection.members.count))
                                            .replacingOccurrences(of: "{unit}", with: host.depth.value?.unit ?? "")
                                            .replacingOccurrences(of: "{level}", with: fa.levels.last?.name ?? ""))
                                            .font(DS.style(.subheadline)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(.vertical, 2)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("set-overlap-\(o.selection.id)")
                            }
                        } header: {
                            ListNote(L.label("whereTheyOverlap"))
                        } footer: {
                            if let s = fa.sources.first(where: { $0.id == walk.sourceId }) {
                                ListNote(dotted([s.publisher, s.edition, SourceRows.checked(s.verification, store: model.store, labels: L)], separator: model.store.label("metaSeparator")))
                            }
                        }
                    }
                } else if a != b {
                    SwiftUI.Section {
                        Text(L.label("noCrosswalk")).font(DS.style(.subheadline)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 2)
                            .accessibilityIdentifier("compare-no-crosswalk")
                    } header: {
                        ListNote(L.label("whereTheyOverlap"))
                    }
                }
                SwiftUI.Section {
                    Label {
                        Text(named?.noScore ?? L.label("noScoreGeneric")).font(DS.style(.subheadline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "scalemass").foregroundStyle(Palette.fg2).accessibilityHidden(true)
                    }
                    .padding(.vertical, 2)
                    .accessibilityIdentifier("compare-no-score")
                } header: {
                    ListNote(L.label("noScoreTitle"))
                }
                SwiftUI.Section {
                    FrameworkRow(framework: fa, line: fa.purpose)
                    if a != b { FrameworkRow(framework: fb, line: fb.purpose) }
                } header: {
                    ListNote(a == b ? L.label("openIt") : L.label("openEach"))
                }
            }
        }
    }

    /// The questions asked of both: the comparison's own rows, or for any two cards the three every card answers.
    private func rows(_ fa: Framework, _ fb: Framework) -> [Comparison.Row] {
        let L = model.frameworks
        if let named { return named.rows }
        return [.init(label: L.label("comparePurpose"), a: fa.purpose, b: fb.purpose),
                .init(label: L.label("compareBinds"), a: fa.binds.line, b: fb.binds.line),
                .init(label: L.label("compareAssessed"), a: fa.verifiedBy.line, b: fb.verifiedBy.line)]
    }

    /// How the two connect: the comparison's own words, or what each card says of the other; where neither names the
    /// other, the screen says so.
    private func connect(_ fa: Framework, _ fb: Framework) -> String {
        if let named { return named.connect }
        let lines = fa.related.filter { $0.id == fb.id }.map(\.line) + fb.related.filter { $0.id == fa.id }.map(\.line)
        return lines.isEmpty ? model.frameworks.label("noLink") : lines.joined(separator: " ")
    }

    private func publisher(_ o: FrameworkLibrary.Overlap) -> String {
        o.from.sources.first { $0.id == o.crosswalk.sourceId }?.publisher ?? o.from.shortName
    }

    static func size(_ f: Framework) -> String { f.size.map { "\(Rules.grouped($0.count)) \($0.unit)" }.joined(separator: ", ") }

    /// "In all, the references reach 209 of the 1,014 controls and enhancements in SP 800-53." Where the other
    /// framework's elements are not listed: "In all, the references name 116 identifiers of ISO/IEC 27001."
    static func reachedLine(_ o: FrameworkLibrary.Overlap, labels L: FrameworkLibrary) -> String {
        guard o.crosswalk.isListed else {
            return L.label("reachedUnlisted").replacingOccurrences(of: "{n}", with: Rules.grouped(o.reached)).replacingOccurrences(of: "{name}", with: o.to.shortName)
        }
        return L.label("reached").replacingOccurrences(of: "{n}", with: Rules.grouped(o.reached)).replacingOccurrences(of: "{of}", with: Rules.grouped(o.of))
            .replacingOccurrences(of: "{unit}", with: o.to.depth.value?.unit ?? "").replacingOccurrences(of: "{name}", with: o.to.shortName)
    }
}

/// One question asked of both frameworks: the label, then each answer under its framework's name in its colour; side by
/// side where the width allows, one under the other on a phone and at the accessibility sizes.
struct CompareRow: View {
    let row: Comparison.Row
    let a: Framework
    let b: Framework
    var nameA: String?
    var nameB: String?
    let wide: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.label).font(DS.style(.footnote)).foregroundStyle(Palette.fg2).accessibilityAddTraits(.isHeader)
            (wide ? AnyLayout(HStackLayout(alignment: .top, spacing: 16)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 8))) {
                cell(a, nameA ?? a.shortName, row.a)
                cell(b, nameB ?? b.shortName, row.b)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("compare-row-\(row.label)")
    }

    private func cell(_ f: Framework, _ name: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Eyebrow(text: name, color: f.tone, small: true)
            Text(text).font(DS.style(.subheadline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// One top-level node's share of the overlap: how many of its elements carry a published link, to how many of the other
/// framework's, and where most of them land. Opens the node.
struct OverlapRow: View {
    @Environment(AppModel.self) private var model
    let row: FrameworkLibrary.Overlap.Row
    let overlap: FrameworkLibrary.Overlap

    var body: some View {
        let L = model.frameworks
        let leaf = overlap.unit
        let identified = L.graphs[overlap.from.id]?.identified(row.node) ?? true
        NavigationLink(value: Nav.node(overlap.from.id, row.node.id)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if identified { NodeBadge(id: row.node.id, tone: overlap.from.tone) }
                    Text(row.node.title ?? row.node.id).font(DS.style(.body)).foregroundStyle(.primary)
                }
                Text(L.label("overlapRow").replacingOccurrences(of: "{linked}", with: "\(row.linked)").replacingOccurrences(of: "{leaves}", with: "\(row.leaves)")
                    .replacingOccurrences(of: "{unit}", with: leaf).replacingOccurrences(of: "{targets}", with: "\(row.targets)")
                    .replacingOccurrences(of: "{targetUnit}", with: overlap.crosswalk.isListed ? (overlap.to.depth.value?.unit ?? "") : L.label("identifiers"))
                    .replacingOccurrences(of: "{name}", with: overlap.to.shortName))
                    .font(DS.style(.subheadline)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                if !row.leading.isEmpty {
                    Text("\(L.label("mostIn")) \(row.leading.joined(separator: ", "))").font(DS.style(.footnote)).foregroundStyle(overlap.to.tone)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("overlap-row-\(row.node.id)")
    }
}
