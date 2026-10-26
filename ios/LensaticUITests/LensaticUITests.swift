import XCTest

/// Walks the app the way a reader does (the redesign, R1): the welcome screen, picking a trailhead, checking off a step
/// and finding it checked after a relaunch, switching trailheads, a step to its card and the card's Sources sheet, then
/// every section of the map not yet redesigned (under Explore and Library), both matrix views and the three About links
/// (found by label, never tapped: they leave the app), with an accessibility audit on each screen. Words come from
/// content/stack.json, which the test bundle carries.
@MainActor
final class LensaticUITests: XCTestCase {
    static let content: [String: Any] = {
        // content/stack.json by reference in the test bundle (ios/project.yml): the runner never reads outside its sandbox
        guard let url = Bundle(for: LensaticUITests.self).url(forResource: "stack", withExtension: "json") else { return [:] }
        return (try? JSONSerialization.jsonObject(with: Data(contentsOf: url))) as? [String: Any] ?? [:]
    }()

    /// The map's sections R1 keeps as they were, by the tab that holds them (the trailheads now live on My Path).
    static let explore = ["stack", "matrix", "functions", "ai"]
    static let library = ["helper", "sources", "glossary", "about"]
    static let sections = explore + library

    var ui: [String: Any] { Self.content["ui"] as? [String: Any] ?? [:] }
    func label(_ key: String) -> String { (ui["labels"] as? [String: String])?[key] ?? key }

    private var launched: XCUIApplication?
    var app: XCUIApplication { launched ?? XCUIApplication() }

    /// Every test starts from a fresh launch, in portrait. By default the progress on the device is forgotten and the
    /// department's trailhead picked, so the tabs show; `door: nil` starts on the welcome screen, and `reset: false`
    /// keeps what the last launch saved (the relaunch test).
    func launch(reset: Bool = true, door: String? = "dow", checked: String? = nil) {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        var args: [String] = []
        if reset { args.append("-LensaticResetProgress") }
        if let door { args += ["-LensaticDoor", door] }
        if let checked { args += ["-LensaticChecked", checked] }
        app.launchArguments = args
        app.launch()
        launched = app
    }

    func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    func tab(for section: String) -> String { Self.explore.contains(section) ? "tab-explore" : "tab-library" }

    /// The tab's first screen: tapping the open tab goes back to it.
    func showShelf(_ tab: String) {
        let button = element(tab)
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        if !button.isSelected { button.tap() }
    }

    func open(_ section: String) {
        showShelf(tab(for: section))
        let row = element("section-\(section)")
        if !row.waitForExistence(timeout: 2) { element(tab(for: section)).tap() }
        XCTAssertTrue(row.waitForExistence(timeout: 5), section)
        row.tap()
    }

    func value(_ id: String) -> String? { element(id).value as? String }

    var doors: [[String: Any]] { Self.content["doors"] as? [[String: Any]] ?? [] }

    /// Runs the audit on what is on screen. With a region (the part of the screen a page or sheet shows), an issue on
    /// an element that is not wholly inside it is deferred to the scroll position where it is: part under a bar, past
    /// an edge or behind a sheet, the audit reads the bar, the edge or the dimming, not the element. The navigation
    /// bars' own items are always audited. Deferred issues are counted and printed, never failed. With report, every
    /// issue is printed and none fails the test (the sweep below).
    func audit(_ screen: String, region: CGRect? = nil, types: XCUIAccessibilityAuditType = .all, report: Bool = false) throws {
        var bars: [CGRect]?  // the navigation bars' own items, looked up once and only when an issue needs them
        func barItems() -> [CGRect] {
            if bars == nil { bars = app.navigationBars.descendants(matching: .any).allElementsBoundByIndex.map(\.frame) }
            return bars ?? []
        }
        func same(_ a: CGRect, _ b: CGRect) -> Bool { abs(a.minX - b.minX) < 1 && abs(a.minY - b.minY) < 1 && abs(a.width - b.width) < 1 && abs(a.height - b.height) < 1 }
        var deferred = 0
        try app.performAccessibilityAudit(for: types) { issue in
            // inline links inside a paragraph are exempt from the target size rule (WCAG 2.5.8, inline): every other
            // control is at least 44 points; the issue is printed so the report can count it
            if issue.auditType == .hitRegion, issue.element?.elementType == .link {
                print("AUDIT \(screen): inline link, target size, exempt: \(issue.element?.label ?? "")")
                return true
            }
            // the tab bar's labels stop growing at the largest standard size and show in the large content viewer at
            // the accessibility sizes, as the system's own tab bars do (R1); the issue is printed so the report can count it
            if issue.auditType == .dynamicType, let frame = issue.element?.frame, frame.minY >= self.tabBarTop() - 1 {
                print("AUDIT \(screen): tab bar label, capped with the large content viewer, exempt: \(issue.element?.label ?? "")")
                return true
            }
            if let region, let frame = issue.element?.frame, !region.insetBy(dx: -1, dy: -1).contains(frame),
               !barItems().contains(where: { same($0, frame) }) {
                deferred += 1
                return true
            }
            print("\(report ? "SWEEP" : "AUDIT") \(screen): \(issue.auditType) \(issue.compactDescription): \(issue.element?.label ?? "")")
            return report
        }
        if deferred > 0 { print("AUDIT \(screen): \(deferred) deferred (element not wholly in view here)") }
    }

    /// A page of the map under its bar and over the tab bar: the audit reads what the page shows between the two.
    func auditPage(_ screen: String) throws {
        let page = app.scrollViews["page"].firstMatch
        try audit(screen, region: page.waitForExistence(timeout: 5) ? visibleRegion(page) : nil)
    }

    /// The top of the tab bar, or the window's foot when no tab bar shows.
    func tabBarTop() -> CGFloat {
        let tab = app.descendants(matching: .any).matching(identifier: "tab-path").firstMatch
        return tab.exists ? tab.frame.minY - 8 : app.windows.firstMatch.frame.maxY
    }

    /// The part of the screen a page shows: its scroll view below the navigation bar above it and above the tab bar,
    /// within the window.
    func visibleRegion(_ page: XCUIElement) -> CGRect {
        let frame = page.frame, window = app.windows.firstMatch.frame
        let bars = app.navigationBars.allElementsBoundByIndex.map(\.frame).filter { $0.maxX > frame.minX && $0.minX < frame.maxX }
        let top = max(frame.minY, bars.map(\.maxY).max() ?? frame.minY), bottom = min(frame.maxY, window.maxY, tabBarTop())
        return CGRect(x: frame.minX, y: top, width: frame.width, height: max(0, bottom - top))
    }

    /// The audit reads only what is on screen: this one reads the whole page, a page at a time from the top, dragged
    /// without momentum so no part is skipped, until the page stops moving. It reports and never fails (see the sweep).
    func sweep(_ screen: String) throws {
        let page = app.scrollViews["page"].firstMatch
        guard page.waitForExistence(timeout: 5) else { return try audit(screen, report: true) }
        let marker = page.staticTexts.firstMatch
        var top = marker.frame.minY
        for part in 1...80 {
            try audit(part == 1 ? screen : "\(screen), part \(part)", region: visibleRegion(page), report: true)
            // held still before lifting, so the page stops where the drag ends: an audit of a moving page reads the wrong pixels
            page.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
                .press(forDuration: 0.05, thenDragTo: page.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)),
                       withVelocity: .slow, thenHoldForDuration: 0.4)
            let now = marker.frame.minY
            if abs(now - top) < 1 { return }
            top = now
        }
        print("SWEEP \(screen): still scrolling after 80 pages")
    }

    // MARK: the redesign

    func testTheWelcomeScreenOffersTheFourTrailheads() throws {
        launch(door: nil)
        XCTAssertTrue(element("welcome").waitForExistence(timeout: 10))
        for door in doors {
            let id = try XCTUnwrap(door["id"] as? String)
            let card = element("door-\(id)")
            XCTAssertTrue(card.exists, id)
            XCTAssertTrue(card.label.contains(webTokens(door["shortTitle"] as? String ?? "")), "\(id) shows its name")
        }
        XCTAssertFalse(element("tab-path").exists, "no tabs before a trailhead is picked")
        try audit("welcome")
    }

    /// The round's acceptance test: pick a door, check off a step, relaunch, and the check is still there.
    func testPickADoorCheckAStepRelaunchAndTheCheckStays() throws {
        launch(door: nil)
        let door = element("door-dow")
        XCTAssertTrue(door.waitForExistence(timeout: 10))
        door.tap()
        XCTAssertTrue(element("my-path").waitForExistence(timeout: 5))
        let check = element("step-check-1")
        XCTAssertTrue(check.waitForExistence(timeout: 5))
        XCTAssertEqual(value("step-check-1"), "Not done")
        check.tap()
        XCTAssertEqual(value("step-check-1"), "Done")
        XCTAssertEqual(value("step-check-2"), "Not done")
        try audit("my path")

        app.terminate()
        launch(reset: false, door: nil)
        XCTAssertTrue(element("my-path").waitForExistence(timeout: 10), "the trailhead is remembered: My Path opens, not the welcome")
        XCTAssertFalse(element("welcome").exists)
        XCTAssertEqual(value("step-check-1"), "Done", "the check survived the relaunch")
        XCTAssertEqual(value("step-check-2"), "Not done")
        // and a second tap takes it back off, which also survives
        element("step-check-1").tap()
        app.terminate()
        launch(reset: false, door: nil)
        XCTAssertTrue(element("step-check-1").waitForExistence(timeout: 10))
        XCTAssertEqual(value("step-check-1"), "Not done")
    }

    func testSwitchingTrailheadsKeepsEachOnesChecks() throws {
        launch(door: "dow", checked: "1,2")
        XCTAssertTrue(element("step-check-2").waitForExistence(timeout: 10))
        XCTAssertEqual(value("step-check-2"), "Done")
        element("change-door").tap()
        let civilian = element("door-federal-civilian")
        XCTAssertTrue(civilian.waitForExistence(timeout: 5))
        try audit("welcome, changing")
        civilian.tap()
        XCTAssertTrue(element("step-check-1").waitForExistence(timeout: 5))
        XCTAssertEqual(value("step-check-1"), "Not done", "a new trailhead starts with nothing checked")
        // Library holds the same setting
        element("tab-library").tap()
        let row = element("library-change-door")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let dow = element("door-dow")
        XCTAssertTrue(dow.waitForExistence(timeout: 5))
        dow.tap()
        XCTAssertTrue(element("step-check-2").waitForExistence(timeout: 5))
        XCTAssertEqual(value("step-check-1"), "Done", "switching back finds the checks again")
        XCTAssertEqual(value("step-check-2"), "Done")
    }

    func testAStepOpensToItsCardAndTheCardToItsSources() throws {
        launch(door: "dow", checked: "1,2")
        let step = element("step-3")
        XCTAssertTrue(step.waitForExistence(timeout: 10))
        step.tap()
        let entry = element("step-3-entity-dod-zt-ot")
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "the step opens to the entries it names")
        entry.tap()
        XCTAssertTrue(element("entity-card-dod-zt-ot").waitForExistence(timeout: 5))
        XCTAssertFalse(element("tab-path").exists, "a card is a full screen: the tab bar steps aside")
        try audit("card dod-zt-ot")
        // the audit steps the text size up and back; the card's foot moves between pinned and inline as it does, so
        // the row is found again once the layout settles
        let verified = element("verified-row")
        XCTAssertTrue(verified.waitForExistence(timeout: 10))
        verified.tap()
        let done = element("sources-done")
        XCTAssertTrue(done.waitForExistence(timeout: 5), "the Verified row opens the Sources sheet")
        XCTAssertTrue(element("sources-open").exists)
        // as with the glossary sheet: the region is what the sheet shows (it scrolls when the text grows), and text
        // detection is left out, since the card behind the sheet shows text VoiceOver does not reach while it is open
        let sheet = app.scrollViews["sheet"].firstMatch
        XCTAssertTrue(sheet.exists)
        // audited at its full height, as the glossary sheet is: drag the sheet up by its top edge first
        let top = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: sheet.frame.midX, dy: sheet.frame.minY + 8))
        top.press(forDuration: 0.1, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: sheet.frame.midX, dy: 60)))
        try audit("sources dod-zt-ot", region: visibleRegion(sheet), types: XCUIAccessibilityAuditType.all.subtracting(.elementDetection))
        done.tap()
        XCTAssertTrue(element("card-read").waitForExistence(timeout: 5))
        element("card-read").tap()
        XCTAssertTrue(element("sources-done").waitForExistence(timeout: 5), "the primary button opens it too")
        element("sources-done").tap()
        element("card-back").tap()
        XCTAssertTrue(element("my-path").waitForExistence(timeout: 5))
        XCTAssertTrue(element("tab-path").exists)
    }

    /// The department's own spelling, as the app resolves the token in a trailhead's name.
    func webTokens(_ s: String) -> String {
        let dow = (Self.content["orgs"] as? [String: Any])?["dow"] as? [String: Any]
        return s.replacingOccurrences(of: "{{dow.current}}", with: dow?["current"] as? String ?? "")
    }

    // MARK: the map's sections, kept as they were

    func testEverySectionAndAnAccessibilityAuditOnEachScreen() throws {
        launch()
        continueAfterFailure = true  // one run reports every screen's audit issues, not only the first screen's
        XCTAssertTrue(element("tab-explore").waitForExistence(timeout: 10))
        for shelf in ["tab-explore", "tab-library", "tab-search"] {
            showShelf(shelf)
            try audit(shelf)
        }
        for section in Self.sections {
            open(section)
            let title = (ui["sections"] as? [String: String])?[section] ?? section
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), "\(section) shows its title")
            try auditPage(section)
        }
    }

    /// A diagnostic, not a pass condition: one section read from top to bottom, every issue printed as SWEEP, none
    /// failed. Below the first screen the audit reports contrast on text whose colours measure 6.5:1 and more and that
    /// passes wherever it is first on screen, so its findings are read by hand. Each section is its own test, from a
    /// fresh launch, so each section's audits start with their own time budget (session 11: in one test, the audit ran
    /// out of time before About). Runs only in the LensaticAuditSweep scheme, which sets LENSATIC_AUDIT_SWEEP:
    /// xcodebuild -scheme LensaticAuditSweep -only-testing:LensaticUITests/LensaticUITests/testSweep02Stack (one
    /// -only-testing per section, testSweep02Stack to testSweep09About) ... test
    func sweepSection(_ section: String) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LENSATIC_AUDIT_SWEEP"] == "1", "the sweep runs only when asked")
        launch()
        continueAfterFailure = true
        open(section)
        try sweep(section)
    }

    // one test per section, numbered in the web's section order, so a run lists them in that order (the trailheads,
    // the web's first section, now live on My Path)
    func testSweep02Stack() throws { try sweepSection("stack") }
    func testSweep03Matrix() throws { try sweepSection("matrix") }
    func testSweep04Functions() throws { try sweepSection("functions") }
    func testSweep05AI() throws { try sweepSection("ai") }
    func testSweep06Helper() throws { try sweepSection("helper") }
    func testSweep07Sources() throws { try sweepSection("sources") }
    func testSweep08Glossary() throws { try sweepSection("glossary") }
    func testSweep09About() throws { try sweepSection("about") }

    /// One of each kind of screen the sections open: a layer of the stack, a matrix cell, and a glossary entry.
    func testALayerACellAndAGlossaryEntryPassTheAudit() throws {
        launch()
        continueAfterFailure = true
        let layers = (Self.content["layers"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
        let layer = try XCTUnwrap(layers.first)
        open("stack")
        let row = element("layer-\(layer)")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.scrollViews["page"].firstMatch.waitForExistence(timeout: 5))
        try auditPage("layer \(layer)")

        open("matrix")
        let cell = element("cell-dow-user-GV")
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        // the cell starts near the foot of the page, its lower part under the tab bar: tap its top edge
        cell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        // the cell's screen is titled with its pillar's name in the view
        let pillars = (Self.content["pillars"] as? [String: Any])?["canonical"] as? [[String: Any]] ?? []
        let user = try XCTUnwrap(pillars.first { $0["id"] as? String == "user" }?["dowName"] as? String)
        XCTAssertTrue(app.navigationBars[user].waitForExistence(timeout: 5), "the cell opens")
        try auditPage("matrix cell user GV")

        // a glossary term in running text opens its entry in a sheet
        open("stack")
        let term = app.scrollViews["page"].firstMatch.links.firstMatch
        XCTAssertTrue(term.waitForExistence(timeout: 5), "the stack screen links a glossary term")
        term.tap()
        let done = element("glossary-done")
        XCTAssertTrue(done.waitForExistence(timeout: 5), "the glossary entry opens in a sheet")
        // one entry in a sheet over the page: the region is the sheet's page (the lowest page on screen), and text
        // detection is left out here because the page behind a sheet shows text that, by design, VoiceOver does not
        // reach while the sheet is open (that page is audited on its own screen)
        let sheet = app.scrollViews.matching(identifier: "page").allElementsBoundByIndex.max { $0.frame.minY < $1.frame.minY }
        try audit("glossary entry", region: sheet.map(visibleRegion), types: XCUIAccessibilityAuditType.all.subtracting(.elementDetection))
        done.tap()
    }

    func testTheMatrixSwitchesBetweenItsProjectedViews() throws {
        launch()
        open("matrix")
        let dow = element("pillar-view-dow"), cisa = element("pillar-view-cisa")
        XCTAssertTrue(dow.waitForExistence(timeout: 5))
        XCTAssertTrue(dow.isSelected)
        XCTAssertTrue(element("cell-dow-user-GV").exists)
        cisa.tap()
        XCTAssertTrue(element("pillar-view-cisa").isSelected)
        XCTAssertTrue(element("cell-cisa-governance-GV").waitForExistence(timeout: 5), "CISA's governance capability shows")
        try auditPage("matrix, CISA view")
        element("pillar-view-dow").tap()
        XCTAssertTrue(element("cell-dow-user-GV").waitForExistence(timeout: 5))
        XCTAssertFalse(element("cell-cisa-governance-GV").exists)
    }

    func testAboutCarriesThePolicySupportAndSourceLinks() {
        launch()
        open("about")
        for (id, key) in [("link-privacy", "pagesPrivacy"), ("link-support", "pagesSupport"), ("link-source", "sourceCode")] {
            let link = element(id)
            XCTAssertTrue(link.waitForExistence(timeout: 5), id)
            XCTAssertEqual(link.label, label(key))
        }
    }
}
