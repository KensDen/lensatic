import SwiftUI
import XCTest
@testable import Lensatic

/// The framework navigator's content model (Lensatic 2.0, Round 1): the files under content/frameworks decode strictly
/// and are the repository's own; every reference resolves, and a broken one fails the load; the three shapes hold (a
/// tree of outcomes with the publisher's text, baselines that select another framework's controls, and techniques that
/// sit under several tactics); every count a screen prints is the structure's own; the crosswalk, the comparison's
/// overlap, the readiness check's result and the countdown are computed from the content; the answers stay in the
/// progress file.
@MainActor
final class FrameworkTests: XCTestCase {
    static let store = try! ContentStore.bundled()
    static let library = try! FrameworkLibrary.bundled(department: store.content.orgs.dow.fields)
    var store: ContentStore { Self.store }
    var lib: FrameworkLibrary { Self.library }

    func day(_ iso: String) -> Date { Calendar.lensatic.date(from: PathPlan.day(iso)!)! }

    func file(_ name: String, in bundle: Bundle = .main) throws -> Data {
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: FrameworkLibrary.folder) else {
            throw FrameworkLibrary.LoadError.missing("\(name).json")
        }
        return try Data(contentsOf: url)
    }

    /// The library with one file's tree edited before it decodes.
    func library(editing name: String, _ edit: (inout [String: Any]) -> Void) throws -> FrameworkLibrary {
        try FrameworkLibrary(department: store.content.orgs.dow.fields) { n in
            let data = try self.file(n)
            guard n == name else { return data }
            var tree = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            edit(&tree)
            return try JSONSerialization.data(withJSONObject: tree)
        }
    }

    // MARK: the files

    func testTheBundledFrameworksDecodeStrictlyAndAreTheRepositoryFiles() throws {
        XCTAssertEqual(lib.frameworks.map(\.id), lib.catalog.frameworks)
        XCTAssertEqual(lib.frameworks.count, 19)
        XCTAssertEqual(Set(lib.frameworks.map(\.id)).count, lib.frameworks.count)
        let repo = Bundle(for: FrameworkTests.self)
        for name in ["catalog"] + lib.catalog.frameworks + lib.catalog.compares + lib.catalog.checks + [lib.catalog.plays].compactMap({ $0 }) {
            XCTAssertEqual(sha256(try file(name)), sha256(try file(name, in: repo)), "\(name).json is the repository's file")
        }
        // every framework the brief names is a card
        for id in ["csf20", "sp800-53", "sp800-207", "dod-zt", "cisa-ztmm", "rmf", "cmmc", "sp800-171", "ai-rmf", "ir8596",
                   "fedramp", "iso27001", "cis", "il", "attack", "d3fend", "aml", "govramp", "cjis"] {
            XCTAssertNotNil(lib.byId[id], id)
        }
        XCTAssertEqual(lib.catalog.lands.map(\.id), ["soc2", "hipaa", "pci-dss"])
        // every group holds a card, and every card's group is in the catalog
        for g in lib.catalog.groups { XCTAssertFalse(lib.frameworks(in: g.id).isEmpty, g.id) }
    }

    func testAnUnknownFieldOrABrokenReferenceFailsTheLoad() throws {
        XCTAssertThrowsError(try library(editing: "csf20") { $0["extra"] = 1 })
        XCTAssertThrowsError(try library(editing: "catalog") { $0["extra"] = 1 })
        XCTAssertThrowsError(try library(editing: "check-csf20") { $0["score"] = 1 })
        XCTAssertThrowsError(try library(editing: "compare-csf20-sp800-53") { $0["strictness"] = "High" }, "a comparison has no field for a score")
        XCTAssertThrowsError(try library(editing: "csf20") { $0["group"] = "nowhere" })
        XCTAssertThrowsError(try library(editing: "csf20") { $0["related"] = [["id": "nothing", "line": "x"]] })
        XCTAssertThrowsError(try library(editing: "fedramp") { f in
            var sets = f["sets"] as! [[String: Any]]
            sets[0]["members"] = ["AC-999"]
            f["sets"] = sets
        }, "a baseline cannot select a control the catalog does not hold")
        XCTAssertThrowsError(try library(editing: "csf20") { f in
            var walks = f["crosswalks"] as! [[String: Any]]
            walks[0]["map"] = ["GV.OC-01": ["ZZ-1"]]
            f["crosswalks"] = walks
        }, "a crosswalk cannot point at a control the catalog does not hold")
        XCTAssertThrowsError(try library(editing: "check-csf20") { c in
            var items = c["items"] as! [[String: Any]]
            items[0]["nodeId"] = "XX.YY"
            c["items"] = items
        })
        XCTAssertThrowsError(try library(editing: "catalog") { c in
            var list = c["frameworks"] as! [String]
            list[0] = "missing"
            c["frameworks"] = list
        })
    }

    func testTheDepartmentsTokensResolveAsTheStacksDo() throws {
        let dod = try XCTUnwrap(lib.byId["dod-zt"])
        XCTAssertTrue(dod.purpose.contains(store.content.orgs.dow.current), dod.purpose)
        for f in lib.frameworks {
            for text in [f.purpose, f.what, f.binds.short, f.binds.line, f.verifiedBy.line, f.sits.line] + f.related.map(\.line) {
                XCTAssertFalse(text.contains("{{"), "\(f.id): \(text)")
            }
        }
        // the title stays as published
        XCTAssertEqual(dod.name, "DoD Zero Trust Strategy")
    }

    // MARK: the three shapes

    /// CSF 2.0: a tree of outcomes with NIST's own identifiers and text.
    func testCSFHoldsItsOutcomes() throws {
        let f = try XCTUnwrap(lib.byId["csf20"]), g = try XCTUnwrap(lib.graphs["csf20"])
        XCTAssertEqual(g.roots.map(\.id), ["GV", "ID", "PR", "DE", "RS", "RC"])
        XCTAssertEqual(f.nodes.filter { $0.level == "category" }.count, 22)
        XCTAssertEqual(f.nodes.filter { $0.level == "subcategory" }.count, 106)
        XCTAssertEqual(f.size.map(\.count), [6, 22, 106])
        XCTAssertEqual(g.children(of: "GV").map(\.id), ["GV.OC", "GV.RM", "GV.RR", "GV.PO", "GV.OV", "GV.SC"])
        XCTAssertEqual(g.children(of: "GV.OC").count, 5)
        XCTAssertEqual(g.descendants(of: "GV").filter { $0.level == "subcategory" }.count, 31)
        XCTAssertEqual(g.node("GV.OC-01")?.text, "The organizational mission is understood and informs cybersecurity risk management")
        XCTAssertEqual(g.top(of: "PR.AA-05"), "PR")
        XCTAssertNil(g.node("ID.BE-01"), "a Subcategory CSF 2.0 withdrew is not shown")
        let depth = try XCTUnwrap(f.depth.value)
        XCTAssertEqual([depth.shown, depth.of], [106, 106])
        XCTAssertEqual(f.terms.shows, .text)
    }

    /// FedRAMP: baselines that select another framework's controls, beside its own indicators.
    func testFedRAMPHoldsBaselinesOnSP80053() throws {
        let f = try XCTUnwrap(lib.byId["fedramp"]), host = try XCTUnwrap(lib.graphs["sp800-53"]), g = try XCTUnwrap(lib.graphs["fedramp"])
        XCTAssertEqual(f.sets.map(\.id), ["rev5-class-b", "rev5-class-c", "rev5-class-d"])
        XCTAssertEqual(f.sets.map(\.members.count), [155, 322, 409])
        for set in f.sets {
            XCTAssertEqual(set.of, "sp800-53")
            XCTAssertTrue(set.members.allSatisfy { host.node($0) != nil })
            XCTAssertEqual(host.grouped(set.members).map(\.nodes.count).reduce(0, +), set.members.count, "every member falls in a family")
            XCTAssertFalse(set.members.contains("CA-5"), "the 2026 rules no longer list CA-5")
        }
        // each class holds the one below it
        XCTAssertTrue(Set(f.sets[0].members).isSubset(of: Set(f.sets[1].members)))
        XCTAssertTrue(Set(f.sets[1].members).isSubset(of: Set(f.sets[2].members)))
        XCTAssertEqual(host.grouped(f.sets[2].members).first?.top.id, "AC")
        XCTAssertEqual(host.grouped(f.sets[2].members).first?.nodes.count, 50)
        XCTAssertEqual(f.nodes.filter { $0.level == "indicator" }.count, 46)
        XCTAssertEqual(f.nodes.filter { $0.level == "theme" }.count, 10)
        XCTAssertEqual(f.nodes.filter { $0.level == "ruleset" }.count, 17)
        XCTAssertEqual(g.node("KSI-CNA-EIS")?.note, "Optional for Class B.")
        XCTAssertEqual(f.crosswalks.first?.map["KSI-IAM-AAM"]?.contains("AC-2(2)"), true)
        // a control knows the baselines that select it, in its own file and in FedRAMP's
        let in2 = Set(lib.memberships(of: "AC-2", in: "sp800-53").map { "\($0.framework.id):\($0.set.id)" })
        XCTAssertTrue(in2.isSuperset(of: ["sp800-53:low", "sp800-53:moderate", "sp800-53:high", "fedramp:rev5-class-b", "fedramp:rev5-class-c", "fedramp:rev5-class-d"]), "\(in2)")
        XCTAssertTrue(lib.memberships(of: "CA-5", in: "sp800-53").allSatisfy { $0.framework.id == "sp800-53" })
    }

    /// ATT&CK: techniques that sit under more than one tactic, and a subset that says so.
    func testATTACKHoldsTechniquesUnderSeveralTactics() throws {
        let f = try XCTUnwrap(lib.byId["attack"]), g = try XCTUnwrap(lib.graphs["attack"])
        XCTAssertFalse(f.compliance)
        XCTAssertEqual(g.roots.count, 15)
        XCTAssertEqual(g.roots.first?.id, "TA0043")
        XCTAssertEqual(f.nodes.filter { $0.level == "technique" }.count, 227)
        let shared = f.nodes.filter { $0.parents.count > 1 }
        XCTAssertFalse(shared.isEmpty)
        let one = try XCTUnwrap(shared.first)
        for tactic in one.parents { XCTAssertTrue(g.children(of: tactic).contains { $0.id == one.id }, "\(one.id) shows under \(tactic)") }
        XCTAssertNil(g.roots.first { $0.title == "Defense Evasion" }, "ATT&CK split Defense Evasion in v19")
        let depth = try XCTUnwrap(f.depth.value)
        // Round 2: the sub-techniques are listed too, each under the technique whose identifier it extends
        XCTAssertEqual(f.nodes.filter { $0.level == "subtechnique" }.count, 479)
        XCTAssertEqual(g.node("T1059.001")?.parents, ["T1059"])
        XCTAssertEqual(depth.shown, 227 + 479)
        XCTAssertEqual(depth.of, 227 + 479)
        XCTAssertEqual(f.terms.basis, .mitre)
        XCTAssertTrue(try XCTUnwrap(f.terms.notice.value).contains("reproduced and distributed with the permission of The MITRE Corporation"))
        XCTAssertTrue(f.nodes.allSatisfy { $0.text == nil }, "names only")
    }

    func testSP80053HoldsTheCatalogByTitle() throws {
        let f = try XCTUnwrap(lib.byId["sp800-53"]), g = try XCTUnwrap(lib.graphs["sp800-53"])
        XCTAssertEqual(g.roots.count, 20)
        XCTAssertEqual(f.nodes.filter { $0.level == "control" }.count, 300)
        XCTAssertEqual(f.nodes.filter { $0.level == "enhancement" }.count, 714)
        XCTAssertEqual(f.sets.map(\.members.count), [149, 287, 370, 96])
        XCTAssertEqual(g.node("AC-2(1)")?.title, "Automated System Account Management")
        XCTAssertEqual(g.node("AC-2(1)")?.parents, ["AC-2"])
        XCTAssertEqual(g.top(of: "AC-2(1)"), "AC")
        XCTAssertNotNil(g.node("SA-24"), "release 5.2.0")
        XCTAssertNil(g.node("RA-4"), "a withdrawn control is not listed")
        XCTAssertTrue(f.nodes.allSatisfy { $0.text == nil })
        XCTAssertFalse(f.nodes.contains { ($0.title ?? "").contains("\u{2014}") })
    }

    /// The licensed and copyrighted frameworks show structure only: no node, and nothing of the publisher's text.
    func testLicensedFrameworksShowStructureOnly() throws {
        for id in ["iso27001", "cis", "govramp"] {
            let f = try XCTUnwrap(lib.byId[id])
            XCTAssertEqual(f.terms.shows, .structure, id)
            XCTAssertTrue(f.nodes.isEmpty, id)
            XCTAssertNil(f.depth.value, id)
            XCTAssertFalse(f.sources.isEmpty, id)
        }
        XCTAssertEqual(lib.byId["iso27001"]?.terms.basis, .copyrighted)
        XCTAssertEqual(lib.byId["cis"]?.terms.basis, .licensed)
        XCTAssertNotNil(lib.byId["cis"]?.terms.notice.value)
    }

    /// Sources on everything: a framework has a source of its own or a stack entry that carries one, and each source
    /// has its publisher, edition, date, link and the day it was checked.
    func testEveryFrameworkCarriesItsSources() throws {
        for f in lib.frameworks {
            XCTAssertTrue(!f.sources.isEmpty || f.entityId.flatMap { store.entities[$0] } != nil, f.id)
            if let e = f.entityId { XCTAssertNotNil(store.entities[e], "\(f.id) names the stack entry \(e)") }
            for s in f.sources {
                XCTAssertNotNil(URL(string: s.url), s.id)
                XCTAssertFalse(s.publisher.isEmpty || s.edition.isEmpty || s.date.isEmpty || s.verification.note.isEmpty, s.id)
                if s.verification.status != .unverified { XCTAssertNotNil(s.verification.verifiedOn, s.id) }
            }
            for l in f.sits.layers { XCTAssertNotNil(store.layers[l], "\(f.id): \(l)") }
        }
        for land in lib.catalog.lands { XCTAssertNotNil(land.source.verification.verifiedOn, land.id) }
    }

    // MARK: connections

    func testTheCrosswalkIsNISTsAndSaysWhatItCannotResolve() throws {
        let f = try XCTUnwrap(lib.byId["csf20"]), walk = try XCTUnwrap(f.crosswalks.first), host = try XCTUnwrap(lib.graphs["sp800-53"])
        XCTAssertEqual(walk.to, "sp800-53")
        XCTAssertEqual(walk.map.count, 106, "every Subcategory carries a reference")
        XCTAssertEqual(Array((walk.map["PR.AA-01"] ?? []).prefix(3)), ["AC-1", "AC-2", "AC-14"])
        XCTAssertEqual(walk.unresolved, ["RA-4"])
        XCTAssertEqual(walk.map["DE.AE-06"]?.contains("RA-4"), true)
        let targets = Set(walk.map.values.flatMap { $0 })
        XCTAssertEqual(targets.filter { host.node($0) == nil }, ["RA-4"])
        // and back: a control knows the outcomes that point at it
        let back = lib.referrers(to: "AC-2", in: "sp800-53")
        XCTAssertEqual(back.map(\.framework.id).sorted(), ["csf20", "fedramp", "sp800-171"])
        XCTAssertTrue(try XCTUnwrap(back.first { $0.framework.id == "csf20" }).nodes.contains("PR.AA-01"))
    }

    func testTheComparisonCountsItsOverlapFromTheCrosswalk() throws {
        let c = try XCTUnwrap(lib.comparison("compare-csf20-sp800-53"))
        let o = try XCTUnwrap(lib.overlap(c))
        XCTAssertEqual(o.from.id, "csf20")
        XCTAssertEqual(o.to.id, "sp800-53")
        XCTAssertEqual(o.rows.map(\.node.id), ["GV", "ID", "PR", "DE", "RS", "RC"])
        XCTAssertEqual(o.rows.map(\.leaves), [31, 21, 22, 11, 13, 8])
        XCTAssertEqual(o.rows.map(\.linked), o.rows.map(\.leaves), "NIST references every Subcategory")
        XCTAssertEqual(o.of, 1014)
        XCTAssertEqual(o.reached, 209, "213 distinct references: one is the withdrawn RA-4 and three name a whole family")
        XCTAssertTrue(o.rows.allSatisfy { !$0.leading.isEmpty && $0.leading.count <= 3 })
        XCTAssertFalse(c.rows.contains { $0.label.lowercased().contains("strict") })
        XCTAssertEqual(lib.comparisons(with: "csf20").map(\.id), [c.id, "compare-csf20-iso27001"])
        XCTAssertEqual(CompareView.reachedLine(o, labels: lib), "In all, the references reach 209 of the 1,014 controls and enhancements in SP 800-53.")
    }

    // MARK: the readiness check

    func testTheCheckEndsInAShortListOfWhatToDoNext() throws {
        let check = try XCTUnwrap(lib.check(for: "csf20"))
        XCTAssertEqual(check.items.count, 22)
        XCTAssertEqual(check.items.map(\.nodeId), lib.byId["csf20"]?.nodes.filter { $0.level == "category" }.map(\.id), "one question for each Category, in the Core's order")
        XCTAssertTrue(check.honest.contains("not an assessment"))
        XCTAssertEqual(check.result([:]), .init(answered: 0, total: 22, counts: [:], next: []))
        // the lowest answers come first, each in the check's order; an item in place needs no step
        let given = ["GV.OC": "yes", "GV.RM": "partly", "GV.RR": "no", "ID.AM": "no", "PR.AA": "partly", "RC.CO": "no", "DE.CM": "bogus"]
        let r = check.result(given)
        XCTAssertEqual(r.answered, 6, "an answer the check does not have is not counted")
        XCTAssertEqual(r.counts, ["yes": 1, "partly": 2, "no": 3])
        XCTAssertEqual(r.next.map(\.id), ["GV.RR", "ID.AM", "RC.CO", "GV.RM", "PR.AA"])
        XCTAssertFalse(r.isComplete)
        let all = Dictionary(uniqueKeysWithValues: check.items.map { ($0.id, "yes") })
        XCTAssertTrue(check.result(all).isComplete)
        XCTAssertTrue(check.result(all).next.isEmpty)
        let none = Dictionary(uniqueKeysWithValues: check.items.map { ($0.id, "no") })
        XCTAssertEqual(check.result(none).next.count, check.nextCount)
        XCTAssertEqual(check.result(none).next.first?.id, "GV.OC", "Govern first")
    }

    func testTheAnswersStayInTheProgressFile() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lensatic-tests-\(UUID().uuidString)").appendingPathComponent("progress.json")
        let p = ProgressStore(url: url)
        p.answer("check-csf20", "GV.OC", "yes")
        p.answer("check-csf20", "GV.RM", "no")
        p.answer("check-csf20", "GV.RM", "partly")
        XCTAssertEqual(ProgressStore(url: url).answers("check-csf20"), ["GV.OC": "yes", "GV.RM": "partly"])
        p.answer("check-csf20", "GV.OC", "yes")
        XCTAssertEqual(ProgressStore(url: url).answers("check-csf20"), ["GV.RM": "partly"], "the same answer again takes it back")
        p.clearAnswers("check-csf20")
        XCTAssertTrue(ProgressStore(url: url).answers("check-csf20").isEmpty)
        // a file from before the checks reads with none, and keeps everything else
        let old = ProgressStore.state(from: Data(#"{"door":"dow","checked":{"dow":[1]},"saved":["entity:csf20"]}"#.utf8))
        XCTAssertTrue(old.readiness.isEmpty)
        XCTAssertEqual(old.saved, ["entity:csf20"])
    }

    // MARK: the countdown

    func testTheCountdownIsTheNextDatedZeroTrustDeadline() throws {
        let c = try XCTUnwrap(lib.zeroTrustCountdown(store: store, today: day("2026-11-14")))
        XCTAssertEqual(c.frameworkId, "dod-zt")
        XCTAssertEqual(c.date, "2027-09-30")
        XCTAssertEqual(c.days(from: day("2026-11-14")), 320)
        XCTAssertEqual(c.label, "Target Level zero trust")
        XCTAssertFalse(c.binds.isEmpty)
        XCTAssertEqual(lib.zeroTrustCountdown(store: store, today: day("2027-09-30"))?.days(from: day("2027-09-30")), 0)
        XCTAssertNil(lib.zeroTrustCountdown(store: store, today: day("2027-10-01")), "a deadline that has passed is not counted down to")
        // the widget's own countdown, before a trailhead is picked, is the same day
        let g = Glance(store: store, state: .init(), today: day("2026-11-14"))
        XCTAssertNil(g.door)
        XCTAssertEqual(g.countdown?.days, 320)
        XCTAssertEqual(g.voiceOver, "Lensatic. 320 days to Target Level. Pick a trailhead to start your path.")
        XCTAssertNil(Glance(store: store, state: .init(), today: day("2027-10-01")).countdown)
        // a trailhead the deadline does not bind still shows none
        XCTAssertNil(Glance(store: store, state: .init(door: "federal-civilian"), today: day("2026-11-14")).countdown)
    }

    func testAFrameworkCardCountsDownToItsOwnNextDeadline() throws {
        let fed = try XCTUnwrap(lib.byId["fedramp"])
        XCTAssertEqual(lib.deadlines(fed, store: store).map(\.date), ["2027-01-01", "2027-06-11", "2028-02-01"])
        XCTAssertEqual(lib.deadlines(fed, store: store).first?.binds, "Cloud providers", "the card's own words say whom the first date binds")
        XCTAssertEqual(lib.upcoming(fed, store: store, today: day("2026-11-14"))?.days(from: day("2026-11-14")), 48)
        XCTAssertEqual(lib.upcoming(fed, store: store, today: day("2027-01-02"))?.date, "2027-06-11")
        XCTAssertNil(lib.upcoming(fed, store: store, today: day("2028-02-02")))
        XCTAssertEqual(lib.upcoming(try XCTUnwrap(lib.byId["cjis"]), store: store, today: day("2026-11-14"))?.date, "2027-09-30")
        // a card with no dated deadline shows none; the cards that do are the ones the content dates
        let dated = lib.frameworks.filter { lib.upcoming($0, store: store, today: day("2026-11-14")) != nil }.map(\.id)
        XCTAssertEqual(dated, ["dod-zt", "fedramp", "cjis"])
        XCTAssertEqual(CountdownDial.share(0), 0)
        XCTAssertEqual(CountdownDial.share(365), 0.5)
        XCTAssertEqual(CountdownDial.share(2000), 1)
    }

    // MARK: what the screens say

    func testEveryLabelTheScreensReadIsInTheCatalog() {
        for key in ["layers", "adversaryColumn", "aiShort", "adversaryShort", "dueToday", "day", "days", "binds", "verified", "size", "sits", "browse",
                    "compare", "with", "landsTitle", "landsLine", "landsOn", "compareIntro", "compareMore", "sources", "openSource", "openPDF",
                    "terms", "openTerms", "notCompliance", "countdown", "countdownHint", "atAGlance", "structure", "shownOf", "baselines",
                    "baselinesOn", "baseline", "baselineCount", "useIt", "checkYourself", "compareWith", "connects", "onTheMap", "onTheMapLine",
                    "notInCatalog", "inBaselines", "referencedBy", "sideBySide", "howTheyConnect", "whereTheyOverlap", "noScoreTitle", "openEach",
                    "reached", "overlapRow", "mostIn", "answered", "whereYouStand", "doNext", "checkStart", "checkFinish", "checkAllInPlace", "cardOnly", "textAtSource", "landsEyebrow", "selfCheck", "nextAtEnd", "inFieldGuide", "jump",
                    "checkNotAssessment", "startOver", "checkKept", "homeFrameworksTitle", "homeFrameworksLine", "homeCheck",
                    // Round 3: the plays' links, a saved element's screen and the two-pane screen
                    "playsIn", "playsInLine", "playsThatTouch", "playsOn", "playsOnLine", "wholeFramework", "element", "elementsWord",
                    "storyAll", "storyStart", "showElements", "hideElements", "spelledOut", "openIt"] {
            XCTAssertNotNil(lib.catalog.labels[key], key)
        }
    }

    func testACardSaysWhereItSitsAndReadsAsOneSentence() throws {
        let model = AppModel(store: store, library: try Library.bundled(), progress: ProgressStore(url: nil), frameworks: lib)
        XCTAssertEqual(model.sitsLabel(try XCTUnwrap(lib.byId["csf20"])), "Layer 1, Outcomes")
        XCTAssertEqual(model.sitsLabel(try XCTUnwrap(lib.byId["iso27001"])), "Layers 1, 4 and 5")
        XCTAssertEqual(model.sitsLabel(try XCTUnwrap(lib.byId["ai-rmf"])), "AI column")
        XCTAssertEqual(model.sitsLabel(try XCTUnwrap(lib.byId["attack"])), "Adversary column")
        // the knowledge base of attacks on AI systems sits in both columns: the AI column's threats, in the adversary column
        XCTAssertEqual(model.sitsLabel(try XCTUnwrap(lib.byId["aml"])), "AI column, Adversary column")
        XCTAssertEqual(lib.byId["aml"]?.shortName, "ATLAS")
        XCTAssertEqual(model.sitsShort(try XCTUnwrap(lib.byId["iso27001"])), "L1 L4 L5")
        let csf = try XCTUnwrap(lib.byId["csf20"])
        XCTAssertEqual(FrameworkCard.sizeShort(csf), "106 Subcategories")
        XCTAssertEqual(FrameworkCard.sizeShort(try XCTUnwrap(lib.byId["sp800-53"])), "1,014 controls and enhancements")
        // a page that stops at the card says so at the top, and one whose numbers surprise says why
        XCTAssertTrue(try XCTUnwrap(lib.byId["iso27001"]?.note).contains("37 organizational, 8 people, 14 physical and 34 technological"))
        XCTAssertTrue(try XCTUnwrap(lib.byId["fedramp"]?.note).contains("was a 3PAO"))
        XCTAssertEqual(lib.byId["fedramp"]?.sets.first?.line, "One fewer than the 156 of the legacy Low and LI-SaaS baselines: the 2026 rules no longer list CA-5.")
        XCTAssertEqual(lib.catalog.featured, ["fedramp", "iso27001", "cis", "cmmc", "attack"])
        XCTAssertNotNil(model.library.guide.chapter(try XCTUnwrap(lib.byId["dod-zt"]?.chapterId)))
        let spoken = FrameworkCard.spoken(csf, model: model, deadline: nil, days: nil)
        XCTAssertTrue(spoken.hasPrefix("CSF 2.0, Outcomes. "), spoken)
        XCTAssertTrue(spoken.contains("Binds: Voluntary. Assessment: Self-described. Size: 6 Functions, 22 Categories, 106 Subcategories. Layer 1, Outcomes."), spoken)
        XCTAssertFalse(spoken.contains(".."), spoken)
        XCTAssertEqual(Rules.grouped(1014), "1,014")
        XCTAssertEqual(Rules.grouped(106), "106")
        XCTAssertEqual(FrameworkDetailView.depthLine(try XCTUnwrap(csf.depth.value), labels: lib), "Lensatic shows 106 of 106 Subcategories.")
        let fed = try XCTUnwrap(lib.byId["fedramp"])
        XCTAssertEqual(BaselineView.countLine(fed.sets[2], host: try XCTUnwrap(lib.byId["sp800-53"]), graph: try XCTUnwrap(lib.graphs[try XCTUnwrap(lib.byId["sp800-53"]).id]), labels: lib),
                       "409 of the 1,014 controls and enhancements in SP 800-53")
        let d = try XCTUnwrap(lib.zeroTrustCountdown(store: store, today: day("2026-11-14")))
        XCTAssertTrue(CountdownCard.spoken(d, days: 320, labels: lib).hasPrefix("320 days: Target Level zero trust, 30 Sep 2027, "))
        XCTAssertEqual(CountdownCard.count(1, labels: lib), "1 day")
        XCTAssertEqual(CountdownCard.count(0, labels: lib), "Due today")
        // Home's countdown opens the framework that sets it
        XCTAssertEqual(model.zeroTrustCountdown(today: day("2026-11-14"))?.frameworkId, "dod-zt")
    }

    /// Search finds the frameworks the navigator adds and the standards it places, and each opens its own screen; a
    /// framework the stack already has is still found once, as its entry.
    func testSearchFindsTheNewFrameworks() throws {
        let index = SearchIndex(store: store, library: try Library.bundled(), door: nil, labels: .init(), frameworks: lib)
        func first(_ q: String) -> SearchIndex.Opens? { index.search(q).first?.results.first?.opens }
        // FedRAMP joined the stack in content 1.4.0, so it is found as its entry, whose card leads to the framework
        XCTAssertEqual(first("FedRAMP"), .nav(.entity("fedramp")))
        XCTAssertEqual(first("ISO 27001"), .nav(.framework("iso27001")))
        XCTAssertEqual(first("ATT&CK"), .nav(.framework("attack")))
        XCTAssertEqual(first("CJIS"), .nav(.framework("cjis")))
        XCTAssertEqual(first("SOC 2"), .nav(.landing("soc2")))
        XCTAssertEqual(first("PCI DSS"), .nav(.landing("pci-dss")))
        // the words a reader still uses lead to the framework that replaced them
        XCTAssertEqual(first("3PAO"), .nav(.entity("fedramp")))
        XCTAssertEqual(first("POA&M"), .nav(.entity("fedramp")))
        XCTAssertEqual(first("27002"), .nav(.framework("iso27001")))
        XCTAssertEqual(first("Statement of Applicability"), .nav(.framework("iso27001")))
        XCTAssertEqual(first("CSF 2.0"), .nav(.entity("csf20")))
        XCTAssertEqual(index.items.filter { $0.id.hasPrefix("framework:") }.count, lib.frameworks.filter { $0.entityId == nil }.count)
        let top = FrameworkDetailView.topLevels(try XCTUnwrap(lib.byId["fedramp"]), try XCTUnwrap(lib.graphs["fedramp"]))
        XCTAssertEqual(top.map(\.level.id), ["theme", "ruleset"], "the indicators' themes lead; the rulesets follow")
        XCTAssertEqual(top.map(\.nodes.count), [10, 17])
    }

    func testTheNewScreensHaveAddressesAndTheFrameworksTabIsSecond() {
        XCTAssertEqual(AppTab.allCases, [.home, .frameworks, .path, .explore, .search])
        for nav in [Nav.framework("csf20"), .node("sp800-53", "AC-2(1)"), .node("csf20", "GV.OC-01"), .baseline("fedramp", "rev5-class-d"),
                    .compare("compare-csf20-sp800-53"), .check("check-csf20"), .landing("soc2")] {
            XCTAssertEqual(Nav(pathParts: nav.pathParts), nav)
            XCTAssertEqual(nav.home, .frameworks)
        }
        let model = AppModel(store: store, library: try! Library.bundled(), progress: ProgressStore(url: nil), frameworks: lib)
        model.showFrameworks(.compare)
        XCTAssertEqual(model.tab, .frameworks)
        XCTAssertEqual(model.frameworksMode, .compare)
        model.show(.check("check-csf20"))
        XCTAssertEqual(model.paths[.frameworks], [.check("check-csf20")])
    }

    // MARK: Round 2: depth, and the routes in

    func testTheNewStructuresHoldWhatTheirPublishersCount() throws {
        func count(_ id: String, _ level: String) -> Int { lib.byId[id]?.nodes.filter { $0.level == level }.count ?? -1 }
        // SP 800-171: both editions, each under its own heading, with identifiers as each edition prints them
        let g171 = try XCTUnwrap(lib.graphs["sp800-171"])
        XCTAssertEqual(g171.roots.map(\.title), ["Revision 2", "Revision 3"])
        XCTAssertFalse(g171.identified(try XCTUnwrap(g171.roots.first)), "a revision has no identifier of its own")
        XCTAssertEqual(g171.descendants(of: "rev2").filter { $0.level == "requirement" }.count, 110)
        XCTAssertEqual(g171.descendants(of: "rev3").filter { $0.level == "requirement" }.count, 97)
        XCTAssertEqual(g171.node("03.01.01")?.title, "Account Management")
        XCTAssertNil(g171.node("03.01.13"), "a withdrawn number is not listed")
        XCTAssertNil(g171.node("3.1.1")?.title, "Revision 2 gives a requirement a statement and no title")
        XCTAssertTrue(try XCTUnwrap(g171.node("03.09.02")?.text).contains("terminated: 1. Disable system access"), "a numbered part reads as the publication prints it, not as the data file numbers it")
        // CMMC: the two levels the rule states itself, and Level 2 as a set on SP 800-171 Revision 2
        let cmmc = try XCTUnwrap(lib.byId["cmmc"]), gc = try XCTUnwrap(lib.graphs["cmmc"])
        XCTAssertEqual(gc.descendants(of: "level-1").filter { $0.level == "requirement" }.count, 15)
        XCTAssertEqual(gc.descendants(of: "level-3").filter { $0.level == "requirement" }.count, 24)
        let two = try XCTUnwrap(cmmc.sets.first { $0.id == "level-2" })
        XCTAssertEqual(two.members.count, 110)
        XCTAssertEqual(BaselineView.countLine(two, host: try XCTUnwrap(lib.byId["sp800-171"]), graph: g171, labels: lib),
                       "110 of the 110 requirements in SP 800-171 Revision 2")
        XCTAssertEqual(cmmc.crosswalks.first?.map["PE.L1-b.1.ix"], ["3.10.3", "3.10.4", "3.10.5"], "one requirement is three in SP 800-171's numbering")
        // the RMF, the AI RMF, the CISA model and the department's activities
        XCTAssertEqual([count("rmf", "step"), count("rmf", "task")], [7, 47])
        XCTAssertEqual(lib.graphs["rmf"]?.node("R-5")?.parents, ["authorize"])
        XCTAssertEqual(lib.graphs["ai-rmf"]?.roots.map(\.id), ["GOVERN", "MAP", "MEASURE", "MANAGE"], "the publication's order, not the alphabet's")
        XCTAssertEqual([count("ai-rmf", "category"), count("ai-rmf", "subcategory")], [19, 72])
        XCTAssertEqual([count("cisa-ztmm", "pillar"), count("cisa-ztmm", "stage")], [5, 160])
        let gz = try XCTUnwrap(lib.graphs["cisa-ztmm"])
        XCTAssertEqual(gz.children(of: "identity.authentication").map(\.title), ["Traditional", "Initial", "Advanced", "Optimal"])
        XCTAssertEqual(gz.name(try XCTUnwrap(gz.node("identity.authentication"))), "Authentication", "CISA numbers nothing, so no identifier is shown")
        let zt = try XCTUnwrap(lib.byId["dod-zt"])
        XCTAssertEqual([count("dod-zt", "pillar"), count("dod-zt", "capability"), count("dod-zt", "activity")], [7, 45, 152])
        XCTAssertEqual(zt.sets.map(\.members.count), [91, 61])
        XCTAssertEqual(lib.graphs["dod-zt"]?.roots.map(\.title).last, "Visibility and Analytics", "as the department's own table prints it")
        // the adversary column: all three knowledge bases by identifier and name, each with its notice
        XCTAssertEqual(count("d3fend", "technique"), 271)
        XCTAssertEqual(lib.byId["d3fend"]?.depth.value?.of, 272)
        XCTAssertEqual([count("aml", "tactic"), count("aml", "technique"), count("aml", "subtechnique")], [16, 129, 92])
        for id in ["attack", "d3fend", "aml"] { XCTAssertNotNil(lib.byId[id]?.terms.notice.value, "\(id) carries its publisher's notice") }
    }

    func testAnyTwoCardsCompareAndOnlyAPublishedCrosswalkIsCounted() throws {
        XCTAssertEqual(lib.compares.count, 5)
        XCTAssertEqual(lib.named("sp800-53", "csf20")?.id, "compare-csf20-sp800-53", "a named comparison is found in either order")
        XCTAssertNil(lib.named("cjis", "attack"))
        // no publisher prints a crosswalk between these two, so nothing is counted
        XCTAssertNil(lib.overlap("fedramp", "govramp"))
        XCTAssertNil(lib.overlap("cjis", "attack"))
        // NIST's references to a standard Lensatic does not list: identifiers are counted, and nothing of ISO's is shown
        let iso = try XCTUnwrap(lib.overlap("iso27001", "csf20"))
        XCTAssertEqual(iso.from.id, "csf20")
        XCTAssertFalse(iso.crosswalk.isListed)
        XCTAssertEqual(iso.of, 0)
        XCTAssertEqual(CompareView.reachedLine(iso, labels: lib), "In all, the references name \(iso.reached) identifiers of ISO/IEC 27001. Lensatic does not list that standard\u{2019}s elements.")
        XCTAssertTrue(try XCTUnwrap(lib.byId["iso27001"]).nodes.isEmpty)
        XCTAssertTrue(Set(iso.crosswalk.map.values.flatMap { $0 }).allSatisfy { $0.hasPrefix("Clause ") || $0.hasPrefix("Annex A ") })
        // SP 800-171 Revision 3 names its source controls; only Revision 3's requirements are counted
        let o = try XCTUnwrap(lib.overlap("sp800-171", "sp800-53"))
        XCTAssertEqual(o.rows.map(\.node.id), ["rev3"])
        XCTAssertEqual(o.rows.first?.leaves, 97)
        XCTAssertEqual(o.unit, "Requirements")
        // two parts of one framework: how much of each Rev5 baseline the indicators name
        let fed = try XCTUnwrap(lib.byId["fedramp"])
        let sets = lib.setOverlap(fed)
        XCTAssertEqual(sets.map(\.selection.id), ["rev5-class-b", "rev5-class-c", "rev5-class-d"])
        XCTAssertTrue(sets.allSatisfy { $0.named > 0 && $0.named <= $0.selection.members.count })
        let same = try XCTUnwrap(lib.comparison("compare-fedramp-20x-rev5"))
        XCTAssertEqual([same.a, same.b, same.aName, same.bName], ["fedramp", "fedramp", "FedRAMP 20x", "FedRAMP Rev5"])
        // no comparison has a field a score could go in, and none uses the word
        for c in lib.compares { XCTAssertFalse((c.rows.map(\.label) + [c.verdict]).contains { $0.lowercased().contains("score") }, c.id) }
    }

    func testEachTrailheadHasItsReadinessCheck() throws {
        XCTAssertEqual(lib.checks.map(\.id), ["check-csf20", "check-fedramp", "check-cmmc-l1", "check-dod-zt"])
        XCTAssertEqual(lib.checks(for: .cloudProvider).map(\.id), ["check-fedramp"])
        XCTAssertEqual(lib.checks(for: .defenseContractor).map(\.id), ["check-cmmc-l1"])
        XCTAssertEqual(lib.checks(for: .dow).map(\.id), ["check-dod-zt"])
        XCTAssertTrue(lib.checks(for: .stateLocal).isEmpty)
        let l1 = try XCTUnwrap(lib.check("check-cmmc-l1")), gc = try XCTUnwrap(lib.graphs["cmmc"])
        XCTAssertEqual(l1.items.count, 15)
        let groups = ReadinessView.groups(l1, gc)
        XCTAssertEqual(groups.compactMap { $0.node?.title }, ["Access Control (AC)", "Identification and Authentication (IA)", "Media Protection (MP)",
                                                             "Physical Protection (PE)", "System and Communications Protection (SC)", "System and Information Integrity (SI)"])
        XCTAssertEqual(groups.map(\.items.count), [4, 2, 1, 2, 2, 4])
        let zt = try XCTUnwrap(lib.check("check-dod-zt")), gz = try XCTUnwrap(lib.graphs["dod-zt"])
        XCTAssertEqual(zt.items.map(\.nodeId), ["1", "2", "3", "4", "5", "6", "7"])
        XCTAssertEqual(ReadinessView.groups(zt, gz).count, 1, "seven questions stand in one group")
        XCTAssertTrue(try XCTUnwrap(zt.items.first).question.contains("13 Target Level activities of the User pillar"))
        for c in lib.checks { XCTAssertTrue(c.honest.contains("stay on this device"), c.id) }
    }

    func testSearchFindsAnElementByItsIdentifier() throws {
        let index = SearchIndex(store: store, library: try Library.bundled(), door: nil, labels: .init(), frameworks: lib)
        func elements(_ q: String) -> [SearchIndex.Opens] { index.search(q).first { $0.kind == .element }?.results.map(\.opens) ?? [] }
        XCTAssertEqual(Array(elements("AC-2").prefix(2)), [.nav(.node("sp800-53", "AC-2")), .nav(.node("sp800-53", "AC-2(1)"))])
        XCTAssertEqual(elements("pr.aa-01"), [.nav(.node("csf20", "PR.AA-01"))])
        XCTAssertEqual(elements("T1059.001"), [.nav(.node("attack", "T1059.001"))])
        XCTAssertEqual(elements("03.01.01").first, .nav(.node("sp800-171", "03.01.01")))
        XCTAssertEqual(elements("KSI-IAM").first, .nav(.node("fedramp", "KSI-IAM")))
        XCTAssertTrue(elements("zero trust").isEmpty)
        // an identifier's own element leads the results; a word that only begins identifiers does not push the rest down
        XCTAssertEqual(index.search("AC-2").first?.kind, .element)
        XCTAssertNotEqual(index.search("KSI").first?.kind, .element)
        XCTAssertLessThanOrEqual(elements("AC").count, 1, "two letters find the identifier itself, not everything it begins")
        // a short word matches a whole word or the start of one, never the inside of a longer word
        let file = SearchIndex.Item(kind: .term, id: "x", title: "A file profile", subtitle: "", aliases: [], body: "", opens: .glossary("x"))
        XCTAssertNil(SearchIndex.score(file, words: ["il"], phrase: "il"))
        XCTAssertNotNil(SearchIndex.score(file, words: ["fil"], phrase: "fil"))
        XCTAssertNotNil(SearchIndex.score(file, words: ["rofile"], phrase: "rofile"), "a longer word still matches inside one")
    }

    func testTheStackAndTheFrameworksTabAreOneMap() throws {
        let model = AppModel(store: store, library: try Library.bundled(), progress: ProgressStore(url: nil), frameworks: lib)
        for layer in store.content.layers {
            let cards = lib.frameworks(onLayer: layer.id)
            XCTAssertFalse(cards.isEmpty, "\(layer.id) holds a card")
            for f in cards { XCTAssertTrue(model.sitsLabel(f).contains(layer.isColumn ? layer.name : "\(layer.order)"), "\(f.id) says it sits on \(layer.id)") }
        }
        // a card that is a stack entry's own sits on that entry's layer, so the two tabs cannot disagree
        for f in lib.frameworks {
            guard let e = f.entityId.flatMap({ store.entities[$0] }), let layer = e.layerId else { continue }
            XCTAssertTrue(f.sits.layers.contains(layer), "\(f.id) sits on \(f.sits.layers), its entry on \(layer)")
        }
        XCTAssertEqual(lib.adversary.map(\.id), ["attack", "d3fend", "aml"])
        XCTAssertEqual(lib.framework(forEntity: "fedramp")?.id, "fedramp")
        XCTAssertEqual(lib.frameworks(onLayer: "l5").map(\.id).contains("fedramp"), true)
        // a framework is saved, described and opened by its own key
        let item = try XCTUnwrap(SavedItem(key: "framework:iso27001"))
        XCTAssertEqual(item, .framework("iso27001"))
        XCTAssertTrue(model.exists(item))
        XCTAssertEqual(model.describe(item)?.title, "ISO/IEC 27001:2022")
        XCTAssertFalse(model.exists(.framework("nope")))
        XCTAssertTrue(model.openSpotlight("framework:iso27001"))
        XCTAssertEqual(model.tab, .frameworks)
        XCTAssertEqual(model.paths[.frameworks], [.framework("iso27001")])
        XCTAssertEqual(Nav(pathParts: ["pair", "fedramp", "govramp"]), .pair("fedramp", "govramp"))
        XCTAssertEqual(Nav.group("adversary").pathParts, ["group", "adversary"])
    }

    func testTheSixthTrailheadCountsDownToFedRAMPsRules() throws {
        let door = try XCTUnwrap(store.content.doors.first { $0.id == .cloudProvider })
        XCTAssertEqual(door.steps.count, 7)
        XCTAssertEqual(Door.ID.welcomeOrder.count, store.content.doors.count)
        let plan = PathPlan(door: door, entities: store.entities)
        XCTAssertEqual(plan.deadlines.map(\.due.date), ["2027-01-01"])
        XCTAssertEqual(plan.upcoming(today: day("2026-11-14")).flatMap { PathPlan.days(from: day("2026-11-14"), to: $0.day) }, 48)
        // the card's dates and the entry's date are one list, none twice
        let fed = try XCTUnwrap(lib.byId["fedramp"])
        XCTAssertEqual(lib.deadlines(fed, store: store).map(\.date), ["2027-01-01", "2027-06-11", "2028-02-01"])
        // the contractor's path is not bound by it
        XCTAssertTrue(PathPlan(door: try XCTUnwrap(store.content.doors.first { $0.id == .defenseContractor }), entities: store.entities).deadlines.isEmpty)
    }

    func testTheCompactListIsKeptWithTheProgress() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lensatic-tests-\(UUID().uuidString)").appendingPathComponent("progress.json")
        let p = ProgressStore(url: url)
        XCTAssertFalse(p.frameworksCompact)
        p.setFrameworksCompact(true)
        XCTAssertTrue(ProgressStore(url: url).frameworksCompact)
        // a file from before Round 2 reads as cards
        XCTAssertFalse(ProgressStore.state(from: Data(#"{"door":"dow"}"#.utf8)).frameworksCompact)
    }

    /// The widget's choice of deadline (ruling 8): Automatic is build 6's behaviour, a deadline only where one binds the
    /// reader's trailhead (and the zero trust countdown before a trailhead is picked); a deadline the reader picks on
    /// Home is counted down to whatever the trailhead, until it passes.
    func testTheWidgetCountsDownToTheDeadlineTheReaderChooses() throws {
        let today = day("2026-11-14")
        XCTAssertEqual(Glance.choices(store: store, today: today).map(\.id), ["fedramp", "dod-zt-strategy"])
        XCTAssertEqual(Glance.choices(store: store, today: day("2027-01-02")).map(\.id), ["dod-zt-strategy"])
        let none = ProgressStore.State()
        XCTAssertEqual(Glance(store: store, state: none, today: today).countdown?.label, "Target Level")
        XCTAssertEqual(Glance(store: store, state: none, today: today, deadline: "fedramp").countdown, .init(days: 48, label: "FedRAMP 2026 rules", sourceId: "fedramp"))
        // a contractor's path has no dated deadline: Automatic shows none, as build 6 does; a chosen one shows
        let contractor = ProgressStore.State(door: "defense-contractor")
        XCTAssertNil(Glance(store: store, state: contractor, today: today).countdown)
        XCTAssertEqual(Glance(store: store, state: contractor, today: today, deadline: "dod-zt-strategy").countdown?.days, 320)
        // the department's path keeps its own deadline on Automatic, and takes the reader's choice when there is one
        let dow = ProgressStore.State(door: "dow")
        XCTAssertEqual(Glance(store: store, state: dow, today: today).countdown?.label, "Target Level")
        XCTAssertEqual(Glance(store: store, state: dow, today: today, deadline: "fedramp").countdown?.label, "FedRAMP 2026 rules")
        // a chosen deadline that has passed, or a choice the content no longer has, falls back to Automatic
        XCTAssertEqual(Glance(store: store, state: dow, today: day("2027-01-02"), deadline: "fedramp").countdown?.label, "Target Level")
        XCTAssertNil(Glance(store: store, state: contractor, today: today, deadline: "nope").countdown)
        // the choice is made in the app and kept in the progress file, which the widget reads
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lensatic-tests-\(UUID().uuidString)").appendingPathComponent("progress.json")
        let p = ProgressStore(url: url)
        p.choose(.defenseContractor)
        p.setWidgetDeadline("fedramp")
        let kept = ProgressStore(url: url).state
        XCTAssertEqual(kept.widgetDeadline, "fedramp")
        XCTAssertEqual(Glance(store: store, state: kept, today: today).countdown?.label, "FedRAMP 2026 rules")
        p.setWidgetDeadline(nil)
        XCTAssertNil(Glance(store: store, state: ProgressStore(url: url).state, today: today).countdown, "Automatic again")
    }

    // MARK: Round 3: the plays tied in, saved elements, an element's text

    /// Every play is tied into the navigator: the links file holds each play of playbook/app/plays.json once, in the
    /// plays' own order; every link names a framework once and elements that framework holds; the file says whose reading
    /// the links are; the lead story starts with the two plays; and the counts the screens print are computed.
    func testEveryPlayIsTiedIntoTheNavigator() throws {
        let links = try XCTUnwrap(lib.playLinks)
        let shelf = try Library.bundled()
        XCTAssertEqual(links.plays.map(\.playId), shelf.plays.plays.map(\.id), "every play, in the plays' own order")
        XCTAssertTrue(links.basis.contains("own reading") && links.basis.contains("No publisher prints a crosswalk"), links.basis)
        for entry in links.plays {
            XCTAssertFalse(entry.links.isEmpty, entry.playId)
            XCTAssertEqual(Set(entry.links.map(\.frameworkId)).count, entry.links.count, "\(entry.playId) names a framework once")
            for link in entry.links {
                let g = try XCTUnwrap(lib.graphs[link.frameworkId], "\(entry.playId): \(link.frameworkId)")
                for n in link.nodeIds { XCTAssertNotNil(g.node(n), "\(entry.playId): \(link.frameworkId) holds \(n)") }
                XCTAssertTrue(link.line.hasSuffix("."), link.line)
            }
        }
        XCTAssertEqual(links.story.playIds, ["insiders", "containment"])
        // the story's two plays reach controls, outcomes and techniques, the AI RMF and all three MITRE knowledge bases
        for play in links.story.playIds {
            let own = lib.links(forPlay: play)
            for id in ["sp800-53", "csf20", "ai-rmf", "attack", "d3fend", "aml", "dod-zt", "cisa-ztmm"] {
                XCTAssertTrue(own.contains { $0.frameworkId == id && !$0.nodeIds.isEmpty }, "\(play) reaches \(id)")
            }
            let counts = lib.linkCounts(forPlay: play)
            XCTAssertEqual(counts.frameworks, own.count)
            XCTAssertEqual(counts.elements, own.reduce(0) { $0 + $1.nodeIds.count })
        }
        // the way back: the plays that touch an element, and a framework
        XCTAssertTrue(lib.plays(touching: "AC-6", in: "sp800-53").contains("insiders"))
        XCTAssertTrue(lib.plays(touching: "AML.T0051", in: "aml").contains("containment"))
        XCTAssertTrue(lib.plays(touching: "AC-6", in: "csf20").isEmpty, "an identifier is its own framework's")
        XCTAssertEqual(lib.plays(touching: "aml").map(\.playId), links.plays.filter { e in e.links.contains { $0.frameworkId == "aml" } }.map(\.playId))
        XCTAssertTrue(lib.links(forPlay: "nothing").isEmpty)
        // a count is in the publisher's word where every element is at one level, and there is none for a whole framework
        let csf = try XCTUnwrap(lib.links(forPlay: "insiders").first { $0.frameworkId == "csf20" })
        XCTAssertEqual(lib.countLine(csf), "\(csf.nodeIds.count) Subcategories")
        let mixed = try XCTUnwrap(lib.links(forPlay: "insiders").first { $0.frameworkId == "sp800-53" })
        XCTAssertEqual(lib.countLine(mixed), "\(mixed.nodeIds.count) elements")
        XCTAssertNil(lib.countLine(try XCTUnwrap(lib.links(forPlay: "resources").first)))
        XCTAssertEqual(PlaysOnFrameworkView.countLine(3, of: 35, labels: lib), "3 of the 35 plays touch it")
        // a link to an element that is not there fails the load
        XCTAssertThrowsError(try library(editing: "play-links") { tree in
            var plays = tree["plays"] as! [[String: Any]]
            var first = (plays[0]["links"] as! [[String: Any]])
            first[0]["nodeIds"] = ["NOPE-1"]
            plays[0]["links"] = first
            tree["plays"] = plays
        })
        XCTAssertEqual(Nav(pathParts: Nav.playsOn("aml").pathParts), .playsOn("aml"))
        XCTAssertEqual(Nav.playsOn("aml").home, .frameworks)
    }

    /// A single element is saved, described and opened by its own key (Round 3), an identifier with a space or a
    /// bracket included, and the app's own link carries it.
    func testAnElementIsSavedByItsOwnKey() throws {
        let model = AppModel(store: store, library: try Library.bundled(), progress: ProgressStore(url: nil), frameworks: lib)
        for (f, n, title, line) in [("sp800-53", "AC-2(1)", "AC-2(1) Automated System Account Management", "SP 800-53"),
                                    ("ai-rmf", "GOVERN 1.1", "GOVERN 1.1", "AI RMF"),
                                    ("aml", "AML.T0051", "AML.T0051 LLM Prompt Injection", "ATLAS")] {
            let item = SavedItem.node(f, n)
            XCTAssertEqual(item.key, "node:\(f):\(n)")
            XCTAssertEqual(SavedItem(key: item.key), item)
            XCTAssertTrue(model.exists(item), item.key)
            let d = try XCTUnwrap(model.describe(item))
            XCTAssertEqual(d.title, title)
            XCTAssertTrue(d.line.hasPrefix(line), d.line)
            XCTAssertTrue(model.open(link: DeepLink.open(item)), item.key)
            XCTAssertEqual(model.tab, .frameworks)
            XCTAssertEqual(model.paths[.frameworks], [.node(f, n)])
        }
        XCTAssertFalse(model.exists(.node("sp800-53", "NOPE-1")))
        XCTAssertNil(SavedItem(key: "node:sp800-53"))
        XCTAssertNil(SavedItem(key: "node::AC-2"))
        // no identifier holds a colon, so a key always splits in three
        for f in lib.frameworks { XCTAssertFalse(f.nodes.contains { $0.id.contains(":") }, f.id) }
        XCTAssertEqual(HomeView.byType([.play("containment"), .node("sp800-53", "AC-6"), .step(.dow, 2)]).map(\.key),
                       ["node:sp800-53:AC-6", "step:dow:2", "play:containment"])
    }

    /// An element's own text takes the map's first-use rule (Round 3): an abbreviation the glossary holds is spelled out
    /// once, the spell-out is marked as Lensatic's, and the publisher's words are all still there, in order.
    func testAnElementsTextTakesTheFirstUseRuleAndKeepsThePublishersWords() throws {
        var spelled = 0
        for f in lib.frameworks where f.terms.shows == .text {
            for node in f.nodes {
                guard let text = node.text else { continue }
                let words = NodeProse(node, rules: store.rules)
                let run = words.prose[try XCTUnwrap(words.text)]
                let own = run.segments.filter { if case .expansion = $0 { return false } else { return true } }.map(\.string).joined()
                XCTAssertEqual(own, text, "\(f.id) \(node.id): the publisher's words, whole and in order")
                XCTAssertEqual(words.expanded, own != run.text, "\(f.id) \(node.id)")
                if words.expanded { spelled += 1 }
            }
        }
        XCTAssertGreaterThan(spelled, 0, "at least one element's text holds an abbreviation the glossary spells out")
        // a framework that shows titles only has no text to spell out
        let control = try XCTUnwrap(lib.graphs["sp800-53"]?.node("AC-6"))
        XCTAssertNil(NodeProse(control, rules: store.rules).text)
    }

    /// Ruling 5 of 15 November 2026: a publisher's title is printed as published. The department's activity 6.5.3 is
    /// the one such title, the file lists it, and its source note says titles are as published.
    func testAPublishersTitleIsPrintedAsPublished() throws {
        let f = try XCTUnwrap(lib.byId["dod-zt"])
        XCTAssertEqual(f.asPublished, ["6.5.3"])
        let title = try XCTUnwrap(lib.graphs["dod-zt"]?.node("6.5.3")?.title)
        XCTAssertEqual(title.split(separator: " ").count, 2)
        XCTAssertTrue(title.split(separator: " ").allSatisfy { $0.first?.isUppercase == true }, "both words carry the department's capitals")
        XCTAssertTrue(f.sources.contains { $0.verification.note.contains("as the department publishes it") })
        XCTAssertTrue(lib.frameworks.filter { $0.id != "dod-zt" }.allSatisfy { $0.asPublished == nil })
    }

    /// The iPad's two panes (Round 3): the sidebar's list is the catalog's order, the detail pane opens on its first
    /// item, a pick shows with nothing over it, the arrow keys move the pick and stop at the ends, a screen of the
    /// sidebar's own kind opened from elsewhere becomes the pick, and one of another kind stays pushed with its way back.
    func testTheTwoPanesFollowThePick() throws {
        let model = AppModel(store: store, library: try Library.bundled(), progress: ProgressStore(url: nil), frameworks: lib)
        XCTAssertEqual(model.paneItems(.browse), lib.catalog.groups.flatMap { g in lib.frameworks(in: g.id).map { Nav.framework($0.id) } } + lib.catalog.lands.map { .landing($0.id) })
        XCTAssertEqual(model.paneItems(.compare), lib.compares.map { .compare($0.id) })
        XCTAssertEqual(model.paneItems(.checks), lib.checks.map { .check($0.id) })
        XCTAssertEqual(model.paneRoot, .framework("csf20"), "the first framework, before any pick")
        model.movePane(by: -1)
        XCTAssertEqual(model.paneRoot, .framework("csf20"), "the list stops at its top")
        model.movePane(by: 1)
        XCTAssertEqual(model.paneRoot, .framework("iso27001"))
        model.showFrameworks(.browse)
        model.selectPane(.framework("fedramp"))
        model.push(.node("fedramp", "KSI-IAM"))
        XCTAssertEqual(model.paths[.frameworks], [.node("fedramp", "KSI-IAM")])
        model.back()
        XCTAssertEqual(model.paths[.frameworks], [], "Command-[ takes the top screen off")
        model.back()
        XCTAssertEqual(model.paneRoot, .framework("fedramp"), "and does nothing at the pane's first screen")
        // a framework opened from elsewhere (Home's chip, a card's Connects To) becomes the pick
        model.show(.framework("cmmc"))
        model.foldPane()
        XCTAssertEqual(model.paneRoot, .framework("cmmc"))
        XCTAssertEqual(model.paths[.frameworks], [])
        // a check opened from a framework's screen is another view's kind: it stays pushed, with its way back
        model.push(.check("check-cmmc-l1"))
        model.foldPane()
        XCTAssertEqual(model.paths[.frameworks], [.check("check-cmmc-l1")])
        XCTAssertEqual(model.paneRoot, .framework("cmmc"))
        // the view follows a screen shown from outside the tab, and each view has its own first item
        model.show(.check("check-fedramp"))
        XCTAssertEqual(model.frameworksMode, .checks)
        model.foldPane()
        XCTAssertEqual(model.paneRoot, .check("check-fedramp"))
        model.frameworksMode = .compare
        XCTAssertEqual(model.paneRoot, lib.compares.first.map { .compare($0.id) }, "a pick of another view is not this view's")
        model.selectPane(.pair("fedramp", "cmmc"))
        XCTAssertEqual(model.paneRoot, .pair("fedramp", "cmmc"))
        let last = try XCTUnwrap(model.paneItems(.compare).last)
        model.selectPane(last)
        model.movePane(by: 1)
        XCTAssertEqual(model.paneRoot, last, "the list stops at its end")
        // two panes at a regular width and a standard text size only
        XCTAssertTrue(Shell.twoPanes(.regular, .large))
        XCTAssertFalse(Shell.twoPanes(.compact, .large))
        XCTAssertFalse(Shell.twoPanes(.regular, .accessibility2))
        XCTAssertEqual(FrameworksSplitView<EmptyView>.sidebarWidth(820), 320)
        XCTAssertEqual(FrameworksSplitView<EmptyView>.sidebarWidth(1366), 400)
    }
}
