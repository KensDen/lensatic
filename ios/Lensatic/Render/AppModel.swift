import Foundation
import Observation

/// One screen pushed inside a tab: a framework, source or solution as its card (the redesign's Framework card), a
/// section of the map not yet redesigned, or a screen pushed inside one.
enum Nav: Hashable, Sendable {
    case entity(String)
    case section(Section)
    case legacy(Route)
}

extension Route {
    /// A screen pushed from a page of the map, as the tabs' stacks hold it: an entry opens as its card.
    var nav: Nav {
        if case .entity(let id) = self { return .entity(id) }
        return .legacy(self)
    }
}

/// Where the reader is (the redesign, R1): the trailhead and the steps they checked off (kept on the device by
/// `ProgressStore`), the tab, the screens pushed inside each tab, the matrix's pillar view and the glossary entry open
/// over a page.
@Observable @MainActor
final class AppModel {
    let store: ContentStore
    let builder: PageBuilder
    let progress: ProgressStore
    var tab: AppTab = .path
    var paths: [AppTab: [Nav]] = [:]
    /// The welcome screen over the tabs, to pick a different trailhead (Change on My Path, the Library's row).
    var changingDoor = false
    var matrixView: PillarView = .dow
    /// A heading to scroll to when the next section screen appears (Why the name, a glossary entry).
    var pendingAnchor: String?
    var glossaryEntry: GlossarySheet?
    /// The Sources sheet over a card, by the card's entity id.
    var sourcesFor: String?
    @ObservationIgnored private var cache: [PageKey: Page] = [:]
    @ObservationIgnored private var plans: [Door.ID: PathPlan] = [:]

    struct GlossarySheet: Identifiable, Hashable {
        let slug: String
        var id: String { slug }
    }

    init(store: ContentStore, progress: ProgressStore = ProgressStore()) {
        self.store = store
        self.progress = progress
        builder = PageBuilder(store: store)
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

    /// Picking a trailhead opens My Path at its top; each trailhead keeps its own checks.
    func choose(_ id: Door.ID) {
        progress.choose(id)
        changingDoor = false
        paths[.path] = []
        tab = .path
        if let view = door(id)?.pillarView.value { matrixView = view }
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

    func page(_ key: PageKey) -> Page {
        if let hit = cache[key] { return hit }
        let page = builder.page(key)
        cache[key] = page
        return page
    }

    /// Follow a link or a control from a page of the map. Outside addresses are not handled here: views open them
    /// through `openURL`, which hands them to the system browser. An entry opens as its card; the trailheads now live
    /// on My Path.
    func go(_ target: Target) {
        switch target {
        case .section(.doors, _):
            glossaryEntry = nil
            tab = .path
        case .section(let s, let anchor):
            pendingAnchor = anchor
            push(.section(s))
        case .push(let route):
            push(route.nav)
        case .glossary(let slug):
            glossaryEntry = GlossarySheet(slug: slug)
        case .anchor, .external:
            break
        }
    }

    /// Opening a door that names a pillar view switches the matrix to it, as on the web (a reader's action only).
    func opened(_ route: Route) {
        if case .door(let id) = route, let view = store.content.doors.first(where: { $0.id.rawValue == id })?.pillarView.value {
            matrixView = view
        }
    }

    #if DEBUG
    /// Launch arguments for the UI tests and the screenshot sheet (Debug builds only): -LensaticResetProgress forgets
    /// the trailhead and every check; -LensaticDoor <id> picks a trailhead; -LensaticChecked <1,2> checks those steps on
    /// it; -LensaticEntity <id> opens that card on My Path and -LensaticSources its Sources sheet; -LensaticScreen
    /// <section> opens a section of the map on the tab that holds it.
    private func debugLaunch(_ args: [String]) {
        func value(_ flag: String) -> String? { args.firstIndex(of: flag).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
        if args.contains("-LensaticResetProgress") { progress.reset() }
        if let d = value("-LensaticDoor").flatMap(Door.ID.init(rawValue:)) {
            progress.choose(d)
            if let checks = value("-LensaticChecked") {
                for n in checks.split(separator: ",").compactMap({ Int($0) }) where !progress.isChecked(d, n) { progress.toggle(d, n) }
            }
        }
        if let id = value("-LensaticEntity"), store.entities[id] != nil {
            paths[.path] = [.entity(id)]
            if args.contains("-LensaticSources") { sourcesFor = id }
        }
        if let s = value("-LensaticScreen").flatMap(Section.init(rawValue:)) {
            tab = LegacyShelf.tab(for: s)
            paths[tab] = [.section(s)]
            pendingAnchor = value("-LensaticAnchor")
        }
    }
    #endif
}

extension Target {
    private static let scheme = "lensatic"

    /// Links inside text carry their target as an address; `init?(url:)` reads it back. Only outside addresses
    /// ever leave the app.
    var url: URL? {
        func make(_ parts: [String]) -> URL? {
            var c = URLComponents()
            c.scheme = Target.scheme
            c.path = "/" + parts.joined(separator: "/")  // ids and anchors are letters, digits and hyphens
            return c.url
        }
        switch self {
        case .section(let s, let anchor): return make(["section", s.rawValue] + (anchor.map { [$0] } ?? []))
        case .push(.door(let id)): return make(["door", id])
        case .push(.layer(let id)): return make(["layer", id])
        case .push(.entity(let id)): return make(["entity", id])
        case .push(.cell(let v, let p, let f)): return make(["cell", v.rawValue, p, f.rawValue])
        case .glossary(let slug): return make(["glossary", slug])
        case .anchor(let id): return make(["anchor", id])
        case .external(let url): return url
        }
    }

    init?(url: URL) {
        guard url.scheme == Target.scheme else {
            guard ["http", "https"].contains(url.scheme ?? "") else { return nil }
            self = .external(url)
            return
        }
        let parts = url.path.split(separator: "/").map(String.init)
        switch (parts.first, parts.count) {
        case ("section", 2), ("section", 3):
            guard let s = Section(rawValue: parts[1]) else { return nil }
            self = .section(s, anchor: parts.count == 3 ? parts[2] : nil)
        case ("door", 2): self = .push(.door(parts[1]))
        case ("layer", 2): self = .push(.layer(parts[1]))
        case ("entity", 2): self = .push(.entity(parts[1]))
        case ("cell", 4):
            guard let v = PillarView(rawValue: parts[1]), let f = FunctionID(rawValue: parts[3]) else { return nil }
            self = .push(.cell(v, parts[2], f))
        case ("glossary", 2): self = .glossary(parts[1])
        case ("anchor", 2): self = .anchor(parts[1])
        default: return nil
        }
    }
}
