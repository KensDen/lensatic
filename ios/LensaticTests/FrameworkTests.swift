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
        XCTAssertEqual(lib.frameworks.count, 18)
        XCTAssertEqual(Set(lib.frameworks.map(\.id)).count, lib.frameworks.count)
        let repo = Bundle(for: FrameworkTests.self)
        for name in ["catalog"] + lib.catalog.frameworks + lib.catalog.compares + lib.catalog.checks {
            XCTAssertEqual(sha256(try file(name)), sha256(try file(name, in: repo)), "\(name).json is the repository's file")
        }
        // every framework the brief names is a card
        for id in ["csf20", "sp800-53", "sp800-207", "dod-zt", "cisa-ztmm", "rmf", "cmmc", "sp800-171", "ai-rmf", "ir8596",
                   "fedramp", "iso27001", "cis", "il", "attack", "d3fend", "govramp", "cjis"] {
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
        XCTAssertEqual(depth.shown, 227)
        XCTAssertEqual(depth.of, 227 + 479)
        XCTAssertNotNil(depth.why.value, "a subset says why")
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
        XCTAssertEqual(back.map(\.framework.id).sorted(), ["csf20", "fedramp"])
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
        XCTAssertEqual(lib.comparisons(with: "csf20").map(\.id), [c.id])
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
                    "checkNotAssessment", "startOver", "checkKept", "homeFrameworksTitle", "homeFrameworksLine", "homeCheck"] {
            XCTAssertNotNil(lib.catalog.labels[key], key)
        }
    }

    func testACardSaysWhereItSitsAndReadsAsOneSentence() throws {
        let model = AppModel(store: store, library: try Library.bundled(), progress: ProgressStore(url: nil), frameworks: lib)
        XCTAssertEqual(model.sitsLabel(try XCTUnwrap(lib.byId["csf20"])), "Layer 1, Outcomes")
        XCTAssertEqual(model.sitsLabel(try XCTUnwrap(lib.byId["iso27001"])), "Layers 1, 4 and 5")
        XCTAssertEqual(model.sitsLabel(try XCTUnwrap(lib.byId["ai-rmf"])), "AI column")
        XCTAssertEqual(model.sitsLabel(try XCTUnwrap(lib.byId["attack"])), "Adversary column")
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
        XCTAssertEqual(BaselineView.countLine(fed.sets[2], host: try XCTUnwrap(lib.byId["sp800-53"]), labels: lib),
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
        XCTAssertEqual(first("FedRAMP"), .nav(.framework("fedramp")))
        XCTAssertEqual(first("ISO 27001"), .nav(.framework("iso27001")))
        XCTAssertEqual(first("ATT&CK"), .nav(.framework("attack")))
        XCTAssertEqual(first("CJIS"), .nav(.framework("cjis")))
        XCTAssertEqual(first("SOC 2"), .nav(.landing("soc2")))
        XCTAssertEqual(first("PCI DSS"), .nav(.landing("pci-dss")))
        // the words a reader still uses lead to the framework that replaced them
        XCTAssertEqual(first("3PAO"), .nav(.framework("fedramp")))
        XCTAssertEqual(first("POA&M"), .nav(.framework("fedramp")))
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
}
