import SwiftUI

/// Explore (content release 1.0.1, section 7: system components first): the map three ways on the system's segmented
/// control under the large title, each an inset-grouped list. Stack gives the five layers as rows with an icon tile, the
/// AI column as a sixth, tinted row (the iPad keeps it as a side column beside the layers); the layer of the reader's
/// next step says so. Matrix goes function by function through the pillars of the chosen view; Functions gives the six
/// CSF functions. Backgrounds are the system's grouped colours, so light and dark need no colour work of their own.
struct ExploreView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// The matrix's jump row has scrolled out of view (build 6): its pinned copy shows at the top of the screen.
    @State private var jumpAway = false
    /// The function the jump row last scrolled to: its code is marked until the reader scrolls the list themselves.
    @State private var jumped: FunctionID?

    var body: some View {
        @Bindable var model = model
        let options = ExploreMode.allCases.map { ($0, model.store.content.ui.nav[$0.rawValue] ?? $0.rawValue.capitalized) }
        // on a phone the matrix carries a row that jumps to a function (build 6); it stays pinned once it scrolls away
        let jumps = model.explore == .matrix && sizeClass == .compact
        ScrollViewReader { proxy in
        List {
            Group {
                SwiftUI.Section {
                    ScreenHeader(title: AppTab.explore.title)
                        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    // the modes: a segmented control under the title
                    if !typeSize.isAccessibilitySize { ModePicker(options: options, selection: $model.explore, identifier: "explore") }
                }
                // at the accessibility sizes, a section of rows, one per mode
                if typeSize.isAccessibilitySize {
                    SwiftUI.Section { ModePicker(options: options, selection: $model.explore, identifier: "explore") }
                }
                switch model.explore {
                case .stack: StackView()
                case .matrix: MatrixView(jumps: jumps, jumpAway: $jumpAway, jumped: jumped) { jump($0, proxy) }
                case .functions: FunctionsView()
                }
            }
            .lxRows()
        }
        .listStyle(.insetGrouped)
        .lxListSurface()
        .environment(\.defaultMinListRowHeight, 44)
        .hardTopEdge()
        .safeAreaInset(edge: .top, spacing: 0) {
            if jumps && jumpAway {
                FunctionJumpRow(functions: model.store.content.functions, current: jumped, identifier: "matrix-jump-pinned") { jump($0, proxy) }
                    .padding(.horizontal, 20).padding(.vertical, 6)
                    .background(Palette.bg)
                    .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("explore")
        .onChange(of: model.explore) { jumpAway = false; jumped = nil }
        .onChange(of: model.matrixView) { jumped = nil }
        // the reader's own scroll takes the mark off: the row no longer knows which function is at the top
        .simultaneousGesture(DragGesture(minimumDistance: 12).onChanged { _ in if jumped != nil { jumped = nil } })
        #if DEBUG
        // -LensaticScrollTo matrix-fn-<code> scrolls the matrix to that function, as its jump row does (the screenshots)
        .task {
            if let target = AppModel.debugScrollTo, target.hasPrefix("matrix-fn-"), let fn = FunctionID(rawValue: String(target.dropFirst("matrix-fn-".count))) {
                try? await Task.sleep(for: .milliseconds(600))
                jump(fn, proxy)
            }
        }
        #endif
        }
    }

    /// Scroll the matrix to a function's first row, at the top of the list under the pinned row, and mark its code there:
    /// the function's own header is then just above the screen's edge, and the mark says where the reader is. (A list
    /// honours a top or a bottom anchor exactly and centres anything between, so the header cannot be held in view.)
    private func jump(_ function: FunctionID, _ proxy: ScrollViewProxy) {
        let screen = model.screen("matrix-\(model.matrixView.rawValue)") { MatrixScreen(store: model.store, view: model.matrixView) }
        guard let first = screen.functions.first(where: { $0.function.id == function })?.rows.first else { return }
        let target = MatrixView.rowID(function, first.pillar)
        jumped = function
        withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut) { proxy.scrollTo(target, anchor: .top) }
        // a list places rows it has not made yet by estimate, so the first scroll can stop short; once the rows exist a
        // second one lands exactly (the fresh-eyes review of build 6, finding 26)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { proxy.scrollTo(target, anchor: .top) }
    }
}

/// The matrix's jump row (build 6): the six CSF functions by their codes (GV ID PR DE RS RC), each a control that scrolls
/// the matrix to that function's rows. The codes keep the largest standard text size, as the tab bar's labels do, so all
/// six stay on one row; a long press at the accessibility sizes shows a code in the large content viewer.
struct FunctionJumpRow: View {
    @Environment(AppModel.self) private var model
    let functions: [CSFFunction]
    /// The function the row last jumped to, marked until the reader scrolls on.
    var current: FunctionID?
    var identifier: String
    let jump: (FunctionID) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(functions, id: \.id) { fn in
                Button { jump(fn.id) } label: {
                    Text(fn.id.rawValue).font(DS.style(.subheadline).weight(.semibold))
                        .foregroundStyle(fn.id == current ? Palette.onSecMaps : Color.primary)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(fn.id == current ? Palette.secMaps : Palette.bg3, in: Capsule())
                        .overlay(Capsule().strokeBorder(fn.id == current ? Palette.secMaps : Palette.line, lineWidth: 1))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(model.store.label("matrixJump")) \(fn.name)")
                .accessibilityAddTraits(fn.id == current ? .isSelected : [])
                .accessibilityIdentifier("\(identifier)-\(fn.id.rawValue)")
                .accessibilityShowsLargeContentViewer { Text("\(fn.id.rawValue) \(fn.name)") }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

/// The system's segmented control; at the accessibility sizes, where a segment's label would be cut, one row per mode
/// with a checkmark on the chosen one, as an inline picker draws it, so the modes still stack one to a line (section 7.7).
struct ModePicker<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    var identifier: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            ForEach(options, id: \.0) { value, label in
                Button { selection = value } label: {
                    HStack(spacing: 12) {
                        Text(label).font(DS.style(.body)).foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if value == selection {
                            Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Palette.link).accessibilityHidden(true)
                        }
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(value == selection ? [.isSelected, .isButton] : .isButton)
                .accessibilityIdentifier("\(identifier)-\(value)")
            }
        } else {
            Picker(identifier, selection: $selection) {
                ForEach(options, id: \.0) { value, label in
                    Text(label).tag(value).accessibilityIdentifier("\(identifier)-\(value)")
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("\(identifier)-picker")
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
}

// MARK: Stack

struct StackView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let screen = model.screen("stack") { StackScreen(store: model.store) }
        let onPath = model.pathLayer
        SwiftUI.Section {
            if sizeClass == .regular, let column = screen.column {
                // the iPad: the layers beside the AI column, the one hero container this screen keeps
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        ForEach(screen.layers, id: \.id) { layer in
                            padRow(layer.id) { layerRow(layer, onPath: onPath) }
                            if layer.id != screen.layers.last?.id { Divider().overlay(Palette.line).padding(.leading, 42) }
                        }
                    }
                    .lxCard(radius: LxCard.inList(12))
                    // the AI column's side tile (build 6): the question runs under the title at the tile's full width, where
                    // beside the icon it wrapped into a narrow column
                    Button { model.push(.layer(column.id)) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                IconTile(symbol: RowIcon.aiColumn.0, tint: RowIcon.aiColumn.1)
                                Text(TitleCase.apply(column.name)).font(DS.style(.body)).foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
                            }
                            Text(column.shortQuestion).font(DS.style(.subheadline)).foregroundStyle(Palette.fg2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(columnCount(column)).font(DS.style(.body)).foregroundStyle(Palette.fg2)
                        }
                        .multilineTextAlignment(.leading)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint(column.question)
                    .accessibilityIdentifier("layer-\(column.id)")
                    .lxCard(radius: LxCard.inList(12), tint: Palette.secPurple).frame(maxWidth: 300)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } else {
                ForEach(screen.layers, id: \.id) { layer in layerLink(layer, onPath: onPath) }
            }
        } footer: {
            ListNote(intro(screen)).font(DS.style(.footnote))
        }
        // the AI column, a sixth row under the layers, tinted as the column and labelled from its content; a section of
        // its own, so its tint never reads as a row left selected
        if sizeClass != .regular, let column = screen.column {
            SwiftUI.Section { columnLink(column).listRowBackground(Palette.secPurple.opacity(0.18)) }
        }
    }

    /// The section's footer, with the number of layers counted from the content.
    private func intro(_ screen: StackScreen) -> String {
        let n = NumberFormatter.localizedString(from: NSNumber(value: screen.layers.count), number: .spellOut).capitalized
        return "\(n) layers, from what leadership funds down to who checks. AI runs alongside."
    }

    private func layerRow(_ layer: Layer, onPath: String?) -> TileRow {
        let n = layer.frameworkIds.count
        return TileRow(icon: RowIcon.layer(layer.order), title: TitleCase.apply(layer.name), subtitle: layer.shortQuestion,
                       note: layer.id == onPath ? "On your path" : nil, value: n == 1 ? "1 framework" : "\(n) frameworks")
    }

    private func columnCount(_ column: Layer) -> String {
        let count = StackScreen.entryIds(column, store: model.store).count
        return count == 1 ? "1 entry" : "\(count) entries"
    }

    private func columnRow(_ column: Layer) -> TileRow {
        TileRow(icon: RowIcon.aiColumn, title: TitleCase.apply(column.name), subtitle: column.shortQuestion, value: columnCount(column))
    }

    private func layerLink(_ layer: Layer, onPath: String?) -> some View {
        NavigationLink(value: Nav.layer(layer.id)) { layerRow(layer, onPath: onPath) }
            .accessibilityHint(layer.question)
            .accessibilityIdentifier("layer-\(layer.id)")
    }

    private func columnLink(_ column: Layer) -> some View {
        let count = StackScreen.entryIds(column, store: model.store).count
        return NavigationLink(value: Nav.layer(column.id)) { columnRow(column) }
            .accessibilityLabel("\(column.name), \(count) entries")
            .accessibilityHint(column.question)
            .accessibilityIdentifier("layer-\(column.id)")
    }

    /// The iPad's side-by-side stack: one plain button per row, at least 44 points tall, with the list's chevron, so each
    /// row is its own target inside the one list row that holds the container.
    private func padRow(_ id: String, @ViewBuilder _ content: () -> TileRow) -> some View {
        let layer = model.store.layers[id]
        return Button { model.push(.layer(id)) } label: {
            HStack(spacing: 8) {
                content()
                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(layer?.question ?? "")
        .accessibilityIdentifier("layer-\(id)")
    }
}

// MARK: Matrix

struct MatrixView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    /// On a phone (build 6): the jump row under the model picker, whether it has scrolled away, and the jump itself.
    var jumps = false
    @Binding var jumpAway: Bool
    var jumped: FunctionID?
    var jump: (FunctionID) -> Void = { _ in }

    /// A row's identity in the list: its function and pillar, so every row is its own (a pillar repeats under each
    /// function) and the jump row can scroll to a function's first row before the list has made it.
    static func rowID(_ function: FunctionID, _ pillar: String) -> String { "matrix-\(function.rawValue)-\(pillar)" }

    var body: some View {
        @Bindable var model = model
        let screen = model.screen("matrix-\(model.matrixView.rawValue)") { MatrixScreen(store: model.store, view: model.matrixView) }
        SwiftUI.Section {
            ModePicker(options: PillarView.allCases.map { ($0, viewName($0)) }, selection: $model.matrixView, identifier: "pillar-view")
        } footer: {
            if !jumps { ListNote(intro(screen)).font(DS.style(.footnote)) }
        }
        if jumps {
            // a section of its own, close under the picker, so the picker's card keeps its corners at every text size
            SwiftUI.Section {
                FunctionJumpRow(functions: screen.functions.map(\.function), current: jumped, identifier: "matrix-jump", jump: jump)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    // once this row scrolls away its pinned copy takes over at the top of the screen
                    .onAppear { jumpAway = false }
                    .onDisappear { jumpAway = true }
            } footer: {
                ListNote(intro(screen)).font(DS.style(.footnote))
            }
            .listSectionSpacing(8)
        }
        ForEach(screen.functions, id: \.function.id) { fn, rows in
            SwiftUI.Section {
                ForEach(rows.map { (id: MatrixView.rowID(fn.id, $0.pillar), row: $0) }, id: \.id) { item in
                    let row = item.row
                    NavigationLink(value: Nav.cell(screen.view, row.pillar, fn.id)) {
                        VStack(alignment: .leading, spacing: 3) {
                            // at the accessibility sizes the capability numbers go under the name, which keeps the width
                            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                                                          : AnyLayout(HStackLayout(alignment: .firstTextBaseline))) {
                                Text(row.crossCutting ? "\(row.name) (\(model.store.label("crossCutting")))" : row.name)
                                    .font(DS.style(.headline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                                if !row.capabilities.isEmpty {
                                    Text("\(model.store.label("capabilities")) \(row.capabilities.joined(separator: " "))")
                                        .font(DS.style(.caption)).foregroundStyle(Palette.fg2)
                                }
                            }
                            ProseText(run: screen.prose[row.line], font: DS.style(.subheadline), color: Palette.fg2, lineSpacing: 2)
                        }
                        .multilineTextAlignment(.leading)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("cell-\(screen.view.rawValue)-\(row.pillar)-\(fn.id.rawValue)")
                }
            } header: {
                ListNote("\(fn.id.rawValue) \(fn.name)")
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
        ForEach(screen.cards, id: \.function.id) { card in
            FunctionSection(card: card, prose: screen.prose)
        }
    }
}

/// One CSF function as a section: its question, where zero trust lands, its categories and, one tap down in the system's
/// disclosure, the pillars.
struct FunctionSection: View {
    @Environment(AppModel.self) private var model
    let card: FunctionsScreen.Card
    let prose: Prose
    @State private var open = false

    var body: some View {
        SwiftUI.Section {
            VStack(alignment: .leading, spacing: 10) {
                ProseText(run: prose[card.question], font: DS.style(.headline), color: .primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.store.label("whereZtLands")).font(DS.style(.footnote)).foregroundStyle(Palette.fg2)
                    ProseText(run: prose[card.landing], font: DS.style(.subheadline), color: .primary)
                }
                FlowLayout(spacing: 6) {
                    ForEach(card.function.categories, id: \.code) { c in
                        Text(c.code).font(DS.style(.caption)).foregroundStyle(Palette.fg2)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Palette.bg3, in: Capsule())
                            .accessibilityLabel("\(c.code), \(c.name)")
                    }
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("function-\(card.function.id.rawValue)")
            // the pillars one tap down, the row the control (a hidden chevron turns), so nothing in it goes unnamed
            Button { open.toggle() } label: {
                HStack {
                    Text("By Pillar").font(DS.style(.body)).foregroundStyle(Palette.link)
                        .fixedSize(horizontal: false, vertical: true).layoutPriority(1)
                    Spacer()
                    Icon(.chevronRight, size: 14, color: Palette.fg2).rotationEffect(.degrees(open ? 90 : 0)).accessibilityHidden(true)
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(open ? "Expanded" : "Collapsed")
            .accessibilityIdentifier("function-\(card.function.id.rawValue)-pillars")
            if open {
                ForEach(card.pillars, id: \.name) { p in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).font(DS.style(.subheadline).weight(.semibold)).foregroundStyle(.primary)
                        ProseText(run: prose[p.line], font: DS.style(.subheadline), color: Palette.fg2, lineSpacing: 2)
                    }
                }
            }
        } header: {
            ListNote("\(card.function.id.rawValue) \(card.function.name)")
        }
    }
}

// MARK: a layer

/// A layer opened from the stack: its question and line, its entries as rows (each opens its card, its short summary
/// beneath), the solutions measured against it and the questions the map answers there. The AI column adds its note and
/// the worked Profile.
struct LayerView: View {
    @Environment(AppModel.self) private var model
    @State private var noteOpen = false
    let id: String

    var body: some View {
        if let screen = model.screen("layer-\(id)", { LayerScreen(store: model.store, id: id) }) {
            let layer = screen.layer
            let p = screen.prose
            ListScreen(eyebrow: layer.isColumn ? nil : "\(model.store.label("layer")) \(layer.order)",
                       eyebrowColor: layer.isColumn ? Palette.secPurple : Palette.secMaps,
                       title: TitleCase.apply(layer.name), identifier: "layer-screen-\(id)") {
                SwiftUI.Section {
                    VStack(alignment: .leading, spacing: 8) {
                        ProseText(run: p[screen.question], font: DS.style(.headline), color: .primary)
                        ProseText(run: p[screen.oneLiner], font: DS.style(.subheadline), color: Palette.fg2)
                        if let note = screen.note {
                            ProseText(run: p[note], font: DS.style(.subheadline), color: .primary)
                            if let rest = screen.noteRest {
                                if noteOpen { ProseText(run: p[rest], font: DS.style(.subheadline), color: .primary) }
                                Button { noteOpen.toggle() } label: {
                                    Text(noteOpen ? "Show Less" : "Read More").font(DS.style(.subheadline)).foregroundStyle(Palette.link)
                                        .frame(minHeight: 44).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("layer-note-more")
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                entries(layer.isColumn ? "In the column" : "On this layer", screen.entryIds)
                if !screen.solutionIds.isEmpty { entries("Validated solutions", screen.solutionIds) }
                if let title = screen.socTitle {
                    SwiftUI.Section {
                        ForEach(Array(screen.soc.enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.function).font(DS.style(.headline)).foregroundStyle(.primary)
                                ProseText(run: p[row.outcome], font: DS.style(.subheadline), color: Palette.fg2, lineSpacing: 2)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    } header: {
                        ProseText(run: p[title], font: DS.style(.footnote), color: Palette.fg2).accessibilityAddTraits(.isHeader)
                    }
                }
                if !screen.helpers.isEmpty {
                    SwiftUI.Section {
                        ForEach(screen.helpers, id: \.id) { h in HelperRow(helper: h, prose: p) }
                    } header: {
                        ListNote(model.store.navTitle(.helper))
                    }
                }
            }
        } else {
            Palette.bg
        }
    }

    private func entries(_ title: String, _ ids: [String]) -> some View {
        SwiftUI.Section {
            ForEach(ids, id: \.self) { eid in
                if let e = model.store.entities[eid] {
                    NavigationLink(value: Nav.entity(eid)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.displayName).font(DS.style(.body)).foregroundStyle(.primary)
                            Text(keepWhole(e.shortSummary)).font(DS.style(.footnote)).foregroundStyle(Palette.fg2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 2)
                    }
                    .accessibilityIdentifier("entry-\(eid)")
                }
            }
        } header: {
            ListNote(title)
        }
    }
}

/// One of the map's questions at a layer, in the system's disclosure: the question opens in place to its answer and the
/// entries it draws on.
struct HelperRow: View {
    @Environment(AppModel.self) private var model
    let helper: LayerScreen.Helper
    let prose: Prose
    @State private var open = false

    var body: some View {
        // the question is the row's control; its answer and entries follow as a row of their own when open
        Button { open.toggle() } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                ProseText(run: prose[helper.question], font: DS.style(.body), color: .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                Icon(.chevronRight, size: 14, color: Palette.fg2).rotationEffect(.degrees(open ? 90 : 0)).accessibilityHidden(true)
            }
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(open ? "Expanded" : "Collapsed")
        .accessibilityIdentifier("helper-\(helper.id)")
        if open {
            VStack(alignment: .leading, spacing: 8) {
                ProseText(run: prose[helper.answer], font: DS.style(.subheadline), color: .primary)
                FlowLayout {
                    ForEach(helper.entityIds, id: \.self) { eid in
                        if let e = model.store.entities[eid] {
                            Button { model.push(.entity(eid)) } label: { Pill(text: e.shortName) }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
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
