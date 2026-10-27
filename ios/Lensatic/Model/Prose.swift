import Foundation

// The text model the first-use rule works on (the redesign, R2: the old page model and its renderer are gone). A screen
// that shows the map's prose builds it as runs of spans, in reading order, and passes them once through
// `Rules.apply`; a view draws each run's segments. The runs are plain data, so the tests read exactly what a screen shows.

/// The map's sections, in the web page's order (tools/build_web.py SECTIONS): their names and titles come from the
/// content's ui.nav and ui.sections.
enum Section: String, CaseIterable, Hashable, Sendable, Identifiable {
    case doors, stack, matrix, functions, ai, helper, sources, glossary, about
    var id: String { rawValue }
}

/// Where a link inside text goes: a screen in the app, a glossary entry, or an outside address (handed to the system).
enum Target: Hashable, Sendable {
    case nav(Nav)
    case glossary(String)
    case external(URL)
}

enum SpanRole: Sendable {
    /// Prose: takes the first-use rule.
    case running
    /// A label (a heading, button, chip or meta line): never takes an expansion and is never a first use.
    case label
    /// A label that names the screen it heads (an entry's own title): its abbreviations describe the text rather than
    /// link (session 11).
    case describedLabel
    /// Text the rule leaves alone but reads (addresses, codes, numbers).
    case hard
    /// A glossary entry's own term: it counts as spelled out, because its expansion follows it.
    case glossaryTerm
}

enum SpanStyle: Hashable, Sendable {
    case plain, strong, mono, monoStrong, url
}

struct Span: Sendable {
    var text: String
    var role: SpanRole
    var style: SpanStyle
    var link: Target?

    init(_ text: String, role: SpanRole = .running, style: SpanStyle = .plain, link: Target? = nil) {
        self.text = text
        self.role = role
        self.style = style
        self.link = link
    }
}

/// A piece of rendered text after the first-use rule: plain text, a glossary term linked to its entry, or an expansion.
enum Segment: Sendable {
    case text(String, SpanStyle, Target?)
    case term(String, slug: String, SpanStyle)
    case expansion(String, SpanStyle, Target?)

    var string: String {
        switch self {
        case .text(let s, _, _), .term(let s, _, _), .expansion(let s, _, _): return s
        }
    }
}

/// One run of text: the spans a screen placed, and, after the rule, the segments a view draws.
struct Run: Sendable {
    var spans: [Span]
    var segments: [Segment] = []
    /// Expansions of abbreviations in labels that sit inside a control: they describe the control (its hint).
    var described: [String] = []
    /// The same, by the link a label span carries (an entry's name in a list of links).
    var linkDescribed: [Target: [String]] = [:]

    init(_ spans: [Span]) { self.spans = spans }
    init(_ span: Span) { spans = [span] }

    /// The text before the rule.
    var source: String { spans.map(\.text).joined() }
    /// The text a reader sees, and VoiceOver reads.
    var text: String { segments.isEmpty && !spans.isEmpty ? source : segments.map(\.string).joined() }
    var isEmpty: Bool { spans.allSatisfy { $0.text.isEmpty } }
}

/// One screen's text in reading order, each run marked when it sits inside a control (where nothing can be linked).
struct Prose: Sendable {
    var runs: [Run] = []
    var interactive: [Bool] = []

    init() {}

    init(_ runs: [Run], interactive: Bool = false) {
        self.runs = runs
        self.interactive = Array(repeating: interactive, count: runs.count)
    }

    /// Add a run and give back its place, so a screen can find it again after the rule.
    @discardableResult
    mutating func add(_ run: Run, interactive: Bool = false) -> Int {
        runs.append(run)
        self.interactive.append(interactive)
        return runs.count - 1
    }

    @discardableResult
    mutating func add(_ spans: [Span], interactive: Bool = false) -> Int { add(Run(spans), interactive: interactive) }

    subscript(_ i: Int) -> Run { runs[i] }

    /// Everything VoiceOver can read from these runs: the text and the expansions that describe controls.
    var accessibilityLabels: [String] { runs.map(\.text) + runs.flatMap(\.described) }
}

extension Target {
    private static let scheme = "lensatic"

    /// Links inside text carry their target as an address; `init?(url:)` reads it back. Only outside addresses ever
    /// leave the app.
    var url: URL? {
        func make(_ parts: [String]) -> URL? {
            var c = URLComponents()
            c.scheme = Target.scheme
            c.path = "/" + parts.joined(separator: "/")  // ids are letters, digits and hyphens
            return c.url
        }
        switch self {
        case .nav(let nav): return make(nav.pathParts)
        case .glossary(let slug): return make(["glossary", slug])
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
        if parts.count == 2, parts[0] == "glossary" {
            self = .glossary(parts[1])
        } else if let nav = Nav(pathParts: parts) {
            self = .nav(nav)
        } else {
            return nil
        }
    }
}
