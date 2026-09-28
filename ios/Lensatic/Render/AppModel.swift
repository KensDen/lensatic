import Foundation
import Observation

/// Where the reader is: the selected section, the screens pushed inside it, the matrix's pillar view and the glossary
/// entry open over the page. Held in memory only: the app stores nothing, so every launch starts at the sections.
@Observable @MainActor
final class AppModel {
    let store: ContentStore
    let builder: PageBuilder
    var selection: Section?
    var path: [Route] = []
    var matrixView: PillarView = .dow
    /// A heading to scroll to when the next section screen appears (Why the name, a glossary entry).
    var pendingAnchor: String?
    var glossaryEntry: GlossarySheet?
    @ObservationIgnored private var cache: [PageKey: Page] = [:]

    struct GlossarySheet: Identifiable, Hashable {
        let slug: String
        var id: String { slug }
    }

    init(store: ContentStore) {
        self.store = store
        builder = PageBuilder(store: store)
        #if DEBUG
        // the screenshot tool (tools/ios_shots.sh) opens a section, and optionally a heading in it, by launch argument
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-LensaticScreen"), i + 1 < args.count, let s = Section(rawValue: args[i + 1]) {
            selection = s
            if let j = args.firstIndex(of: "-LensaticAnchor"), j + 1 < args.count { pendingAnchor = args[j + 1] }
        }
        #endif
    }

    func page(_ key: PageKey) -> Page {
        if let hit = cache[key] { return hit }
        let page = builder.page(key)
        cache[key] = page
        return page
    }

    /// Follow a link or a control. Outside addresses are not handled here: views open them through `openURL`, which
    /// hands them to the system browser.
    func go(_ target: Target) {
        switch target {
        case .section(let s, let anchor):
            pendingAnchor = anchor
            path = []
            glossaryEntry = nil
            selection = s
        case .push(let route):
            glossaryEntry = nil
            path.append(route)
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
