import Foundation

/// The content, loaded once from the bundled content/stack.json (a resource by reference, never a copy): decoded
/// strictly, its department tokens resolved, and indexed for the pages.
final class ContentStore: Sendable {
    let content: Content
    let rules: Rules
    let terms: [Rules.Term]
    let entities: [String: Entity]
    let frameworks: [Entity]
    let sources: [Entity]
    let solutions: [Entity]
    let layers: [String: Layer]
    let functions: [FunctionID: CSFFunction]
    let pillars: [String: Pillar]
    let capabilityNames: [String: String]
    let cells: [String: Matrix.Cell]
    let latestCheck: String
    let counts: [Verification.Status: Int]
    let sections: [Section]
    let maker: String
    let appVersion: String

    enum LoadError: Error { case missing(String), invalid(String) }

    static func bundled(_ bundle: Bundle = .main) throws -> ContentStore {
        guard let url = bundle.url(forResource: "stack", withExtension: "json") else { throw LoadError.missing("stack.json") }
        let info = bundle.infoDictionary ?? [:]
        let version = [info["CFBundleShortVersionString"] as? String, (info["CFBundleVersion"] as? String).map { "(\($0))" }]
            .compactMap { $0 }.joined(separator: " ")
        return try ContentStore(data: Data(contentsOf: url), maker: info["LensaticMaker"] as? String ?? "", appVersion: version)
    }

    init(data: Data, maker: String = "", appVersion: String = "") throws {
        let raw = try Strict.decode(Content.self, from: data)
        let (content, tree) = try Rules.resolved(data, department: raw.orgs.dow.fields)
        self.content = content
        terms = Rules.terms(content.glossary, rawTerms: raw.glossary.map(\.term))
        rules = Rules(terms: terms)
        frameworks = content.frameworks.map(\.entity)
        sources = content.sources.map(\.entity)
        solutions = content.solutions.map(\.entity)
        entities = Dictionary(uniqueKeysWithValues: (frameworks + sources + solutions).map { ($0.id, $0) })
        layers = Dictionary(uniqueKeysWithValues: content.layers.map { ($0.id, $0) })
        functions = Dictionary(uniqueKeysWithValues: content.functions.map { ($0.id, $0) })
        pillars = Dictionary(uniqueKeysWithValues: content.pillars.canonical.map { ($0.id, $0) })
        // the last name wins for a repeated capability id, as the web's lookup does
        capabilityNames = Dictionary(content.pillars.canonical.flatMap { $0.capabilities ?? [] }.map { ($0.id, $0.name) }, uniquingKeysWith: { _, last in last })
        cells = Dictionary(uniqueKeysWithValues: content.matrix.cells.map { (ContentStore.cellKey($0.pillarId, $0.functionId), $0) })
        latestCheck = Rules.latestCheck(tree)
        counts = Rules.verificationCounts(tree)
        sections = Section.allCases.filter { $0 != .glossary || !content.glossary.isEmpty }
        self.maker = maker
        self.appVersion = appVersion
        // every pillar a view lists must exist and carry that view's name: a column is never dropped in silence
        let views = content.pillars.views
        for (id, name) in views.dow.map({ ($0, self.pillars[$0]?.dowName.value) })
            + (views.cisa.pillars + views.cisa.crossCutting).map({ ($0, self.pillars[$0]?.cisaName.value) }) where name == nil {
            throw LoadError.invalid("pillar \(id) is in a view but has no name for it")
        }
    }

    static func cellKey(_ pillar: String, _ function: FunctionID) -> String { "\(pillar)|\(function.rawValue)" }

    func cell(_ pillar: String, _ function: FunctionID) -> Matrix.Cell? { cells[ContentStore.cellKey(pillar, function)] }

    /// A label from ui.labels. Every key the app reads is in the content; the tests build every page, so a missing
    /// one fails there before it can ship.
    func label(_ key: String) -> String {
        guard let v = content.ui.labels[key] else { preconditionFailure("ui.labels.\(key) is missing from the content") }
        return v
    }

    func sectionTitle(_ s: Section) -> String { content.ui.sections[s.rawValue] ?? s.rawValue }
    func navTitle(_ s: Section) -> String { content.ui.nav[s.rawValue] ?? s.rawValue }
    func sectionNumber(_ s: Section) -> String { String(format: "%02d", (sections.firstIndex(of: s) ?? 0) + 1) }

    /// The pillars of a view, in the view's printed order: the department's seven, or CISA's five and then its three
    /// cross-cutting capabilities (marked).
    func columns(_ view: PillarView) -> [(id: String, name: String, crossCutting: Bool)] {
        switch view {
        case .dow:
            return content.pillars.views.dow.compactMap { id in pillars[id]?.dowName.value.map { (id, $0, false) } }
        case .cisa:
            let v = content.pillars.views.cisa
            return v.pillars.compactMap { id in pillars[id]?.cisaName.value.map { (id, $0, false) } }
                + v.crossCutting.compactMap { id in pillars[id]?.cisaName.value.map { (id, $0, true) } }
        }
    }
}
