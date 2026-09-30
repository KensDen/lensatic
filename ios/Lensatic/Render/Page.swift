import Foundation

// The render model: every screen is a `Page` of blocks, built from content by `PageBuilder` and passed once through
// the first-use rule before a view draws it. Pages are plain data, so the tests read exactly what a screen shows.

/// The sections, in the web page's order (tools/build_web.py SECTIONS), each titled from the content.
enum Section: String, CaseIterable, Hashable, Sendable, Identifiable {
    case doors, stack, matrix, functions, ai, helper, sources, glossary, about
    var id: String { rawValue }
}

/// A screen pushed inside a section.
enum Route: Hashable, Sendable {
    case door(String)
    case layer(String)
    case entity(String)
    case cell(PillarView, String, FunctionID)
}

/// Where a link or a control goes.
enum Target: Hashable, Sendable {
    case section(Section, anchor: String?)
    case push(Route)
    case glossary(String)
    case anchor(String)
    case external(URL)
}

enum SpanRole: Sendable {
    /// Prose: takes the first-use rule.
    case running
    /// A label (a heading, button, chip, badge, tag or meta line): never takes an expansion and is never a first use.
    case label
    /// A label that stands where the web has a disclosure's summary (an entry's own title and short name at the top of
    /// its screen): as inside the web's summary, its abbreviations describe the text rather than link (session 11).
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

/// One run of text: the spans the builder placed, and, after the rule, the segments a view draws.
struct Run: Sendable {
    var spans: [Span]
    var segments: [Segment] = []
    /// Expansions of abbreviations in labels that sit inside a control: they describe the control (its hint).
    var described: [String] = []
    /// The same, by the link a label span carries (an entry's name in a list of links), for a view that draws each link
    /// as its own control.
    var linkDescribed: [Target: [String]] = [:]
    /// What VoiceOver reads instead of the text, where the text is an address: the site, not the address letter by letter.
    var spoken: String?

    init(_ spans: [Span]) { self.spans = spans }
    init(_ span: Span) { spans = [span] }

    /// The text before the rule.
    var source: String { spans.map(\.text).joined() }
    /// The text a reader sees, and VoiceOver reads.
    var text: String { segments.isEmpty && !spans.isEmpty ? source : segments.map(\.string).joined() }
    var isEmpty: Bool { spans.allSatisfy { $0.text.isEmpty } }
}

enum TextStyle: Sendable {
    case body, lede, small, note, question, elevator, strong
}

struct Badge: Sendable {
    var status: Verification.Status
    var run: Run
}

struct Chip: Sendable {
    var label: Run
    var target: Target
    var kind: Entity.Kind
}

/// A row that opens something: a door card, a layer, a source, a matrix cell. The whole row is one control.
struct NavRow: Sendable {
    enum Style: Sendable {
        case standard
        /// A layer of the stack: its name in the mono label face, its question as the row's main line.
        case layer
    }

    var lead: Run?
    var title: Run
    var lines: [Run] = []
    var meta: Run?
    /// The meta line is a sentence from the content (a door with no steps), shown in its own case.
    var metaIsSentence = false
    var style = Style.standard
    var badges: [Badge] = []
    var target: Target
    var identifier: String

    /// What VoiceOver reads for the row: every visible part, in order.
    var accessibilityLabel: String {
        ([lead?.text, title.text] + lines.map(\.text) + [meta?.text] + badges.map(\.run.text))
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

/// A button: the hero's two, the pillar views, the version line's link, the About links.
struct Control: Sendable {
    var label: Run
    var target: Target
    var prominent = false
    var identifier: String
}

struct StepItem: Sendable {
    var tag: Control?
    var text: Run
    var links: Run?

    var accessibilityLabel: String {
        [tag?.label.text, text.text, links?.text].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct KeyValue: Sendable {
    var key: Run
    var value: Run
    var badges: [Badge] = []
    var extra: Run?
}

struct GlossaryItem: Sendable {
    var anchor: String
    var term: Run
    var body: Run
    var badge: Badge?
}

struct Disclosure: Sendable {
    var summary: Run
    var body: [Run]
    var identifier: String
}

indirect enum BlockKind: Sendable {
    case sectionHead(number: Run, title: Run)
    /// The eyebrow is its phrases, each ending with its separator, so a narrow screen wraps it only between phrases.
    case hero(eyebrow: [Run], name: Run, lede: Run)
    case title(Run)
    case heading(Run)
    case text(Run, TextStyle)
    case controls([Control])
    /// The front door's stamp: the content version (a link to About) with the punctuation that follows it, the
    /// checked-through date, Why the name?
    case versionLine(version: Control, joiner: String, Run, why: Control)
    case chips([Chip])
    case rows([NavRow])
    case steps([StepItem])
    /// A layer's tag and its name; the AI column's tag is its name, so it has no second run.
    case tagLine(Control, Run?)
    case keyValues([KeyValue])
    case bullets([Run])
    case badges([Badge])
    case statusKey(title: Run, rows: [(Badge, Run)])
    case glossary([GlossaryItem])
    case disclosures([Disclosure])
    case pillarViews([Control], selected: Int)
    case links([Control])
    case aboutHeader(name: Run, version: Run)
    case story(heading: Run, photoAlt: String, paragraphs: [Run])
    case group([Block])
}

struct Block: Sendable {
    var anchor: String?
    var kind: BlockKind

    init(_ kind: BlockKind, anchor: String? = nil) {
        self.kind = kind
        self.anchor = anchor
    }
}

struct Page: Sendable {
    var title: String
    var blocks: [Block]
    /// Every content string the page places, before the first-use rule: the parity test reads this.
    var texts: [String] = []

    /// Visit every run in reading order, with whether it sits inside a control (where no link can be nested).
    mutating func visitRuns(_ body: (inout Run, Bool) -> Void) {
        for i in blocks.indices { blocks[i].kind.visit(body) }
    }

    /// Every run, in reading order.
    var runs: [Run] {
        var out: [Run] = []
        var copy = self
        copy.visitRuns { run, _ in out.append(run) }
        return out
    }

    /// The accessibility labels the views compose from runs (rows, steps, the photo), for the tests.
    var accessibilityLabels: [String] {
        var out: [String] = []
        func walk(_ kind: BlockKind) {
            switch kind {
            case .rows(let rows): out += rows.map(\.accessibilityLabel)
            case .steps(let steps): out += steps.map(\.accessibilityLabel)
            case .story(_, let alt, _): out.append(alt)
            case .group(let blocks): blocks.forEach { walk($0.kind) }
            default: break
            }
        }
        blocks.forEach { walk($0.kind) }
        return out + runs.map(\.text) + runs.flatMap(\.described) + runs.compactMap(\.spoken)
    }
}

extension BlockKind {
    mutating func visit(_ body: (inout Run, Bool) -> Void) {
        func each(_ runs: inout [Run], _ interactive: Bool) { for i in runs.indices { body(&runs[i], interactive) } }
        func control(_ c: inout Control) { body(&c.label, true) }
        func badges(_ b: inout [Badge], _ interactive: Bool) { for i in b.indices { body(&b[i].run, interactive) } }
        switch self {
        case .sectionHead(var n, var t):
            body(&n, false); body(&t, false)
            self = .sectionHead(number: n, title: t)
        case .hero(var e, var n, var l):
            each(&e, false); body(&n, false); body(&l, false)
            self = .hero(eyebrow: e, name: n, lede: l)
        case .title(var r):
            body(&r, false)
            self = .title(r)
        case .heading(var r):
            body(&r, false)
            self = .heading(r)
        case .text(var r, let style):
            body(&r, false)
            self = .text(r, style)
        case .controls(var cs):
            for i in cs.indices { control(&cs[i]) }
            self = .controls(cs)
        case .versionLine(var v, let joiner, var r, var c):
            control(&v); body(&r, false); control(&c)
            self = .versionLine(version: v, joiner: joiner, r, why: c)
        case .chips(var chips):
            for i in chips.indices { body(&chips[i].label, true) }
            self = .chips(chips)
        case .rows(var rows):
            for i in rows.indices {
                if var lead = rows[i].lead { body(&lead, true); rows[i].lead = lead }
                body(&rows[i].title, true)
                each(&rows[i].lines, true)
                if var meta = rows[i].meta { body(&meta, true); rows[i].meta = meta }
                badges(&rows[i].badges, true)
            }
            self = .rows(rows)
        case .steps(var steps):
            for i in steps.indices {
                if var tag = steps[i].tag { control(&tag); steps[i].tag = tag }
                body(&steps[i].text, false)
                if var links = steps[i].links { body(&links, false); steps[i].links = links }
            }
            self = .steps(steps)
        case .tagLine(var c, let r):
            control(&c)
            var run = r
            if var x = run { body(&x, false); run = x }
            self = .tagLine(c, run)
        case .keyValues(var kvs):
            for i in kvs.indices {
                body(&kvs[i].key, false)
                body(&kvs[i].value, false)
                badges(&kvs[i].badges, false)
                if var extra = kvs[i].extra { body(&extra, false); kvs[i].extra = extra }
            }
            self = .keyValues(kvs)
        case .bullets(var runs):
            each(&runs, false)
            self = .bullets(runs)
        case .badges(var b):
            badges(&b, false)
            self = .badges(b)
        case .statusKey(var title, var rows):
            body(&title, false)
            for i in rows.indices { body(&rows[i].0.run, false); body(&rows[i].1, false) }
            self = .statusKey(title: title, rows: rows)
        case .glossary(var items):
            for i in items.indices {
                body(&items[i].term, false)
                body(&items[i].body, false)
                if var b = items[i].badge { body(&b.run, false); items[i].badge = b }
            }
            self = .glossary(items)
        case .disclosures(var ds):
            for i in ds.indices { body(&ds[i].summary, true); each(&ds[i].body, false) }
            self = .disclosures(ds)
        case .pillarViews(var cs, let selected):
            for i in cs.indices { control(&cs[i]) }
            self = .pillarViews(cs, selected: selected)
        case .links(var cs):
            for i in cs.indices { control(&cs[i]) }
            self = .links(cs)
        case .aboutHeader(var n, var v):
            body(&n, false); body(&v, false)
            self = .aboutHeader(name: n, version: v)
        case .story(var h, let alt, var ps):
            body(&h, false); each(&ps, false)
            self = .story(heading: h, photoAlt: alt, paragraphs: ps)
        case .group(var blocks):
            for i in blocks.indices { blocks[i].kind.visit(body) }
            self = .group(blocks)
        }
    }
}
