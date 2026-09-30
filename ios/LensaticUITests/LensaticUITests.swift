import XCTest

/// Walks the app the way a reader does: every section, an accessibility audit on each screen, a door's step to its
/// framework entry, both matrix views, the three About links (found by label, never tapped: they leave the app), and
/// Why the name from the start screen. Words come from content/stack.json, which the test bundle carries.
@MainActor
final class LensaticUITests: XCTestCase {
    static let content: [String: Any] = {
        // content/stack.json by reference in the test bundle (ios/project.yml): the runner never reads outside its sandbox
        guard let url = Bundle(for: LensaticUITests.self).url(forResource: "stack", withExtension: "json") else { return [:] }
        return (try? JSONSerialization.jsonObject(with: Data(contentsOf: url))) as? [String: Any] ?? [:]
    }()

    static let sections = ["doors", "stack", "matrix", "functions", "ai", "helper", "sources", "glossary", "about"]

    var ui: [String: Any] { Self.content["ui"] as? [String: Any] ?? [:] }
    func label(_ key: String) -> String { (ui["labels"] as? [String: String])?[key] ?? key }

    private var launched: XCUIApplication?
    var app: XCUIApplication { launched ?? XCUIApplication() }

    /// Every test starts from a fresh launch, in portrait, on the section list (iPhone) or the list and the front door (iPad).
    func launch() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        launched = app
    }

    func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    /// Back to the section list: on iPhone it is the root of the stack; on iPad it stays beside the page.
    func showList() {
        let row = element("section-doors")
        var tries = 0
        while !row.isHittable && tries < 6 {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            guard back.exists else { break }
            back.tap()
            tries += 1
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }

    func open(_ section: String) {
        showList()
        element("section-\(section)").tap()
    }

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

    /// The part of the screen a page shows: its scroll view below the navigation bar above it, within the window.
    func visibleRegion(_ page: XCUIElement) -> CGRect {
        let frame = page.frame, window = app.windows.firstMatch.frame
        let bars = app.navigationBars.allElementsBoundByIndex.map(\.frame).filter { $0.maxX > frame.minX && $0.minX < frame.maxX }
        let top = max(frame.minY, bars.map(\.maxY).max() ?? frame.minY), bottom = min(frame.maxY, window.maxY)
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

    func testEverySectionAndAnAccessibilityAuditOnEachScreen() throws {
        launch()
        continueAfterFailure = true  // one run reports every screen's audit issues, not only the first screen's
        XCTAssertTrue(element("section-doors").waitForExistence(timeout: 10))
        // the start screen's bar carries the name as its title: the list's on iPhone, the sidebar's on iPad
        let name = (Self.content["meta"] as? [String: Any])?["name"] as? String ?? ""
        XCTAssertFalse(name.isEmpty)
        XCTAssertTrue(app.navigationBars.staticTexts[name].firstMatch.waitForExistence(timeout: 5), "the start screen shows its title")
        try audit("section list")
        for section in Self.sections {
            open(section)
            let title = (ui["sections"] as? [String: String])?[section] ?? section
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), "\(section) shows its title")
            try audit(section)
        }
    }

    /// A diagnostic, not a pass condition: every section read from top to bottom, every issue printed as SWEEP, none
    /// failed. Below the first screen the audit reports contrast on text whose colours measure 6.5:1 and more and that
    /// passes wherever it is first on screen, so its findings are read by hand. Runs only in the LensaticAuditSweep
    /// scheme, which sets LENSATIC_AUDIT_SWEEP: xcodebuild -scheme LensaticAuditSweep
    /// -only-testing:LensaticUITests/LensaticUITests/testSweepEverySection ... test
    func testSweepEverySection() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LENSATIC_AUDIT_SWEEP"] == "1", "the sweep runs only when asked")
        launch()
        continueAfterFailure = true
        for section in Self.sections {
            open(section)
            try sweep(section)
        }
    }

    func testADoorStepLeadsToItsFrameworkEntry() throws {
        launch()
        // the first step, in content order, that names a framework (not a source or a solution)
        let frameworks = Self.content["frameworks"] as? [[String: Any]] ?? []
        let frameworkIDs = Set(frameworks.compactMap { $0["id"] as? String })
        let doors = Self.content["doors"] as? [[String: Any]] ?? []
        var found: (door: String, entity: String)?
        for door in doors where found == nil {
            for step in door["steps"] as? [[String: Any]] ?? [] {
                if let id = (step["entityIds"] as? [String])?.first(where: frameworkIDs.contains), let d = door["id"] as? String {
                    found = (d, id)
                    break
                }
            }
        }
        let (doorID, entityID) = try XCTUnwrap(found)
        open("doors")
        let card = element("door-\(doorID)")
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let link = element("entity-link-\(entityID)")
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        try audit("door \(doorID)")
        link.tap()
        // the entry's screen is titled with its short name (its heading may carry a first-use expansion)
        let short = try XCTUnwrap(frameworks.first { $0["id"] as? String == entityID }?["shortName"] as? String)
        XCTAssertTrue(app.navigationBars[short].waitForExistence(timeout: 5), "the entry \(entityID) opens")
        try audit("entry \(entityID)")
    }

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
        try audit("layer \(layer)")

        open("matrix")
        let cell = element("cell-dow-user-GV")
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
        // the cell's screen is titled with its pillar's name in the view
        let pillars = (Self.content["pillars"] as? [String: Any])?["canonical"] as? [[String: Any]] ?? []
        let user = try XCTUnwrap(pillars.first { $0["id"] as? String == "user" }?["dowName"] as? String)
        XCTAssertTrue(app.navigationBars[user].waitForExistence(timeout: 5), "the cell opens")
        try audit("matrix cell user GV")

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
        try audit("matrix, CISA view")
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

    func testWhyTheNameOpensAboutAtItsHeadingWithThePhoto() {
        launch()
        open("doors")
        let why = element("why-name")
        XCTAssertTrue(why.waitForExistence(timeout: 5))
        XCTAssertEqual(why.label, label("whyName"))
        why.tap()
        let heading = element("about-name")
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        XCTAssertEqual(heading.label, label("whyNameHeading"))
        XCTAssertTrue(heading.isHittable, "About opens scrolled to the heading")
        let photo = element("about-photo")
        XCTAssertTrue(photo.exists)
        XCTAssertEqual(photo.label, label("aboutPhotoAlt"))
        XCTAssertEqual(photo.elementType, .image)
    }
}
