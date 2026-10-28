import Foundation

/// What Changed (the redesign, R3; simplified in R5, item 19): the dated list the content release bundles
/// (content/changes.json, which tools/build_changes.py generates from the content diff and the verification log; a
/// resource by reference). The news, what moved in the world, shows by default; source checks only when the reader asks.
/// My Path shows the news newer than the reader's last visit to the list, kept in the progress file.
struct Changes: Decodable, Sendable {
    init(contentVersion: String, builtOn: String, items: [Item]) {
        self.contentVersion = contentVersion
        self.builtOn = builtOn
        self.items = items
    }

    struct Item: Decodable, Sendable, Identifiable, Hashable {
        enum Kind: String, Decodable, Sendable {
            case added, removed, document, deadline, status, link, recheck

            /// A check against the source (a recheck, a status it changed), not news: behind Show Source Checks.
            var isCheck: Bool { self == .recheck || self == .status }

            /// What kind of change, first on the row's line.
            var label: String {
                switch self {
                case .added: return "New entry"
                case .removed: return "Removed"
                case .document: return "New document"
                case .deadline: return "Deadline"
                case .link: return "New link"
                case .status: return "Status"
                case .recheck: return "Source check"
                }
            }
        }
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

    /// The news: every item but the source checks.
    var news: [Item] { items.filter { !$0.kind.isCheck } }

    /// Whether an item came after a last visit: a release after the one that visit saw; every item when the reader has
    /// never visited the list.
    static func isNew(_ item: Item, since viewed: ProgressStore.State.ChangesViewed?) -> Bool {
        guard let viewed else { return true }
        return Changes.version(viewed.through).lexicographicallyPrecedes(Changes.version(item.release))
    }

    /// The news newer than a last visit, in the list's order; source checks are never new.
    func new(since viewed: ProgressStore.State.ChangesViewed?) -> [Item] {
        news.filter { Changes.isNew($0, since: viewed) }
    }

    /// The new news for a trailhead: what touches its steps first, then the rest, each newest first by the day each is
    /// about (a release brings items about earlier days: a document's own date).
    func new(since viewed: ProgressStore.State.ChangesViewed?, door: Door?) -> [Item] {
        let fresh = Changes.newestFirst(new(since: viewed))
        return fresh.filter { !Changes.steps($0, on: door).isEmpty } + fresh.filter { Changes.steps($0, on: door).isEmpty }
    }

    static func newestFirst(_ items: [Item]) -> [Item] {
        items.enumerated().sorted { a, b in a.element.date != b.element.date ? a.element.date > b.element.date : a.offset < b.offset }.map(\.element)
    }

    /// Items grouped by the day each is about, newest day first, for the full list (versions stay in About).
    static func byDay(_ items: [Item]) -> [(day: String, items: [Item])] {
        var out: [(day: String, items: [Item])] = []
        for item in newestFirst(items) {
            if let last = out.last, last.day == item.date {
                out[out.count - 1].items.append(item)
            } else {
                out.append((item.date, [item]))
            }
        }
        return out
    }

    /// The Library's line for the list: how many news items are new since the last visit ("2 New"), or the day of the
    /// newest news ("Updated 24 Oct", with the year when it is not this year).
    func libraryLine(since viewed: ProgressStore.State.ChangesViewed?, today: Date = Date(), calendar: Calendar = .lensatic) -> String {
        let fresh = new(since: viewed).count
        if fresh > 0 { return "\(fresh) New" }
        guard let day = Changes.newestFirst(news).first?.date, let c = PathPlan.day(day), let month = c.month, let d = c.day else { return "" }
        let year = c.year == calendar.component(.year, from: today) ? "" : " \(c.year ?? 0)"
        return "Updated \(d) \(Rules.months[month - 1])\(year)"
    }

    static func version(_ v: String) -> [Int] { v.split(separator: ".").map { Int($0) ?? 0 } }

    /// The steps on a trailhead an item touches: those that name its entry, in order.
    static func steps(_ item: Item, on door: Door?) -> [Int] {
        door?.steps.filter { $0.entityIds.contains(item.entityId) }.map(\.order) ?? []
    }

    /// The line under an item, the same on every row: what kind of change, its day, and its entry's short name
    /// ("New document · 8 Oct 2026 · NSA ZT guidance").
    static func line(_ item: Item, store: ContentStore) -> String {
        let name = store.entities[item.entityId]?.shortName
        return [item.kind.label, Rules.formatDate(item.date), name].compactMap { $0 }.joined(separator: store.label("metaSeparator"))
    }

    /// Today as an ISO date in the reader's calendar, for the last view.
    static func today(_ now: Date = Date(), calendar: Calendar = .lensatic) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
