import SwiftUI

/// Home (build 6, Ken's pick of 10 November 2026; option A of the playbook-forward mock-ups): the first tab and where the
/// app opens, on first launch and after. The compass tile, the LENSATIC eyebrow and the content's tagline; then the three
/// doors in the website hub's order, Framework Maps, Field Guide and the playbook, each with its section colour, icon tile,
/// eyebrow, title, the hub's own line on what it is for and a live status line; then what the Library tab held: Saved,
/// Reference and About. A system inset-grouped list on the app's own surfaces, with the doors as its hero cards (section
/// 7 of the content release: lxCard, icon tiles, Dynamic Type). On the iPad the doors sit side by side. Every count is
/// computed: the steps done on the reader's trailhead, the guide's week, the plays read, the terms and verified sources.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showStory = false
    static let savedShown = 5
    /// The play the playbook door starts with (Ken's ruling, 10 November 2026): Agentic Insider Risk, by its id in
    /// playbook/app/plays.json. A unit test holds it to a play in the file.
    static let startPlay = "insiders"

    var body: some View {
        let saved = model.progress.saved.filter { model.describe($0) != nil }
        List {
            Group {
                SwiftUI.Section {
                    header
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 2, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    // Lensatic 2.0: the zero trust countdown and the way into the frameworks lead; the three doors follow
                    lead
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    doors
                        // the doors' edges line up with the sections' below
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                SwiftUI.Section {
                    if saved.isEmpty {
                        Text("Nothing saved yet. Tap the bookmark on a framework, a step or a play to keep it here.")
                            .font(DS.style(.subheadline)).foregroundStyle(Palette.fg2)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("home-saved-empty")
                    } else {
                        // grouped by type: frameworks and sources, then steps, then plays, each newest first
                        ForEach(HomeView.byType(Array(saved.prefix(HomeView.savedShown))), id: \.key) { item in SavedListRow(item: item) }
                        if saved.count > HomeView.savedShown {
                            NavigationLink(value: Nav.saved) {
                                Text("All \(saved.count) Saved").font(DS.style(.body))
                            }
                            .accessibilityIdentifier("home-all-saved")
                        }
                    }
                } header: {
                    ListNote("Saved")
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home-saved")
                #if DEBUG
                .id("home-saved")
                #endif
                SwiftUI.Section {
                    ReferenceRow(icon: RowIcon.glossary, title: model.store.navTitle(.glossary), detail: "\(model.store.terms.count) terms",
                                 nav: .glossary, id: "home-glossary")
                    ReferenceRow(icon: RowIcon.sources, title: "All Sources", detail: "\(model.store.counts[.verified] ?? 0) verified",
                                 nav: .sources, id: "home-sources")
                    ReferenceRow(icon: RowIcon.changes, title: "What Changed", detail: Rules.shortDate(model.store.content.meta.builtOn),
                                 nav: .changes, id: "home-changes")
                    widgetDeadlineRow
                } header: {
                    ListNote("Reference")
                }
                // About, visible (Ken's ruling, 10 November 2026): the story of the name and the About screen, each a row
                SwiftUI.Section {
                    Button { showStory = true } label: {
                        HStack(spacing: 8) {
                            TileRow(icon: RowIcon.story, title: model.store.label("whyName"))
                            Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the story of the name")
                    .accessibilityIdentifier("home-why")
                    NavigationLink(value: Nav.about) {
                        TileRow(icon: RowIcon.about, title: model.store.label("homeAbout").replacingOccurrences(of: "{name}", with: model.store.content.meta.name))
                    }
                    .accessibilityIdentifier("home-about")
                } header: {
                    ListNote(model.library.site.aboutLabel)
                }
            }
            .lxRows()
        }
        .listStyle(.insetGrouped)
        .lxListSurface()
        // the header starts close under the status bar, so the three doors fit a 390 x 844 phone with no scroll
        .contentMargins(.top, 0, for: .scrollContent)
        .environment(\.defaultMinListRowHeight, 44)
        .hardTopEdge()
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("home")
        .sheet(isPresented: $showStory) { StorySheet().environment(model).tint(Palette.link) }
        #if DEBUG
        .debugScrollTo()
        // -LensaticStory opens the story of the name at launch, for the tests and screenshots
        .onAppear { if CommandLine.arguments.contains("-LensaticStory") { showStory = true } }
        #endif
    }

    /// The widget's countdown (Round 2, ruling 8): Automatic, which is build 6's behaviour (a deadline only where one
    /// binds the reader's trailhead), or a dated deadline from the stack, counted down to whatever the trailhead. One
    /// control, a menu; the choice is kept in the progress file, which the widget reads.
    private var widgetDeadlineRow: some View {
        let L = model.frameworks
        let choices = Glance.choices(store: model.store, today: Date())
        let picked = choices.first { $0.id == model.progress.state.widgetDeadline }
        return Menu {
            Button(L.label("widgetAutomatic")) { model.progress.setWidgetDeadline(nil) }
            ForEach(choices) { c in Button(c.title) { model.progress.setWidgetDeadline(c.id) } }
        } label: {
            TileRow(icon: ("timer", .teal), title: L.label("widgetDeadline"), subtitle: picked == nil ? L.label("widgetAutomaticLine") : nil,
                    value: picked?.label ?? L.label("widgetAutomatic"))
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("home-widget-deadline")
    }

    /// The compass tile (its tap opens the story of the name, as on the trailhead question) and the LENSATIC eyebrow, then
    /// the content's tagline.
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button { showStory = true } label: { MarkTile(side: 44) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Why Lensatic")
                    .accessibilityHint("Opens the story of the name")
                    .accessibilityIdentifier("home-story")
                Eyebrow(text: model.store.content.meta.name)
            }
            // at the accessibility sizes the tagline takes the row title's size, so the doors start on the first screen
            Text(model.store.content.meta.tagline).font(typeSize.isAccessibilitySize ? DS.rowTitle : DS.sheetTitle).foregroundStyle(Palette.fg)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("home-tagline")
        }
    }

    /// Lensatic 2.0, above the doors: the countdown to the next dated zero trust deadline, as a bearing on the compass,
    /// which opens the framework that sets it; and the frameworks card. Side by side on the iPad, with the card's three
    /// ways in (Browse, Compare and the self-checks). On a phone both are compact, one under the other, so that all three
    /// doors are on the first screen of the smallest current iPhone at the default text size (Ken's ruling 7, 14 November
    /// 2026): the countdown is one row, and the frameworks card is its name and the row of frameworks to open; Compare
    /// and the self-checks are one tap on, in the Frameworks tab.
    @ViewBuilder private var lead: some View {
        let L = model.frameworks
        let wide = sizeClass == .regular && !typeSize.isAccessibilitySize
        let today = Date()
        (wide ? AnyLayout(HStackLayout(alignment: .top, spacing: 12)) : AnyLayout(VStackLayout(spacing: 10))) {
            if let d = model.zeroTrustCountdown(today: today), let days = d.days(from: today), let f = L.byId[d.frameworkId] {
                Button { model.show(.framework(f.id)) } label: {
                    CountdownCard(deadline: d, days: days, tone: f.tone, eyebrow: L.label("countdown"), chevron: true, tall: wide, compact: !wide)
                }
                .buttonStyle(.plain)
                .accessibilityHint(L.label("countdownHint"))
                .accessibilityIdentifier("home-countdown")
            }
            HomeFrameworks(tall: wide, compact: !wide && !typeSize.isAccessibilitySize)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The three doors, in the hub's order (Ken's ruling): stacked on a phone, side by side on the iPad.
    @ViewBuilder private var doors: some View {
        let site = model.library.site
        let wide = sizeClass == .regular && !typeSize.isAccessibilitySize
        let layout = wide ? AnyLayout(HStackLayout(alignment: .top, spacing: 12)) : AnyLayout(VStackLayout(spacing: 10))
        layout {
            HomeDoor(symbol: RowIcon.maps.0, tile: RowIcon.maps.1, tint: Palette.secMaps, eyebrow: site.section("maps")?.name ?? "",
                     title: model.store.label("homeMapsTitle"), line: site.section("maps")?.line ?? "",
                     status: model.pathStatus ?? [model.store.label("homePickTrailhead")], tall: wide, identifier: "home-door-maps") {
                model.openMaps()
            }
            HomeDoor(symbol: RowIcon.guide.0, tile: RowIcon.guide.1, tint: Palette.secGuides, eyebrow: model.store.label("homeFieldGuide"),
                     title: site.guideTitle, line: site.section("guides")?.line ?? "", status: [model.guideStatus.line], tall: wide,
                     identifier: "home-door-guide") {
                model.push(.guide)
            }
            HomeDoor(symbol: RowIcon.playbook.0, tile: RowIcon.playbook.1, tint: Palette.secPurple, eyebrow: site.playsName,
                     // the hub's line opens with the title this door already carries, so the app has its own (ui.labels)
                     title: site.playsTitle, line: model.store.label("homePlaysLine"), status: [model.playsStatus.line], tall: wide,
                     start: model.library.play(HomeView.startPlay).map { play in
                         (model.store.label("homeStartHere").replacingOccurrences(of: "{play}", with: play.name), { model.push(.play(play.id)) })
                     },
                     identifier: "home-door-playbook") {
                model.push(.plays)
            }
        }
        // side by side, the doors share one height
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Saved items grouped by type, in the order frameworks, steps, plays, each group keeping its newest-first order.
    static func byType(_ items: [SavedItem]) -> [SavedItem] {
        func rank(_ i: SavedItem) -> Int {
            switch i { case .entity, .framework: return 0; case .step: return 1; case .play: return 2 }
        }
        return items.enumerated().sorted { a, b in rank(a.element) != rank(b.element) ? rank(a.element) < rank(b.element) : a.offset < b.offset }.map(\.element)
    }
}

/// One of Home's three doors (build 6): a hero card in a light wash of its section's tint, with an icon tile, the section's mono caps
/// eyebrow, the title, one line on what the section is for and a live status line. The whole card opens the section; the
/// playbook's also carries a second control, the play to start with, so it never reads as last place.
struct HomeDoor: View {
    let symbol: String
    let tile: Color
    let tint: Color
    let eyebrow: String
    let title: String
    let line: String
    /// The status line's parts: on one line with the content's dot between them where they fit, else one to a line.
    let status: [String]
    /// The iPad's side-by-side doors: the tile above the words, and every door the height of the tallest.
    var tall = false
    var start: (label: String, open: () -> Void)?
    let identifier: String
    let open: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // at the accessibility sizes, and side by side on the iPad, the tile sits above the words, which keep the width
        let stacked = tall || typeSize.isAccessibilitySize
        VStack(alignment: .leading, spacing: 0) {
            Button(action: open) {
                (stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))) {
                    if stacked {
                        // the tile above the words, with the chevron at the card's far corner, so the card reads as a way in
                        HStack(alignment: .top) {
                            IconTile(symbol: symbol, tint: tile)
                            Spacer()
                            Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                    } else {
                        IconTile(symbol: symbol, tint: tile)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Eyebrow(text: eyebrow, color: tint, small: true)
                        Text(title).font(DS.style(.headline)).foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        // Lensatic 2.0: on a phone the door keeps its name and its live status; the line on what the
                        // section is for shows where there is room for it, side by side on the iPad
                        if tall {
                            Text(line).font(DS.style(.subheadline)).foregroundStyle(Palette.fg2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ViewThatFits(in: .horizontal) {
                            Text(status.joined(separator: model.store.label("metaSeparator"))).lineLimit(1)
                            VStack(alignment: .leading, spacing: 1) {
                                ForEach(status, id: \.self) { Text($0).fixedSize(horizontal: false, vertical: true) }
                            }
                        }
                        .font(DS.style(.footnote).weight(.semibold)).foregroundStyle(.primary)
                        .padding(.top, 3)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(status.joined(separator: ", "))
                        .accessibilityIdentifier("\(identifier)-status")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    if !stacked {
                        Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            .padding(.top, 8).accessibilityHidden(true)
                    }
                }
                .frame(maxHeight: tall ? .infinity : nil, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(identifier)
            if let start {
                Divider().overlay(Palette.line).padding(.top, 10)
                Button(action: start.open) {
                    HStack(spacing: 8) {
                        Text(start.label).font(DS.style(.subheadline).weight(.semibold)).foregroundStyle(Palette.link)
                            .frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // the row's 44 points reach into the card's own bottom padding, so the card ends close under its words
                .padding(.bottom, -10)
                .accessibilityIdentifier("\(identifier)-start")
            }
        }
        // the doors' row is inset 4 points from the list row's edge
        .lxCard(radius: LxCard.inList(18, inset: 4), tint: tint)
    }
}

/// Home's frameworks card (Lensatic 2.0): how many frameworks the navigator holds, in one line, and the three things a
/// first-time reader can do with them at once, each a control of its own: Browse, Compare and Check Yourself.
struct HomeFrameworks: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    var tall = false
    /// A phone at the standard text sizes: the card's name and the row of frameworks, without the line and the buttons.
    var compact = false

    var body: some View {
        let L = model.frameworks
        VStack(alignment: .leading, spacing: 10) {
            Button { model.showFrameworks(.browse) } label: {
                HStack(alignment: .top, spacing: 12) {
                    IconTile(symbol: "square.stack.3d.up.fill", tint: .indigo)
                    VStack(alignment: .leading, spacing: 3) {
                        Eyebrow(text: AppTab.frameworks.title, color: Palette.link, small: true)
                        Text(L.label("homeFrameworksTitle").replacingOccurrences(of: "{count}", with: "\(L.frameworks.count)"))
                            .font(DS.style(.headline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                        if !compact {
                            Text(L.label("homeFrameworksLine")).font(DS.style(.subheadline)).foregroundStyle(Palette.fg2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        .padding(.top, 8).accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("home-frameworks")
            // the frameworks a first-time reader is most likely to be looking for, each one tap from Home: a row that
            // scrolls sideways, in each framework's own color
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(L.catalog.featured.compactMap { L.byId[$0] }) { f in
                        Button { model.show(.framework(f.id)) } label: {
                            HStack(spacing: 6) {
                                Circle().fill(f.tone).frame(width: 8, height: 8).accessibilityHidden(true)
                                Text(keepDesignations(f.shortName)).font(DS.style(.subheadline).weight(.semibold)).foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(Palette.bg2, in: Capsule())
                            .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(f.kind)
                        .accessibilityIdentifier("home-framework-\(f.id)")
                    }
                }
            }
            .accessibilityIdentifier("home-featured")
            if !compact {
                (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))) {
                    action(L.label("browse"), "home-frameworks-browse") { model.showFrameworks(.browse) }
                    action(L.label("compare"), "home-frameworks-compare") { model.showFrameworks(.compare) }
                    if !L.checks.isEmpty {
                        action(L.label("homeCheck"), "home-frameworks-check") { model.showFrameworks(.checks) }
                    }
                }
            }
            if tall { Spacer(minLength: 0) }
        }
        .frame(maxHeight: tall ? .infinity : nil, alignment: .topLeading)
        .lxCard(radius: LxCard.inList(18, inset: 4), tint: Palette.link, vertical: compact ? 12 : 16)
    }

    private func action(_ title: String, _ id: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(title).font(DS.style(.subheadline).weight(.semibold)).foregroundStyle(Palette.link)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.link.opacity(0.45), lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

/// My Path before a trailhead is picked (build 6: the app opens on Home, so the tab can be reached first): what a path
/// is, in the trailhead question's own words, and the way to the question.
struct NoTrailheadView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: AppTab.path.title)
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.store.label("homeMapsTitle")).font(DS.heroStep).foregroundStyle(Palette.fg)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(model.store.label("welcomeLede")).font(DS.lede).foregroundStyle(Palette.fg2).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { model.changingDoor = true } label: { Text(model.store.label("homeChoose")) }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("path-choose")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(radius: 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .hardTopEdge()
        .accessibilityIdentifier("my-path-empty")
    }
}
