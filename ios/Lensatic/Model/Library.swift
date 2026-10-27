import Foundation

/// The Library's two sections (the redesign, R2), drawn natively: the Zero Trust guide and the Agentic SecOps plays, as
/// tools/build_library.py generates them into each section's own tree (guides/zero-trust/app/guide.json,
/// playbook/app/plays.json), and the umbrella's names for them from hub/site.json. All three are resources by reference,
/// never copies. Nothing here is counted by hand: weeks, groups and plays are counted from these files.
final class Library: Sendable {
    let guide: Guide
    let plays: Plays
    let site: SiteNames

    enum LoadError: Error { case missing(String) }

    static func bundled(_ bundle: Bundle = .main) throws -> Library {
        func data(_ name: String) throws -> Data {
            guard let url = bundle.url(forResource: name, withExtension: "json") else { throw LoadError.missing("\(name).json") }
            return try Data(contentsOf: url)
        }
        return try Library(guide: data("guide"), plays: data("plays"), site: data("site"))
    }

    init(guide: Data, plays: Data, site: Data) throws {
        let decoder = JSONDecoder()
        self.guide = try decoder.decode(Guide.self, from: guide)
        self.plays = try decoder.decode(Plays.self, from: plays)
        self.site = try decoder.decode(SiteNames.self, from: site)
    }

    // MARK: the guide

    /// The guide's track for a trailhead: the department's and the civilian agencies' have their own; a contractor and
    /// everyone else take the private-sector track, as the guide's "Which track are you?" table sends them.
    func track(for door: Door.ID) -> Guide.Track? {
        let id: String
        switch door {
        case .dow: id = "dow"
        case .federalCivilian: id = "federal-civilian"
        case .defenseContractor, .other: id = "private-sector"
        }
        return guide.tracks.first { $0.id == id } ?? guide.tracks.first
    }

    /// The reader's weeks: the shared core's, then their track's, in order.
    func weeks(for door: Door.ID) -> [Guide.Week] { guide.core + (track(for: door)?.weeks ?? []) }

    /// The key a week's check is kept under: the core's are shared by every track, a track's are its own.
    func weekKey(_ week: Guide.Week, door: Door.ID) -> String {
        guide.core.contains(where: { $0.week == week.week }) ? "core" : (track(for: door)?.id ?? "core")
    }

    // MARK: the plays

    func play(_ id: String) -> Plays.Play? { plays.plays.first { $0.id == id } }

    func group(of id: String) -> Plays.Group? { plays.groups.first { $0.playIds.contains(id) } }

    func plays(in group: Plays.Group) -> [Plays.Play] { group.playIds.compactMap(play) }
}

/// One block of a guide chapter or a play, in the generator's few kinds.
struct LibraryBlock: Decodable, Sendable {
    enum Kind: String, Decodable, Sendable { case heading, text, callout, list, cards, table, stats, links }

    struct Card: Decodable, Sendable {
        let eyebrow: String?
        let title: String
        let text: String?
        let bullets: [String]?
        let meta: String?
        let url: String?
    }

    struct Stat: Decodable, Sendable { let value, label, source: String }
    struct Link: Decodable, Sendable { let label, url: String }
    struct Row: Decodable, Sendable {
        let cells: [String]
        let url: String?
    }

    let kind: Kind
    let heading: String?
    let text: String?
    let label: String?
    let level: Int?
    let ordered: Bool
    let url: String?
    let columns: [String]
    let rows: [Row]
    let lines: [String]
    let cards: [Card]
    let stats: [Stat]
    let links: [Link]

    private enum CodingKeys: String, CodingKey { case type, heading, text, label, level, ordered, url, columns, rows, items }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(Kind.self, forKey: .type)
        heading = try c.decodeIfPresent(String.self, forKey: .heading)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        label = try c.decodeIfPresent(String.self, forKey: .label)
        level = try c.decodeIfPresent(Int.self, forKey: .level)
        ordered = try c.decodeIfPresent(Bool.self, forKey: .ordered) ?? false
        url = try c.decodeIfPresent(String.self, forKey: .url)
        columns = try c.decodeIfPresent([String].self, forKey: .columns) ?? []
        rows = try c.decodeIfPresent([Row].self, forKey: .rows) ?? []
        lines = kind == .list ? try c.decode([String].self, forKey: .items) : []
        cards = kind == .cards ? try c.decode([Card].self, forKey: .items) : []
        stats = kind == .stats ? try c.decode([Stat].self, forKey: .items) : []
        links = kind == .links ? try c.decode([Link].self, forKey: .items) : []
    }

    /// Every word the block shows, for search.
    var searchText: String {
        var out = [heading, text, label].compactMap { $0 } + columns + rows.flatMap(\.cells) + lines
        for c in cards { out += [c.eyebrow, c.title, c.text, c.meta].compactMap { $0 } + (c.bullets ?? []) }
        out += stats.flatMap { [$0.value, $0.label] } + links.map(\.label)
        return out.joined(separator: " ")
    }
}

struct Guide: Decodable, Sendable {
    struct Week: Decodable, Sendable, Hashable {
        let week: Int
        let read: String
        let apply: String
        let check: String
    }

    struct Track: Decodable, Sendable {
        let id: String
        let name: String
        let weeks: [Week]
    }

    struct Chapter: Decodable, Sendable, Identifiable {
        let id: String
        let title: String
        let blocks: [LibraryBlock]
    }

    let edition: String
    let core: [Week]
    let tracks: [Track]
    let chapters: [Chapter]

    func chapter(_ id: String) -> Chapter? { chapters.first { $0.id == id } }
}

struct Plays: Decodable, Sendable {
    struct Group: Decodable, Sendable, Hashable {
        let label: String
        let playIds: [String]
    }

    struct Play: Decodable, Sendable, Identifiable {
        let id: String
        let name: String
        let title: String
        let subtitle: String
        let blocks: [LibraryBlock]
    }

    let groups: [Group]
    let plays: [Play]
}

/// The umbrella's names, from hub/site.json: each section's name, the guide's name and shape, and the playbook's title.
struct SiteNames: Decodable, Sendable {
    struct SectionInfo: Decodable, Sendable {
        let key: String
        let name: String
        let line: String
    }

    struct GuideInfo: Decodable, Sendable {
        let key: String
        let name: String
        let line: String
    }

    struct Card: Decodable, Sendable {
        let title: String
        let lede: String
    }

    let sections: [SectionInfo]
    let guides: [GuideInfo]
    let labels: [String: String]
    let cards: [String: Card]

    func section(_ key: String) -> SectionInfo? { sections.first { $0.key == key } }

    /// The Field Guides section's name, and the playbook section's: read here, never typed in the app.
    var guidesName: String { section("guides")?.name ?? "" }
    var playsName: String { section("playbook")?.name ?? "" }
    /// The playbook's own title (Agentic SecOps).
    var playsTitle: String { cards["playbook"]?.title ?? "" }
    var guideName: String { guides.first?.name ?? "" }
    /// The guide's title on its card: its name and its shape (Zero Trust in Eight Weeks).
    var guideTitle: String {
        let shape = labels["guideShape"].map { " in " + $0.lowercased() } ?? ""
        return TitleCase.apply(guideName + shape)
    }
}
