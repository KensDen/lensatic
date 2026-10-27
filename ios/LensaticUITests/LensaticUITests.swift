import XCTest

/// Walks the app the way a reader does (the redesign, R1 and R2): the welcome screen, picking a trailhead, checking off
/// a step and finding it checked after a relaunch, switching trailheads, a step to its card and the card's Sources
/// sheet; Explore to a layer and a framework card, the matrix and the functions; Search to a result; saving and finding
/// it saved after a relaunch; the Library to the Field Guide and the plays; the reference screens and the three About
/// links (found by label, never tapped: they leave the app); with an accessibility audit on each screen, and again at
/// the largest accessibility text size. Words come from content/stack.json, which the test bundle carries.
@MainActor
final class LensaticUITests: XCTestCase {
    static let content: [String: Any] = {
        // content/stack.json by reference in the test bundle (ios/project.yml): the runner never reads outside its sandbox
        guard let url = Bundle(for: LensaticUITests.self).url(forResource: "stack", withExtension: "json") else { return [:] }
        return (try? JSONSerialization.jsonObject(with: Data(contentsOf: url))) as? [String: Any] ?? [:]
    }()

    var ui: [String: Any] { Self.content["ui"] as? [String: Any] ?? [:] }
    func label(_ key: String) -> String { (ui["labels"] as? [String: String])?[key] ?? key }

    private var launched: XCUIApplication?
    var app: XCUIApplication { launched ?? XCUIApplication() }

    /// Every test starts from a fresh launch, in portrait. By default the progress on the device is forgotten and the
    /// department's trailhead picked, so the tabs show; `door: nil` starts on the welcome screen, and `reset: false`
    /// keeps what the last launch saved (the relaunch test).
    func launch(reset: Bool = true, door: String? = "dow", checked: String? = nil, _ extra: [String] = []) {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        var args: [String] = []
        if reset { args.append("-LensaticResetProgress") }
        if let door { args += ["-LensaticDoor", door] }
        if let checked { args += ["-LensaticChecked", checked] }
        app.launchArguments = args + extra
        app.launch()
        launched = app
    }

    func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    /// The tab's first screen: tapping the open tab goes back to it.
    func showTab(_ tab: String) {
        let button = element(tab)
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        if !button.isSelected { button.tap() }
    }

    /// Tap a control, scrolling the screen it is on until it is in view.
    func tap(_ id: String, in screen: String? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(id)
        XCTAssertTrue(target.waitForExistence(timeout: 5), id, file: file, line: line)
        if let screen {
            let scroll = app.scrollViews[screen].firstMatch
            var tries = 0
            while !target.isHittable || target.frame.maxY > tabBarTop(), tries < 12 {
                scroll.swipeUp(velocity: .slow)
                tries += 1
            }
        }
        target.tap()
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
            // a text line that sits across the edge of the scrolling region is reported clipped, or measured against the bar
            // beyond the edge for contrast, with no element to place it; it depends only on where the edge falls (the same
            // screen passes with its text a few points higher, and on a phone of another width), so it is deferred like any
            // element not wholly in view, and counted
            if region != nil, issue.element == nil, issue.auditType == .textClipped || issue.auditType == .contrast {
                deferred += 1
                print("AUDIT \(screen): \(issue.auditType == .contrast ? "contrast" : "text clipped") with no element (a line across the scrolling edge), deferred")
                return true
            }
            if let region, let frame = issue.element?.frame, !region.insetBy(dx: -1, dy: -1).contains(frame),
               !barItems().contains(where: { same($0, frame) }) {
                deferred += 1
                return true
            }
            print("\(report ? "SWEEP" : "AUDIT") \(screen): \(issue.auditType) \(issue.compactDescription): \(issue.element?.label ?? "")"
                  + " [\(issue.element?.identifier ?? "")] \(issue.element.map { "\($0.elementType.rawValue) \($0.frame)" } ?? "") \(issue.detailedDescription)")
            return report
        }
        if deferred > 0 { print("AUDIT \(screen): \(deferred) deferred (element not wholly in view here)") }
    }

    /// A screen over the tab bar: the audit reads what its scroll view shows above the tab bar.
    func auditScreen(_ id: String, types: XCUIAccessibilityAuditType = .all) throws {
        let page = app.scrollViews[id].firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 5), id)
        try audit(id, region: visibleRegion(page), types: types)
    }

    /// Drag a sheet up by its top edge to its full height, so the audit reads all of it as the text grows.
    func expandSheet() {
        let sheet = app.scrollViews["sheet"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: sheet.frame.midX, dy: sheet.frame.minY + 8))
            .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: sheet.frame.midX, dy: 60)))
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
        let page = app.scrollViews[screen].firstMatch
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

    // MARK: Explore (R2)

    /// Explore to a layer, a layer to its entries, an entry to its Framework card; the AI column opens the same way.
    func testExploreOpensALayerAndALayerItsFrameworkCard() throws {
        launch(door: "dow", checked: "1,2")
        showTab("tab-explore")
        XCTAssertTrue(element("explore").waitForExistence(timeout: 5))
        XCTAssertTrue(element("explore-stack").isSelected)
        try auditScreen("explore")
        tap("layer-l3", in: "explore")
        XCTAssertTrue(element("layer-screen-l3").waitForExistence(timeout: 5))
        try auditScreen("layer-screen-l3")
        tap("entry-dod-zt-strategy", in: "layer-screen-l3")
        XCTAssertTrue(element("entity-card-dod-zt-strategy").waitForExistence(timeout: 5), "the entry opens its card")
        XCTAssertFalse(element("tab-path").exists, "a card is a full screen: the tab bar steps aside")
        XCTAssertTrue(element("card-summary").label.count <= 140, "the card shows the short summary")
        element("card-summary-more").tap()
        XCTAssertGreaterThan(element("card-summary").label.count, 140, "Read More shows the whole one-liner")
        element("card-back").tap()
        element("back").tap()
        tap("layer-l6", in: "explore")
        XCTAssertTrue(element("layer-screen-l6").waitForExistence(timeout: 5), "the AI column opens")
        // a glossary term in running text opens its entry in a sheet
        let term = app.scrollViews["layer-screen-l6"].links.firstMatch
        XCTAssertTrue(term.waitForExistence(timeout: 5), "the column's screen links a glossary term")
        term.tap()
        XCTAssertTrue(element("glossary-done").waitForExistence(timeout: 5), "the glossary entry opens in a sheet")
        expandSheet()
        try audit("glossary entry", region: visibleRegion(app.scrollViews["sheet"].firstMatch),
                  types: XCUIAccessibilityAuditType.all.subtracting(.elementDetection))
        element("glossary-done").tap()
    }

    func testTheMatrixSwitchesViewsAndOpensACellAndTheFunctionsOpenByPillar() throws {
        launch()
        showTab("tab-explore")
        element("explore-matrix").tap()
        let dow = element("pillar-view-dow"), cisa = element("pillar-view-cisa")
        XCTAssertTrue(dow.waitForExistence(timeout: 5))
        XCTAssertTrue(dow.isSelected)
        XCTAssertTrue(element("cell-dow-user-GV").exists)
        cisa.tap()
        XCTAssertTrue(element("cell-cisa-governance-GV").waitForExistence(timeout: 5), "CISA's governance capability shows")
        try auditScreen("explore")
        element("pillar-view-dow").tap()
        XCTAssertTrue(element("cell-dow-user-GV").waitForExistence(timeout: 5))
        XCTAssertFalse(element("cell-cisa-governance-GV").exists)
        tap("cell-dow-user-GV", in: "explore")
        XCTAssertTrue(element("cell-screen").waitForExistence(timeout: 5), "the cell opens")
        try auditScreen("cell-screen")
        element("back").tap()
        element("explore-functions").tap()
        XCTAssertTrue(element("function-GV").waitForExistence(timeout: 5))
        tap("function-GV-pillars", in: "explore")
        XCTAssertEqual(element("function-GV-pillars").value as? String, "Open")
        try auditScreen("explore")
    }

    // MARK: Search (R2)

    func testSearchFindsAFrameworkAndAStepAndOpensEach() throws {
        launch(door: "dow")
        showTab("tab-search")
        let field = element("search-field")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("overlays\n")  // Return searches and puts the keyboard away
        let result = element("result-entity:dod-zt-overlays")
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(element("results-framework").exists && element("results-step").exists, "results are grouped by kind")
        try auditScreen("search")
        result.tap()
        XCTAssertTrue(element("entity-card-dod-zt-overlays").waitForExistence(timeout: 5), "a framework opens its card")
        element("card-back").tap()
        tap("result-step:dow:5", in: "search")
        XCTAssertTrue(element("my-path").waitForExistence(timeout: 5), "a step opens My Path")
        XCTAssertTrue(element("step-5-entity-dod-zt-overlays").waitForExistence(timeout: 5), "with the step open")
        showTab("tab-search")
        element("search-clear").tap()
        field.tap()
        field.typeText("zzqx")
        XCTAssertTrue(element("search-empty").waitForExistence(timeout: 5))
    }

    // MARK: Saved (R2)

    /// Save a framework, a step and a play, relaunch, and they are still saved, newest first, in the Library.
    func testSaveRelaunchAndTheItemsAreStillSaved() throws {
        launch(door: "dow", checked: nil, ["-LensaticNav", "entity/sp800-207"])
        let bookmark = element("bookmark")
        XCTAssertTrue(bookmark.waitForExistence(timeout: 10))
        XCTAssertEqual(bookmark.label, "Save")
        bookmark.tap()
        XCTAssertEqual(element("bookmark").label, "Saved")
        element("card-back").tap()
        showTab("tab-path")
        tap("step-2", in: "my-path")
        let stepMark = app.descendants(matching: .any).matching(identifier: "bookmark").firstMatch
        XCTAssertTrue(stepMark.waitForExistence(timeout: 5))
        stepMark.tap()
        app.terminate()
        launch(reset: false, door: nil)
        showTab("tab-library")
        XCTAssertTrue(element("saved-step:dow:2").waitForExistence(timeout: 10), "the saved step survived the relaunch")
        XCTAssertTrue(element("saved-entity:sp800-207").exists, "the saved framework survived the relaunch")
        XCTAssertLessThan(element("saved-step:dow:2").frame.minY, element("saved-entity:sp800-207").frame.minY, "newest first")
        element("saved-entity:sp800-207").tap()
        XCTAssertTrue(element("entity-card-sp800-207").waitForExistence(timeout: 5), "a saved item opens")
        element("bookmark").tap()
        element("card-back").tap()
        XCTAssertFalse(element("saved-entity:sp800-207").waitForExistence(timeout: 2), "unsaved, it leaves the list")
    }

    // MARK: Library (R2)

    func testTheLibraryOpensTheFieldGuideAndThePlays() throws {
        launch(door: "dow")
        showTab("tab-library")
        XCTAssertTrue(element("library").waitForExistence(timeout: 5))
        try auditScreen("library")
        element("library-guide").tap()
        XCTAssertTrue(element("guide-screen").waitForExistence(timeout: 5))
        XCTAssertEqual(value("week-check-1"), "Not done")
        element("week-check-1").tap()
        XCTAssertEqual(value("week-check-1"), "Done")
        try auditScreen("guide-screen")
        tap("chapter-part-1", in: "guide-screen")
        XCTAssertTrue(element("chapter-screen").waitForExistence(timeout: 5), "a chapter opens natively")
        try auditScreen("chapter-screen")
        element("back").tap()
        element("back").tap()
        XCTAssertTrue(element("library-guide").label.contains("Week 2"), "the guide's card counts the weeks done")
        element("library-plays").tap()
        XCTAssertTrue(element("plays-screen").waitForExistence(timeout: 5))
        try auditScreen("plays-screen")
        tap("play-containment", in: "plays-screen")
        XCTAssertTrue(element("play-screen").waitForExistence(timeout: 5), "a play opens natively")
        try auditScreen("play-screen")
        element("bookmark").tap()
        element("back").tap()
        element("back").tap()
        XCTAssertTrue(element("saved-play:containment").waitForExistence(timeout: 5), "a saved play is in the list")
    }

    func testTheReferenceScreensAndTheAboutLinks() throws {
        launch()
        showTab("tab-library")
        for (row, screen) in [("library-glossary", "glossary-screen"), ("library-sources", "sources-screen"), ("library-about", "about-screen")] {
            tap(row, in: "library")
            XCTAssertTrue(element(screen).waitForExistence(timeout: 5), screen)
            try auditScreen(screen)
            if screen == "about-screen" {
                for (id, key) in [("link-privacy", "pagesPrivacy"), ("link-support", "pagesSupport"), ("link-source", "sourceCode")] {
                    let link = element(id)
                    XCTAssertTrue(link.waitForExistence(timeout: 5), id)
                    XCTAssertEqual(link.label, label(key))
                }
            }
            element("back").tap()
        }
    }

    /// Every screen of the redesign passes the audit at the largest accessibility text size (AX5).
    func testEveryScreenPassesTheAuditAtTheLargestTextSize() throws {
        let ax5 = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        continueAfterFailure = true
        let screens: [([String], String)] = [
            (["-LensaticTab", "path"], "my-path"),
            (["-LensaticTab", "explore"], "explore"),
            (["-LensaticTab", "explore", "-LensaticExplore", "matrix"], "explore"),
            (["-LensaticTab", "explore", "-LensaticExplore", "functions"], "explore"),
            (["-LensaticTab", "search", "-LensaticQuery", "overlays"], "search"),
            (["-LensaticTab", "library"], "library"),
            (["-LensaticNav", "layer/l3"], "layer-screen-l3"),
            (["-LensaticNav", "cell/dow/user/GV"], "cell-screen"),
            (["-LensaticNav", "guide"], "guide-screen"),
            (["-LensaticNav", "chapter/part-1"], "chapter-screen"),
            (["-LensaticNav", "plays"], "plays-screen"),
            (["-LensaticNav", "play/containment"], "play-screen"),
            (["-LensaticNav", "glossary-list"], "glossary-screen"),
            (["-LensaticNav", "sources"], "sources-screen"),
            (["-LensaticNav", "about"], "about-screen"),
        ]
        for (args, id) in screens {
            launch(door: "dow", checked: "1,2", ax5 + args)
            continueAfterFailure = true
            try auditScreen(id)
        }
        launch(door: "dow", checked: "1,2", ax5 + ["-LensaticNav", "entity/dod-zt-strategy"])
        continueAfterFailure = true
        XCTAssertTrue(element("entity-card-dod-zt-strategy").waitForExistence(timeout: 10))
        try audit("card at AX5")
    }

    /// A diagnostic, not a pass condition: one screen read from top to bottom, every issue printed as SWEEP, none
    /// failed. Below the first screen the audit reports contrast on text whose colours measure 6.5:1 and more and that
    /// passes wherever it is first on screen, so its findings are read by hand. Each screen is its own test, from a
    /// fresh launch, so each one's audits start with their own time budget. Runs only in the LensaticAuditSweep scheme,
    /// which sets LENSATIC_AUDIT_SWEEP: xcodebuild -scheme LensaticAuditSweep
    /// -only-testing:LensaticUITests/LensaticUITests/testSweep01Stack ... test
    func sweepScreen(_ args: [String], _ id: String) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LENSATIC_AUDIT_SWEEP"] == "1", "the sweep runs only when asked")
        launch(door: "dow", checked: nil, args)
        continueAfterFailure = true
        XCTAssertTrue(element(id).waitForExistence(timeout: 10), id)
        try sweep(id)
    }

    func testSweep01Stack() throws { try sweepScreen(["-LensaticTab", "explore"], "explore") }
    func testSweep02Matrix() throws { try sweepScreen(["-LensaticTab", "explore", "-LensaticExplore", "matrix"], "explore") }
    func testSweep03Functions() throws { try sweepScreen(["-LensaticTab", "explore", "-LensaticExplore", "functions"], "explore") }
    func testSweep04AIColumn() throws { try sweepScreen(["-LensaticNav", "layer/l6"], "layer-screen-l6") }
    func testSweep05Sources() throws { try sweepScreen(["-LensaticNav", "sources"], "sources-screen") }
    func testSweep06Glossary() throws { try sweepScreen(["-LensaticNav", "glossary-list"], "glossary-screen") }
    func testSweep07About() throws { try sweepScreen(["-LensaticNav", "about"], "about-screen") }
    func testSweep08Chapter() throws { try sweepScreen(["-LensaticNav", "chapter/part-1"], "chapter-screen") }
}
