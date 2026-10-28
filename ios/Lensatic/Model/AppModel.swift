import Foundation
import Observation

/// Where the reader is: the trailhead, the checks, the saved items and the guide's weeks (kept on the device by
/// `ProgressStore`), the tab, the screens pushed inside each tab, Explore's view and the matrix's pillar view, the step
/// to open on My Path, the glossary entry and the Sources sheet open over a screen.
@Observable @MainActor
final class AppModel {
    let store: ContentStore
    let library: Library
    let changes: Changes
    let progress: ProgressStore
    var tab: AppTab = .path
    var paths: [AppTab: [Nav]] = [:]
    /// The welcome screen over the tabs, to pick a different trailhead (Change on My Path, Library's Settings).
    var changingDoor = false
    var explore: ExploreMode = .stack
    var matrixView: PillarView = .dow
    /// A step to open and show on My Path (a search result, a saved step, iOS search).
    var pathFocus: Int?
    var query = ""
    var glossaryEntry: GlossarySheet?
    /// The Sources sheet over a card, by the card's entity id.
    var sourcesFor: String?
    @ObservationIgnored private var plans: [Door.ID: PathPlan] = [:]
    @ObservationIgnored private var screens: [String: Any] = [:]
    @ObservationIgnored private var searchIndex: (door: Door.ID?, index: SearchIndex)?

    struct GlossarySheet: Identifiable, Hashable {
        let slug: String
        var id: String { slug }
    }

    init(store: ContentStore, library: Library, changes: Changes = .empty, progress: ProgressStore = ProgressStore()) {
        self.store = store
        self.library = library
        self.changes = changes
        self.progress = progress
        if let view = door?.pillarView.value { matrixView = view }
        #if DEBUG
        debugLaunch(ProcessInfo.processInfo.arguments)
        #endif
    }

    // MARK: the path

    var door: Door? { progress.door.flatMap(door) }

    func door(_ id: Door.ID) -> Door? { store.content.doors.first { $0.id == id } }

    func plan(_ door: Door) -> PathPlan {
        if let hit = plans[door.id] { return hit }
        let plan = PathPlan(door: door, entities: store.entities)
        plans[door.id] = plan
        return plan
    }

    /// Picking a trailhead opens My Path at its top; each trailhead keeps its own checks. iOS search gets its steps. A
    /// reader's very first pick starts What Changed from this release: what changed before they arrived is not news.
    func choose(_ id: Door.ID) {
        if progress.door == nil && progress.state.changesViewed == nil {
            progress.viewChanges(through: changes.contentVersion, on: Changes.today())
        }
        progress.choose(id)
        changingDoor = false
        paths[.path] = []
        tab = .path
        if let view = door(id)?.pillarView.value { matrixView = view }
        indexForSpotlight()
    }

    /// The layer the reader's next step sits at: Explore calls it out as on their path.
    var pathLayer: String? {
        guard let door else { return nil }
        let plan = plan(door)
        return plan.next(progress.checked(door.id))?.layerId ?? plan.steps.last?.layerId
    }

    // MARK: What Changed

    /// The news newer than the reader's last visit to What Changed: My Path shows it until the reader opens the list.
    var newChanges: [Changes.Item] { changes.new(since: progress.state.changesViewed, door: door) }

    /// The reader has seen the list: everything in this release is no longer new (kept with the day, on the device).
    func markChangesSeen() {
        progress.viewChanges(through: changes.contentVersion, on: Changes.today())
    }

    // MARK: screens, built once

    func screen<T>(_ key: String, _ make: () -> T) -> T {
        // the stored value is unwrapped first: a missing key cast to an optional T would read as a stored nil
        if let stored = screens[key], let hit = stored as? T { return hit }
        let made = make()
        screens[key] = made
        return made
    }

    var search: SearchIndex {
        if let hit = searchIndex, hit.door == door?.id { return hit.index }
        let index = SearchIndex(store: store, library: library, door: door, labels: .init())
        searchIndex = (door?.id, index)
        return index
    }

    // MARK: navigation

    /// Whether the open tab shows a card: the tab bar is hidden then.
    var cardOnTop: Bool {
        if case .entity? = paths[tab]?.last { return true }
        return false
    }

    func push(_ nav: Nav) {
        glossaryEntry = nil
        paths[tab, default: []].append(nav)
    }

    /// Open a screen from outside its tab (iOS search, a saved item): its tab, with only that screen pushed.
    func show(_ nav: Nav) {
        glossaryEntry = nil
        sourcesFor = nil
        changingDoor = false
        tab = nav.home
        paths[nav.home] = [nav]
    }

    /// Open a step on My Path, opened in place and scrolled to.
    func showStep(_ door: Door.ID, _ order: Int) {
        glossaryEntry = nil
        sourcesFor = nil
        if progress.door != door, self.door(door) != nil { progress.choose(door) }
        tab = .path
        paths[.path] = []
        pathFocus = order
    }

    func open(_ item: SavedItem) {
        switch item {
        case .entity(let id): push(.entity(id))
        case .play(let id): push(.play(id))
        case .step(let door, let order): showStep(door, order)
        }
    }

    func open(_ result: SearchIndex.Opens) {
        switch result {
        case .nav(let nav): push(nav)
        case .step(let door, let order): showStep(door, order)
        case .glossary(let slug): glossaryEntry = GlossarySheet(slug: slug)
        }
    }

    /// A tap on an item in iOS search, the widget or an intent: its identifier is a saved item's key. Returns whether
    /// it named something in this content.
    @discardableResult
    func openSpotlight(_ identifier: String) -> Bool {
        guard let item = SavedItem(key: identifier), exists(item) else { return false }
        switch item {
        case .entity(let id): show(.entity(id))
        case .play(let id): show(.play(id))
        case .step(let door, let order): showStep(door, order)
        }
        return true
    }

    func exists(_ item: SavedItem) -> Bool {
        switch item {
        case .entity(let id): return store.entities[id] != nil
        case .play(let id): return library.play(id) != nil
        case .step(let door, let order): return self.door(door)?.steps.contains(where: { $0.order == order }) == true
        }
    }

    /// Open Search with its field empty, ready to type (Siri and Shortcuts, R3).
    func openSearch() {
        glossaryEntry = nil
        sourcesFor = nil
        changingDoor = false
        query = ""
        paths[.search] = []
        tab = .search
    }

    /// The app's own links (R3), from the widget, an intent or another app: lensatic://open/<item key> opens that item,
    /// lensatic://search opens Search, lensatic://path opens My Path. Anything else is ignored. These links only move
    /// around the app; nothing is fetched.
    @discardableResult
    func open(link url: URL) -> Bool {
        guard url.scheme == DeepLink.scheme else { return false }
        switch url.host() {
        case "open": return openSpotlight(String(url.path().drop { $0 == "/" }))
        case "search":
            openSearch()
            return true
        case "path":
            showPath()
            return true
        default: return false
        }
    }

    /// My Path at its top, with nothing over it.
    func showPath() {
        glossaryEntry = nil
        sourcesFor = nil
        changingDoor = false
        tab = .path
        paths[.path] = []
    }

    /// Follow a link inside text: a screen pushes, a glossary term opens its entry, an outside address opens in the
    /// in-app reader (R3).
    func go(_ target: Target) {
        switch target {
        case .nav(let nav): push(nav)
        case .glossary(let slug): glossaryEntry = GlossarySheet(slug: slug)
        case .external(let url): Reader.open(url)
        }
    }

    /// What a saved item is called in the Library's list, the line under it, and its section's colour key.
    func describe(_ item: SavedItem) -> (title: String, line: String, section: String)? {
        let sep = store.label("metaSeparator")
        switch item {
        case .entity(let id):
            guard let e = store.entities[id] else { return nil }
            let layer = store.layerTag(e.layerId)
            return (e.displayName, [kindName(e.kind), layer].compactMap { $0 }.joined(separator: sep), "maps")
        case .play(let id):
            guard let p = library.play(id) else { return nil }
            return (p.name, [library.site.playsName, library.group(of: id)?.label].compactMap { $0 }.joined(separator: sep), "playbook")
        case .step(let d, let order):
            guard let door = door(d), let step = door.steps.first(where: { $0.order == order }) else { return nil }
            return (step.title, "Step \(order)\(sep)\(door.shortTitle)", "path")
        }
    }

    func kindName(_ kind: Entity.Kind) -> String {
        switch kind {
        case .framework: return "Framework"
        case .source: return "Source"
        case .solution: return "Solution"
        }
    }

    // MARK: iOS search

    func indexForSpotlight() {
        Spotlight.index(Spotlight.entries(store: store, library: library, door: door))
    }

    #if DEBUG
    /// The view a pushed screen scrolls to when it appears (-LensaticScrollTo), for the screenshots.
    @MainActor static var debugScrollTo: String?

    /// Launch arguments for the UI tests and the screenshot sheet (Debug builds only): -LensaticResetProgress forgets
    /// everything; -LensaticDoor <id> picks a trailhead; -LensaticChecked <1,2> checks those steps on it; -LensaticSaved
    /// <key,key> saves those items; -LensaticWeeks <1,2> marks those weeks done; -LensaticTab <tab> opens a tab;
    /// -LensaticExplore <view> picks Explore's view; -LensaticNav <path> pushes a screen (as Target.url's path, such
    /// as entity/dod-zt-strategy) on its tab, and -LensaticSources its Sources sheet; -LensaticEntity <id> opens a
    /// card on My Path; -LensaticQuery <text> fills Search; -LensaticScreen <section> opens a section of the map where
    /// the redesign keeps it (tools/ios_shots.sh).
    private func debugLaunch(_ args: [String]) {
        func value(_ flag: String) -> String? { args.firstIndex(of: flag).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
        func list(_ flag: String) -> [String] { value(flag)?.split(separator: ",").map(String.init) ?? [] }
        if args.contains("-LensaticResetProgress") { progress.reset() }
        if let d = value("-LensaticDoor").flatMap(Door.ID.init(rawValue:)) {
            progress.choose(d)
            if let view = door(d)?.pillarView.value { matrixView = view }
            for n in list("-LensaticChecked").compactMap({ Int($0) }) where !progress.isChecked(d, n) { progress.toggle(d, n) }
            for w in list("-LensaticWeeks").compactMap({ Int($0) }) {
                if let week = library.weeks(for: d).first(where: { $0.week == w }) {
                    let key = library.weekKey(week, door: d)
                    if !progress.weeksDone(key).contains(w) { progress.toggleWeek(key, w) }
                }
            }
        }
        for item in list("-LensaticSaved").reversed().compactMap(SavedItem.init(key:)) where !progress.isSaved(item) { progress.toggleSaved(item) }
        if let t = value("-LensaticTab").flatMap(AppTab.init(rawValue:)) { tab = t }
        if let e = value("-LensaticExplore").flatMap(ExploreMode.init(rawValue:)) { explore = e }
        if let q = value("-LensaticQuery") { query = q }
        if let id = value("-LensaticEntity"), store.entities[id] != nil {
            paths[.path] = [.entity(id)]
            if args.contains("-LensaticSources") { sourcesFor = id }
        }
        if let path = value("-LensaticNav"), let nav = Nav(pathParts: path.split(separator: "/").map(String.init)) {
            tab = args.contains("-LensaticTab") ? tab : nav.home
            paths[tab] = [nav]
            if case .entity(let id) = nav, args.contains("-LensaticSources") { sourcesFor = id }
        }
        // -LensaticChangesViewed <release> sets the last view of What Changed to that release; "none" forgets it
        if let v = value("-LensaticChangesViewed") {
            // the day of the view is that release's day where the list has it, so the screens stay consistent
            let day = changes.items.first { $0.release == v }?.released ?? changes.builtOn
            progress.setChangesViewed(v == "none" ? nil : .init(through: v, on: day.isEmpty ? Changes.today() : day))
        }
        // -LensaticScrollTo <figure-id> scrolls the screen opened to that figure (the R4 screenshots)
        AppModel.debugScrollTo = value("-LensaticScrollTo")
        // -LensaticLink <url> follows one of the app's own links, as a tap on the widget does
        if let link = value("-LensaticLink").flatMap(URL.init(string:)) { open(link: link) }
        if let s = value("-LensaticScreen").flatMap(Section.init(rawValue:)) {
            switch s {
            case .doors: tab = .path
            case .stack, .matrix, .functions:
                tab = .explore
                explore = ExploreMode(rawValue: s.rawValue) ?? .stack
            case .ai, .helper:
                tab = .explore
                paths[.explore] = [.layer(store.content.layers.first(where: \.isColumn)?.id ?? "")]
            case .sources: show(.sources)
            case .glossary: show(.glossary)
            case .about: show(.about)
            }
        }
    }
    #endif
}
