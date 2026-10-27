import XCTest
@testable import Lensatic

/// The redesign's path (R1): progress, the next step, the deadline math, the door cards' lines, switching trailheads
/// on the device, Title Case, and what a card says. Every expected number below is read from or computed against the
/// real content; the dates are fixed so the tests do not depend on the day they run.
@MainActor
final class PathTests: XCTestCase {
    static let store = try! ContentStore.bundled()
    static let library = try! Library.bundled()
    var store: ContentStore { Self.store }
    let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    func date(_ iso: String, _ hour: Int = 12) -> Date {
        let p = iso.split(separator: "-").map { Int($0)! }
        return utc.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: hour))!
    }

    func door(_ id: Door.ID) throws -> Door { try XCTUnwrap(store.content.doors.first { $0.id == id }) }
    func plan(_ id: Door.ID) throws -> PathPlan { PathPlan(door: try door(id), entities: store.entities) }
    var labels: [String: String] { store.content.ui.labels }

    // MARK: progress

    func testProgressCountsOnlyTheStepsThePathHas() throws {
        let p = try plan(.dow)
        XCTAssertEqual(p.steps.count, 7)
        XCTAssertEqual(p.progress([]), .init(done: 0, total: 7))
        XCTAssertEqual(p.progress([1, 2]), .init(done: 2, total: 7))
        XCTAssertEqual(p.progress([1, 2]).fraction, 2.0 / 7.0, accuracy: 1e-9)
        // a check left for a step the path no longer has (an older content file) is not counted
        XCTAssertEqual(p.progress([1, 2, 9]).done, 2)
        XCTAssertFalse(p.progress([1, 2, 3, 4, 5, 6]).isComplete)
        XCTAssertTrue(p.progress(Set(1...7)).isComplete)
        let none = try plan(.other)
        XCTAssertEqual(none.progress([]), .init(done: 0, total: 0))
        XCTAssertFalse(none.progress([]).isComplete)
        XCTAssertEqual(none.progress([]).fraction, 0)
    }

    func testTheNextStepIsTheFirstNotCheckedOff() throws {
        let p = try plan(.dow)
        XCTAssertEqual(p.next([])?.order, 1)
        XCTAssertEqual(p.next([1, 2])?.order, 3)
        XCTAssertEqual(p.next([1, 3])?.order, 2, "a step skipped earlier comes back as the next one")
        XCTAssertNil(p.next(Set(1...7)))
        XCTAssertEqual(p.next([1, 2])?.title, "Add zero trust for operational tech")
        XCTAssertEqual(p.next([1, 2])?.when, "If you own control systems")
    }

    // MARK: deadlines

    func testDaysCountWholeCalendarDays() throws {
        let fy27 = try XCTUnwrap(PathPlan.day("2027-09-30"))
        XCTAssertEqual(PathPlan.days(from: date("2026-10-26"), to: fy27, calendar: utc), 339)
        XCTAssertEqual(PathPlan.days(from: date("2026-10-26", 0), to: fy27, calendar: utc), 339, "the hour of day does not matter")
        XCTAssertEqual(PathPlan.days(from: date("2026-10-26", 23), to: fy27, calendar: utc), 339)
        XCTAssertEqual(PathPlan.days(from: date("2027-09-29", 23), to: fy27, calendar: utc), 1)
        XCTAssertEqual(PathPlan.days(from: date("2027-09-30", 23), to: fy27, calendar: utc), 0)
        XCTAssertEqual(PathPlan.days(from: date("2027-10-01"), to: fy27, calendar: utc), -1)
        // across a leap day
        XCTAssertEqual(PathPlan.days(from: date("2028-02-28"), to: try XCTUnwrap(PathPlan.day("2028-03-01")), calendar: utc), 2)
        XCTAssertEqual(PathPlan.days(from: date("2027-02-28"), to: try XCTUnwrap(PathPlan.day("2027-03-01")), calendar: utc), 1)
        // a whole year
        XCTAssertEqual(PathPlan.days(from: date("2026-09-30"), to: fy27, calendar: utc), 365)
    }

    func testOnlyARealCalendarDateIsADay() {
        XCTAssertNotNil(PathPlan.day("2028-02-29"))
        XCTAssertNil(PathPlan.day("2027-02-29"))
        XCTAssertNil(PathPlan.day("2026-02-30"))
        XCTAssertNil(PathPlan.day("2026-13-01"))
        XCTAssertNil(PathPlan.day("2026-9-1"))
        XCTAssertNil(PathPlan.day("FY2027"))
    }

    func testCountdownWords() {
        XCTAssertEqual(Countdown.text(days: 339), "339 days")
        XCTAssertEqual(Countdown.text(days: 1), "1 day")
        XCTAssertEqual(Countdown.text(days: 0), "Due today")
    }

    func testTheDepartmentPathCountsDownToTargetLevel() throws {
        let p = try plan(.dow)
        XCTAssertEqual(p.deadlines.map(\.due.date), ["2027-09-30"])
        let up = try XCTUnwrap(p.upcoming(today: date("2026-10-26"), calendar: utc))
        XCTAssertEqual(up.sourceId, "dod-zt-strategy")
        XCTAssertEqual(up.due.label, "Target Level zero trust")
        XCTAssertEqual(up.due.fiscalYear, 2027)
        XCTAssertEqual(up.due.stated(separator: " · "), "End of FY2027 · 30 Sep 2027")
        XCTAssertEqual(up.due.byLine, "Target Level by FY2027")
        XCTAssertNotNil(p.upcoming(today: date("2027-09-30", 23), calendar: utc), "due today still counts")
        XCTAssertNil(p.upcoming(today: date("2027-10-01"), calendar: utc), "a passed deadline is not upcoming")
    }

    func testAPassedDeadlineGivesWayToTheNextStep() throws {
        // the civilian path's one dated deadline, the M-22-09 goals, passed at the end of FY2024
        let p = try plan(.federalCivilian)
        XCTAssertEqual(p.deadlines.map(\.due.date), ["2024-09-30"])
        XCTAssertEqual(p.deadlines.first?.sourceId, "omb-m2209")
        XCTAssertNil(p.upcoming(today: date("2026-10-26"), calendar: utc))
        XCTAssertNotNil(p.upcoming(today: date("2024-09-01"), calendar: utc))
    }

    func testADeadlineThatBindsSomeoneElseIsNotThePathsOwn() throws {
        // the contractor path cites the department's strategy, which binds components, not contractors
        let p = try plan(.defenseContractor)
        XCTAssertTrue(p.steps.contains { $0.entityIds.contains("dod-zt-strategy") })
        XCTAssertTrue(p.deadlines.isEmpty)
        XCTAssertTrue(try plan(.other).deadlines.isEmpty)
    }

    func testEveryDateInTheContentIsOnTheEntryWhoseSourceStatesIt() {
        for e in store.entities.values {
            guard let d = e.authority.deadline.value, let due = d.due else { continue }
            XCTAssertEqual(d.sourceId, e.id, "\(e.id): the date sits on its own source")
            XCTAssertEqual(e.authority.verification.status, .verified, e.id)
            XCTAssertNotNil(PathPlan.day(due.date), e.id)
            if let fy = due.fiscalYear {
                XCTAssertEqual(due.date, "\(fy)-09-30", "\(e.id): a fiscal year ends on 30 September")
                XCTAssertTrue(d.text.contains(String(fy)), e.id)
            }
        }
    }

    // MARK: the welcome screen's lines

    func testTheDoorCardLineCountsStepsAndNamesTheDeadlineAhead() throws {
        let today = date("2026-10-26")
        XCTAssertEqual(try plan(.dow).cardLine(today: today, labels: labels, calendar: utc), "7 steps · Target Level by FY2027")
        XCTAssertEqual(try plan(.federalCivilian).cardLine(today: today, labels: labels, calendar: utc), "7 steps · M-22-09, CISA ZTMM")
        XCTAssertEqual(try plan(.defenseContractor).cardLine(today: today, labels: labels, calendar: utc), "5 steps · SP 800-171, CMMC")
        XCTAssertEqual(try plan(.other).cardLine(today: today, labels: labels, calendar: utc), "State, local, company, university")
        // after Target Level's day the line falls back to the trailhead's own
        XCTAssertEqual(try plan(.dow).cardLine(today: date("2027-10-01"), labels: labels, calendar: utc),
                       "7 steps · DoD ZT Strategy, DoD ZT Roadmap")
    }

    func testTheTrailheadNamesAreInTitleCase() throws {
        XCTAssertEqual(store.content.doors.map(\.shortTitle),
                       ["Federal Civilian Agency", "Department of War Component", "Defense Contractor with CUI", "Everyone Else"])
        for d in store.content.doors {
            XCTAssertEqual(TitleCase.apply(d.shortTitle), d.shortTitle, d.id.rawValue)
            XCTAssertEqual(Set(d.steps.map(\.title)).count, d.steps.count, "\(d.id.rawValue): step titles are distinct")
            for s in d.steps { XCTAssertFalse(s.title.hasSuffix("."), s.title) }
        }
    }

    // MARK: switching trailheads, on the device

    func tempStore() -> (ProgressStore, URL) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lensatic-tests-\(UUID().uuidString)")
            .appendingPathComponent("progress.json")
        return (ProgressStore(url: url), url)
    }

    func testEachTrailheadKeepsItsOwnChecksAcrossASwitch() {
        let (p, url) = tempStore()
        XCTAssertNil(p.door)
        p.choose(.dow)
        p.toggle(.dow, 1)
        p.toggle(.dow, 2)
        p.choose(.federalCivilian)
        XCTAssertEqual(p.door, .federalCivilian)
        XCTAssertEqual(p.checked(.federalCivilian), [], "a new trailhead starts with nothing checked")
        p.toggle(.federalCivilian, 3)
        p.choose(.dow)
        XCTAssertEqual(p.checked(.dow), [1, 2], "switching back finds the checks again")
        XCTAssertEqual(p.checked(.federalCivilian), [3])
        p.toggle(.dow, 2)
        XCTAssertEqual(p.checked(.dow), [1], "a second tap unchecks")
        // a relaunch reads the same file
        let again = ProgressStore(url: url)
        XCTAssertEqual(again.door, .dow)
        XCTAssertEqual(again.checked(.dow), [1])
        XCTAssertEqual(again.checked(.federalCivilian), [3])
        again.reset()
        XCTAssertNil(ProgressStore(url: url).door)
        XCTAssertEqual(ProgressStore(url: url).state, .init())
    }

    func testTheModelSwitchesTrailheadAndOpensMyPathAtItsTop() throws {
        let (p, _) = tempStore()
        let model = AppModel(store: store, library: Self.library, progress: p)
        XCTAssertNil(model.door)
        model.choose(.dow)
        XCTAssertEqual(model.door?.id, .dow)
        XCTAssertEqual(model.matrixView, .dow)
        model.push(.entity("dod-zt-strategy"))
        XCTAssertTrue(model.cardOnTop)
        model.changingDoor = true
        model.choose(.federalCivilian)
        XCTAssertFalse(model.changingDoor)
        XCTAssertEqual(model.tab, .path)
        XCTAssertEqual(model.paths[.path] ?? [], [])
        XCTAssertEqual(model.matrixView, .cisa, "the civilian trailhead reads CISA's pillars")
        XCTAssertEqual(model.plan(try XCTUnwrap(model.door)).steps.count, 7)
    }

    func testAnUnreadableFileStartsFresh() throws {
        XCTAssertEqual(ProgressStore.state(from: nil), .init())
        XCTAssertEqual(ProgressStore.state(from: Data("not json".utf8)), .init())
        XCTAssertEqual(ProgressStore.state(from: Data(#"{"door":"dow","checked":{"dow":[2,1]}}"#.utf8)),
                       .init(door: "dow", checked: ["dow": [2, 1]]))
        let (_, url) = tempStore()
        XCTAssertNil(ProgressStore(url: url).door, "no file yet")
    }

    func testTheProgressFileIsTheTrailheadTheChecksTheSavedItemsAndTheWeeksOnly() throws {
        let (p, url) = tempStore()
        p.choose(.dow)
        p.toggle(.dow, 3)
        p.toggleSaved(.entity("sp800-207"))
        p.toggleWeek("core", 1)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["door", "checked", "saved", "weeks"])
        XCTAssertEqual(json["door"] as? String, "dow")
        XCTAssertEqual(json["checked"] as? [String: [Int]], ["dow": [3]])
        XCTAssertEqual(json["saved"] as? [String], ["entity:sp800-207"])
        XCTAssertEqual(json["weeks"] as? [String: [Int]], ["core": [1]])
    }

    // MARK: Title Case and the card

    func testDesignationsAndDatesStayWhole() {
        XCTAssertEqual(keepDesignations("Define zero trust with SP 800-207"), "Define zero trust with SP\u{00A0}800-207")
        XCTAssertEqual(keepDesignations("Start with EO 14028"), "Start with EO\u{00A0}14028")
        XCTAssertEqual(keepDesignations("Express the target as a CSF 2.0 Profile"), "Express the target as a CSF\u{00A0}2.0 Profile")
        XCTAssertEqual(keepDesignations("Step 3 of 7"), "Step 3 of 7", "an ordinary word before a number may still break")
        XCTAssertEqual(unbroken("9 Sep 2026"), "9\u{00A0}Sep\u{00A0}2026")
    }

    func testTitleCase() {
        XCTAssertEqual(TitleCase.apply("DoW components"), "DoW Components")
        XCTAssertEqual(TitleCase.apply("Federal civilian agencies"), "Federal Civilian Agencies")
        XCTAssertEqual(TitleCase.apply("Defense contractors handling FCI or CUI"), "Defense Contractors Handling FCI or CUI")
        XCTAssertEqual(TitleCase.apply("the end of the line"), "The End of the Line")
        XCTAssertEqual(TitleCase.apply("Enterprise service"), "Enterprise Service")
        XCTAssertEqual(TitleCase.apply("customer's model"), "Customer's Model")
    }

    func testTheCardSaysWhatTheContentSays() throws {
        let strategy = EntityFacts(try XCTUnwrap(store.entities["dod-zt-strategy"]), store: store)
        XCTAssertEqual(strategy.binds, "DoW Components")
        XCTAssertEqual(strategy.due, "FY2027")
        XCTAssertEqual(strategy.type, "Strategy")
        XCTAssertEqual(strategy.readLabel, "Read the Strategy")
        XCTAssertEqual(strategy.eyebrow, "Layer 3 · Target state and maturity")
        XCTAssertEqual(strategy.verifiedLine, "Verified against the source · " + unbroken("9 Sep 2026"))
        XCTAssertTrue(strategy.isPDF)
        XCTAssertEqual(strategy.answers?.text, store.entities["dod-zt-strategy"]?.answersQuestion)
        // a deadline with no date the source prints, and none at all
        XCTAssertEqual(EntityFacts(try XCTUnwrap(store.entities["eo14028"]), store: store).due, "Not Dated")
        XCTAssertEqual(EntityFacts(try XCTUnwrap(store.entities["sp800-207"]), store: store).due, "None")
        XCTAssertEqual(EntityFacts(try XCTUnwrap(store.entities["omb-m2209"]), store: store).due, "FY2024")
        // a source has no layer of its own: its role stands where a framework's question does
        let eo = EntityFacts(try XCTUnwrap(store.entities["eo14028"]), store: store)
        XCTAssertEqual(eo.answers?.text, store.entities["eo14028"]?.role)
        XCTAssertEqual(EntityFacts(try XCTUnwrap(store.entities["csf20"]), store: store).binds, "Federal Civilian Agencies, DoW Components")
        // the one unverified entry says so
        let unverified = try XCTUnwrap(store.entities.values.first { $0.verification.status == .unverified })
        XCTAssertEqual(EntityFacts(unverified, store: store).verifiedLine, "Not yet confirmed against the source")
    }

    func testGoesWithNamesTheEntriesThatShareASteps() {
        XCTAssertEqual(store.goesWith("dod-zt-strategy"), ["dod-zt-roadmap", "rmf-ato", "cora", "sp800-207"])
        for id in store.entities.keys {
            let goes = store.goesWith(id)
            XCTAssertLessThanOrEqual(goes.count, 4)
            XCTAssertFalse(goes.contains(id))
            XCTAssertEqual(Set(goes).count, goes.count)
        }
    }

    // MARK: the new fields decode strictly

    func mutated(_ edit: (inout [String: Any]) -> Void) throws -> Data {
        let data = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "stack", withExtension: "json")))
        var tree = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        edit(&tree)
        return try JSONSerialization.data(withJSONObject: tree)
    }

    func editDue(_ tree: inout [String: Any], _ edit: (inout [String: Any]) -> Void) {
        var list = tree["frameworks"] as! [[String: Any]]
        let i = list.firstIndex { $0["id"] as? String == "dod-zt-strategy" }!
        var a = list[i]["authority"] as! [String: Any]
        var d = a["deadline"] as! [String: Any]
        var due = d["due"] as! [String: Any]
        edit(&due)
        d["due"] = due
        a["deadline"] = d
        list[i]["authority"] = a
        tree["frameworks"] = list
    }

    func editStep(_ tree: inout [String: Any], _ edit: (inout [String: Any]) -> Void) {
        var doors = tree["doors"] as! [[String: Any]]
        var steps = doors[0]["steps"] as! [[String: Any]]
        edit(&steps[0])
        doors[0]["steps"] = steps
        tree["doors"] = doors
    }

    func testTheNewFieldsAreHeldToTheirShape() throws {
        XCTAssertNoThrow(try Strict.decode(Content.self, from: mutated { _ in }))
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.editDue(&$0) { $0["extra"] = 1 } }))
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.editDue(&$0) { $0["date"] = nil } }))
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.editDue(&$0) { $0["fiscalYear"] = NSNull() } }))
        XCTAssertNoThrow(try Strict.decode(Content.self, from: mutated { self.editDue(&$0) { $0["fiscalYear"] = nil } }))
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.editStep(&$0) { $0["title"] = nil } }))
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.editStep(&$0) { $0["when"] = NSNull() } }))
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { t in
            var doors = t["doors"] as! [[String: Any]]
            doors[0]["shortTitle"] = nil
            t["doors"] = doors
        }))
    }
}
