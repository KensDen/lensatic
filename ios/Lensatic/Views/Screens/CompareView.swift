import SwiftUI

/// One honest comparison (Lensatic 2.0, Round 1): the same questions asked of each framework, purpose, who must follow
/// it, how it is assessed, where it sits and how big it is; how the two connect; and where their elements overlap, counted
/// from a crosswalk the publisher itself prints. No score: two frameworks on different layers are not stricter or looser
/// than each other, and the screen says so.
struct CompareView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    let id: String

    var body: some View {
        let L = model.frameworks
        if let c = L.comparison(id), let a = L.byId[c.a], let b = L.byId[c.b] {
            let overlap = model.screen("overlap-\(id)") { L.overlap(c) }
            ListScreen(eyebrow: L.label("compare"), eyebrowColor: Palette.fg2,
                       title: "\(a.shortName) \(L.label("with")) \(b.shortName)", identifier: "compare-screen") {
                SwiftUI.Section {
                    VStack(alignment: .leading, spacing: 10) {
                        ComparePair(a: a, b: b)
                        Text(c.verdict).font(DS.style(.headline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("compare-verdict")
                    }
                    .padding(.vertical, 4)
                }
                SwiftUI.Section {
                    ForEach(c.rows, id: \.label) { row in CompareRow(row: row, a: a, b: b, wide: sizeClass == .regular && !typeSize.isAccessibilitySize) }
                    CompareRow(row: .init(label: L.label("sits"), a: model.sitsLabel(a), b: model.sitsLabel(b)), a: a, b: b,
                               wide: sizeClass == .regular && !typeSize.isAccessibilitySize)
                    CompareRow(row: .init(label: L.label("size"), a: CompareView.size(a), b: CompareView.size(b)), a: a, b: b,
                               wide: sizeClass == .regular && !typeSize.isAccessibilitySize)
                } header: {
                    ListNote(L.label("sideBySide"))
                }
                SwiftUI.Section {
                    Text(c.connect).font(DS.style(.body)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 4)
                        .accessibilityIdentifier("compare-connect")
                } header: {
                    ListNote(L.label("howTheyConnect"))
                }
                if let overlap {
                    SwiftUI.Section {
                        Text(c.overlapLine).font(DS.style(.subheadline)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
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
                }
                SwiftUI.Section {
                    Label {
                        Text(c.noScore).font(DS.style(.subheadline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "scalemass").foregroundStyle(Palette.fg2).accessibilityHidden(true)
                    }
                    .padding(.vertical, 2)
                    .accessibilityIdentifier("compare-no-score")
                } header: {
                    ListNote(L.label("noScoreTitle"))
                }
                SwiftUI.Section {
                    FrameworkRow(framework: a, line: a.purpose)
                    FrameworkRow(framework: b, line: b.purpose)
                } header: {
                    ListNote(L.label("openEach"))
                }
            }
        }
    }

    static func size(_ f: Framework) -> String { f.size.map { "\(Rules.grouped($0.count)) \($0.unit)" }.joined(separator: ", ") }

    /// "213 of 1,014 controls and enhancements in SP 800-53 are referenced at least once."
    static func reachedLine(_ o: FrameworkLibrary.Overlap, labels L: FrameworkLibrary) -> String {
        L.label("reached").replacingOccurrences(of: "{n}", with: Rules.grouped(o.reached)).replacingOccurrences(of: "{of}", with: Rules.grouped(o.of))
            .replacingOccurrences(of: "{unit}", with: o.to.depth.value?.unit ?? "").replacingOccurrences(of: "{name}", with: o.to.shortName)
    }
}

/// One question asked of both frameworks: the label, then each answer under its framework's name in its colour; side by
/// side where the width allows, one under the other on a phone and at the accessibility sizes.
struct CompareRow: View {
    let row: Comparison.Row
    let a: Framework
    let b: Framework
    let wide: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.label).font(DS.style(.footnote)).foregroundStyle(Palette.fg2).accessibilityAddTraits(.isHeader)
            (wide ? AnyLayout(HStackLayout(alignment: .top, spacing: 16)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 8))) {
                cell(a, row.a)
                cell(b, row.b)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("compare-row-\(row.label)")
    }

    private func cell(_ f: Framework, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Eyebrow(text: f.shortName, color: f.tone, small: true)
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
        let leaf = overlap.from.levels.last?.plural ?? ""
        NavigationLink(value: Nav.node(overlap.from.id, row.node.id)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    NodeBadge(id: row.node.id, tone: overlap.from.tone)
                    Text(row.node.title ?? row.node.id).font(DS.style(.body)).foregroundStyle(.primary)
                }
                Text(L.label("overlapRow").replacingOccurrences(of: "{linked}", with: "\(row.linked)").replacingOccurrences(of: "{leaves}", with: "\(row.leaves)")
                    .replacingOccurrences(of: "{unit}", with: leaf).replacingOccurrences(of: "{targets}", with: "\(row.targets)")
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
