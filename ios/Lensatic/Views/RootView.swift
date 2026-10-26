import SwiftUI

/// The app (the redesign, R1): the welcome screen until a trailhead is picked, then the four tabs. Change brings the
/// welcome screen back over the tabs; a glossary entry and an entry's Sources open as sheets.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            if model.door == nil {
                WelcomeView()
            } else {
                Shell()
            }
        }
        .tint(Palette.link)
        .sheet(isPresented: $model.changingDoor) {
            WelcomeView(isChange: true)
                .environment(model)
        }
        .sheet(item: $model.glossaryEntry) { entry in
            GlossarySheetView(slug: entry.slug)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .tint(Palette.link)
        }
    }
}

/// The four tabs, each its own navigation stack (the screens pushed in each are kept while the reader is elsewhere),
/// over the tab bar. Tapping the tab already open goes back to its first screen.
struct Shell: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let tab = model.tab
        VStack(spacing: 0) {
            NavigationStack(path: Binding(get: { model.paths[tab] ?? [] }, set: { model.paths[tab] = $0 })) {
                root(tab)
                    .navigationDestination(for: Nav.self) { destination($0) }
            }
            .id(tab)
            // a card is a full screen of its own, as the mockup draws it: the tab bar steps aside while it is open
            if !model.cardOnTop {
                TabBar(selection: Binding(get: { model.tab }, set: { new in
                if new == model.tab { model.paths[new] = [] }
                model.tab = new
            }))
            }
        }
        .background(Palette.bg)
        // a slightly darker scrim than the system's behind a sheet (nits v0.3, item 9), so the card recedes as drawn
        .overlay {
            if model.sourcesFor != nil {
                Color.black.opacity(0.3).ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.sourcesFor)
        .sheet(isPresented: Binding(get: { model.sourcesFor != nil }, set: { if !$0 { model.sourcesFor = nil } })) {
            if let id = model.sourcesFor { SourcesSheet(id: id).environment(model).tint(Palette.link) }
        }
    }

    @ViewBuilder private func root(_ tab: AppTab) -> some View {
        switch tab {
        case .path: MyPathView()
        case .explore: ShelfView(tab: .explore)
        case .search: SearchPlaceholderView()
        case .library: ShelfView(tab: .library)
        }
    }

    @ViewBuilder private func destination(_ nav: Nav) -> some View {
        switch nav {
        case .entity(let id):
            EntityCardView(id: id)
        case .section(let s):
            // one identity per section, so a jump between sections starts a fresh page (and its scroll)
            PageScreen(key: .section(s, s == .matrix ? model.matrixView : .dow)).id(s)
        case .legacy(let route):
            PageScreen(key: .route(route)).onAppear { model.opened(route) }
        }
    }
}

/// Where the sections of the map that R1 does not redesign live until their own screens arrive (R2): the stack, the
/// matrix, the six functions and the AI column under Explore; the questions, sources, glossary and About under Library.
enum LegacyShelf {
    static let explore: [Section] = [.stack, .matrix, .functions, .ai]
    static let library: [Section] = [.helper, .sources, .glossary, .about]

    static func tab(for s: Section) -> AppTab {
        if s == .doors { return .path }
        return explore.contains(s) ? .explore : .library
    }
}

/// Explore and Library in R1: a header and the map's sections as list rows, each opening the section as the map shows
/// it. Library also holds the trailhead setting.
struct ShelfView: View {
    @Environment(AppModel.self) private var model
    let tab: AppTab

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(eyebrow: model.store.label("mapName"), title: tab.title)
                if tab == .library, let door = model.door {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Your trailhead")
                        Button { model.changingDoor = true } label: {
                            ListRow(title: door.shortTitle, subtitle: "Change where you stand", icon: door.id.icon, iconColor: door.id.color)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("library-change-door")
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: tab == .library ? "Reference" : "The map")
                    ForEach(tab == .library ? LegacyShelf.library : LegacyShelf.explore, id: \.self) { s in
                        NavigationLink(value: Nav.section(s)) {
                            ListRow(title: TitleCase.apply(model.store.navTitle(s)), subtitle: model.store.sectionTitle(s))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("section-\(s.rawValue)")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Palette.bg)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Search in R1: a placeholder until R2 brings one search across frameworks, steps and the glossary.
struct SearchPlaceholderView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Search")
                HStack(spacing: 12) {
                    Icon(.search, size: 24, color: Palette.fg2)
                    Text("One search across frameworks, path steps and the glossary arrives in the next update.")
                        .font(DS.step).foregroundStyle(Palette.fg2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(radius: 14)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(Palette.bg)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// One screen: its page, built once and drawn by `PageView`.
struct PageScreen: View {
    @Environment(AppModel.self) private var model
    let key: PageKey

    var body: some View {
        let page = model.page(key)
        PageView(page: page)
            .navigationTitle(page.title)
            .navigationBarTitleDisplayMode(.inline)
            // the map's pages keep their bar, with its back button and title, under a tab whose first screen hides one
            .toolbar(.visible, for: .navigationBar)
    }
}

struct GlossarySheetView: View {
    @Environment(\.dismiss) private var dismiss
    let slug: String

    var body: some View {
        // Done sits in the sheet, in the app's type, so it scales with Dynamic Type like everything else
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Text("Done").font(Typo.button).foregroundStyle(Palette.link).padding(.horizontal, 20).frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("glossary-done")
            }
            .padding(.top, 8)
            PageScreen(key: .glossaryEntry(slug))
        }
        .background(Palette.bg)
    }
}
