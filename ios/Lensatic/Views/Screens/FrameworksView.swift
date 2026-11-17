import SwiftUI

/// Frameworks (Lensatic 2.0, Round 1): the second tab. Browse gives every framework as a card, grouped the way the stack
/// is ordered, from the outcomes leadership funds down to who checks the evidence, then the state and local programs, the
/// AI column and the adversary column, and under them the answers to where other standards land. Compare gives the
/// comparisons the content holds. Every word and count comes from content/frameworks.
struct FrameworksView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The iPad's sidebar (Round 3): the same three views in a narrow column beside the detail pane. A tap picks what
    /// the detail pane shows, the pick is marked, and Browse is always the compact list.
    var pane = false

    /// Open a screen from the list: pushed on a phone; in the sidebar, picked for the detail pane.
    private func open(_ nav: Nav) {
        if pane { model.selectPane(nav) } else { model.push(nav) }
    }

    /// Whether the detail pane shows this screen at its root.
    private func picked(_ nav: Nav) -> Bool { pane && model.paneRoot == nav && (model.paths[.frameworks] ?? []).isEmpty }

    var body: some View {
        @Bindable var model = model
        let L = model.frameworks
        ScrollViewReader { proxy in
        ScrollView {
            // not lazy: nineteen cards are few, and the accessibility audit's text size check needs every row laid out
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: AppTab.frameworks.title)
                Text(L.catalog.intro).font(DS.step).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("frameworks-intro")
                VStack(spacing: 6) {
                    ModePicker(options: FrameworksMode.allCases.map { ($0, L.label($0.rawValue)) }, selection: $model.frameworksMode, identifier: "frameworks")
                }
                switch model.frameworksMode {
                case .browse:
                    // the sidebar is one compact list: no jump row and no choice of view to make
                    if !pane {
                        jumpRow(proxy)
                        densityRow
                    }
                    browse
                case .compare: compare
                case .checks: checks
                }
            }
            .padding(.horizontal, pane ? 16 : 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.bg)
        .hardTopEdge()
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("frameworks")
        // the sidebar follows the pick: an arrow key, or a framework opened from elsewhere, scrolls its row into view
        .onChange(of: model.frameworksPane) { _, pick in
            guard pane, case .framework(let id)? = pick else { return }
            withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut) { proxy.scrollTo("row-\(id)") }
        }
        }
    }

    /// The groups as a row that scrolls sideways: a tap brings that group's cards to the top, so the eleventh card is
    /// one tap away and not three screens down.
    private func jumpRow(_ proxy: ScrollViewProxy) -> some View {
        let L = model.frameworks
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(L.catalog.groups.filter { !L.frameworks(in: $0.id).isEmpty }) { g in
                    Button {
                        withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut) { proxy.scrollTo("group-\(g.id)", anchor: .top) }
                    } label: {
                        Text(g.name).font(DS.chip).foregroundStyle(Palette.fg)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(Palette.bg3, in: Capsule())
                            .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(L.label("jump")) \(g.name)")
                    .accessibilityIdentifier("frameworks-jump-\(g.id)")
                }
            }
        }
        .accessibilityIdentifier("frameworks-jump")
    }

    /// One column on a phone and at the accessibility sizes, two or three where the width allows.
    private var grid: CardGrid { CardGrid(minimum: typeSize.isAccessibilitySize ? 560 : 330, spacing: 12) }

    /// Cards or a compact list (Round 2): the same frameworks, a card each or a row each, nine or ten rows to a phone
    /// screen. The choice is kept with the reader's progress on the device.
    private var densityRow: some View {
        let L = model.frameworks
        let compact = model.progress.frameworksCompact
        return HStack(spacing: 8) {
            Text(L.label(compact ? "viewList" : "viewCards")).font(DS.caption).foregroundStyle(Palette.fg2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
            ForEach([false, true], id: \.self) { list in
                Button { model.progress.setFrameworksCompact(list) } label: {
                    Image(systemName: list ? "list.bullet" : "rectangle.grid.1x2")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(compact == list ? Palette.bg2 : Palette.fg)
                        .frame(width: 44, height: 36)
                        .background(compact == list ? Palette.link : Palette.bg3, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(compact == list ? Palette.link : Palette.line, lineWidth: 1))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.label(list ? "viewList" : "viewCards"))
                .accessibilityAddTraits(compact == list ? [.isSelected, .isButton] : .isButton)
                .accessibilityIdentifier(list ? "frameworks-view-list" : "frameworks-view-cards")
            }
        }
    }

    @ViewBuilder private var browse: some View {
        let L = model.frameworks
        ForEach(L.catalog.groups) { group in
            let cards = L.frameworks(in: group.id)
            if !cards.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    CountedLabel(text: group.name, count: cards.count)
                    Text(group.line).font(DS.caption).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 6)
                .id("group-\(group.id)")
                .accessibilityIdentifier("framework-group-\(group.id)")
                if pane || model.progress.frameworksCompact {
                    VStack(spacing: 0) {
                        ForEach(cards) { f in
                            let on = picked(.framework(f.id))
                            Button { open(.framework(f.id)) } label: { CompactFrameworkRow(framework: f, days: !pane, picked: on) }
                                .buttonStyle(.plain)
                                // the pick: a wash of the link colour and a bar at the row's leading edge
                                .background(on ? Palette.link.opacity(0.12) : Color.clear)
                                .overlay(alignment: .leading) { if on { Rectangle().fill(Palette.link).frame(width: 3).accessibilityHidden(true) } }
                                .lxHover()
                                .id("row-\(f.id)")
                                .accessibilityAddTraits(on ? .isSelected : [])
                                .accessibilityIdentifier("framework-card-\(f.id)")
                            if f.id != cards.last?.id { Divider().overlay(Palette.line).padding(.leading, 14) }
                        }
                    }
                    .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
                } else {
                    grid {
                        ForEach(cards) { f in
                            Button { model.push(.framework(f.id)) } label: { FrameworkCard(framework: f) }
                                .buttonStyle(.plain)
                                .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .lxHover()
                                .accessibilityIdentifier("framework-card-\(f.id)")
                        }
                    }
                }
            }
        }
        if !L.catalog.lands.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel(text: L.label("landsTitle"))
                Text(L.label("landsLine")).font(DS.caption).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 6)
            grid {
                ForEach(L.catalog.lands) { land in
                    Button { open(.landing(land.id)) } label: {
                        ResultRow(title: land.name, line: land.owner, bar: picked(.landing(land.id)) ? Palette.link : Palette.lineStrong, trailing: true)
                    }
                    .buttonStyle(.plain)
                    .lxHover()
                    .accessibilityAddTraits(picked(.landing(land.id)) ? .isSelected : [])
                    .accessibilityIdentifier("landing-\(land.id)")
                }
            }
        }
    }

    @ViewBuilder private var compare: some View {
        let L = model.frameworks
        Text(L.label("compareIntro")).font(DS.step).foregroundStyle(Palette.fg).fixedSize(horizontal: false, vertical: true)
        // Round 2: any two cards. Two menus and a button; the named comparisons follow
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: L.label("compareAny"))
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))) {
                pick(L.label("compareFirst"), model.compareA, "compare-pick-a") { model.compareA = $0 }
                pick(L.label("compareSecond"), model.compareB, "compare-pick-b") { model.compareB = $0 }
            }
            let ready = model.compareA != nil && model.compareB != nil && model.compareA != model.compareB
            Button {
                if let a = model.compareA, let b = model.compareB, a != b { open(.pair(a, b)) }
            } label: {
                Text(L.label("compareOpen")).font(DS.style(.subheadline).weight(.semibold))
                    // not yet ready: the page's own text on the quiet fill, with a hairline, so it still reads at full contrast
                    .foregroundStyle(ready ? Palette.bg2 : Palette.fg)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(ready ? Palette.link : Palette.bg3, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(ready ? Palette.link : Palette.line, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // not disabled: the system dims a disabled control below the contrast floor. Until two are picked the button
            // does nothing, looks quiet and says why
            .accessibilityHint(ready ? "" : L.label("compareHint"))
            .accessibilityIdentifier("compare-open")
        }
        .lxCard(radius: 18)
        SectionLabel(text: L.label("compareNamed")).padding(.top, 6)
        ForEach(L.compares) { c in
            if let a = L.byId[c.a], let b = L.byId[c.b] {
                Button { open(.compare(c.id)) } label: { ComparisonCard(comparison: c, a: a, b: b) }
                    .buttonStyle(.plain)
                    .overlay { if picked(.compare(c.id)) { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.link, lineWidth: 2).accessibilityHidden(true) } }
                    .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .lxHover()
                    .accessibilityAddTraits(picked(.compare(c.id)) ? .isSelected : [])
                    .accessibilityIdentifier("compare-card-\(c.id)")
            }
        }
        Text(L.label("compareMore")).font(DS.caption).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("compare-more")
    }

    /// One of Compare's two menus: every card, by group, with the one picked named on the control.
    private func pick(_ prompt: String, _ picked: String?, _ id: String, _ set: @escaping (String) -> Void) -> some View {
        let L = model.frameworks
        return Menu {
            ForEach(L.catalog.groups) { g in
                SwiftUI.Section(g.name) {
                    ForEach(L.frameworks(in: g.id)) { f in Button(f.shortName) { set(f.id) } }
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let f = picked.flatMap({ L.byId[$0] }) {
                    Circle().fill(f.tone).frame(width: 8, height: 8).accessibilityHidden(true)
                    Text(keepDesignations(f.shortName)).font(DS.style(.subheadline).weight(.semibold)).foregroundStyle(.primary)
                } else {
                    Text(prompt).font(DS.style(.subheadline)).foregroundStyle(Palette.fg2)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down").font(.footnote.weight(.semibold)).foregroundStyle(Palette.fg2).accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Palette.bg3, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .accessibilityLabel(picked.flatMap { L.byId[$0]?.shortName }.map { "\(prompt): \($0)" } ?? prompt)
        .accessibilityIdentifier(id)
    }

    /// The self-checks (Round 2): each a card that says what it checks and how far along the reader is.
    @ViewBuilder private var checks: some View {
        let L = model.frameworks
        Text(L.label("checksIntro")).font(DS.step).foregroundStyle(Palette.fg).fixedSize(horizontal: false, vertical: true)
        ForEach(L.checks) { check in
            if let f = L.byId[check.frameworkId] {
                let result = check.result(model.progress.answers(check.id))
                Button { open(.check(check.id)) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        FrameworkTile(framework: f)
                        VStack(alignment: .leading, spacing: 3) {
                            Eyebrow(text: f.shortName, color: f.tone, small: true)
                            Text(check.title).font(DS.style(.headline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                            Text(check.line).font(DS.style(.subheadline)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                            Text(L.label("answered").replacingOccurrences(of: "{n}", with: "\(result.answered)").replacingOccurrences(of: "{m}", with: "\(result.total)"))
                                .font(DS.style(.footnote).weight(.semibold)).foregroundStyle(.primary).padding(.top, 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).padding(.top, 8).accessibilityHidden(true)
                    }
                    .lxCard(radius: 18)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                }
                .buttonStyle(.plain)
                .overlay { if picked(.check(check.id)) { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.link, lineWidth: 2).accessibilityHidden(true) } }
                .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 18, style: .continuous))
                .lxHover()
                .accessibilityAddTraits(picked(.check(check.id)) ? .isSelected : [])
                .accessibilityIdentifier("check-card-\(check.id)")
            }
        }
        Text(L.label("checkNotAssessment")).font(DS.caption).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
    }
}

/// Cards in as many equal columns as fit a minimum width, row by row, each row as tall as its tallest card. Not lazy.
struct CardGrid: Layout {
    var minimum: CGFloat = 330
    var spacing: CGFloat = 12

    private func columns(_ width: CGFloat) -> Int { max(1, Int((width + spacing) / (minimum + spacing))) }

    private func frames(_ width: CGFloat, _ subviews: Subviews) -> [CGRect] {
        let n = columns(width)
        let w = (width - spacing * CGFloat(n - 1)) / CGFloat(n)
        var out: [CGRect] = [], y: CGFloat = 0
        for start in stride(from: 0, to: subviews.count, by: n) {
            let row = start..<min(start + n, subviews.count)
            let h = row.map { subviews[$0].sizeThatFits(ProposedViewSize(width: w, height: nil)).height }.max() ?? 0
            for (k, _) in row.enumerated() { out.append(CGRect(x: CGFloat(k) * (w + spacing), y: y, width: w, height: h)) }
            y += h + spacing
        }
        return out
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? minimum
        return CGSize(width: width, height: frames(width, subviews).map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (sv, f) in zip(subviews, frames(bounds.width, subviews)) {
            sv.place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY), proposal: ProposedViewSize(f.size))
        }
    }
}

/// A comparison's card in the Compare list: the two frameworks by tile and short name, and the one-sentence verdict.
struct ComparisonCard: View {
    @Environment(AppModel.self) private var model
    let comparison: Comparison
    let a: Framework
    let b: Framework

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ComparePair(a: a, b: b, nameA: comparison.aName, nameB: comparison.bName)
            Text(comparison.verdict).font(DS.style(.subheadline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.leading)
        .lxCard(radius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Two frameworks, each by its tile, short name and kind, with the word between them from the content: side by side
/// where both names and kinds fit on one line each, one under the other where they do not (long names on a phone, the
/// accessibility sizes). Round 2: in two equal columns a point wider than its longest word, a kind broken over two lines
/// under a name broken over two read as low contrast to the audit on the iPhone 18 Pro, and was cramped on every phone.
struct ComparePair: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let a: Framework
    let b: Framework
    /// Each side's own name where both are parts of one framework (FedRAMP 20x, FedRAMP Rev5).
    var nameA: String?
    var nameB: String?

    var body: some View {
        if typeSize.isAccessibilitySize {
            column
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 10) {
                    side(a, nameA, oneLine: true)
                    with
                    side(b, nameB, oneLine: true)
                }
                column
            }
        }
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: 8) {
            side(a, nameA, oneLine: false)
            with
            side(b, nameB, oneLine: false)
        }
    }

    private var with: some View {
        Text(model.frameworks.label("with")).font(DS.style(.footnote)).foregroundStyle(Palette.fg2)
    }

    private func side(_ f: Framework, _ name: String?, oneLine: Bool) -> some View {
        HStack(spacing: 8) {
            FrameworkTile(framework: f, base: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text(keepDesignations(name ?? f.shortName)).font(DS.style(.headline)).foregroundStyle(.primary)
                    .fixedSize(horizontal: oneLine, vertical: true)
                Eyebrow(text: f.kind, color: f.tone, small: true).fixedSize(horizontal: oneLine, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // one element, read as a name and what it is: "CSF 2.0, Outcomes"
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name ?? f.shortName), \(f.kind)")
    }
}

/// Where does X land? A standard without a full entry: what it is, who asks for it, the frameworks here it meets, and
/// its source.
struct LandingView: View {
    @Environment(AppModel.self) private var model
    let id: String

    var body: some View {
        let L = model.frameworks
        if let land = L.catalog.lands.first(where: { $0.id == id }) {
            ListScreen(eyebrow: L.label("landsEyebrow"), eyebrowColor: Palette.fg2, title: land.name, identifier: "landing-screen") {
                SwiftUI.Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(land.what).font(DS.style(.body)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                        Text(land.lands).font(DS.style(.subheadline)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                } header: {
                    ListNote(land.owner)
                }
                SwiftUI.Section {
                    ForEach(land.frameworkIds.compactMap { L.byId[$0] }) { f in FrameworkRow(framework: f, line: f.purpose) }
                } header: {
                    ListNote(L.label("landsOn"))
                }
                SwiftUI.Section {
                    SourceRows(source: land.source, tone: Palette.link)
                } header: {
                    ListNote(L.label("sources"))
                }
            }
        }
    }
}

/// A framework as a list row: its tile, its short name and one line; opens the framework.
struct FrameworkRow: View {
    @Environment(AppModel.self) private var model
    let framework: Framework
    let line: String

    var body: some View {
        NavigationLink(value: Nav.framework(framework.id)) {
            HStack(alignment: .top, spacing: 12) {
                FrameworkTile(framework: framework, base: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(keepDesignations(framework.shortName)).font(DS.style(.body)).foregroundStyle(.primary)
                    Text(line).font(DS.style(.subheadline)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("framework-row-\(framework.id)")
    }
}

/// A source's rows: its title with publisher, edition and date, the day it was last checked, and the link, which opens
/// in the in-app reader with the PDF tag where it opens a PDF. The trust mark, on every new entry.
struct SourceRows: View {
    @Environment(AppModel.self) private var model
    let source: Framework.SourceRecord
    let tone: Color

    var body: some View {
        let L = model.frameworks
        let sep = model.store.label("metaSeparator")
        VStack(alignment: .leading, spacing: 3) {
            Text(keepWhole(source.title)).font(DS.style(.body)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            Text(dotted([source.publisher, source.edition, SourceRows.date(source.date, unlessIn: source.edition)].compactMap { $0 }, separator: sep))
                .font(DS.style(.footnote)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
            Text(SourceRows.checked(source.verification, store: model.store, labels: L))
                .font(DS.style(.footnote)).foregroundStyle(source.verification.status == .conflict ? Palette.bad : Palette.secMaps)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("source-\(source.id)")
        .id("source-\(source.id)")
        if let url = URL(string: source.url) {
            Button { Reader.open(url) } label: {
                HStack(spacing: 8) {
                    Text(L.label("openSource")).font(DS.style(.body)).foregroundStyle(Palette.link)
                    if LinkFormat.isPDF(source.url) { PDFTag() }
                    Spacer()
                    Image(systemName: "arrow.up.forward").font(.footnote.weight(.semibold)).foregroundStyle(Palette.link).accessibilityHidden(true)
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("source-open-\(source.id)")
        }
        if let pdf = source.pdf.flatMap(URL.init(string:)) {
            Button { Reader.open(pdf) } label: {
                HStack(spacing: 8) {
                    Text(L.label("openPDF")).font(DS.style(.body)).foregroundStyle(Palette.link)
                    PDFTag()
                    Spacer()
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("source-pdf-\(source.id)")
        }
    }

    /// The source's date for its line, or nil where the edition already prints it (Round 4): "Release 5.2.0 (OSCAL content
    /// v1.6.0, 22 October 2026)" is not followed by "22 Oct 2026" again.
    static func date(_ date: String, unlessIn edition: String) -> String? {
        let shown = Rules.formatDate(date)
        let p = date.split(separator: "-").compactMap { Int($0) }
        let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        var forms = [shown]
        if p.count >= 2, (1...12).contains(p[1]) {
            forms.append(p.count == 3 ? "\(p[2]) \(months[p[1] - 1]) \(p[0])" : "\(months[p[1] - 1]) \(p[0])")
        } else if p.count == 1 {
            forms.append(String(p[0]))
        }
        return forms.contains { edition.contains($0) } ? nil : shown
    }

    /// "Verified · checked 14 Nov 2026", in the stack's own status words.
    static func checked(_ v: Verification, store: ContentStore, labels L: FrameworkLibrary) -> String {
        let status = store.content.ui.status[v.status.rawValue] ?? v.status.rawValue
        guard let on = v.verifiedOn else { return status }
        return dotted([status, "\(store.label("verifiedOn")) \(Rules.formatDate(on))"], separator: store.label("metaSeparator"))
    }
}

/// A framework as one compact row (Round 2; the density of the Ledger direction): a square of its colour, its short
/// name, its size, the days to its next dated deadline and where it sits. One control; VoiceOver hears the card's sentence.
struct CompactFrameworkRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let framework: Framework
    var today = Date()
    /// The days to the next dated deadline at the row's end; the iPad's narrow sidebar leaves them to the detail pane.
    var days = true
    /// The iPad's sidebar marks the pick with a wash of the link colour: on it the row's second line and its layer take
    /// the page's own text colour, since the secondary grey falls under the contrast floor there.
    var picked = false

    var body: some View {
        let f = framework, L = model.frameworks
        let quiet = picked ? Palette.fg : Palette.fg2
        let deadline = L.upcoming(f, store: model.store, today: today)
        let days = deadline.flatMap { $0.days(from: today) }
        let showDays = self.days
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(f.tone).frame(width: 10, height: 10).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(keepDesignations(f.shortName)).font(DS.style(.body).weight(.semibold)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                // the size alone: the kind is on the card, and a second fact would wrap the row at this width
                // in the sidebar the second line is a size larger: the rows are the pane's navigation, and on the iPad's
                // screen the footnote size is thin enough that the contrast audit misreads it (it measures 7.5:1)
                Text(FrameworkCard.sizeShort(f)).font(DS.style(showDays ? .footnote : .subheadline)).foregroundStyle(quiet).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let days, showDays, !typeSize.isAccessibilitySize {
                Text(CountdownCard.count(days, labels: L)).font(DS.style(.footnote).weight(.semibold)).foregroundStyle(f.tone)
            }
            // never cut short: it keeps its own width, and the name beside it wraps instead
            Text(model.sitsShort(f)).font(DS.eyebrowSmall).foregroundStyle(quiet).fixedSize()
            Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
        }
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 14).padding(.vertical, 9)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(FrameworkCard.spoken(f, model: model, deadline: deadline, days: days))
        .accessibilityAddTraits(.isButton)
    }
}

/// A group of cards as a screen of its own (Round 2): Explore's adversary column opens it, so the knowledge bases that
/// sit beside the stack are reached from the stack too.
struct FrameworkGroupView: View {
    @Environment(AppModel.self) private var model
    let id: String

    var body: some View {
        let L = model.frameworks
        if let group = L.group(id) {
            ListScreen(eyebrow: AppTab.frameworks.title, eyebrowColor: Palette.link, title: group.name, identifier: "group-screen") {
                SwiftUI.Section {
                    Text(group.line).font(DS.style(.subheadline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 2)
                }
                SwiftUI.Section {
                    ForEach(L.frameworks(in: id)) { f in FrameworkRow(framework: f, line: f.purpose) }
                }
            }
        }
    }
}
