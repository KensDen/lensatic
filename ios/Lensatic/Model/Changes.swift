import Foundation

/// What Changed (the redesign, R3): the dated list the content release bundles (content/changes.json, which
/// tools/build_changes.py generates from the content diff and the verification log; a resource by reference). My Path
/// shows the items newer than the reader's last view, kept in the progress file.
struct Changes: Decodable, Sendable {
    init(contentVersion: String, builtOn: String, items: [Item]) {
        self.contentVersion = contentVersion
        self.builtOn = builtOn
        self.items = items
    }

    struct Item: Decodable, Sendable, Identifiable, Hashable {
        enum Kind: String, Decodable, Sendable { case added, removed, document, deadline, status, link, recheck }
        let id: String
        /// The content release that brought it (contentVersion), and that release's day.
        let release: String
        let released: String
        /// The day the item is about: a document's own date, a recheck's, or the release day.
        let date: String
        let kind: Kind
        let entityId: String
        let title: String
    }

    let contentVersion: String
    let builtOn: String
    let items: [Item]

    /// No list (a model built without one, in the tests).
    static let empty = Changes(contentVersion: "0", builtOn: "", items: [])

    static func bundled(_ bundle: Bundle = .main) throws -> Changes {
        guard let url = bundle.url(forResource: "changes", withExtension: "json") else { throw ContentStore.LoadError.missing("changes.json") }
        return try JSONDecoder().decode(Changes.self, from: Data(contentsOf: url))
    }

    /// The items newer than a last view: those of releases after the one it cleared, newest first; every item when the
    /// reader has never viewed the list.
    func new(since viewed: ProgressStore.State.ChangesViewed?) -> [Item] {
        guard let viewed else { return items }
        let seen = Changes.version(viewed.through)
        return items.filter { seen.lexicographicallyPrecedes(Changes.version($0.release)) }
    }

    /// The new items for a trailhead: those that touch its steps first, then the rest, each newest first by the day
    /// each is about (a release brings items about earlier days: a document's own date, a check's).
    func new(since viewed: ProgressStore.State.ChangesViewed?, door: Door?) -> [Item] {
        let fresh = Changes.newestFirst(new(since: viewed))
        return fresh.filter { !Changes.steps($0, on: door).isEmpty } + fresh.filter { Changes.steps($0, on: door).isEmpty }
    }

    static func newestFirst(_ items: [Item]) -> [Item] {
        items.enumerated().sorted { a, b in a.element.date != b.element.date ? a.element.date > b.element.date : a.offset < b.offset }.map(\.element)
    }

    /// The items grouped by release, newest first, for the full list.
    var releases: [(release: String, released: String, items: [Item])] {
        var out: [(String, String, [Item])] = []
        for item in items {
            if let last = out.last, last.0 == item.release {
                out[out.count - 1].2.append(item)
            } else {
                out.append((item.release, item.released, [item]))
            }
        }
        return out
    }

    static func version(_ v: String) -> [Int] { v.split(separator: ".").map { Int($0) ?? 0 } }

    /// The steps on a trailhead an item touches: those that name its entry, in order.
    static func steps(_ item: Item, on door: Door?) -> [Int] {
        door?.steps.filter { $0.entityIds.contains(item.entityId) }.map(\.order) ?? []
    }

    /// The line under an item: its day, then the steps it affects on the reader's path ("affects step 3", "affects steps 1
    /// and 2"), or its entry's layer when it is not on the path.
    static func line(_ item: Item, door: Door?, store: ContentStore) -> String {
        let sep = store.label("metaSeparator")
        let steps = steps(item, on: door)
        let tail: String?
        switch steps.count {
        case 0: tail = store.entities[item.entityId].map { e in store.layerTag(e.layerId) ?? e.shortName }
        case 1: tail = "affects step \(steps[0])"
        default: tail = "affects steps " + steps.dropLast().map(String.init).joined(separator: ", ") + " and \(steps.last!)"
        }
        return [dated(item), tail].compactMap { $0 }.joined(separator: sep)
    }

    /// The item's day with what it is the day of: a document's publication, a check against the source, or the
    /// content release that made the change.
    static func dated(_ item: Item) -> String {
        let day = Rules.formatDate(item.date)
        switch item.kind {
        case .document: return "Published \(day)"
        case .recheck: return "Checked \(day)"
        default: return "Updated \(day)"
        }
    }

    /// Today as an ISO date in the reader's calendar, for the last view.
    static func today(_ now: Date = Date(), calendar: Calendar = .lensatic) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
