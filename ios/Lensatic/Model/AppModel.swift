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
    /// The framework navigator's content (Lensatic 2.0): the cards, their structure, the comparisons and the checks.
    let frameworks: FrameworkLibrary
    /// The Frameworks tab's two views of the cards.
    var frameworksMode: FrameworksMode = .browse
    /// Compare's two picks (Round 2): any two cards.
    var compareA: String?
    var compareB: String?
    /// The iPad's two panes (Round 3): what the sidebar has picked for the detail pane to show at its root; nil shows the
    /// first item of the sidebar's list.
    var frameworksPane: Nav?
    /// The app opens on Home (build 6), on first launch and after.
    var tab: AppTab = .home
    var paths: [AppTab: [Nav]] = [:]
    /// The trailhead question over the tabs: to pick the first trailhead (Home's Framework Maps door, My Path before a
    /// pick) or a different one (Change Path on My Path).
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

    init(store: ContentStore, library: Library, changes: Changes = .empty, progress: ProgressStore = ProgressStore(),
         frameworks: FrameworkLibrary? = nil) {
        self.store = store
        self.library = library
        self.changes = changes
        self.progress = progress
        // the frameworks ship inside the app and the unit tests decode them on every build, as the stack is
        self.frameworks = frameworks ?? AppModel.bundledFrameworks(store)
        if let view = door?.pillarView.value { matrixView = view }
        #if DEBUG
        debugLaunch(ProcessInfo.processInfo.arguments)
        #endif
    }

    static func bundledFrameworks(_ store: ContentStore) -> FrameworkLibrary {
        do {
            return try FrameworkLibrary.bundled(department: store.content.orgs.dow.fields)
        } catch {
            preconditionFailure("the bundled frameworks did not decode: \(error)")
        }
    }

    // MARK: the frameworks (Lensatic 2.0)

    /// The countdown Home leads with and the widget falls back to: the next dated zero trust deadline.
    func zeroTrustCountdown(today: Date = Date()) -> DatedDeadline? { frameworks.zeroTrustCountdown(store: store, today: today) }

    /// The Frameworks tab at its top, in Browse or Compare.
    func showFrameworks(_ mode: FrameworksMode = .browse) {
        glossaryEntry = nil
        sourcesFor = nil
        changingDoor = false
        frameworksMode = mode
        paths[.frameworks] = []
        tab = .frameworks
    }

    // MARK: the iPad's two panes (Round 3)

    /// What the sidebar lists in a view of the Frameworks tab, in its order: the arrow keys move through these.
    func paneItems(_ mode: FrameworksMode) -> [Nav] {
        let L = frameworks
        switch mode {
        case .browse: return L.catalog.groups.flatMap { g in L.frameworks(in: g.id).map { Nav.framework($0.id) } } + L.catalog.lands.map { .landing($0.id) }
        case .compare: return L.compares.map { .compare($0.id) }
        case .checks: return L.checks.map { .check($0.id) }
        }
    }

    /// The view of the Frameworks tab a screen belongs to, where it is one the sidebar can pick.
    static func paneMode(of nav: Nav) -> FrameworksMode? {
        switch nav {
        case .framework, .landing: return .browse
        case .compare, .pair: return .compare
        case .check: return .checks
        default: return nil
        }
    }

    /// The detail pane's first screen: the sidebar's pick where it belongs to the view shown, else the view's first item.
    var paneRoot: Nav? {
        if let pick = frameworksPane, AppModel.paneMode(of: pick) == frameworksMode { return pick }
        return paneItems(frameworksMode).first
    }

    /// Pick a screen in the sidebar: the detail pane shows it, with nothing pushed over it.
    func selectPane(_ nav: Nav) {
        glossaryEntry = nil
        sourcesFor = nil
        if let mode = AppModel.paneMode(of: nav) { frameworksMode = mode }
        frameworksPane = nav
        paths[.frameworks] = []
    }

    /// The arrow keys: the next or the previous item of the sidebar's list, stopping at its ends.
    func movePane(by step: Int) {
        let items = paneItems(frameworksMode)
        guard !items.isEmpty else { return }
        guard let at = paneRoot.flatMap({ items.firstIndex(of: $0) }) else { return selectPane(items[0]) }
        let to = min(max(at + step, 0), items.count - 1)
        if to != at { selectPane(items[to]) }
    }

    /// With two panes on screen, a screen of the sidebar's own kind at the bottom of the tab's path (a framework opened
    /// from Home, or from another framework's Connects To) becomes the sidebar's pick, so the sidebar always shows
    /// where the reader is. A screen of another view's kind stays pushed, with its way back.
    func foldPane() {
        guard let first = paths[.frameworks]?.first, AppModel.paneMode(of: first) == frameworksMode else { return }
        frameworksPane = first
        paths[.frameworks]?.removeFirst()
    }

    /// The way back from the keyboard (Command-[): the screen on top of the open tab leaves.
    func back() {
        guard !(paths[tab] ?? []).isEmpty else { return }
        glossaryEntry = nil
        paths[tab]?.removeLast()
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
        changingDoor = false
        progress.choose(id)
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

    /// One of Lensatic's own headlines in What Changed (Round 3): the trailhead question, or the Frameworks tab.
    func run(_ action: Changes.Item.Action) {
        switch action {
        case .trailheads: changingDoor = true
        case .frameworks: showFrameworks(.browse)
        }
    }

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
        let index = SearchIndex(store: store, library: library, door: door, labels: .init(), frameworks: frameworks)
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
        // the Frameworks tab's own view follows a screen of its kind, so the way back, and the iPad's sidebar, show the
        // list that screen belongs to (Round 3)
        if let mode = AppModel.paneMode(of: nav) { frameworksMode = mode }
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
        case .framework(let id): push(.framework(id))
        case .node(let f, let n): push(.node(f, n))
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
        case .framework(let id): show(.framework(id))
        case .node(let f, let n): show(.node(f, n))
        case .step(let door, let order): showStep(door, order)
        }
        return true
    }

    func exists(_ item: SavedItem) -> Bool {
        switch item {
        case .entity(let id): return store.entities[id] != nil
        case .play(let id): return library.play(id) != nil
        case .framework(let id): return frameworks.byId[id] != nil
        case .node(let f, let n): return frameworks.graphs[f]?.node(n) != nil
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
        // the key as it was written: an element's identifier may hold a space or a bracket, which an address escapes
        case "open": return openSpotlight(String(url.path(percentEncoded: false).drop { $0 == "/" }))
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

    /// Home's Framework Maps door (build 6): My Path once a trailhead is picked; before that, the trailhead question.
    func openMaps() {
        if door == nil { changingDoor = true } else { showPath() }
    }

    /// Home's status lines (build 6), each computed from the content and the progress file.
    /// The reader's trailhead and steps done, as the parts of one line; nil before a pick.
    var pathStatus: [String]? {
        guard let door else { return nil }
        let p = plan(door).progress(progress.checked(door.id))
        if p.total == 0 { return [door.shortTitle] }
        return [door.shortTitle, "\(p.done) of \(p.total) \(p.total == 1 ? "step" : "steps") done"]
    }

    /// Week N of 8: the first week on the reader's route not marked done; every week done says so. Before a trailhead is
    /// picked, the route's length. The fraction is the share done.
    var guideStatus: (line: String, fraction: Double) {
        guard let door else {
            let n = library.guide.core.count + (library.guide.tracks.first?.weeks.count ?? 0)
            return ("\(n) weeks", 0)
        }
        let weeks = library.weeks(for: door.id)
        let done = weeks.filter { progress.weeksDone(library.weekKey($0, door: door.id)).contains($0.week) }
        let fraction = weeks.isEmpty ? 0 : Double(done.count) / Double(weeks.count)
        if let next = weeks.first(where: { w in !done.contains(w) }) { return ("Week \(next.week) of \(weeks.count)", fraction) }
        return ("All \(weeks.count) weeks done", fraction)
    }

    /// N of 35 plays read: the plays the reader has opened, of the plays in the file.
    var playsStatus: (line: String, fraction: Double) {
        let plays = library.plays.plays
        let read = plays.filter { progress.isRead(play: $0.id) }.count
        return ("\(read) of \(plays.count) plays read", plays.isEmpty ? 0 : Double(read) / Double(plays.count))
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

    /// What a saved item is called in Home's Saved list, the line under it, and its section's colour key.
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
        case .framework(let id):
            guard let f = frameworks.byId[id] else { return nil }
            return (f.name, [f.kind, frameworks.group(f.group)?.name].compactMap { $0 }.joined(separator: sep), "maps")
        case .node(let fid, let nid):
            // an element by its name as the publisher prints it, under its framework and its level ("SP 800-53 · Control")
            guard let f = frameworks.byId[fid], let g = frameworks.graphs[fid], let n = g.node(nid) else { return nil }
            let name = g.name(n)
            return (name.isEmpty ? nid : name, [f.shortName, g.level(n.level)?.name].compactMap { $0 }.joined(separator: sep), "maps")
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
        Spotlight.index(Spotlight.entries(store: store, library: library, door: door, frameworks: frameworks))
    }

    #if DEBUG
    /// The view a pushed screen scrolls to when it appears (-LensaticScrollTo), for the screenshots.
    @MainActor static var debugScrollTo: String?

    /// Launch arguments for the UI tests and the screenshot sheet (Debug builds only): -LensaticResetProgress forgets
    /// everything; -LensaticDoor <id> picks a trailhead; -LensaticChecked <1,2> checks those steps on it; -LensaticSaved
    /// <key,key> saves those items; -LensaticWeeks <1,2> marks those weeks done; -LensaticTab <tab> opens a tab;
    /// -LensaticPick opens the trailhead question over Home;
    /// -LensaticExplore <view> picks Explore's view; -LensaticNav <path> pushes a screen (as Target.url's path, such
    /// as entity/dod-zt-strategy) on its tab, and -LensaticSources its Sources sheet; -LensaticEntity <id> opens a
    /// card on My Path; -LensaticQuery <text> fills Search; -LensaticRecent <text,text> fills Search's Recent list, newest
    /// first; -LensaticScreen <section> opens a section of the map where the redesign keeps it (tools/ios_shots.sh).
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
        if args.contains("-LensaticPick") { changingDoor = true }
        if let e = value("-LensaticExplore").flatMap(ExploreMode.init(rawValue:)) { explore = e }
        // -LensaticFrameworks <browse|compare> picks the Frameworks tab's view; -LensaticAnswers <check>:<answer,answer>
        // answers that check's items in order with those answer ids, repeating the list (the readiness captures)
        if let m = value("-LensaticFrameworks").flatMap(FrameworksMode.init(rawValue:)) { frameworksMode = m }
        // -LensaticCompact shows the Frameworks list as compact rows (the captures)
        if args.contains("-LensaticCompact") { progress.setFrameworksCompact(true) }
        if let spec = value("-LensaticAnswers")?.split(separator: ":", maxSplits: 1).map(String.init), spec.count == 2,
           let check = frameworks.check(spec[0]) {
            let given = spec[1].split(separator: ",").map(String.init)
            progress.clearAnswers(check.id)
            for (i, item) in check.items.enumerated() where !given.isEmpty && given[i % given.count] != "-" {
                progress.answer(check.id, item.id, given[i % given.count])
            }
        }
        if let q = value("-LensaticQuery") { query = q }
        // -LensaticRecent <text,text> keeps those searches, newest first, as running them would (the empty-state captures)
        for q in list("-LensaticRecent").reversed() { progress.remember(search: q) }
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
        // -LensaticScrollTo <id> scrolls the screen opened to that figure (the R4 screenshots), or Home to its Saved
        // section (home-saved, the empty-state captures)
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
