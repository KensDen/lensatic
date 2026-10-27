import Foundation
import Observation

/// One screen pushed inside a tab (the redesign, R2): an entry's card, a layer, a cell of the matrix, the Library's
/// reference screens, the guide and its chapters, the plays and one play, the saved list.
enum Nav: Hashable, Sendable {
    case entity(String)
    case layer(String)
    case cell(PillarView, String, FunctionID)
    case glossary
    case sources
    case about
    case saved
    case guide
    case chapter(String)
    case plays
    case play(String)

    /// The screen as the parts of an address (Target.url), and back.
    var pathParts: [String] {
        switch self {
        case .entity(let id): return ["entity", id]
        case .layer(let id): return ["layer", id]
        case .cell(let v, let p, let f): return ["cell", v.rawValue, p, f.rawValue]
        case .glossary: return ["glossary-list"]
        case .sources: return ["sources"]
        case .about: return ["about"]
        case .saved: return ["saved"]
        case .guide: return ["guide"]
        case .chapter(let id): return ["chapter", id]
        case .plays: return ["plays"]
        case .play(let id): return ["play", id]
        }
    }

    init?(pathParts parts: [String]) {
        switch (parts.first, parts.count) {
        case ("entity", 2): self = .entity(parts[1])
        case ("layer", 2): self = .layer(parts[1])
        case ("cell", 4):
            guard let v = PillarView(rawValue: parts[1]), let f = FunctionID(rawValue: parts[3]) else { return nil }
            self = .cell(v, parts[2], f)
        case ("glossary-list", 1): self = .glossary
        case ("sources", 1): self = .sources
        case ("about", 1): self = .about
        case ("saved", 1): self = .saved
        case ("guide", 1): self = .guide
        case ("chapter", 2): self = .chapter(parts[1])
        case ("plays", 1): self = .plays
        case ("play", 2): self = .play(parts[1])
        default: return nil
        }
    }

    /// The tab a screen lives under when it is opened from elsewhere (iOS search, a saved item, a link).
    var home: AppTab {
        switch self {
        case .entity, .layer, .cell: return .explore
        case .glossary, .sources, .about, .saved, .guide, .chapter, .plays, .play: return .library
        }
    }
}

/// Explore's three views of the map.
enum ExploreMode: String, CaseIterable, Hashable, Sendable {
    case stack, matrix, functions
}

/// Where the reader is: the trailhead, the checks, the saved items and the guide's weeks (kept on the device by
/// `ProgressStore`), the tab, the screens pushed inside each tab, Explore's view and the matrix's pillar view, the step
/// to open on My Path, the glossary entry and the Sources sheet open over a screen.
@Observable @MainActor
final class AppModel {
    let store: ContentStore
    let library: Library
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

    init(store: ContentStore, library: Library, progress: ProgressStore = ProgressStore()) {
        self.store = store
        self.library = library
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

    /// Picking a trailhead opens My Path at its top; each trailhead keeps its own checks. iOS search gets its steps.
    func choose(_ id: Door.ID) {
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

    /// A tap on an item in iOS search: its identifier is a saved item's key.
    func openSpotlight(_ identifier: String) {
        guard let item = SavedItem(key: identifier) else { return }
        switch item {
        case .entity(let id) where store.entities[id] != nil: show(.entity(id))
        case .play(let id) where library.play(id) != nil: show(.play(id))
        case .step(let door, let order) where self.door(door)?.steps.contains(where: { $0.order == order }) == true: showStep(door, order)
        default: break
        }
    }

    /// Follow a link inside text: a screen pushes, a glossary term opens its entry. Outside addresses are not handled
    /// here: views open them through `openURL`, which hands them to the system browser.
    func go(_ target: Target) {
        switch target {
        case .nav(let nav): push(nav)
        case .glossary(let slug): glossaryEntry = GlossarySheet(slug: slug)
        case .external: break
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
