import XCTest
@testable import Lensatic

/// One test per transformation rule in `Rules`, on small inputs whose right answer is the web build's.
final class RulesTests: XCTestCase {
    let department = ["abbr": "DoW", "current": "Department of War", "statutory": "Department of Defense"]

    func term(_ t: String, _ exp: String?, forms: [String]? = nil, prefix: Bool = false, notAbbreviation: Bool = false,
              wellKnown: Bool = false, nameFirst: Bool = false) -> Rules.Term {
        Rules.Term(term: t, slug: Rules.slug(t), expansion: exp, forms: forms ?? [t], prefix: prefix, notAbbreviation: notAbbreviation,
                   wellKnown: wellKnown, nameFirst: nameFirst)
    }

    lazy var rules = Rules(terms: [
        term("NIST", "National Institute of Standards and Technology"),
        term("DoW", "Department of War", nameFirst: true),
        term("AI", "artificial intelligence", wellKnown: true),
        term("MITRE", nil, notAbbreviation: true),
        term("ISO", "International Organization for Standardization", prefix: true),
        term("IEC", "International Electrotechnical Commission", prefix: true),
        term("FY", "fiscal year", prefix: true),
        term("STIG", "Security Technical Implementation Guide", forms: ["STIG", "STIGs"]),
        term("DCDC", "Department of Defense Cyber Defense Command"),
        term("AI RMF", "Artificial Intelligence Risk Management Framework"),
    ])

    /// Run the rule over one screen of runs and give back what a reader sees in each.
    func render(_ runs: [[Span]], interactive: Bool = false) -> [String] {
        var page = Page(title: "", blocks: runs.map { spans in
            interactive ? Block(.rows([NavRow(title: Run(spans), target: .anchor("x"), identifier: "x")])) : Block(.text(Run(spans), .body))
        })
        rules.apply(&page)
        return page.runs.map(\.text)
    }

    func segments(_ spans: [Span]) -> [Segment] {
        var page = Page(title: "", blocks: [Block(.text(Run(spans), .body))])
        rules.apply(&page)
        return page.runs[0].segments
    }

    // MARK: tokens and the department

    func testTokensRenderTheAbbreviationOrTheField() {
        XCTAssertEqual(Rules.resolveTokens("{{dow}} components", department: department), "DoW components")
        XCTAssertEqual(Rules.resolveTokens("the {{ dow.current }} and the {{dow.statutory}}", department: department),
                       "the Department of War and the Department of Defense")
        XCTAssertEqual(Rules.resolveTokens("x{{dow.nothing}}y", department: department), "xy")
    }

    func testTheDepartmentIsSpelledOutNameFirstAtItsFirstMentionOnly() {
        XCTAssertEqual(render([[Span("DoW components and DoW contractors")]]), ["Department of War (DoW) components and DoW contractors"])
    }

    // MARK: first use

    func testFirstUseIsSpelledOutOncePerScreenAndLinked() {
        let out = segments([Span("NIST wrote it; NIST keeps it.")])
        XCTAssertEqual(out.map(\.string).joined(), "NIST (National Institute of Standards and Technology) wrote it; NIST keeps it.")
        guard case .term("NIST", "nist", _) = out[0] else { return XCTFail("the first NIST is not linked") }
        XCTAssertFalse(out.dropFirst().contains { if case .term = $0 { return true } else { return false } })
    }

    func testAnExpansionAlreadyOnTheScreenIsNotRepeated() {
        XCTAssertEqual(render([[Span("The National Institute of Standards and Technology publishes.")], [Span("NIST says so.")]]),
                       ["The National Institute of Standards and Technology publishes.", "NIST says so."])
    }

    func testAFormAfterItsOwnNameIsLeftAlone() {
        // the name before the parenthesis is not the expansion, so only the names-itself rule leaves it alone
        XCTAssertTrue(Rules.namesItself(before: "the DoD Cyber Defense Command (", after: ") runs it", expansion: "Department of Defense Cyber Defense Command"))
        XCTAssertEqual(render([[Span("the DoD Cyber Defense Command (DCDC) runs it")]]), ["the DoD Cyber Defense Command (DCDC) runs it"])
        XCTAssertEqual(render([[Span("the Cyber Command (DCDC) runs it")]]),
                       ["the Cyber Command (DCDC [Department of Defense Cyber Defense Command]) runs it"])
    }

    func testAShortNameInParenthesesTakesBracketsAsOneRunOfText() {
        // the builder places "(AI RMF)" as one span, as the web's span.short is one text node
        XCTAssertEqual(render([[Span("The risk framework 1.0")], [Span("(AI RMF)")]]),
                       ["The risk framework 1.0", "(AI RMF [Artificial Intelligence Risk Management Framework])"])
    }

    func testANameWithAWellKnownTermWrittenShortCountsAsSpelledOut() {
        // session 11 (ED-06): AI is never spelled out, so "AI Risk Management Framework" is AI RMF's name spelled out
        XCTAssertEqual(rules.spelled["AI RMF"], ["Artificial Intelligence Risk Management Framework", "AI Risk Management Framework"])
        XCTAssertEqual(render([[Span("The AI Risk Management Framework 1.0")], [Span("(AI RMF)")]]),
                       ["The AI Risk Management Framework 1.0", "(AI RMF)"])
        XCTAssertEqual(render([[Span("the AI RMF applies")]]), ["the AI RMF (Artificial Intelligence Risk Management Framework) applies"])
    }

    func testADescribedLabelIsNeitherExpandedNorLinked() {
        // session 11: an entry's own title at the top of its screen, as inside the web's summary
        var page = Page(title: "", blocks: [Block(.title(Run(Span("NIST rules", role: .describedLabel)))), Block(.text(Run(Span("NIST says")), .body))])
        rules.apply(&page)
        XCTAssertEqual(page.runs.map(\.text), ["NIST rules", "NIST (National Institute of Standards and Technology) says"])
        XCTAssertFalse(page.runs[0].segments.contains { if case .term = $0 { return true } else { return false } })
        XCTAssertEqual(page.runs[0].described, ["National Institute of Standards and Technology"])
    }

    func testALabelInALinkDescribesThatLink() {
        // session 11 (ED-05): an entry's name in a list of links is a label: never expanded, and the link is described
        let target = Target.push(.entity("x"))
        var page = Page(title: "", blocks: [Block(.text(Run([Span("Draws on: "), Span("NIST", role: .label, link: target)]), .small)),
                                            Block(.text(Run(Span("NIST says")), .body))])
        rules.apply(&page)
        XCTAssertEqual(page.runs.map(\.text), ["Draws on: NIST", "NIST (National Institute of Standards and Technology) says"])
        XCTAssertEqual(page.runs[0].linkDescribed[target], ["National Institute of Standards and Technology"])
        XCTAssertEqual(page.runs[0].described, ["National Institute of Standards and Technology"])
    }

    func testInsideAParenthesisTheExpansionTakesBrackets() {
        XCTAssertEqual(render([[Span("a rule (per NIST) holds")]]), ["a rule (per NIST [National Institute of Standards and Technology]) holds"])
    }

    func testAPluralFormTakesAPluralExpansion() {
        XCTAssertEqual(render([[Span("apply the STIGs")]]), ["apply the STIGs (Security Technical Implementation Guides)"])
    }

    func testAPrefixFormKeepsItsDesignationAndAnInnerFormAddsItsExpansion() {
        XCTAssertEqual(render([[Span("ISO/IEC 27001 and IEC rules")]]),
                       ["ISO/IEC 27001 (International Organization for Standardization and International Electrotechnical Commission) and IEC rules"])
        XCTAssertEqual(render([[Span("by FY2027, done")]]), ["by FY2027 (fiscal year), done"])
    }

    func testANameIsLinkedAndNeverExpanded() {
        let out = segments([Span("MITRE and MITRE")])
        XCTAssertEqual(out.map(\.string).joined(), "MITRE and MITRE")
        guard case .term("MITRE", "mitre", _) = out[0] else { return XCTFail("MITRE is not linked") }
    }

    /// Session 17: a well-known term is never spelled out, and links to its entry only at its first use in running text
    /// on the AI column screen; it is plain on every other screen and in every label.
    func testAWellKnownTermLinksOnlyAtFirstUseOnTheAIColumnAndIsNeverSpelledOut() {
        func isTerm(_ form: String) -> (Segment) -> Bool { { if case .term(let f, _, _) = $0 { return f == form } else { return false } } }
        let plain = segments([Span("AI helps; AI hurts.")])
        XCTAssertEqual(plain.map(\.string).joined(), "AI helps; AI hurts.")
        XCTAssertFalse(plain.contains(where: isTerm("AI")), "AI is linked off the AI column")
        var page = Page(title: "", blocks: [Block(.text(Run(Span("AI helps; AI hurts.")), .body))])
        rules.apply(&page, linksWellKnown: true)
        let linked = page.runs[0].segments
        XCTAssertEqual(linked.map(\.string).joined(), "AI helps; AI hurts.")
        guard case .term("AI", "ai", _) = linked[0] else { return XCTFail("AI is not linked at its first use on the AI column") }
        XCTAssertEqual(linked.filter(isTerm("AI")).count, 1, "AI is linked past its first use")
        for aiColumn in [false, true] {
            var labels = Page(title: "", blocks: [Block(.heading(Run(Span("AI and NIST", role: .label)))),
                                                  Block(.rows([NavRow(title: Run(Span("AI", role: .label)), target: .anchor("x"), identifier: "x")]))])
            rules.apply(&labels, linksWellKnown: aiColumn)
            XCTAssertFalse(labels.runs.flatMap(\.segments).contains(where: isTerm("AI")), "AI is linked in a label")
            XCTAssertTrue(labels.runs[0].segments.contains(where: isTerm("NIST")), "a label's other abbreviation no longer links")
            XCTAssertFalse(labels.accessibilityLabels.contains { $0.contains("artificial intelligence") })
            XCTAssertFalse(labels.runs.flatMap(\.described).contains("artificial intelligence"))
        }
    }

    func testALabelIsNeverExpandedAndIsNotAFirstUse() {
        var page = Page(title: "", blocks: [Block(.heading(Run(Span("NIST rules", role: .label)))), Block(.text(Run(Span("NIST says")), .body))])
        rules.apply(&page)
        XCTAssertEqual(page.runs.map(\.text), ["NIST rules", "NIST (National Institute of Standards and Technology) says"])
        guard case .term("NIST", "nist", _)? = page.runs[0].segments.first else { return XCTFail("a label's form links to its entry") }
        XCTAssertEqual(page.runs[0].described, ["National Institute of Standards and Technology"])
    }

    func testInsideAControlNothingIsLinkedAndALabelDescribesTheControl() {
        var page = Page(title: "", blocks: [Block(.rows([NavRow(title: Run(Span("NIST", role: .label)), lines: [Run(Span("NIST says"))],
                                                                target: .anchor("x"), identifier: "x")]))])
        rules.apply(&page)
        XCTAssertEqual(page.runs.map(\.text), ["NIST", "NIST (National Institute of Standards and Technology) says"])
        XCTAssertFalse(page.runs.flatMap(\.segments).contains { if case .term = $0 { return true } else { return false } })
        XCTAssertEqual(page.runs[0].described, ["National Institute of Standards and Technology"])
    }

    func testAGlossaryTermCountsAsSpelledOut() {
        XCTAssertEqual(render([[Span("NIST", role: .glossaryTerm)], [Span("NIST again")]]), ["NIST", "NIST again"])
    }

    func testAddressesAreNotExpanded() {
        XCTAssertEqual(render([[Span("https://nist.gov/NIST", role: .hard)], [Span("NIST")]]),
                       ["https://nist.gov/NIST", "NIST (National Institute of Standards and Technology)"])
    }

    // MARK: source formatting

    func testDatesAreFormattedAsTheWebFormatsThem() {
        XCTAssertEqual(Rules.formatDate("2026"), "2026")
        XCTAssertEqual(Rules.formatDate("2026-09"), "Sep 2026")
        XCTAssertEqual(Rules.formatDate("2026-09-09"), "9 Sep 2026")
        XCTAssertEqual(Rules.formatDate("undated"), "undated")
    }

    /// The web build's cite_edition on the session 10 ledger's cases (ED-09, ED-10, RED-06), and designations that keep
    /// their capital: tools/check_web.py pins the same rulings.
    func testCitationLinesGiveTheEditionByTheRule() {
        let cases: [(String, String, String, String?)] = [
            ("Class Deviation 2024-O0013, Revision 1: Safeguarding Covered Defense Information and Cyber Incident Reporting", "Revision 1", "2024-05-22", nil),
            ("Zero Trust PfMO Newsletter", "November 2024", "2024-11", nil),
            ("NSA Zero Trust Guidance", "Eight cybersecurity information sheets (2021 to 2024) and four implementation guidelines (2026)", "2026-05-28",
             "eight cybersecurity information sheets (2021 to 2024) and four implementation guidelines (2026)"),
            ("The AI Defense Matrix", "None printed (copyright 2026)", "2026", "none printed (copyright 2026)"),
            ("Cyber Operational Readiness Assessment (CORA) program", "Program; no printed edition", "2024-02-28", "program; no printed edition"),
            ("DISA awards Thunderdome production agreement", "Production agreement awarded 28 July 2023; no printed edition", "2023-08-02",
             "production agreement awarded 28 July 2023; no printed edition"),
            ("DoD Zero Trust Strategy", "Version 1.0", "2022-10-21", "Version 1.0"),
            ("Security and Privacy Controls for Information Systems and Organizations", "Revision 5 (includes updates as of 10 December 2020)", "2020-09",
             "Revision 5 (includes updates as of 10 December 2020)"),
            ("Improving the Nation's Cybersecurity", "Executive Order 14028", "2021-05-12", "Executive Order 14028"),
            ("Implementing Suspension of CMMC Phase II (memorandum)", "Acquisition and Sustainment memorandum with Attachment 1, CMMC procedures",
             "2026-07-13", "Acquisition and Sustainment memorandum with Attachment 1, CMMC procedures"),
            ("Removing Barriers to Defense Industrial Base Expansion", "CIO memorandum", "2026-07-13", "CIO memorandum"),
            // a title that carries "Revision 10" does not carry "Revision 1"; a date one day off is not the same date
            ("Guide, Revision 10", "Revision 1", "2024", "Revision 1"),
            ("Letter", "3 May 2024", "2024-05-04", "3 May 2024"),
        ]
        for (title, edition, date, want) in cases {
            XCTAssertEqual(Rules.citeEdition(title: title, edition: edition, date: date), want, edition)
        }
    }

    func testFirstSentenceSplitsAtTheFirstStop() {
        XCTAssertEqual(Rules.firstSentence("One. Two three.").first, "One.")
        XCTAssertEqual(Rules.firstSentence("One. Two three.").rest, "Two three.")
        XCTAssertEqual(Rules.firstSentence("SP 800-207 v1.0 says so").rest, "")
        XCTAssertEqual(Rules.firstSentence("No stop").first, "No stop")
    }

    func testPlainURLsBecomeLinksWithProsePunctuationOutside() {
        let spans = Rules.linkify("Read https://example.gov/a.pdf, then stop.")
        XCTAssertEqual(spans.map(\.text).joined(), "Read https://example.gov/a.pdf, then stop.")
        let links = spans.filter { $0.link != nil }
        XCTAssertEqual(links.map(\.text), ["https://example.gov/a.pdf"])
        XCTAssertEqual(links.first?.link, .external(URL(string: "https://example.gov/a.pdf")!))
        XCTAssertEqual(links.first?.role, .hard)
    }

    func testBadgesSayTheStatusTheCheckAndTheRecheck() throws {
        let store = try ContentStore.bundled()
        let json = #"{"status":"verified","verifiedOn":"2026-09-09","method":"primary-fetch","note":"","recheckAfter":"2026-10-15"}"#
        let v = try Strict.decode(Verification.self, from: Data(json.utf8))
        XCTAssertEqual(Rules.badgeText(v, ui: store.content.ui), "Verified, checked 9 Sep 2026, recheck after 15 Oct 2026")
    }

    func door(_ steps: [String], paragraph: String? = nil) throws -> Door {
        let authored = #"{"status":"authored","verifiedOn":null,"method":"synthesis","basisIds":["x"],"note":""}"#
        let list = steps.enumerated().map { #"{"order":\#($0.offset + 1),"layerId":"\#($0.element)","entityIds":["x"],"text":"t","verification":\#(authored)}"# }
        let para = paragraph.map { "\"\($0)\"" } ?? "null"
        let json = #"{"id":"other","title":"T","whoYouAre":"W.","steps":[\#(list.joined(separator: ","))],"pillarView":null,"paragraph":\#(para),"verification":\#(authored)}"#
        return try Strict.decode(Door.self, from: Data(json.utf8))
    }

    func testTheDoorMetaLineCountsStepsAndListsLayers() throws {
        let order = ["l1": 1, "l2": 2, "l3": 3]
        let L = ["doorMetaSteps": "{n} steps", "doorMetaStep": "1 step", "doorMetaLayers": "layers {list}", "doorMetaLayer": "layer {list}",
                 "metaSeparator": " · ", "listSeparator": ", "]
        // sorted, each layer once, the plural and singular words
        XCTAssertEqual(Rules.doorMeta(try door(["l3", "l1", "l3"]), layerOrder: order, labels: L), "3 steps · layers 1, 3")
        XCTAssertEqual(Rules.doorMeta(try door(["l2"]), layerOrder: order, labels: L), "1 step · layer 2")
        XCTAssertEqual(Rules.doorMeta(try door(["l2", "l2"]), layerOrder: order, labels: L), "2 steps · layer 2")
        // no steps: the paragraph's first sentence
        XCTAssertEqual(Rules.doorMeta(try door([], paragraph: "Nothing binds you. Use the rest."), layerOrder: order, labels: L), "Nothing binds you.")
    }

    func testTheLatestCheckAndTheCountsWalkTheWholeContent() throws {
        let tree: [String: Any] = ["a": ["verification": ["status": "verified", "verifiedOn": "2026-09-01"]],
                                   "b": [["verification": ["status": "conflict", "verifiedOn": "2026-09-20"]]],
                                   "glossary": [["verification": ["status": "verified", "verifiedOn": "2026-12-31"]]]]
        XCTAssertEqual(Rules.latestCheck(tree), "2026-09-20")
        let counts = Rules.verificationCounts(tree)
        XCTAssertEqual(counts[.verified], 2)
        XCTAssertEqual(counts[.conflict], 1)
    }

    func testSlugsMatchTheWebs() {
        XCTAssertEqual(Rules.slug("MIT License"), "mit-license")
        XCTAssertEqual(Rules.slug("ISO/IEC 27001"), "iso-iec-27001")
        XCTAssertEqual(Rules.slug("DoW"), "dow")
    }

    func testLinkTargetsSurviveTheirAddress() throws {
        let targets: [Target] = [.section(.about, anchor: "about-name"), .section(.stack, anchor: nil), .push(.door("dow")),
                                 .push(.layer("l2")), .push(.entity("sp800-207")), .push(.cell(.cisa, "visibility", .DE)),
                                 .glossary("ai"), .anchor("doors"), .external(Site.privacy)]
        for t in targets { XCTAssertEqual(Target(url: try XCTUnwrap(t.url)), t) }
    }
}
