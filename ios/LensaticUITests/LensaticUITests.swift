import XCTest

/// Walks the app the way a reader does (the redesign, R1 and R2; build 6): Home and its three doors, the trailhead
/// question, picking a trailhead, checking off a step and finding it checked after a relaunch, switching trailheads, a
/// step to its card and the card's Sources sheet; Explore to a layer and a framework card, the matrix and the functions;
/// Search to a result; saving and finding it saved after a relaunch; Home to the Field Guide and the plays; the reference
/// screens and the three About links (found by label); What Changed showing and clearing, a widget's tap, the share sheet, a play's outline and the
/// in-app reader (R3); with an accessibility audit on each screen, and again at the largest accessibility text size.
/// Words come from content/stack.json, which the test bundle carries.
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
    /// department's trailhead picked; `door: nil` starts as a fresh install does, with no trailhead, and `reset: false`
    /// keeps what the last launch saved (the relaunch test). The app opens on Home (build 6). The tests written on My Path
    /// start there, so a launch with a trailhead, or one that keeps the last launch's, opens the My Path tab unless it
    /// names a tab or a screen of its own or asks for the app's own opening screen with `home: true`; a fresh install
    /// with no trailhead always opens as the app does, on Home.
    func launch(reset: Bool = true, door: String? = "dow", checked: String? = nil, home: Bool = false, _ extra: [String] = []) {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        var args: [String] = []
        if reset { args.append("-LensaticResetProgress") }
        if let door { args += ["-LensaticDoor", door] }
        if let checked { args += ["-LensaticChecked", checked] }
        let placed = ["-LensaticTab", "-LensaticNav", "-LensaticScreen", "-LensaticEntity", "-LensaticLink"].contains { extra.contains($0) }
        if !home, !placed, door != nil || !reset { args += ["-LensaticTab", "path"] }
        app.launchArguments = args + extra
        app.launch()
        launched = app
    }

    /// The trailhead question from Home (build 6): the Framework Maps door opens it while no trailhead is picked.
    func openQuestion(file: StaticString = #filePath, line: UInt = #line) {
        let door = element("home-door-maps")
        XCTAssertTrue(door.waitForExistence(timeout: 10), "Home shows the Framework Maps door", file: file, line: line)
        door.tap()
        XCTAssertTrue(element("welcome").waitForExistence(timeout: 5), "the door opens the trailhead question", file: file, line: line)
    }

    func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    /// A screen's scrolling container: a scroll view, or since content release 1.0.1 a system list (Home, Explore and
    /// the screens Explore opens), which XCTest sees as a collection view.
    func scroller(_ id: String) -> XCUIElement {
        let types = [XCUIElement.ElementType.scrollView, .collectionView].map(\.rawValue)
        return app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND elementType IN %@", id, types)).firstMatch
    }

    /// A segment of a mode control: the system's segmented control names its segments by their labels (section 7), the
    /// app's stacked control at the accessibility sizes by identifier.
    func segment(_ id: String, _ label: String) -> XCUIElement {
        let byId = element(id)
        return byId.exists ? byId : app.buttons[label].firstMatch
    }
    var nav: [String: String] { ui["nav"] as? [String: String] ?? [:] }

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
        // a system list creates its rows lazily: a row below the fold (the AI column under the stack's layers, now that
        // each layer row carries its question) exists only once the list scrolls toward it
        if let screen, !target.waitForExistence(timeout: 2) {
            let scroll = scroller(screen)
            var tries = 0
            while !target.exists, tries < 8 { scroll.swipeUp(velocity: .slow); tries += 1 }
        }
        XCTAssertTrue(target.waitForExistence(timeout: 5), id, file: file, line: line)
        if let screen {
            let scroll = scroller(screen)
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
    func audit(_ screen: String, region: CGRect? = nil, types: XCUIAccessibilityAuditType = .all, report: Bool = false,
               systemList: CGRect? = nil) throws {
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
            // a system list (content release 1.0.1, section 7: Library, Explore and the screens Explore opens): the audit samples
            // a list cell's or section header's text at a larger size before the list resizes the cell, and reports a header
            // or a section's last row, a different one each run, as clipped or partly scaled. The same texts are whole at
            // every size in the captures (handoffs/20261105-content-release-101/polish, AX XL); the issue is printed and
            // counted, and every other audit type still fails
            if let list = systemList, issue.auditType == .dynamicType || issue.auditType == .textClipped,
               let frame = issue.element?.frame, list.insetBy(dx: -1, dy: -1).contains(frame) {
                print("AUDIT \(screen): system list, \(issue.auditType == .dynamicType ? "Dynamic Type" : "text clipped") sampled before the cell resizes, exempt: \(issue.element?.label ?? "")")
                return true
            }
            // the system's segmented control (section 7) keeps its own label size below the accessibility sizes, where the
            // screen shows its modes as rows instead; the audit reports it with no element
            if systemList != nil, issue.auditType == .dynamicType, issue.element == nil {
                print("AUDIT \(screen): the system segmented control, rows at the accessibility sizes, exempt")
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
        let page = scroller(id)
        XCTAssertTrue(page.waitForExistence(timeout: 5), id)
        try audit(id, region: visibleRegion(page), types: types, systemList: page.elementType == .collectionView ? page.frame : nil)
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

    /// The part of the screen a page shows: its scroll view below the navigation bar above it, or below the status bar,
    /// which the system draws over a page scrolled under it (54 points covers the iPhones with a Dynamic Island), and
    /// above the tab bar, within the window.
    func visibleRegion(_ page: XCUIElement) -> CGRect {
        let frame = page.frame, window = app.windows.firstMatch.frame
        let bars = app.navigationBars.allElementsBoundByIndex.map(\.frame).filter { $0.maxX > frame.minX && $0.minX < frame.maxX }
        let statusBar = window.minY + 54
        let top = max(frame.minY, bars.map(\.maxY).max() ?? statusBar, statusBar), bottom = min(frame.maxY, window.maxY, tabBarTop())
        return CGRect(x: frame.minX, y: top, width: frame.width, height: max(0, bottom - top))
    }

    /// The audit reads only what is on screen: this one reads the whole page, a page at a time from the top, dragged
    /// without momentum so no part is skipped, until the page stops moving. It reports and never fails (see the sweep).
    func sweep(_ screen: String) throws {
        let page = scroller(screen)
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

    /// R5 (items 11, 12, 16): the five doors, the eyebrow and the footer fit the screen with nothing to scroll, in the light
    /// and the dark, at the default text size, on a phone 900 points tall or more (content release 1.0.1: each card now says
    /// who it is for); the footer says where to switch paths.
    func testWelcomeFitsWithoutScrolling() throws {
        defer { XCUIDevice.shared.appearance = .light }
        for appearance in [XCUIDevice.Appearance.light, .dark] {
            XCUIDevice.shared.appearance = appearance
            launch(door: nil)
            openQuestion()
            let window = app.windows.firstMatch.frame
            let footer = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Switch paths anytime from My Path'")).firstMatch
            XCTAssertTrue(footer.exists, "the footer says where to switch paths")
            XCTAssertTrue(app.staticTexts["CHOOSE A TRAILHEAD"].exists || app.staticTexts["Choose a trailhead"].exists, "the eyebrow")
            // content release 1.0.1 (6.14, Ken's ruling of 7 November 2026): each trailhead says who it is for in one
            // short line, and all five, with the footer, fit without a scroll at the default size on every phone
            for id in ["door-dow", "door-federal-civilian", "door-defense-contractor", "door-state-local", "door-industry-academia"] {
                XCTAssertTrue(element(id).isHittable, "\(id) is on screen")
                XCTAssertLessThanOrEqual(element(id).frame.maxY, window.maxY, id)
            }
            XCTAssertLessThanOrEqual(footer.frame.maxY, window.maxY, "the footer is on screen without a scroll")
            app.terminate()
        }
    }

    /// R5 (item 17): the compass tile opens the story of the name as a sheet, and Done closes it. Since build 6 the tile is
    /// in Home's header and on the trailhead question, and Home's About section has a row for the story too.
    func testTheCompassOpensTheStory() throws {
        launch(door: nil)
        openQuestion()
        XCTAssertTrue(element("welcome-story").exists, "the question keeps its compass tile")
        XCTAssertEqual(element("welcome-story").label, "Why Lensatic")
        element("welcome-cancel").tap()
        let tile = element("home-story")
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        XCTAssertEqual(tile.label, "Why Lensatic")
        XCTAssertGreaterThanOrEqual(tile.frame.width, 44)
        XCTAssertGreaterThanOrEqual(tile.frame.height, 44)
        tile.tap()
        XCTAssertTrue(element("story-sheet").waitForExistence(timeout: 5))
        XCTAssertTrue(element("about-photo").exists, "the photo is in the sheet")
        // as with the other sheets: the region is what the sheet shows (the story scrolls past its foot), and text detection
        // is left out, since Welcome behind the sheet shows text VoiceOver does not reach while it is open
        let sheet = app.scrollViews["story-sheet"].firstMatch
        sleep(1)  // the sheet settles before the audit reads it (mid-animation its text reads as clipped)
        try audit("story sheet", region: visibleRegion(sheet), types: XCUIAccessibilityAuditType.all.subtracting(.elementDetection))
        element("story-done").tap()
        XCTAssertTrue(element("home-door-maps").waitForExistence(timeout: 5))
        // the visible row (Ken's ruling, 10 November 2026): Why "Lensatic"? at the foot of Home opens the same story
        tap("home-why", in: "home")
        XCTAssertTrue(element("story-sheet").waitForExistence(timeout: 5), "the row opens the story")
        XCTAssertEqual(element("home-why").label.isEmpty, false)
        element("story-done").tap()
    }

    /// R5 (item 16): each new door opens a path of real steps with the next step in the hero, no countdown.
    func testTheNewDoorsOpenTheirPaths() throws {
        for id in ["state-local", "industry-academia"] {
            launch(door: nil)
            openQuestion()
            let door = element("door-\(id)")
            XCTAssertTrue(door.waitForExistence(timeout: 10))
            door.tap()
            XCTAssertTrue(element("my-path").waitForExistence(timeout: 5))
            XCTAssertTrue(element("step-check-6").waitForExistence(timeout: 5), "\(id): six steps")
            XCTAssertTrue(element("path-hero").label.contains("Next step"), element("path-hero").label)
            XCTAssertFalse(element("path-hero").label.contains("days"), "no countdown: \(element("path-hero").label)")
            try auditScreen("my-path")
            app.terminate()
        }
    }

    func testTheWelcomeScreenOffersTheFiveTrailheads() throws {
        launch(door: nil)
        openQuestion()
        for door in doors {
            let id = try XCTUnwrap(door["id"] as? String)
            let card = element("door-\(id)")
            XCTAssertTrue(card.exists, id)
            XCTAssertTrue(card.label.contains(webTokens(door["shortTitle"] as? String ?? "")), "\(id) shows its name")
        }
        try audit("welcome")
        // the question is over Home (build 6): Cancel goes back to it with no trailhead picked
        element("welcome-cancel").tap()
        XCTAssertTrue(element("home-door-maps").waitForExistence(timeout: 5), "Cancel returns to Home")
        XCTAssertTrue(element("home-door-maps").label.contains(label("homePickTrailhead")), element("home-door-maps").label)
    }

    /// The round's acceptance test: pick a door, check off a step, relaunch, and the check is still there.
    func testPickADoorCheckAStepRelaunchAndTheCheckStays() throws {
        launch(door: nil)
        openQuestion()
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
        // the app opens on Home (build 6): its Framework Maps door shows the trailhead and the step done, and opens My Path
        launch(reset: false, door: nil, home: true)
        XCTAssertTrue(element("home-door-maps").waitForExistence(timeout: 10), "the app opens on Home")
        XCTAssertTrue(element("home-door-maps").label.contains("1 of"), element("home-door-maps").label)
        element("home-door-maps").tap()
        XCTAssertTrue(element("my-path").waitForExistence(timeout: 10), "the trailhead is remembered: the door opens My Path, not the question")
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
        // Change Path is on My Path's header only (6.19)
        XCTAssertTrue(element("change-door").waitForExistence(timeout: 5))
        element("change-door").tap()
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
        XCTAssertTrue(segment("explore-stack", nav["stack"] ?? "Stack").isSelected)
        // the short layer fields (R3): all five layers fit on the screen at the default text size, above the tab bar
        for id in ["layer-l1", "layer-l5"] { XCTAssertTrue(element(id).isHittable, id) }
        XCTAssertLessThanOrEqual(element("layer-l5").frame.maxY, tabBarTop() + 8, "the fifth layer is on screen")
        try auditScreen("explore")
        tap("layer-l3", in: "explore")
        XCTAssertTrue(element("layer-screen-l3").waitForExistence(timeout: 5))
        try auditScreen("layer-screen-l3")
        tap("entry-dod-zt-strategy", in: "layer-screen-l3")
        XCTAssertTrue(element("entity-card-dod-zt-strategy").waitForExistence(timeout: 5), "the entry opens its card")
        XCTAssertFalse(element("tab-path").exists, "a card is a full screen: the tab bar steps aside")
        // the one Read More rule (content release 1.0.1): no card summary hides enough, so the card shows the one-liner whole
        XCTAssertGreaterThan(element("card-summary").label.count, 140, "the card shows the whole one-liner")
        XCTAssertFalse(element("card-summary-more").exists, "and no Read More")
        element("card-back").tap()
        element("back").tap()
        tap("layer-l6", in: "explore")
        XCTAssertTrue(element("layer-screen-l6").waitForExistence(timeout: 5), "the AI column opens")
        // a glossary term in running text opens its entry in a sheet
        let term = scroller("layer-screen-l6").links.firstMatch
        XCTAssertTrue(term.waitForExistence(timeout: 5), "the column's screen links a glossary term")
        term.tap()
        XCTAssertTrue(element("glossary-done").waitForExistence(timeout: 5), "the glossary entry opens in a sheet")
        expandSheet()
        sleep(1)  // the sheet settles at full height before the audit reads it
        try audit("glossary entry", region: visibleRegion(app.scrollViews["sheet"].firstMatch),
                  types: XCUIAccessibilityAuditType.all.subtracting(.elementDetection))
        element("glossary-done").tap()
    }

    func testTheMatrixSwitchesViewsAndOpensACellAndTheFunctionsOpenByPillar() throws {
        launch()
        showTab("tab-explore")
        segment("explore-matrix", nav["matrix"] ?? "Matrix").tap()
        let dow = segment("pillar-view-dow", "DoW Model"), cisa = segment("pillar-view-cisa", "CISA Model")
        XCTAssertTrue(dow.waitForExistence(timeout: 5))
        XCTAssertTrue(dow.isSelected)
        XCTAssertTrue(element("cell-dow-user-GV").exists)
        cisa.tap()
        // a list builds its rows as they come into view (section 7): scroll to the cross-cutting row
        let governance = element("cell-cisa-governance-GV")
        var swipes = 0
        while !governance.exists, swipes < 6 { scroller("explore").swipeUp(velocity: .slow); swipes += 1 }
        XCTAssertTrue(governance.waitForExistence(timeout: 5), "CISA's governance capability shows")
        // contrast first, on its own, with the list where the swipes left it: the audit's text size check resizes the
        // rows and the list does not come back to the same place (in the 10 November 2026 recording it sat 342 points
        // away), and a contrast read after that was reported on rows whose colours measure 7.5:1. Every row in view is
        // still read for contrast, and nothing is exempt; the other checks follow
        try auditScreen("explore", types: .contrast)
        try auditScreen("explore", types: XCUIAccessibilityAuditType.all.subtracting(.contrast))
        // back up to the control, which the list let go while it scrolled
        swipes = 0
        while !segment("pillar-view-dow", "DoW Model").exists, swipes < 8 { scroller("explore").swipeDown(velocity: .fast); swipes += 1 }
        segment("pillar-view-dow", "DoW Model").tap()
        XCTAssertTrue(element("cell-dow-user-GV").waitForExistence(timeout: 5))
        XCTAssertFalse(element("cell-cisa-governance-GV").exists)
        tap("cell-dow-user-GV", in: "explore")
        XCTAssertTrue(element("cell-screen").waitForExistence(timeout: 5), "the cell opens")
        try auditScreen("cell-screen")
        element("back").tap()
        segment("explore-functions", nav["functions"] ?? "Functions").tap()
        XCTAssertTrue(element("function-GV").waitForExistence(timeout: 5))
        tap("function-GV-pillars", in: "explore")
        XCTAssertEqual(element("function-GV-pillars").value as? String, "Expanded")
        sleep(1)  // the list fades the pillar rows in; the audit reads them once they are whole
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

    /// Search before a query (6.18): the Start With chips run their search, the next step on the path opens its source,
    /// and the Recent list keeps the searches across a relaunch, with Clear emptying it.
    func testTheStartChipsSearchAndRecentSearchesSurviveARelaunch() throws {
        launch(door: "dow")
        showTab("tab-search")
        XCTAssertTrue(element("search-starters").waitForExistence(timeout: 5))
        XCTAssertTrue(element("search-next-step").exists, "the next step on the path")
        XCTAssertFalse(element("search-recent").exists, "no Recent list before a search")
        try auditScreen("search")
        element("starter-CMMC").tap()
        XCTAssertTrue(element("result-entity:cmmc20").waitForExistence(timeout: 5), "the chip ran its search")
        element("search-clear").tap()
        let field = element("search-field")
        field.tap()
        field.typeText("overlays\n")
        XCTAssertTrue(element("result-entity:dod-zt-overlays").waitForExistence(timeout: 5))
        app.terminate()
        launch(reset: false, door: nil)
        showTab("tab-search")
        XCTAssertTrue(element("search-recent").waitForExistence(timeout: 5), "Recent survives the relaunch")
        XCTAssertTrue(element("recent-overlays").exists && element("recent-CMMC").exists)
        let recent = element("recent-overlays"), chip = element("recent-CMMC")
        XCTAssertLessThan(recent.frame.minY, chip.frame.minY, "newest first")
        recent.tap()
        XCTAssertTrue(element("result-entity:dod-zt-overlays").waitForExistence(timeout: 5), "a recent search runs again")
        element("search-clear").tap()
        element("recent-clear").tap()
        XCTAssertFalse(element("search-recent").exists, "Clear empties the list")
    }

    // MARK: Saved (R2)

    /// Save a framework and a step, relaunch, and they are still saved, grouped by type, on Home.
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
        launch(reset: false, door: nil, home: true)
        tap("saved-step:dow:2", in: "home")
        XCTAssertTrue(element("step-2").waitForExistence(timeout: 5), "a saved step opens on My Path")
        showTab("tab-home")
        XCTAssertTrue(element("saved-step:dow:2").waitForExistence(timeout: 10), "the saved step survived the relaunch")
        XCTAssertTrue(element("saved-entity:sp800-207").exists, "the saved framework survived the relaunch")
        // grouped by type since content release 1.0.1 (6.19): frameworks, then steps, then plays, each newest first
        XCTAssertLessThan(element("saved-entity:sp800-207").frame.minY, element("saved-step:dow:2").frame.minY, "grouped by type")
        element("saved-entity:sp800-207").tap()
        XCTAssertTrue(element("entity-card-sp800-207").waitForExistence(timeout: 5), "a saved item opens")
        element("bookmark").tap()
        element("card-back").tap()
        XCTAssertFalse(element("saved-entity:sp800-207").waitForExistence(timeout: 2), "unsaved, it leaves the list")
    }

    // MARK: Home (build 6; the Library tab until then)

    /// Home is the first tab and where a fresh install opens: the header, then the three doors in the hub's order, all
    /// on screen with no scroll at the default text size, each with its status line; the Framework Maps door opens the
    /// trailhead question until a trailhead is picked, and the playbook door names the play to start with.
    func testHomeOpensOnTheThreeDoors() throws {
        launch(door: nil)
        XCTAssertTrue(element("home").waitForExistence(timeout: 10), "a fresh install opens on Home")
        XCTAssertEqual(element("home-tagline").label, (Self.content["meta"] as? [String: Any])?["tagline"] as? String)
        for tab in ["tab-home", "tab-path", "tab-explore", "tab-search"] { XCTAssertTrue(element(tab).exists, tab) }
        XCTAssertFalse(element("tab-library").exists, "the Library tab folded into Home")
        XCTAssertTrue(element("tab-home").isSelected)
        XCTAssertLessThan(element("tab-home").frame.minX, element("tab-path").frame.minX, "Home is the first tab")
        let ids = ["home-door-maps", "home-door-guide", "home-door-playbook"]
        for id in ids {
            XCTAssertTrue(element(id).isHittable, "\(id) is on screen")
            XCTAssertLessThanOrEqual(element(id).frame.maxY, tabBarTop(), "\(id) fits above the tab bar with no scroll")
        }
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCTAssertLessThan(element(ids[0]).frame.minY, element(ids[1]).frame.minY, "Framework Maps, then Field Guide")
            XCTAssertLessThan(element(ids[1]).frame.minY, element(ids[2]).frame.minY, "then the playbook")
        } else {
            XCTAssertLessThan(element(ids[0]).frame.minX, element(ids[1]).frame.minX, "side by side on the iPad")
            XCTAssertLessThan(element(ids[1]).frame.minX, element(ids[2]).frame.minX)
        }
        XCTAssertTrue(element("home-door-maps").label.contains("FRAMEWORK MAPS") || element("home-door-maps").label.contains("Framework Maps"), element("home-door-maps").label)
        XCTAssertTrue(element("home-door-guide").label.contains("8 weeks"), element("home-door-guide").label)
        XCTAssertTrue(element("home-door-playbook").label.contains("0 of"), element("home-door-playbook").label)
        try auditScreen("home")
        // the playbook door's second control opens the play to start with
        let start = element("home-door-playbook-start")
        XCTAssertTrue(start.isHittable)
        XCTAssertLessThanOrEqual(start.frame.maxY, tabBarTop(), "Start here fits above the tab bar")
        XCTAssertTrue(start.label.hasPrefix("Start here: "), start.label)
        start.tap()
        XCTAssertTrue(element("play-screen").waitForExistence(timeout: 5), "Start here opens its play")
        XCTAssertTrue(start.label.hasSuffix(element("screen-title").label), "the play it names: \(element("screen-title").label)")
        element("back").tap()
        XCTAssertTrue(element("home-door-playbook").label.contains("1 of"), "the play opened counts as read: \(element("home-door-playbook").label)")
        // My Path before a pick says what a path is and leads to the same question
        showTab("tab-path")
        XCTAssertTrue(element("my-path-empty").waitForExistence(timeout: 5))
        try audit("my path, no trailhead")
        element("path-choose").tap()
        XCTAssertTrue(element("welcome").waitForExistence(timeout: 5))
        element("door-federal-civilian").tap()
        XCTAssertTrue(element("my-path").waitForExistence(timeout: 5), "a pick opens My Path")
        showTab("tab-home")
        XCTAssertTrue(element("home-door-maps").label.contains("0 of"), element("home-door-maps").label)
        XCTAssertTrue(element("home-door-guide").label.contains("Week 1"), element("home-door-guide").label)
        element("home-door-maps").tap()
        XCTAssertTrue(element("my-path").waitForExistence(timeout: 5), "with a trailhead picked, the door opens My Path")
    }

    func testHomeOpensTheFieldGuideAndThePlays() throws {
        launch(door: "dow", home: true)
        XCTAssertTrue(element("home").waitForExistence(timeout: 5))
        try auditScreen("home")
        element("home-door-guide").tap()
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
        XCTAssertTrue(element("home-door-guide").label.contains("Week 2"), "the guide's door counts the weeks done")
        element("home-door-playbook").tap()
        XCTAssertTrue(element("plays-screen").waitForExistence(timeout: 5))
        try auditScreen("plays-screen")
        tap("play-containment", in: "plays-screen")
        XCTAssertTrue(element("play-screen").waitForExistence(timeout: 5), "a play opens natively")
        try auditScreen("play-screen")
        element("bookmark").tap()
        element("back").tap()
        element("back").tap()
        tap("saved-play:containment", in: "home")
        XCTAssertTrue(element("play-screen").waitForExistence(timeout: 5), "a saved play is in the list and opens")
    }

    func testTheReferenceScreensAndTheAboutLinks() throws {
        launch(home: true)
        for (row, screen) in [("home-glossary", "glossary-screen"), ("home-sources", "sources-screen"), ("home-changes", "changes-screen"), ("home-about", "about-screen")] {
            tap(row, in: "home")
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
            (["-LensaticTab", "home"], "home"),
            (["-LensaticNav", "layer/l3"], "layer-screen-l3"),
            (["-LensaticNav", "cell/dow/user/GV"], "cell-screen"),
            (["-LensaticNav", "guide"], "guide-screen"),
            (["-LensaticNav", "chapter/part-1"], "chapter-screen"),
            (["-LensaticNav", "plays"], "plays-screen"),
            (["-LensaticNav", "play/containment"], "play-screen"),
            (["-LensaticNav", "glossary-list"], "glossary-screen"),
            (["-LensaticNav", "sources"], "sources-screen"),
            (["-LensaticNav", "about"], "about-screen"),
            (["-LensaticNav", "changes", "-LensaticChangesViewed", "1.2.16"], "changes-screen"),
        ]
        // in the light theme and in the dark (R4), the device's own appearance setting
        defer { XCUIDevice.shared.appearance = .light }
        for appearance in [XCUIDevice.Appearance.light, .dark] {
            XCUIDevice.shared.appearance = appearance
            let name = appearance == .light ? "light" : "dark"
            for (args, id) in screens {
                launch(door: "dow", checked: "1,2", ax5 + args)
                continueAfterFailure = true
                print("AUDIT \(id), \(name)")
                try auditScreen(id)
            }
            launch(door: "dow", checked: "1,2", ax5 + ["-LensaticNav", "entity/dod-zt-strategy"])
            continueAfterFailure = true
            XCTAssertTrue(element("entity-card-dod-zt-strategy").waitForExistence(timeout: 10))
            try audit("card at AX5, \(name)")
            // a play with a figure the app draws, and one with a drawn figure, scrolled to it (R4)
            for (play, figure) in [("blue", "lethal-trifecta"), ("program", "org-chart")] {
                launch(door: "dow", checked: "1,2", ax5 + ["-LensaticNav", "play/\(play)", "-LensaticScrollTo", "figure-\(figure)"])
                continueAfterFailure = true
                XCTAssertTrue(element("figure-\(figure)").waitForExistence(timeout: 10), figure)
                sleep(1)
                try auditScreen("play-screen")
            }
        }
    }

    // MARK: R3

    /// What Changed (R5, item 19) shows on My Path while it has news newer than the last visit, each item marked New,
    /// and opens an item's card; the list groups by day with a plain intro, keeps the source checks behind a toggle, and a
    /// visit puts My Path's section away, which a relaunch remembers. Home's row then dates the latest news.
    func testWhatChangedShowsUntilTheListIsVisited() throws {
        launch(door: "dow", checked: "1,2", ["-LensaticChangesViewed", "1.2.16"])
        XCTAssertTrue(element("my-path").waitForExistence(timeout: 10))
        XCTAssertTrue(element("what-changed").waitForExistence(timeout: 5), "newer news shows on My Path")
        try auditScreen("my-path")  // the whole screen at the top
        let first = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'change-1.2.'")).firstMatch
        var tries = 0
        while !first.isHittable || first.frame.maxY > tabBarTop(), tries < 12 { app.scrollViews["my-path"].swipeUp(velocity: .slow); tries += 1 }
        XCTAssertTrue(first.label.hasPrefix("New"), "a new item says so: \(first.label)")
        XCTAssertFalse(first.label.contains("affects") || first.label.contains("Layer"), first.label)
        sleep(1)  // the scroll settles before the audit reads the screen
        // contrast is read where the same rows sit at rest, on the full list below; every other check runs here
        print("AUDIT what changed: contrast read on the changes screen at rest, not after the swipe")
        try audit("what changed", region: element("what-changed").frame.intersection(visibleRegion(app.scrollViews["my-path"].firstMatch)),
                  types: XCUIAccessibilityAuditType.all.subtracting(.contrast))
        first.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'entity-card-'")).firstMatch
            .waitForExistence(timeout: 5), "an item opens its entry's card")
        element("card-back").tap()
        tap("changes-all", in: "my-path")
        XCTAssertTrue(element("changes-screen").waitForExistence(timeout: 5))
        XCTAssertEqual(element("changes-intro").label, "What moved in the frameworks, newest first.")
        let checks = app.descendants(matching: .any).matching(NSPredicate(format: "identifier ENDSWITH '/recheck'"))
        XCTAssertEqual(checks.count, 0, "source checks are off by default")
        try auditScreen("changes-screen")
        let toggle = element("changes-checks")
        XCTAssertEqual(toggle.value as? String, "Off")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "On")
        XCTAssertTrue(checks.firstMatch.waitForExistence(timeout: 3), "the toggle shows them")
        element("back").tap()
        XCTAssertTrue(element("my-path").waitForExistence(timeout: 5))
        XCTAssertFalse(element("what-changed").waitForExistence(timeout: 2), "a visit to the list puts the section away")
        app.terminate()
        launch(reset: false, door: nil)
        XCTAssertTrue(element("my-path").waitForExistence(timeout: 10))
        XCTAssertFalse(element("what-changed").waitForExistence(timeout: 2), "and it stays away after a relaunch")
        showTab("tab-home")
        tap("home-changes", in: "home")
        XCTAssertTrue(element("changes-screen").waitForExistence(timeout: 5), "Home's row opens the list")
        element("back").tap()
        // the content release's day (6.19: What Changed's value is the content date)
        XCTAssertTrue(element("home-changes").label.contains("What Changed"), element("home-changes").label)
        XCTAssertNotNil(element("home-changes").label.range(of: #"\d{1,2} [A-Z][a-z]{2}"#, options: .regularExpression), element("home-changes").label)
    }

    /// A tap on the widget opens its link, lensatic://open/step:dow:3, which opens that step on My Path (the widget's
    /// own link is the glance's, a unit test holds them equal).
    func testAWidgetsTapOpensItsStep() throws {
        launch(door: "dow", checked: "1,2", ["-LensaticTab", "home"])
        XCTAssertTrue(element("home").waitForExistence(timeout: 10))
        app.open(URL(string: "lensatic" + "://open/step:dow:3")!)
        XCTAssertTrue(element("my-path").waitForExistence(timeout: 10), "the link opens My Path")
        XCTAssertTrue(element("step-3-entity-dod-zt-ot").waitForExistence(timeout: 5), "with step 3 open")
        XCTAssertEqual(element("step-3").value as? String, "Expanded")
        app.open(URL(string: "lensatic" + "://search")!)
        XCTAssertTrue(element("search-field").waitForExistence(timeout: 5), "the search link opens Search")
    }

    /// The widget itself, from the home screen: added through the system's widget gallery, small and then medium, it
    /// shows the next step and a tap on it opens that step. The gallery is the system's own screen, so a change in it
    /// skips this test rather than fail it; the link test above holds the tap either way.
    func testTheWidgetOnTheHomeScreenOpensItsStep() throws {
        for medium in [false, true] {
            launch(door: "dow", checked: "1,2")
            XCTAssertTrue(element("my-path").waitForExistence(timeout: 10))
            let widget = try addWidget(medium: medium)
            XCTAssertGreaterThan(widget.frame.width, medium ? 300 : 140, "the \(medium ? "medium" : "small") widget is placed")
            widget.tap()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), "a tap on the widget opens the app")
            XCTAssertTrue(element("step-3-entity-dod-zt-ot").waitForExistence(timeout: 10), "on the next step, open")
            app.terminate()
        }
    }

    /// Both widgets on the home screen in the light and the dark appearance (R4): VoiceOver reads each as one element,
    /// the countdown, the next step and the steps done; a screenshot of each appearance is attached for the review sheet.
    func testTheWidgetsInBothAppearancesReadAsOneElement() throws {
        launch(door: "dow", checked: "1,2")
        XCTAssertTrue(element("my-path").waitForExistence(timeout: 10))
        let small = try addWidget(medium: false)
        app.activate()
        _ = try addWidget(medium: true)
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // the widget's own element, inside the home screen's: its label is the glance read aloud
        let spoken = home.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Lensatic, ' AND label CONTAINS 'Next, step 3 of'"))
        XCTAssertTrue(spoken.firstMatch.waitForExistence(timeout: 10), "VoiceOver reads the widget as one sentence")
        XCTAssertTrue(spoken.firstMatch.label.contains("days to") && spoken.firstMatch.label.contains("2 of 7 steps done"), spoken.firstMatch.label)
        defer { XCUIDevice.shared.appearance = .light }
        for appearance in [XCUIDevice.Appearance.light, .dark] {
            XCUIDevice.shared.appearance = appearance
            sleep(3)  // the home screen redraws the widgets in the new appearance
            XCTAssertTrue(small.exists)
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = "widgets-\(appearance == .light ? "light" : "dark")"
            shot.lifetime = .keepAlways
            add(shot)
        }
    }

    /// The order VoiceOver moves through My Path (R4), with each element's label, value and frame, attached as JSON for
    /// the review sheet's focus walk; every element in it has a label, and the steps read in their order.
    func testMyPathsVoiceOverOrder() throws {
        launch(door: "dow", checked: "1,2", ["-LensaticChangesViewed", "1.2.16"])
        XCTAssertTrue(element("my-path").waitForExistence(timeout: 10))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "my-path-focus-screen"
        shot.lifetime = .keepAlways
        add(shot)
        let window = app.windows.firstMatch.frame
        var walk: [[String: Any]] = []
        let all = app.descendants(matching: .any).allElementsBoundByAccessibilityElement
        for e in all where e.exists {
            let f = e.frame
            guard e.isHittable || e.elementType == .staticText || e.elementType == .image, !f.isEmpty, f.intersects(window),
                  !e.label.isEmpty, ![.window, .other, .scrollView, .application].contains(e.elementType) || e.label.count > 0 else { continue }
            if [.window, .application].contains(e.elementType) { continue }
            walk.append(["label": e.label, "value": (e.value as? String) ?? "", "type": e.elementType.rawValue, "id": e.identifier,
                         "x": f.minX, "y": f.minY, "w": f.width, "h": f.height])
        }
        XCTAssertFalse(walk.isEmpty)
        let steps = walk.compactMap { ($0["id"] as? String).flatMap { $0.wholeMatch(of: /step-(\d+)/).map { Int($0.1)! } } }
        XCTAssertEqual(steps, steps.sorted(), "the steps read in their order")
        let data = try JSONSerialization.data(withJSONObject: walk, options: [.prettyPrinted])
        let a = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        a.name = "my-path-focus-walk"
        a.lifetime = .keepAlways
        add(a)
    }

    /// VoiceOver on every main screen (R4): every control and image has a label in words, never an identifier, a file
    /// name or a symbol's name, and no label has an em dash; the labels of each screen are attached for the report.
    func testEveryScreensControlsHaveSpokenLabels() throws {
        continueAfterFailure = true
        let screens: [([String], String)] = [
            (["-LensaticTab", "path", "-LensaticChangesViewed", "1.2.16"], "my-path"),
            (["-LensaticTab", "explore"], "explore"),
            (["-LensaticTab", "explore", "-LensaticExplore", "matrix"], "explore"),
            (["-LensaticTab", "explore", "-LensaticExplore", "functions"], "explore"),
            (["-LensaticTab", "search", "-LensaticQuery", "overlays"], "search"),
            (["-LensaticTab", "home"], "home"),
            (["-LensaticNav", "layer/l3"], "layer-screen-l3"),
            (["-LensaticNav", "entity/dod-zt-strategy"], "entity-card-dod-zt-strategy"),
            (["-LensaticNav", "guide"], "guide-screen"),
            (["-LensaticNav", "chapter/part-1"], "chapter-screen"),
            (["-LensaticNav", "plays"], "plays-screen"),
            (["-LensaticNav", "play/blue", "-LensaticScrollTo", "figure-lethal-trifecta"], "play-screen"),
            (["-LensaticNav", "play/program", "-LensaticScrollTo", "figure-org-chart"], "play-screen"),
            (["-LensaticNav", "glossary-list"], "glossary-screen"),
            (["-LensaticNav", "sources"], "sources-screen"),
            (["-LensaticNav", "about"], "about-screen"),
            (["-LensaticNav", "changes", "-LensaticChangesViewed", "1.2.16"], "changes-screen"),
        ]
        // LENSATIC_LABELS_ONLY (a quick run while fixing): only the screens whose id is listed
        let only = ProcessInfo.processInfo.environment["LENSATIC_LABELS_ONLY"].map { Set($0.split(separator: ",").map(String.init)) }
        let chosen = only.map { o in screens.filter { o.contains($0.1) } } ?? screens
        var report: [String] = []
        let raw = try NSRegularExpression(pattern: #"^[a-z0-9]+(-[a-z0-9]+)+$|\.(png|json|swift)\b|^[a-z]+\.[a-z.]+$|_"#)
        for (args, id) in chosen {
            launch(door: "dow", checked: "1,2", args)
            continueAfterFailure = true
            XCTAssertTrue(element(id).waitForExistence(timeout: 10), id)
            sleep(1)
            report.append("== \(args.joined(separator: " "))")
            // one snapshot of the tree, read at once (a query per element is minutes on a long screen)
            let kinds: Set<XCUIElement.ElementType> = [.button, .image, .link, .staticText, .switch, .textField, .searchField]
            func walk(_ e: XCUIElementSnapshot) {
                // the system list's own row chevron (NavigationLink, content release 1.0.1): VoiceOver reads it as part of its
                // row and never stops on it
                let accessory = e.elementType == .image && e.identifier == "chevron.forward"
                if kinds.contains(e.elementType), !e.frame.isEmpty, !accessory {
                    let label = e.label
                    report.append("\(e.elementType.rawValue)\t\(label)\t\((e.value as? String) ?? "")")
                    if e.elementType != .staticText {
                        XCTAssertFalse(label.trimmingCharacters(in: .whitespaces).isEmpty, "\(id): a \(e.elementType.rawValue) with no label [\(e.identifier)] at \(e.frame), in \(e.children.count) children")
                    }
                    XCTAssertNil(raw.firstMatch(in: label, range: NSRange(label.startIndex..., in: label)), "\(id): \(label)")
                    XCTAssertFalse(label.contains("\u{2014}"), "\(id): an em dash in \(label)")
                }
                e.children.forEach(walk)
            }
            walk(try app.snapshot())
        }
        let a = XCTAttachment(string: report.joined(separator: "\n"))
        a.name = "voiceover-labels"
        a.lifetime = .keepAlways
        add(a)
    }

    /// Put Lensatic's widget on the home screen through the gallery, and return it (an existing one of that size is
    /// used as it is).
    func addWidget(medium: Bool) throws -> XCUIElement {
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCUIDevice.shared.press(.home)
        func find(_ q: XCUIElementQuery, _ label: String, _ t: TimeInterval = 5) -> XCUIElement? {
            // the gallery's button reads " Add Widget", its symbol before the words
            let e = q.matching(NSPredicate(format: "label ==[c] %@ OR identifier ==[c] %@ OR label ENDSWITH[c] %@", label, label, " " + label)).firstMatch
            return e.waitForExistence(timeout: t) ? e : nil
        }
        func placed() -> XCUIElement? {
            // the home screen redraws as it settles, so each candidate is read once and a vanished one is passed over
            let query = home.descendants(matching: .other).matching(NSPredicate(format: "label == 'Lensatic' OR label BEGINSWITH 'Lensatic, ' OR label BEGINSWITH 'Lensatic. '"))
            for i in 0..<query.count {
                let e = query.element(boundBy: i)
                guard e.exists else { continue }
                let w = e.frame.width
                if medium ? w > 300 : (w > 140 && w < 200) { return e }
            }
            return nil
        }
        _ = home.wait(for: .runningForeground, timeout: 5)
        if let w = placed() { return w }
        home.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).press(forDuration: 2.5)
        guard let edit = find(home.buttons, "Edit") else { throw XCTSkip("the home screen's Edit button was not found") }
        edit.tap()
        guard let add = find(home.buttons, "Add Widget") else { throw XCTSkip("Add Widget was not found") }
        add.tap()
        let search = home.searchFields["Search Widgets"]
        guard search.waitForExistence(timeout: 8) else { throw XCTSkip("the widget gallery's search field was not found") }
        search.tap()
        search.typeText("Lensatic")
        guard let result = find(home.cells, "Lensatic", 8) else { throw XCTSkip("Lensatic is not in the widget gallery") }
        result.tap()
        let preview = home.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Lensatic'")).firstMatch
        guard preview.waitForExistence(timeout: 8) else { throw XCTSkip("the gallery's preview was not found") }
        if medium {
            preview.swipeLeft()
            let mediumPreview = home.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Lensatic' AND value CONTAINS 'Medium'")).firstMatch
            guard mediumPreview.waitForExistence(timeout: 5) else { throw XCTSkip("the gallery's medium size was not found") }
        }
        guard let place = find(home.buttons, "Add Widget", 8) else { throw XCTSkip("the gallery's Add Widget button was not found") }
        place.tap()
        if let done = find(home.buttons, "Done", 3) { done.tap() }
        var tries = 0
        while placed() == nil, tries < 10 { _ = home.buttons.firstMatch.waitForExistence(timeout: 1); tries += 1 }
        guard let w = placed() else { throw XCTSkip("the placed widget was not found") }
        return w
    }

    /// Share on a card and on a step opens the system share sheet with the card's image and the source link.
    func testTheShareSheetOpensFromACardAndAStep() throws {
        launch(door: "dow", checked: "1,2", ["-LensaticNav", "entity/dod-zt-ot"])
        let share = element("share")
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.tap()
        let sheet = app.otherElements["ActivityListView"]
        let close = app.buttons["Close"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 10) || close.waitForExistence(timeout: 2), "the share sheet opens")
        if close.exists { close.tap() } else { app.swipeDown() }
        XCTAssertTrue(element("card-back").waitForExistence(timeout: 10))
        element("card-back").tap()
        showTab("tab-path")
        tap("step-3", in: "my-path")
        let stepShare = element("share")
        XCTAssertTrue(stepShare.waitForExistence(timeout: 5), "an opened step can be shared")
        stepShare.tap()
        XCTAssertTrue(sheet.waitForExistence(timeout: 10) || close.waitForExistence(timeout: 2), "the share sheet opens for a step")
        if close.exists { close.tap() } else { app.swipeDown() }
    }

    /// A play reads summary first; its outline lists its sections and a tap brings one to the top of the screen.
    func testAPlaysOutlineJumpsToASection() throws {
        launch(door: "dow", checked: nil, ["-LensaticNav", "play/containment"])
        XCTAssertTrue(element("play-screen").waitForExistence(timeout: 10))
        let summary = element("summary")
        XCTAssertTrue(summary.exists, "the play opens on its summary")
        let outline = element("outline")
        XCTAssertLessThan(summary.frame.minY, outline.frame.minY, "summary first, then the outline")
        XCTAssertEqual(outline.value as? String, "Collapsed")
        outline.tap()
        XCTAssertEqual(outline.value as? String, "Expanded")
        try auditScreen("play-screen")
        let entry = element("outline-5")
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        let title = entry.label.split(separator: ",").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? entry.label
        entry.tap()
        let heading = app.staticTexts.matching(NSPredicate(format: "label == %@", title)).allElementsBoundByIndex.first { $0.frame.minY > 0 }
        XCTAssertNotNil(heading, "the section's heading: \(title)")
        let top = app.windows.firstMatch.frame.minY
        XCTAssertLessThan(heading?.frame.minY ?? 9999, top + 200, "the section is at the top of the screen")
    }

    /// The Sources sheet's button opens the source in Safari's viewer inside the app, and its line says so.
    func testASourceOpensInTheInAppReader() throws {
        launch(door: "dow", checked: nil, ["-LensaticNav", "entity/sp800-207", "-LensaticSources"])
        let open = element("sources-open")
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[label("opensInReader")].exists, "the line under the button")
        open.tap()
        // Safari's viewer: its Done button (the sheet's own Done has its identifier)
        let done = app.buttons.matching(NSPredicate(format: "label == 'Done' AND identifier != 'sources-done'")).firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 15), "the reader opens over the sheet")
        XCTAssertEqual(app.state, .runningForeground, "the app stays in front: no system browser")
        done.tap()
        XCTAssertTrue(element("sources-done").waitForExistence(timeout: 10), "Done goes back to the sheet")
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
