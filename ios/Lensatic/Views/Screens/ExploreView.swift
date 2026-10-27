import SwiftUI

/// Explore (the redesign, R2; Explore.dc.html): the map three ways on a segmented control. Stack shows the five layers,
/// narrowest at the top, with the AI column beside them; the layer of the reader's next step is called out as on their
/// path. Matrix goes function by function through the pillars of the chosen view; Functions gives the six CSF functions.
struct ExploreView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: AppTab.explore.title)
                Segmented(options: ExploreMode.allCases.map { ($0, model.store.content.ui.nav[$0.rawValue] ?? $0.rawValue.capitalized) },
                          selection: $model.explore, identifier: "explore")
                switch model.explore {
                case .stack: StackView()
                case .matrix: MatrixView()
                case .functions: FunctionsView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Palette.bg)
        .hardTopEdge()
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("explore")
    }
}

// MARK: Stack

struct StackView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The turned label's line height, which is its width on screen: it grows with the text, so the label is never cut.
    @ScaledMetric(relativeTo: .caption) private var labelLine: CGFloat = 20

    var body: some View {
        let screen = model.screen("stack") { StackScreen(store: model.store) }
        let onPath = model.pathLayer
        VStack(alignment: .leading, spacing: 14) {
            ProseText(run: Run(Span(intro(screen), role: .label)), font: DS.note, color: Palette.fg2)
            if typeSize.isAccessibilitySize {
                // at the accessibility sizes the column takes its own row under the layers, so neither is squeezed
                layers(screen, onPath)
                if let column = screen.column { columnCard(column, vertical: false) }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    layers(screen, onPath)
                    if let column = screen.column { columnCard(column, vertical: true) }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The mockup's two short lines, with the number of layers counted from the content.
    private func intro(_ screen: StackScreen) -> String {
        let n = NumberFormatter.localizedString(from: NSNumber(value: screen.layers.count), number: .spellOut).capitalized
        return "\(n) layers, from what leadership funds down to who checks. AI runs alongside. Tap a layer."
    }

    private func layers(_ screen: StackScreen, _ onPath: String?) -> some View {
        let n = screen.layers.count
        return VStack(spacing: 8) {
            ForEach(Array(screen.layers.enumerated()), id: \.element.id) { i, layer in
                // the stack narrows toward the top, as the mockup draws it: four points each side per layer
                let inset = typeSize.isAccessibilitySize ? 0 : CGFloat(n - 1 - i) * 4
                LayerCard(layer: layer, names: StackScreen.names(layer, store: model.store), onPath: layer.id == onPath)
                    .padding(.horizontal, inset)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func columnCard(_ column: Layer, vertical: Bool) -> some View {
        let count = StackScreen.entryIds(column, store: model.store).count
        let label = "\(column.name.uppercased())\(model.store.label("metaSeparator"))\(count)"
        return Button { model.push(.layer(column.id)) } label: {
            Group {
                if vertical {
                    VStack(spacing: 10) {
                        Icon(.chip, size: 24, color: Palette.secPurple, lineWidth: 1.8)
                        Text(label).font(DS.eyebrowSmall).kerning(1.1).foregroundStyle(Palette.secPurple)
                            .fixedSize()
                            .rotationEffect(.degrees(90))
                            .frame(width: labelLine)
                            .frame(minHeight: 140)
                    }
                    .frame(minWidth: 64)
                    .frame(maxHeight: .infinity)
                } else {
                    HStack(spacing: 12) {
                        Icon(.chip, size: 24, color: Palette.secPurple, lineWidth: 1.8)
                        Text(label).font(DS.eyebrowSmall).foregroundStyle(Palette.secPurple)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                }
            }
            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.secPurple, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(column.name), \(count) entries")
        .accessibilityHint(column.question)
        .accessibilityIdentifier("layer-\(column.id)")
    }
}

/// One layer of the stack: its number and name, its question, and the short names of its entries.
struct LayerCard: View {
    @Environment(AppModel.self) private var model
    let layer: Layer
    let names: [String]
    let onPath: Bool

    var body: some View {
        let sep = model.store.label("metaSeparator")
        Button { model.push(.layer(layer.id)) } label: {
            VStack(alignment: .leading, spacing: 4) {
                // untracked mono caps, as the mockup sets them; a non-breaking space keeps each dot with the word after it, so no line ends on a dot
                Eyebrow(text: ("\(layer.order)\(sep)\(layer.shortName)" + (onPath ? "\(sep)On your path" : ""))
                            .replacingOccurrences(of: sep, with: " " + sep.trimmingCharacters(in: .whitespaces) + "\u{00A0}"),
                        color: onPath ? Palette.secMaps : Palette.accent, small: true, tracked: false)
                Text(layer.shortQuestion).font(DS.layerTitle).foregroundStyle(Palette.fg)
                // each name kept on one line, so a line breaks only between names (nit 2)
                Text(names.map { $0.replacingOccurrences(of: " ", with: "\u{00A0}") }.joined(separator: sep)).font(DS.layerNames).foregroundStyle(Palette.fg2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .card(radius: 12, fill: onPath ? Palette.bg3 : Palette.bg2, stroke: onPath ? Palette.secMaps : Palette.line)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("layer-\(layer.id)")
    }
}

// MARK: Matrix

struct MatrixView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let screen = model.screen("matrix-\(model.matrixView.rawValue)") { MatrixScreen(store: model.store, view: model.matrixView) }
        VStack(alignment: .leading, spacing: 14) {
            Text(intro(screen)).font(DS.note).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
            Segmented(options: PillarView.allCases.map { ($0, viewName($0)) },
                      selection: $model.matrixView, identifier: "pillar-view")
            ForEach(screen.functions, id: \.function.id) { fn, rows in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(fn.id.rawValue).font(DS.eyebrow).foregroundStyle(Palette.accent)
                        Text(fn.name).font(DS.readerHeading).foregroundStyle(Palette.fg)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    ForEach(rows, id: \.pillar) { row in
                        Button { model.push(.cell(screen.view, row.pillar, fn.id)) } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(row.crossCutting ? "\(row.name) (\(model.store.label("crossCutting")))" : row.name)
                                        .font(DS.layerTitle).foregroundStyle(Palette.fg)
                                    Spacer(minLength: 8)
                                    if !row.capabilities.isEmpty {
                                        Text("\(model.store.label("capabilities")) \(row.capabilities.joined(separator: " "))")
                                            .font(DS.eyebrowSmall).foregroundStyle(Palette.fg2)
                                    }
                                }
                                ProseText(run: screen.prose[row.line], font: DS.note, color: Palette.fg2, lineSpacing: 2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .padding(12)
                            .card(radius: 12)
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("cell-\(screen.view.rawValue)-\(row.pillar)-\(fn.id.rawValue)")
                    }
                }
            }
        }
    }
}

extension MatrixView {
    /// One short line, counted from the content: the functions, and the pillars in the chosen view.
    func intro(_ screen: MatrixScreen) -> String {
        func spell(_ n: Int) -> String { NumberFormatter.localizedString(from: NSNumber(value: n), number: .spellOut) }
        let pillars = screen.functions.first?.rows.count ?? 0
        return "\(spell(screen.functions.count).capitalized) functions, each with a row for the \(spell(pillars)) pillars of the view. Tap a row for the full text."
    }

    /// A view's name for the control: the label before its colon, in Title Case (the counts are in the line above).
    func viewName(_ view: PillarView) -> String {
        let label = model.store.label(view == .dow ? "pillarViewDow" : "pillarViewCisa")
        return TitleCase.apply(String(label.split(separator: ":").first ?? Substring(label)))
    }
}

// MARK: Functions

struct FunctionsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let screen = model.screen("functions") { FunctionsScreen(store: model.store) }
        VStack(alignment: .leading, spacing: 12) {
            ForEach(screen.cards, id: \.function.id) { card in
                FunctionCard(card: card, prose: screen.prose)
            }
        }
    }
}

struct FunctionCard: View {
    @Environment(AppModel.self) private var model
    let card: FunctionsScreen.Card
    let prose: Prose
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(card.function.id.rawValue).font(DS.eyebrow).foregroundStyle(Palette.accent)
                Text(card.function.name).font(DS.readerHeading).foregroundStyle(Palette.fg)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ProseText(run: prose[card.question], font: DS.nextTitle)
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: model.store.label("whereZtLands"), tracked: false)
                ProseText(run: prose[card.landing], font: DS.step)
            }
            FlowLayout(spacing: 6) {
                ForEach(card.function.categories, id: \.code) { c in
                    Text(c.code).font(DS.eyebrowSmall).foregroundStyle(Palette.fg2)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
                        .accessibilityLabel("\(c.code), \(c.name)")
                }
            }
            Button { open.toggle() } label: {
                HStack {
                    Text(open ? "Hide the Pillars" : "By Pillar").font(DS.link).foregroundStyle(Palette.link)
                    Spacer()
                    Icon(.chevronRight, size: 16, color: Palette.link).rotationEffect(.degrees(open ? 90 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(open ? "Open" : "Closed")
            .accessibilityIdentifier("function-\(card.function.id.rawValue)-pillars")
            if open {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(card.pillars, id: \.name) { p in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).font(DS.stepStrong).foregroundStyle(Palette.fg)
                            ProseText(run: prose[p.line], font: DS.step, color: Palette.fg2, lineSpacing: 2)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 14)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("function-\(card.function.id.rawValue)")
    }
}

// MARK: a layer

/// A layer opened from the stack: its question and line, its entries (each opens its card), the solutions measured
/// against it and the questions the map answers there. The AI column adds its note and the worked Profile.
struct LayerView: View {
    @Environment(AppModel.self) private var model
    @State private var noteOpen = false
    let id: String

    var body: some View {
        if let screen = model.screen("layer-\(id)", { LayerScreen(store: model.store, id: id) }) {
            let layer = screen.layer
            let p = screen.prose
            DetailScreen(eyebrow: layer.isColumn ? nil : "\(model.store.label("layer")) \(layer.order)",
                         eyebrowColor: layer.isColumn ? Palette.secPurple : Palette.secMaps,
                         title: TitleCase.apply(layer.name), identifier: "layer-screen-\(id)") {
                ProseText(run: p[screen.question], font: DS.nextTitle)
                ProseText(run: p[screen.oneLiner], font: DS.answer, color: Palette.fg2)
                if let note = screen.note {
                    ProseText(run: p[note], font: DS.answer)
                    if let rest = screen.noteRest {
                        if noteOpen { ProseText(run: p[rest], font: DS.answer) }
                        Button { noteOpen.toggle() } label: {
                            Text(noteOpen ? "Show Less" : "Read More").font(DS.link).foregroundStyle(Palette.link)
                                .frame(minHeight: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("layer-note-more")
                    }
                }
                entries(layer.isColumn ? "In the column" : "On this layer", screen.entryIds)
                if !screen.solutionIds.isEmpty { entries("Validated solutions", screen.solutionIds) }
                if let title = screen.socTitle {
                    VStack(alignment: .leading, spacing: 8) {
                        ProseText(run: p[title], font: DS.readerHeading).accessibilityAddTraits(.isHeader)
                        ForEach(Array(screen.soc.enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.function).font(DS.stepStrong).foregroundStyle(Palette.fg)
                                ProseText(run: p[row.outcome], font: DS.step, color: Palette.fg2, lineSpacing: 2)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(radius: 14)
                }
                if !screen.helpers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: model.store.navTitle(.helper))
                        ForEach(screen.helpers, id: \.id) { h in HelperCard(helper: h, prose: p) }
                    }
                }
            }
        } else {
            Palette.bg
        }
    }

    private func entries(_ title: String, _ ids: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            ForEach(ids, id: \.self) { eid in
                if let e = model.store.entities[eid] {
                    Button { model.push(.entity(eid)) } label: { ResultRow(title: e.displayName, line: e.shortSummary) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("entry-\(eid)")
                }
            }
        }
    }
}

/// One of the map's questions at a layer: the question opens in place to its answer and the entries it draws on.
struct HelperCard: View {
    @Environment(AppModel.self) private var model
    let helper: LayerScreen.Helper
    let prose: Prose
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { open.toggle() } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    ProseText(run: prose[helper.question], font: DS.nextTitle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    Icon(.chevronRight, size: 16, color: Palette.fg2).rotationEffect(.degrees(open ? 90 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(open ? "Open" : "Closed")
            .accessibilityIdentifier("helper-\(helper.id)")
            if open {
                ProseText(run: prose[helper.answer], font: DS.step)
                FlowLayout {
                    ForEach(helper.entityIds, id: \.self) { eid in
                        if let e = model.store.entities[eid] {
                            Button { model.push(.entity(eid)) } label: { Pill(text: e.shortName) }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 12)
    }
}

// MARK: a cell

struct CellView: View {
    @Environment(AppModel.self) private var model
    let view: PillarView
    let pillar: String
    let function: FunctionID

    var body: some View {
        if let screen = model.screen("cell-\(view.rawValue)-\(pillar)-\(function.rawValue)", {
            CellScreen(store: model.store, view: view, pillar: pillar, function: function)
        }) {
            DetailScreen(eyebrow: "\(screen.function.id.rawValue)\(model.store.label("metaSeparator"))\(screen.function.name)",
                         title: screen.title, identifier: "cell-screen") {
                ProseText(run: screen.prose[screen.text], font: DS.summary)
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: model.store.label("categories"), tracked: false)
                    FlowLayout(spacing: 6) {
                        ForEach(screen.categories, id: \.self) { code in
                            let name = screen.function.categories.first { $0.code == code }?.name
                            Text(name.map { "\(code) \($0)" } ?? code).font(DS.step).foregroundStyle(Palette.fg)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Palette.bg3, in: Capsule())
                        }
                    }
                }
                if !screen.capabilities.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(text: model.store.label(view == .dow ? "capabilities" : "capabilitiesDow"), tracked: false)
                        ForEach(screen.capabilities, id: \.self) { c in
                            Text(c).font(DS.step).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        } else {
            Palette.bg
        }
    }
}
