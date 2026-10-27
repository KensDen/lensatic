import CoreSpotlight
import SwiftUI

/// The app (the redesign): the welcome screen until a trailhead is picked, then the four tabs. Change brings the
/// welcome screen back over the tabs; a glossary entry and an entry's Sources open as sheets. A tap on one of the app's
/// items in iOS search opens it.
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
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String { model.openSpotlight(id) }
        }
        .task { model.indexForSpotlight() }
    }
}

/// The four tabs, each its own navigation stack (the screens pushed in each are kept while the reader is elsewhere),
/// over the tab bar. Tapping the tab already open goes back to its first screen. Links inside the map's text open in
/// the app; outside addresses go to the system browser.
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
        .environment(\.openURL, OpenURLAction { url in
            guard let target = Target(url: url) else { return .discarded }
            if case .external = target { return .systemAction }
            model.go(target)
            return .handled
        })
        // a slightly darker scrim than the system's behind a sheet (nits v0.3, item 9), so the screen recedes as drawn
        .overlay {
            if model.sourcesFor != nil || model.glossaryEntry != nil {
                Color.black.opacity(0.3).ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.sourcesFor)
        .animation(.easeOut(duration: 0.2), value: model.glossaryEntry)
        .sheet(isPresented: Binding(get: { model.sourcesFor != nil }, set: { if !$0 { model.sourcesFor = nil } })) {
            if let id = model.sourcesFor { SourcesSheet(id: id).environment(model).tint(Palette.link) }
        }
        .sheet(item: $model.glossaryEntry) { entry in
            GlossarySheetView(slug: entry.slug).environment(model).tint(Palette.link)
        }
    }

    @ViewBuilder private func root(_ tab: AppTab) -> some View {
        switch tab {
        case .path: MyPathView()
        case .explore: ExploreView()
        case .search: SearchView()
        case .library: LibraryView()
        }
    }

    @ViewBuilder private func destination(_ nav: Nav) -> some View {
        switch nav {
        case .entity(let id): EntityCardView(id: id)
        case .layer(let id): LayerView(id: id)
        case .cell(let v, let p, let f): CellView(view: v, pillar: p, function: f)
        case .glossary: GlossaryView()
        case .sources: SourcesListView()
        case .about: AboutView()
        case .saved: SavedListView()
        case .guide: GuideView()
        case .chapter(let id): ChapterView(id: id)
        case .plays: PlaysView()
        case .play(let id): PlayView(id: id)
        }
    }
}
