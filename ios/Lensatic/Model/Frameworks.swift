import Foundation

// The framework navigator's content model (Lensatic 2.0, Round 1): the Codable types that match the files under
// content/frameworks/ and their schemas in content/schema/. One file per framework, a catalog that orders them, and a
// file for each comparison and each readiness check. Decoded with `Strict`, as the stack is. Adding a framework is
// adding a file and its id to the catalog: no code changes.

/// One framework: the card (what it is, who it binds, how it is verified, how big it is, where it sits), its sources
/// and terms, and its structure where the app goes deeper than the card.
struct Framework: Decodable, Sendable, Identifiable {
    let id: String
    /// The stack entry this framework also is, where the map has one: its card, its sources and its dated deadline.
    let entityId: String?
    let name: String
    let shortName: String
    let group: String
    /// What kind of thing it is, in two or three words (Outcomes, Control Catalog, Authorization Program).
    let kind: String
    /// False for the adversary column: a knowledge base, not something an organization complies with.
    let compliance: Bool
    /// An SF Symbol on the deployment target.
    let symbol: String
    let color: Tone
    /// What it is for, before what it says (wayfinding).
    let purpose: String
    let what: String
    /// What a reader should know before going further, in Lensatic's own words: what the screen does not show, or how
    /// a program's new words meet its old ones.
    let note: String?
    /// Other names a reader may search by (a program's former terms, a standard's short forms).
    let aliases: [String]?
    /// The Field Guide chapter that goes with it, where there is one.
    let chapterId: String?
    /// The card's size fact where the last count alone would mislead (a catalog's controls and enhancements together).
    let cardSize: String?
    let binds: Fact
    let verifiedBy: Fact
    let size: [Size]
    let sits: Sits
    let sources: [SourceRecord]
    let terms: Terms
    let deadlines: [Deadline]
    let related: [Related]
    /// How much of the publisher's structure the app shows: N of M, and why when N is less. Null for a card with no depth.
    let depth: Nullable<Depth>
    let levels: [Level]
    let nodes: [Node]
    let sets: [NodeSet]
    let crosswalks: [Crosswalk]
    /// The elements whose title is printed exactly as the publisher prints it although it carries a word the content's
    /// house rule otherwise keeps out (Round 3, ruling 5). The checks read it; the app shows every title as it is.
    let asPublished: [String]?
    /// The heading over the sets, and the line under them, where they are not baselines on another catalog (CMMC's levels).
    let setsTitle: String?
    let setsLine: String?

    /// The framework's one colour, as a pair: its light value on paper and its dark value on the dial. The battery holds
    /// each to 4.5:1 on the app's two surfaces (tools/check_frameworks.py).
    struct Tone: Decodable, Sendable, Hashable {
        let light: String
        let dark: String
    }

    /// A card fact: two or three words for the card, and one sentence for the detail screen.
    struct Fact: Decodable, Sendable {
        let short: String
        let line: String
    }

    struct Size: Decodable, Sendable, Hashable {
        let count: Int
        let unit: String
    }

    /// Where it sits on the stack: one or more of the stack's layers (or a column), and a line that says why.
    struct Sits: Decodable, Sendable {
        let layers: [String]
        let line: String
    }

    /// A source, in the stack's own shape: publisher, title, edition, date, link and the verification record with the
    /// date it was last checked.
    struct SourceRecord: Decodable, Sendable, Identifiable {
        let id: String
        let publisher: String
        let title: String
        let edition: String
        let date: String
        let url: String
        let pdf: String?
        let verification: Verification
    }

    /// The publisher's terms Lensatic relied on, and what the app therefore shows.
    struct Terms: Decodable, Sendable {
        enum Basis: String, Decodable, Sendable { case usGovernmentWork = "us-government-work", copyrighted, licensed, mitre, publisher }
        /// What is shown: the publisher's own text, its titles only, or the structure with Lensatic's own descriptions.
        enum Shows: String, Decodable, Sendable { case text, titles, structure }
        let basis: Basis
        let shows: Shows
        let line: String
        /// A notice the publisher requires wherever its material is shown, verbatim.
        let notice: Nullable<String>
        let url: Nullable<String>
    }

    /// A dated deadline the framework itself carries (the stack entry's own deadline comes through `entityId`).
    struct Deadline: Decodable, Sendable, Hashable {
        let date: String
        let label: String
        let short: String
        let binds: String
        let sourceId: String
    }

    struct Related: Decodable, Sendable, Hashable {
        let id: String
        let line: String
    }

    struct Depth: Decodable, Sendable {
        let shown: Int
        let of: Int
        let unit: String
        let why: Nullable<String>
    }

    /// A level of the publisher's structure, in the publisher's word for it (Function, Family, Tactic).
    struct Level: Decodable, Sendable, Hashable {
        let id: String
        let name: String
        let plural: String
        /// False where the publisher gives this level no identifiers (the RMF's steps, the CISA model's functions): a
        /// node's id is then the file's own key, and the app shows the title alone. Round 2.
        let identified: Bool?
    }

    /// One element of the structure, with the publisher's identifier. A node names its parents, so the same list holds a
    /// tree (a Subcategory under one Category) and a graph (a technique under several tactics).
    struct Node: Decodable, Sendable, Identifiable, Hashable {
        let id: String
        let level: String
        let parents: [String]
        let title: String?
        let text: String?
        /// A note in Lensatic's own words, beside the publisher's (an indicator that is optional for one class).
        let note: String?
    }

    /// A named selection of another framework's nodes, or of this one's: a baseline.
    struct NodeSet: Decodable, Sendable, Identifiable {
        let id: String
        let name: String
        /// The framework whose nodes the members are.
        let of: String
        let sourceId: String
        let members: [String]
        /// A line in Lensatic's words on why the count is what it is.
        let line: String?
        /// The set's screen title where it is not a baseline (CMMC Level 2, Target Level).
        let title: String?
    }

    /// Links from this framework's nodes to another's, as a source publishes them.
    struct Crosswalk: Decodable, Sendable {
        let to: String
        let relation: String
        let edition: String
        let sourceId: String
        /// Targets the source lists that the other framework's current edition no longer holds.
        let unresolved: [String]
        let map: [String: [String]]
        /// False where the targets are identifiers of a framework whose elements Lensatic does not list (a copyrighted
        /// standard): the app shows and counts the identifiers as the source prints them, and opens nothing. Round 2.
        let listed: Bool?
        /// The relation's plural where adding an s does not make it.
        let plural: String?

        var isListed: Bool { listed ?? true }
        func relations(_ n: Int) -> String { n == 1 ? relation : (plural ?? relation + "s") }
    }
}

/// The catalog: the groups, the order of the cards, the answers to where other standards land, and the names of the
/// comparison and readiness check files.
struct FrameworkCatalog: Decodable, Sendable {
    let modelVersion: String
    let checkedOn: String
    let intro: String
    let groups: [Group]
    let frameworks: [String]
    /// The frameworks Home names, each a way straight in.
    let featured: [String]
    let lands: [Landing]
    let compares: [String]
    let checks: [String]
    /// The file that links the Agentic SecOps plays to the frameworks' elements (Round 3).
    let plays: String?
    let labels: [String: String]

    struct Group: Decodable, Sendable, Identifiable {
        let id: String
        let name: String
        let line: String
    }

    /// Where does X land? A standard without a full entry: what it is, who asks for it, and the frameworks here it meets.
    struct Landing: Decodable, Sendable, Identifiable {
        let id: String
        let name: String
        let owner: String
        let what: String
        let lands: String
        let frameworkIds: [String]
        let source: Framework.SourceRecord
    }
}

/// One honest comparison of two frameworks: the same questions asked of each, how they connect, and where their
/// elements overlap by a published crosswalk. No score.
struct Comparison: Decodable, Sendable, Identifiable {
    let id: String
    let a: String
    let b: String
    /// Each side's name where both are parts of one framework (FedRAMP 20x, FedRAMP Rev5). Round 2.
    let aName: String?
    let bName: String?
    let title: String?
    let verdict: String
    let rows: [Row]
    let connect: String
    let noScore: String
    /// The line over the counted overlap; none where no publisher prints a crosswalk between the two.
    let overlapLine: String?

    struct Row: Decodable, Sendable, Hashable {
        let label: String
        let a: String
        let b: String
    }
}

/// A readiness check: questions tied to a framework's nodes, three answers, and what to do next for each. A self-check
/// kept on the device, and it says so.
struct ReadinessCheck: Decodable, Sendable, Identifiable {
    let id: String
    let frameworkId: String
    let title: String
    let line: String
    let honest: String
    let answers: [Answer]
    let items: [Item]
    /// How many next steps the result lists.
    let nextCount: Int
    /// The trailheads the check belongs to: My Path offers it to a reader on one of them. Round 2.
    let doors: [String]?
    /// "parent" groups the questions under each question's own parent (a level's domains); the default is the top level.
    let groupBy: String?
    /// The check's name on a button or a row.
    let short: String?

    struct Answer: Decodable, Sendable, Hashable, Identifiable {
        let id: String
        let label: String
        let value: Int
    }

    struct Item: Decodable, Sendable, Identifiable, Hashable {
        let id: String
        let nodeId: String
        let question: String
        let next: String
    }

    /// The result of a set of answers (item id to answer id): how many items are answered, how many at each answer,
    /// the tally by the framework's top-level node, and the short list of what to do next. Items answered with the
    /// lowest value come first, then the next lowest, each in the check's own order; the highest answer needs no step.
    struct Result: Sendable, Equatable {
        let answered: Int
        let total: Int
        let counts: [String: Int]
        let next: [Item]
        var isComplete: Bool { total > 0 && answered == total }
    }

    func result(_ given: [String: String]) -> Result {
        let valid = Dictionary(uniqueKeysWithValues: answers.map { ($0.id, $0.value) })
        let known = items.compactMap { item in given[item.id].flatMap { valid[$0] }.map { (item, $0) } }
        let top = answers.map(\.value).max() ?? 0
        var counts: [String: Int] = [:]
        for item in items { if let a = given[item.id], valid[a] != nil { counts[a, default: 0] += 1 } }
        let ranked = known.filter { $0.1 < top }.enumerated().sorted { l, r in l.element.1 != r.element.1 ? l.element.1 < r.element.1 : l.offset < r.offset }
        return Result(answered: known.count, total: items.count, counts: counts, next: Array(ranked.prefix(nextCount).map(\.element.0)))
    }
}

/// The links from the Agentic SecOps plays to the navigator (Lensatic 2.0, Round 3): for each play, the frameworks it
/// touches and, in each, the elements, with one line that says why. Lensatic's own reading of each play, which `basis`
/// says on screen; no publisher prints this crosswalk, so nothing in it is counted as an overlap. `story` is what Home
/// leads with: a title, its lines and the plays to start with.
struct PlayLinks: Decodable, Sendable {
    let id: String
    let basis: String
    let story: Story
    let plays: [Entry]

    struct Story: Decodable, Sendable {
        let title: String
        let line: String
        /// The story in one line, for the card on a phone.
        let short: String
        let playIds: [String]
    }

    struct Entry: Decodable, Sendable, Identifiable {
        let playId: String
        let links: [Link]
        var id: String { playId }
    }

    /// One framework a play touches: the elements by the publisher's identifiers, or none where the play touches the
    /// framework as a whole, and why.
    struct Link: Decodable, Sendable, Hashable, Identifiable {
        let frameworkId: String
        let nodeIds: [String]
        let line: String
        var id: String { frameworkId }
    }
}

/// A dated deadline on a framework's card, whichever file it comes from: the framework's own, or its stack entry's.
struct DatedDeadline: Sendable, Hashable {
    let frameworkId: String
    let date: String
    let label: String
    let short: String
    /// Who it binds, in a few words.
    let binds: String
    let day: DateComponents

    func days(from today: Date, calendar: Calendar = .lensatic) -> Int? { PathPlan.days(from: today, to: day, calendar: calendar) }
}

/// The frameworks, loaded once from the bundled content/frameworks folder (a resource by reference): the catalog, each
/// framework it lists, each comparison and each check, decoded strictly, with the department's tokens resolved as the
/// stack's are, and indexed for the screens.
final class FrameworkLibrary: Sendable {
    let catalog: FrameworkCatalog
    let frameworks: [Framework]
    let byId: [String: Framework]
    let graphs: [String: Graph]
    let compares: [Comparison]
    let checks: [ReadinessCheck]
    /// The plays' links (Round 3); nil where the catalog names no such file (a test's own small catalog).
    let playLinks: PlayLinks?
    private let linksByPlay: [String: [PlayLinks.Link]]

    enum LoadError: Error, Equatable { case missing(String), invalid(String) }

    static let folder = "frameworks"

    static func bundled(_ bundle: Bundle = .main, department: [String: String]) throws -> FrameworkLibrary {
        try FrameworkLibrary(department: department) { name in
            guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: folder) else { throw LoadError.missing("\(name).json") }
            return try Data(contentsOf: url)
        }
    }

    /// Loads through a reader of files by name (the bundle's folder, or a test's own files).
    init(department: [String: String], read: (String) throws -> Data) throws {
        func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
            try Strict.decode(type, from: FrameworkLibrary.resolved(try read(name), department: department))
        }
        catalog = try decode(FrameworkCatalog.self, "catalog")
        frameworks = try catalog.frameworks.map { id in
            let f = try decode(Framework.self, id)
            guard f.id == id else { throw LoadError.invalid("\(id).json holds the framework \(f.id)") }
            return f
        }
        byId = Dictionary(uniqueKeysWithValues: frameworks.map { ($0.id, $0) })
        graphs = Dictionary(uniqueKeysWithValues: frameworks.map { ($0.id, Graph($0)) })
        compares = try catalog.compares.map { try decode(Comparison.self, $0) }
        checks = try catalog.checks.map { try decode(ReadinessCheck.self, $0) }
        playLinks = try catalog.plays.map { try decode(PlayLinks.self, $0) }
        linksByPlay = Dictionary((playLinks?.plays ?? []).map { ($0.playId, $0.links) }, uniquingKeysWith: { first, _ in first })
        // a play's link never points at a framework or an element that is not there
        for entry in playLinks?.plays ?? [] {
            for link in entry.links {
                guard let g = graphs[link.frameworkId] else { throw LoadError.invalid("play \(entry.playId) links \(link.frameworkId), which is not a framework") }
                if let bad = link.nodeIds.first(where: { g.node($0) == nil }) { throw LoadError.invalid("play \(entry.playId): \(bad) is not in \(link.frameworkId)") }
            }
        }
        // every reference resolves: a card never points at a framework, a group or a node that is not there
        let groups = Set(catalog.groups.map(\.id))
        for f in frameworks {
            guard groups.contains(f.group) else { throw LoadError.invalid("\(f.id): no group \(f.group)") }
            for r in f.related where byId[r.id] == nil { throw LoadError.invalid("\(f.id): related \(r.id) is not a framework") }
            for s in f.sets {
                guard let host = graphs[s.of] else { throw LoadError.invalid("\(f.id): set \(s.id) is on \(s.of), which is not a framework") }
                if let bad = s.members.first(where: { host.node($0) == nil }) { throw LoadError.invalid("\(f.id): set \(s.id) names \(bad), which \(s.of) does not hold") }
            }
            for c in f.crosswalks {
                guard let host = graphs[c.to], let own = graphs[f.id] else { throw LoadError.invalid("\(f.id): a crosswalk to \(c.to), which is not a framework") }
                for (from, targets) in c.map {
                    guard own.node(from) != nil else { throw LoadError.invalid("\(f.id): the crosswalk names \(from), which it does not hold") }
                    // identifiers of a framework Lensatic does not list resolve to nothing, by design
                    guard c.isListed else { continue }
                    if let bad = targets.first(where: { host.node($0) == nil && !c.unresolved.contains($0) }) {
                        throw LoadError.invalid("\(f.id): \(from) points at \(bad), which \(c.to) does not hold")
                    }
                }
            }
        }
        for c in compares where byId[c.a] == nil || byId[c.b] == nil { throw LoadError.invalid("comparison \(c.id) names a framework that is not there") }
        for c in compares where c.a == c.b && (c.aName == nil || c.bName == nil) { throw LoadError.invalid("comparison \(c.id) sets one framework beside itself and does not name the two sides") }
        let doors = Set(Door.ID.allCases.map(\.rawValue))
        for c in checks { if let bad = (c.doors ?? []).first(where: { !doors.contains($0) }) { throw LoadError.invalid("check \(c.id) names the trailhead \(bad), which is not one") } }
        for c in checks {
            guard let g = graphs[c.frameworkId] else { throw LoadError.invalid("check \(c.id) is on \(c.frameworkId), which is not a framework") }
            if let bad = c.items.first(where: { g.node($0.nodeId) == nil }) { throw LoadError.invalid("check \(c.id): \(bad.nodeId) is not in \(c.frameworkId)") }
        }
        if let bad = catalog.featured.first(where: { byId[$0] == nil }) { throw LoadError.invalid("the catalog features \(bad), which is not a framework") }
        for l in catalog.lands { if let bad = l.frameworkIds.first(where: { byId[$0] == nil }) { throw LoadError.invalid("\(l.id) lands on \(bad), which is not a framework") } }
    }

    /// The file with the department's tokens resolved in every string, as the stack's are (Rules.resolveTokens).
    static func resolved(_ data: Data, department: [String: String]) throws -> Data {
        func walk(_ node: Any) -> Any {
            if let s = node as? String { return Rules.resolveTokens(s, department: department) }
            if let a = node as? [Any] { return a.map(walk) }
            if let d = node as? [String: Any] { return d.mapValues(walk) }
            return node
        }
        return try JSONSerialization.data(withJSONObject: walk(try JSONSerialization.jsonObject(with: data)), options: [.sortedKeys])
    }

    func label(_ key: String) -> String {
        guard let v = catalog.labels[key] else { preconditionFailure("catalog.labels.\(key) is missing from the content") }
        return v
    }

    func group(_ id: String) -> FrameworkCatalog.Group? { catalog.groups.first { $0.id == id } }

    /// The cards of a group, in the catalog's order.
    func frameworks(in group: String) -> [Framework] { frameworks.filter { $0.group == group } }

    func check(for framework: String) -> ReadinessCheck? { checks.first { $0.frameworkId == framework } }
    func check(_ id: String) -> ReadinessCheck? { checks.first { $0.id == id } }
    func comparison(_ id: String) -> Comparison? { compares.first { $0.id == id } }
    func comparisons(with framework: String) -> [Comparison] { compares.filter { $0.a == framework || $0.b == framework } }

    // MARK: deadlines

    /// Every dated deadline on a framework's card: its own, and its stack entry's (a date exists there only where the
    /// deadline's own source prints it).
    func deadlines(_ f: Framework, store: ContentStore) -> [DatedDeadline] {
        var out = f.deadlines.compactMap { d in
            PathPlan.day(d.date).map { DatedDeadline(frameworkId: f.id, date: d.date, label: d.label, short: d.short, binds: d.binds, day: $0) }
        }
        // the entry's own date, unless the card already carries that day in its own words (FedRAMP's first date binds
        // providers, which the card says and the entry's wider list of who it binds would not)
        if let e = f.entityId.flatMap({ store.entities[$0] }), let due = e.authority.deadline.value?.due, let day = PathPlan.day(due.date),
           !out.contains(where: { $0.date == due.date }) {
            let binds = e.authority.binds.compactMap { store.content.ui.binds[$0.rawValue] }.joined(separator: ", ")
            out.append(DatedDeadline(frameworkId: f.id, date: due.date, label: due.label, short: due.short, binds: binds, day: day))
        }
        return out.sorted { $0.date < $1.date }
    }

    /// The framework's next dated deadline, today or later.
    func upcoming(_ f: Framework, store: ContentStore, today: Date, calendar: Calendar = .lensatic) -> DatedDeadline? {
        deadlines(f, store: store).first { ($0.days(from: today, calendar: calendar) ?? -1) >= 0 }
    }

    /// The countdown Home leads with: the next dated deadline among the zero trust frameworks, today or later.
    func zeroTrustCountdown(store: ContentStore, today: Date, calendar: Calendar = .lensatic) -> DatedDeadline? {
        frameworks(in: FrameworkLibrary.zeroTrustGroup).compactMap { upcoming($0, store: store, today: today, calendar: calendar) }.min { $0.date < $1.date }
    }

    static let zeroTrustGroup = "zero-trust"

    // MARK: connections

    /// The sets, in every framework, that hold a node of this framework: the baselines a control is in.
    func memberships(of node: String, in framework: String) -> [(framework: Framework, set: Framework.NodeSet)] {
        frameworks.flatMap { f in f.sets.filter { $0.of == framework && $0.members.contains(node) }.map { (f, $0) } }
    }

    /// The nodes, in every framework, whose published crosswalk points at a node of this framework.
    func referrers(to node: String, in framework: String) -> [(framework: Framework, crosswalk: Framework.Crosswalk, nodes: [String])] {
        frameworks.flatMap { f in
            f.crosswalks.filter { $0.to == framework }.compactMap { c in
                let from = (graphs[f.id]?.order ?? []).filter { c.map[$0]?.contains(node) == true }
                return from.isEmpty ? nil : (f, c, from)
            }
        }
    }

    /// The overlap of two frameworks by a published crosswalk from one to the other, for a comparison: for each
    /// top-level node of the source that holds linked elements, how many of its elements carry a link and how many
    /// distinct targets they reach, and in all how many of the target's nodes are reached. The elements counted are the
    /// level the crosswalk starts from (CSF's Subcategories; SP 800-171's Revision 3 requirements).
    func overlap(_ c: Comparison) -> Overlap? { overlap(c.a, c.b) }

    func overlap(_ a: String, _ b: String) -> Overlap? {
        guard a != b else { return nil }
        for (from, to) in [(a, b), (b, a)] {
            guard let f = byId[from], let g = graphs[from], let host = graphs[to], let walk = f.crosswalks.first(where: { $0.to == to }) else { continue }
            let levels = Set(walk.map.keys.compactMap { g.node($0)?.level })
            let rows = g.roots.compactMap { root -> Overlap.Row? in
                let leaves = g.descendants(of: root.id).filter { levels.contains($0.level) }
                let linked = leaves.filter { !(walk.map[$0.id] ?? []).isEmpty }
                guard !linked.isEmpty else { return nil }
                let targets = Set(linked.flatMap { walk.map[$0.id] ?? [] })
                var families: [String: Int] = [:]
                if walk.isListed { for t in targets { if let top = host.top(of: t) { families[top, default: 0] += 1 } } }
                let lead = families.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(3).map(\.key)
                return Overlap.Row(node: root, leaves: leaves.count, linked: linked.count, targets: targets.count,
                                   leading: lead.compactMap { id in host.node(id).map { host.identified($0) ? id : host.line($0) } })
            }
            let unit = (f.levels.first { levels.contains($0.id) })?.plural ?? ""
            let all = Set(walk.map.values.flatMap { $0 })
            guard walk.isListed else {
                return Overlap(from: f, to: host.framework, crosswalk: walk, rows: rows, unit: unit, reached: all.count, of: 0)
            }
            // a reference to a whole family (NIST prints a few) is not one of the family's controls, so it is not counted;
            // the target's elements are the levels the crosswalk lands on, in the target's edition it names
            let targetLevels = Set(all.compactMap { host.node($0)?.level })
            let top = host.framework.levels.first?.id
            let counted = targetLevels.subtracting(targetLevels.count > 1 ? [top ?? ""] : [])
            let scope = Set(all.compactMap { host.top(of: $0) })
            let reached = all.filter { id in host.node(id).map { counted.contains($0.level) } ?? false }
            let hostLeaves = host.order.filter { id in host.node(id).map { counted.contains($0.level) } ?? false && scope.contains(host.top(of: id) ?? "") }
            return Overlap(from: f, to: host.framework, crosswalk: walk, rows: rows, unit: unit, reached: reached.count, of: hostLeaves.count)
        }
        return nil
    }

    /// Two parts of one framework set side by side (FedRAMP's 20x indicators and its Rev5 baselines): for each of the
    /// framework's sets, how many of its members the framework's own crosswalk also names.
    func setOverlap(_ f: Framework) -> [SetOverlap] {
        f.sets.compactMap { set in
            guard let walk = f.crosswalks.first(where: { $0.to == set.of }) else { return nil }
            let named = Set(walk.map.values.flatMap { $0 })
            return SetOverlap(selection: set, named: set.members.filter(named.contains).count, linking: walk.map.count)
        }
    }

    struct SetOverlap: Sendable, Identifiable {
        let selection: Framework.NodeSet
        /// How many of the set's members the crosswalk names, and how many of the framework's elements carry a link.
        let named: Int
        let linking: Int
        var id: String { selection.id }
    }

    /// The comparison the content writes for two frameworks, in either order.
    func named(_ a: String, _ b: String) -> Comparison? {
        compares.first { ($0.a == a && $0.b == b) || ($0.a == b && $0.b == a) }
    }

    /// The readiness checks a trailhead's readers are offered on My Path.
    func checks(for door: Door.ID) -> [ReadinessCheck] { checks.filter { ($0.doors ?? []).contains(door.rawValue) } }
    func checks(on framework: String) -> [ReadinessCheck] { checks.filter { $0.frameworkId == framework } }

    // MARK: the plays' links (Round 3)

    /// The frameworks a play touches, in the file's order; none for a play the file does not hold.
    func links(forPlay id: String) -> [PlayLinks.Link] { linksByPlay[id] ?? [] }

    /// How many elements a play's links name, and in how many frameworks.
    func linkCounts(forPlay id: String) -> (elements: Int, frameworks: Int) {
        let links = links(forPlay: id)
        return (links.reduce(0) { $0 + $1.nodeIds.count }, links.count)
    }

    /// The plays that touch a framework, in the plays' own order, each with its link.
    func plays(touching framework: String) -> [(playId: String, link: PlayLinks.Link)] {
        (playLinks?.plays ?? []).compactMap { e in e.links.first { $0.frameworkId == framework }.map { (e.playId, $0) } }
    }

    /// The plays that name one element of a framework, in the plays' own order.
    func plays(touching node: String, in framework: String) -> [String] {
        (playLinks?.plays ?? []).filter { e in e.links.contains { $0.frameworkId == framework && $0.nodeIds.contains(node) } }.map(\.playId)
    }

    /// The count of what a link names, in the publisher's word where every element is at one level ("5 Techniques"),
    /// else in the content's word for elements.
    func countLine(_ link: PlayLinks.Link) -> String? {
        guard !link.nodeIds.isEmpty, let g = graphs[link.frameworkId] else { return nil }
        let levels = Set(link.nodeIds.compactMap { g.node($0)?.level })
        let n = link.nodeIds.count
        if levels.count == 1, let level = levels.first.flatMap({ g.level($0) }) { return "\(n) \(n == 1 ? level.name : level.plural)" }
        return "\(n) \(label(n == 1 ? "element" : "elementsWord"))"
    }

    // MARK: one layer model (Round 2)

    /// The cards that sit on a layer of the stack, in the catalog's order: Explore's layer screens list them, so the
    /// stack and the Frameworks tab are one map.
    func frameworks(onLayer id: String) -> [Framework] { frameworks.filter { $0.sits.layers.contains(id) } }

    /// The cards of the adversary column: the knowledge bases, which sit beside the stack.
    var adversary: [Framework] { frameworks.filter { !$0.compliance } }

    /// The card that is a stack entry's own, where the navigator has one.
    func framework(forEntity id: String) -> Framework? { frameworks.first { $0.entityId == id } }

    struct Overlap: Sendable {
        struct Row: Sendable, Identifiable {
            let node: Framework.Node
            let leaves: Int
            let linked: Int
            let targets: Int
            /// The target framework's top-level nodes that most of the links land in.
            let leading: [String]
            var id: String { node.id }
        }

        let from: Framework
        let to: Framework
        let crosswalk: Framework.Crosswalk
        let rows: [Row]
        /// The source's elements that are counted, in the publisher's word (Subcategories, Requirements).
        let unit: String
        /// How many of the target's elements the crosswalk reaches, and of how many; `of` is zero where the target's
        /// elements are not listed, and `reached` is then the number of distinct identifiers named.
        let reached: Int
        let of: Int
    }

    /// A framework's structure, indexed: each node by id, the children of each, and the top level.
    struct Graph: Sendable {
        let framework: Framework
        let order: [String]
        private let byId: [String: Framework.Node]
        private let kids: [String: [String]]
        let roots: [Framework.Node]

        init(_ f: Framework) {
            framework = f
            order = f.nodes.map(\.id)
            byId = Dictionary(f.nodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            var kids: [String: [String]] = [:]
            for n in f.nodes { for p in n.parents { kids[p, default: []].append(n.id) } }
            self.kids = kids
            roots = f.nodes.filter { $0.parents.isEmpty }
        }

        func node(_ id: String) -> Framework.Node? { byId[id] }
        /// Whether a node's id is the publisher's own identifier, to show, or the file's key for a level the publisher
        /// does not number.
        func identified(_ n: Framework.Node) -> Bool { level(n.level)?.identified ?? true }
        /// A node's name in running text: "AC-2 Account Management", "PR.AA-01", or a title alone where there is no identifier.
        func name(_ n: Framework.Node) -> String {
            guard identified(n) else { return n.title ?? n.text ?? "" }
            return n.title.map { "\(n.id) \($0)" } ?? n.id
        }
        func children(of id: String) -> [Framework.Node] { (kids[id] ?? []).compactMap { byId[$0] } }
        func level(_ id: String) -> Framework.Level? { framework.levels.first { $0.id == id } }

        /// Every node under a node, each once, in the file's order.
        func descendants(of id: String) -> [Framework.Node] {
            var seen = Set<String>(), stack = kids[id] ?? []
            while let next = stack.popLast() {
                guard seen.insert(next).inserted else { continue }
                stack.append(contentsOf: kids[next] ?? [])
            }
            return order.filter(seen.contains).compactMap { byId[$0] }
        }

        /// The top-level node a node sits under (its first parent's, upward); itself when it is one.
        func top(of id: String) -> String? {
            var at = id, hops = 0
            while let p = byId[at]?.parents.first, hops < 8 { at = p; hops += 1 }
            return byId[at] == nil ? nil : at
        }

        /// A node's name for a row: its title, or for a node the publisher gives only a sentence, that sentence.
        func line(_ n: Framework.Node) -> String { n.title ?? n.text ?? n.id }

        /// A set's members grouped by the host's top-level nodes, in the host's order, for a baseline's screen.
        func grouped(_ members: [String]) -> [(top: Framework.Node, nodes: [Framework.Node])] {
            var by: [String: [Framework.Node]] = [:]
            for m in members { if let n = byId[m], let t = top(of: m) { by[t, default: []].append(n) } }
            return roots.compactMap { r in by[r.id].map { (r, $0) } }
        }
    }
}
