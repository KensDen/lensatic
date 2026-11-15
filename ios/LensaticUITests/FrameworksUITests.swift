import XCTest

/// The framework navigator (Lensatic 2.0, Round 1), walked the way a first-time reader would: Home leads with the
/// countdown and the frameworks; Browse shows every framework as a card; a framework opens to its real structure, down to
/// an outcome and the controls NIST points it at; FedRAMP opens to its indicators and its baselines; Compare is honest and
/// carries no score; the readiness check keeps its answers on the device and ends in what to do next. Each screen passes
/// the accessibility audit.
extension LensaticUITests {
    /// The navigator's screens, for the audit at the largest text size and the spoken labels.
    static let frameworkScreens: [([String], String)] = [
        (["-LensaticTab", "frameworks"], "frameworks"),
        (["-LensaticNav", "framework/fedramp"], "framework-screen"),
        (["-LensaticNav", "node/csf20/GV.OC-01"], "node-screen"),
        (["-LensaticNav", "baseline/fedramp/rev5-class-b"], "baseline-screen"),
        (["-LensaticNav", "compare/compare-csf20-sp800-53"], "compare-screen"),
        (["-LensaticNav", "check/check-csf20", "-LensaticAnswers", "check-csf20:yes,partly,no"], "check-screen"),
    ]

    /// The pushed screen's title as its words: the app keeps a designation and its number on one line with a no-break space.
    func title() -> String { element("screen-title").label.replacingOccurrences(of: "\u{00A0}", with: " ") }

    static let frameworkIds = ["csf20", "iso27001", "sp800-207", "dod-zt", "cisa-ztmm", "sp800-53", "sp800-171", "cis", "rmf", "fedramp", "il", "cmmc",
                               "govramp", "cjis", "ai-rmf", "ir8596", "attack", "d3fend", "aml"]

    /// Home (Lensatic 2.0): the countdown opens the framework that sets it, and the frameworks card says how many there are
    /// and names a reader's own framework. On a phone (Round 2, ruling 7) the countdown and the card are compact, so all
    /// three doors, the playbook's start row included, are on the first screen at the default text size; where the card
    /// keeps its three controls (the iPad) they open Browse, Compare and the self-checks.
    func testHomeLeadsWithTheCountdownAndTheFrameworks() throws {
        launch(door: nil)
        XCTAssertTrue(element("home").waitForExistence(timeout: 10))
        let countdown = element("home-countdown")
        XCTAssertTrue(countdown.label.contains("days: Target Level zero trust"), countdown.label)
        XCTAssertTrue(countdown.label.contains("2027"), countdown.label)
        XCTAssertTrue(element("home-frameworks").label.contains("\(Self.frameworkIds.count) frameworks"), element("home-frameworks").label)
        // a reader's own framework is named on the first screen and is one tap away
        XCTAssertTrue(element("home-framework-fedramp").isHittable && element("home-framework-iso27001").isHittable)
        if UIDevice.current.userInterfaceIdiom == .phone {
            // every door on the first screen, above the tab bar, with nothing scrolled
            for id in ["home-countdown", "home-frameworks", "home-door-maps", "home-door-guide", "home-door-playbook", "home-door-playbook-start"] {
                XCTAssertTrue(element(id).isHittable, "\(id) is on the first screen")
                XCTAssertLessThanOrEqual(element(id).frame.maxY, tabBarTop(), "\(id) ends above the tab bar")
            }
            XCTAssertFalse(element("home-frameworks-compare").exists, "the compact card leaves Compare to the Frameworks tab")
            element("home-frameworks").tap()
            XCTAssertTrue(element("framework-card-csf20").waitForExistence(timeout: 5), "the card opens Browse")
        } else {
            element("home-frameworks-compare").tap()
            XCTAssertTrue(element("compare-card-compare-csf20-sp800-53").waitForExistence(timeout: 5), "Compare opens on the comparisons")
            showTab("tab-home")
            element("home-frameworks-check").tap()
            XCTAssertTrue(element("check-card-check-csf20").waitForExistence(timeout: 5), "Self-Checks opens the list of checks")
            showTab("tab-home")
            element("home-frameworks-browse").tap()
            XCTAssertTrue(element("framework-card-csf20").waitForExistence(timeout: 5), "Browse opens on the cards")
        }
        XCTAssertTrue(element("tab-frameworks").isSelected)
        showTab("tab-home")
        element("home-framework-fedramp").tap()
        XCTAssertTrue(element("framework-screen").waitForExistence(timeout: 5))
        XCTAssertTrue(element("framework-note").label.contains("FedRAMP Authorized"), "the new words are tied to the old ones")
        showTab("tab-home")
        element("home-countdown").tap()
        XCTAssertTrue(element("framework-screen").waitForExistence(timeout: 5), "the countdown opens its framework")
        XCTAssertEqual(title(), "DoD Zero Trust Strategy")
        XCTAssertTrue(reveal("framework-countdown", in: "framework-screen").exists)
    }

    /// Browse: every framework is a card that reads as one sentence, grouped the way the stack is ordered; a card with a
    /// dated deadline counts down; the adversary column says it is not compliance; other standards land.
    func testBrowseShowsEveryFrameworkAsACard() throws {
        launch(door: nil, ["-LensaticTab", "frameworks"])
        XCTAssertTrue(element("frameworks").waitForExistence(timeout: 10))
        XCTAssertTrue(element("tab-frameworks").isSelected)
        let first = element("framework-card-csf20")
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(first.label.hasPrefix("CSF 2.0, Outcomes."), first.label)
        for part in ["Binds: Voluntary", "Assessment: Self-described", "106 Subcategories", "Layer 1"] { XCTAssertTrue(first.label.contains(part), "\(part): \(first.label)") }
        try auditScreen("frameworks")
        // the jump row brings a group's cards up in one tap
        element("frameworks-jump-authorization").tap()
        XCTAssertTrue(element("framework-card-fedramp").waitForExistence(timeout: 5))
        var last: CGFloat = -.greatestFiniteMagnitude
        for id in Self.frameworkIds {
            let card = reveal("framework-card-\(id)", in: "frameworks")
            XCTAssertFalse(card.label.isEmpty, id)
            if UIDevice.current.userInterfaceIdiom == .phone, id == "sp800-207" || id == "fedramp" { last = card.frame.minY }
            switch id {
            case "dod-zt": XCTAssertTrue(card.label.contains("days: Target Level zero trust"), card.label)
            case "fedramp": XCTAssertTrue(card.label.contains("FedRAMP Certified") && card.label.contains("days: "), card.label)
            case "iso27001": XCTAssertTrue(card.label.contains("Layers 1, 4 and 5") && card.label.contains("Accredited certification"), card.label)
            case "attack": XCTAssertTrue(card.label.contains("Adversary column") && card.label.contains("Not a compliance check"), card.label)
            case "sp800-53": XCTAssertTrue(card.label.contains("20 Families, 300 Controls, 714 Enhancements"), card.label)
            default: break
            }
        }
        _ = last
        let soc = reveal("landing-soc2", in: "frameworks")
        XCTAssertTrue(element("landing-hipaa").exists && element("landing-pci-dss").exists)
        tap("landing-soc2", in: "frameworks")
        XCTAssertTrue(element("landing-screen").waitForExistence(timeout: 5), soc.label)
        XCTAssertEqual(title(), "SOC 2")
        XCTAssertTrue(reveal("framework-row-fedramp", in: "landing-screen").exists, "it lands on a framework here")
        try auditScreen("landing-screen")
    }

    /// CSF 2.0 at full depth: Function, Category, Subcategory with NIST's text, then the SP 800-53 controls NIST points
    /// it at, and from a control back to the outcomes and baselines that name it.
    func testAFrameworkOpensDownToAnOutcomeAndItsControls() throws {
        launch(door: nil, ["-LensaticNav", "framework/csf20"])
        XCTAssertTrue(element("framework-screen").waitForExistence(timeout: 10))
        XCTAssertEqual(title(), "NIST Cybersecurity Framework 2.0")
        XCTAssertFalse(element("framework-purpose").label.isEmpty)
        try auditScreen("framework-screen")
        tap("node-row-GV", in: "framework-screen")
        XCTAssertTrue(element("node-screen").waitForExistence(timeout: 5))
        XCTAssertEqual(title(), "GV Govern")
        tap("node-row-GV.OC", in: "node-screen")
        XCTAssertTrue(element("node-row-GV.OC-01").waitForExistence(timeout: 5), "a Category lists its Subcategories")
        tap("node-row-GV.OC-01", in: "node-screen")
        XCTAssertTrue(element("node-text").waitForExistence(timeout: 5))
        XCTAssertEqual(element("node-text").label, "The organizational mission is understood and informs cybersecurity risk management")
        try auditScreen("node-screen")
        // the controls NIST's references point this outcome at, each by identifier and title
        let control = reveal("node-row-PM-11", in: "node-screen")
        XCTAssertTrue(control.label.contains("PM-11") && control.label.contains("Mission and Business Process Definition"), control.label)
        tap("node-row-PM-11", in: "node-screen")
        XCTAssertTrue(element("screen-title").waitForExistence(timeout: 5))
        XCTAssertEqual(title(), "PM-11 Mission and Business Process Definition")
        XCTAssertTrue(reveal("node-row-GV.OC-01", in: "node-screen").exists, "and the control names the outcomes that point at it")
        // the framework says how much of the publisher's structure it shows
        launch(door: nil, ["-LensaticNav", "framework/csf20"])
        XCTAssertEqual(reveal("framework-depth", in: "framework-screen").label, "Lensatic shows 106 of 106 Subcategories.")
        // a framework with no depth this round shows its card and sources only
        launch(door: nil, ["-LensaticNav", "framework/iso27001"])
        XCTAssertTrue(element("framework-screen").waitForExistence(timeout: 10))
        XCTAssertFalse(element("framework-depth").exists)
        XCTAssertTrue(element("framework-note").label.contains("37 organizational"), "a page that stops at the card says what it shows, at the top")
        XCTAssertTrue(reveal("source-iso27001-catalogue", in: "framework-screen").label.contains("checked"), "a source says when it was checked")
        try auditScreen("framework-screen")
        // the adversary column says what it is not
        launch(door: nil, ["-LensaticNav", "framework/attack"])
        XCTAssertTrue(element("framework-not-compliance").waitForExistence(timeout: 10))
        XCTAssertTrue(reveal("framework-notice", in: "framework-screen").label.contains("The MITRE Corporation"), "MITRE's notice is shown with its material")
    }

    /// FedRAMP at full depth: the countdown to its next dated rule, its Key Security Indicators with FedRAMP's own
    /// statements, and its Rev5 baselines as counted selections of SP 800-53.
    func testFedRAMPOpensItsIndicatorsAndItsBaselines() throws {
        launch(door: nil, ["-LensaticNav", "framework/fedramp"])
        XCTAssertTrue(element("framework-screen").waitForExistence(timeout: 10))
        XCTAssertTrue(reveal("framework-countdown", in: "framework-screen").label.contains("days: "), element("framework-countdown").label)
        tap("node-row-KSI-CNA", in: "framework-screen")
        XCTAssertTrue(element("node-screen").waitForExistence(timeout: 5))
        tap("node-row-KSI-CNA-EIS", in: "node-screen")
        XCTAssertTrue(element("node-note").waitForExistence(timeout: 5))
        XCTAssertEqual(element("node-note").label, "Optional for Class B.")
        try auditScreen("node-screen")
        launch(door: nil, ["-LensaticNav", "framework/fedramp"])
        XCTAssertTrue(element("framework-screen").waitForExistence(timeout: 10))
        XCTAssertTrue(reveal("framework-depth", in: "framework-screen").label.hasPrefix("Lensatic shows 46 of 46 Key Security Indicators."))
        tap("baseline-row-rev5-class-d", in: "framework-screen")
        XCTAssertTrue(element("baseline-screen").waitForExistence(timeout: 5))
        XCTAssertEqual(title(), "Rev5 Class D Baseline")
        XCTAssertEqual(element("baseline-count").label, "409 of the 1,014 controls and enhancements in SP 800-53")
        XCTAssertTrue(element("baseline-line").label.contains("no longer list CA-5"), "the count that surprises says why")
        try auditScreen("baseline-screen")
        tap("node-row-AC-2", in: "baseline-screen")
        XCTAssertTrue(element("node-screen").waitForExistence(timeout: 5))
        XCTAssertEqual(title(), "AC-2 Account Management")
        XCTAssertTrue(reveal("membership-fedramp-rev5-class-d", in: "node-screen").exists, "a control names the baselines that select it")
    }

    /// Compare: the same questions asked of both, how they connect, the overlap counted from NIST's references, and a
    /// plain statement that there is no score.
    func testCompareIsHonestAndCarriesNoScore() throws {
        launch(door: nil, ["-LensaticTab", "frameworks", "-LensaticFrameworks", "compare"])
        XCTAssertTrue(element("frameworks").waitForExistence(timeout: 10))
        try auditScreen("frameworks")
        tap("compare-card-compare-csf20-sp800-53", in: "frameworks")
        XCTAssertTrue(element("compare-screen").waitForExistence(timeout: 5))
        XCTAssertEqual(title(), "CSF 2.0 with SP 800-53")
        XCTAssertTrue(element("compare-verdict").label.hasPrefix("Not rivals."), element("compare-verdict").label)
        try auditScreen("compare-screen")
        for row in ["Purpose", "Who Must Follow It", "How It Is Assessed"] { XCTAssertTrue(reveal("compare-row-\(row)", in: "compare-screen").exists, row) }
        XCTAssertTrue(reveal("overlap-row-GV", in: "compare-screen").label.contains("31 of 31 Subcategories"), element("overlap-row-GV").label)
        XCTAssertEqual(reveal("compare-reached", in: "compare-screen").label, "In all, the references reach 209 of the 1,014 controls and enhancements in SP 800-53.")
        XCTAssertTrue(reveal("compare-no-score", in: "compare-screen").label.contains("no strictness score"), element("compare-no-score").label)
        // no score, anywhere on the screen
        let texts = app.staticTexts.allElementsBoundByIndex.map(\.label)
        XCTAssertFalse(texts.contains { $0.range(of: #"\b(Low|High|Medium) (vs|versus)\b"#, options: .regularExpression) != nil })
    }

    /// The readiness check: it says it is a self-check before the first question, an answer shows at once in the count and
    /// the next steps, a relaunch finds it, and Start Over forgets it.
    func testTheReadinessCheckKeepsItsAnswersAndListsWhatToDoNext() throws {
        launch(door: nil, ["-LensaticNav", "check/check-csf20"])
        XCTAssertTrue(element("check-screen").waitForExistence(timeout: 10))
        XCTAssertTrue(element("check-honest").label.contains("not an assessment"), element("check-honest").label)
        XCTAssertEqual(element("check-answered").label, "0 of 22 answered")
        try auditScreen("check-screen")
        tap("check-GV.OC-no", in: "check-screen")
        XCTAssertTrue(element("check-GV.OC-no").isSelected)
        tap("check-GV.RM-yes", in: "check-screen")
        launch(reset: false, door: nil, ["-LensaticNav", "check/check-csf20"])
        XCTAssertTrue(element("check-screen").waitForExistence(timeout: 10))
        XCTAssertEqual(element("check-answered").label, "2 of 22 answered", "the answers are still there after a relaunch")
        try auditScreen("check-screen")
        // the next steps are after the questions, so answering never moves the question under the finger
        XCTAssertTrue(reveal("check-next-GV.OC", in: "check-screen").exists, "what is not yet in place is what to do next")
        XCTAssertFalse(element("check-next-GV.RM").exists, "what is in place needs no step")
        tap("check-next-GV.OC", in: "check-screen")
        XCTAssertTrue(element("node-screen").waitForExistence(timeout: 5), "a next step opens the Category it is about")
        XCTAssertEqual(title(), "GV.OC Organizational Context")
        goBack(from: "node-screen")
        tap("check-start-over", in: "check-screen")
        var tries = 0
        while !element("check-answered").exists, tries < 20 { scroller("check-screen").swipeDown(velocity: .fast); tries += 1 }
        XCTAssertEqual(element("check-answered").label, "0 of 22 answered")
    }

    // MARK: Round 2

    /// The compact list is the same frameworks as rows, and the choice survives a relaunch; Compare sets any two cards
    /// side by side, counts an overlap only where a publisher prints a crosswalk, and says so where none does; the
    /// self-checks are a view of their own.
    func testTheCompactListAndCompareForAnyTwo() throws {
        launch(door: nil, ["-LensaticTab", "frameworks"])
        XCTAssertTrue(element("frameworks").waitForExistence(timeout: 10))
        tap("frameworks-view-list", in: "frameworks")
        XCTAssertTrue(element("frameworks-view-list").isSelected)
        let row = element("framework-card-csf20")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.hasPrefix("CSF 2.0, Outcomes."), "a row reads as the card does: \(row.label)")
        XCTAssertLessThan(row.frame.height, 90, "a row, not a card")
        try auditScreen("frameworks")
        launch(reset: false, door: nil, ["-LensaticTab", "frameworks"])
        XCTAssertTrue(element("frameworks-view-list").waitForExistence(timeout: 10))
        XCTAssertTrue(element("frameworks-view-list").isSelected, "the view chosen is kept")
        tap("frameworks-view-cards", in: "frameworks")
        // Compare: the picker, then the written comparisons
        launch(door: nil, ["-LensaticTab", "frameworks", "-LensaticFrameworks", "compare"])
        XCTAssertTrue(element("compare-open").waitForExistence(timeout: 10))
        element("compare-open").tap()
        XCTAssertFalse(element("compare-screen").waitForExistence(timeout: 1), "nothing opens until two frameworks are picked")
        for id in ["compare-fedramp-20x-rev5", "compare-fedramp-govramp", "compare-sp800-171-sp800-53", "compare-csf20-iso27001"] {
            XCTAssertTrue(reveal("compare-card-\(id)", in: "frameworks").exists, id)
        }
        // two cards no publisher joins: the facts side by side, and a plain statement that nothing is counted
        launch(door: nil, ["-LensaticNav", "pair/cjis/attack"])
        XCTAssertTrue(element("compare-screen").waitForExistence(timeout: 10))
        XCTAssertEqual(title(), "CJIS with ATT&CK")
        XCTAssertFalse(element("compare-verdict").exists, "no written verdict for a pair nobody wrote one for")
        for row in ["Purpose", "Who Must Follow It", "How It Is Assessed"] { XCTAssertTrue(reveal("compare-row-\(row)", in: "compare-screen").exists, row) }
        XCTAssertTrue(reveal("compare-no-crosswalk", in: "compare-screen").label.contains("counts no overlap"))
        XCTAssertTrue(reveal("compare-no-score", in: "compare-screen").label.contains("no strictness score"))
        try auditScreen("compare-screen")
        // a pair that has a written comparison shows it, whichever order it is asked in
        launch(door: nil, ["-LensaticNav", "pair/iso27001/csf20"])
        XCTAssertTrue(element("compare-screen").waitForExistence(timeout: 10))
        XCTAssertEqual(title(), "CSF 2.0 with ISO/IEC 27001")
        XCTAssertTrue(element("compare-verdict").label.hasPrefix("Complementary."), element("compare-verdict").label)
        XCTAssertTrue(reveal("compare-reached", in: "compare-screen").label.contains("identifiers of ISO/IEC 27001"), element("compare-reached").label)
        // two parts of one framework
        launch(door: nil, ["-LensaticNav", "compare/compare-fedramp-20x-rev5"])
        XCTAssertTrue(element("compare-screen").waitForExistence(timeout: 10))
        XCTAssertEqual(title(), "FedRAMP 20x with FedRAMP Rev5")
        XCTAssertTrue(reveal("set-overlap-rev5-class-c", in: "compare-screen").label.contains("of its 322 controls and enhancements"), element("set-overlap-rev5-class-c").label)
        try auditScreen("compare-screen")
        // the self-checks
        launch(door: nil, ["-LensaticTab", "frameworks", "-LensaticFrameworks", "checks"])
        for id in ["check-csf20", "check-fedramp", "check-cmmc-l1", "check-dod-zt"] { XCTAssertTrue(reveal("check-card-\(id)", in: "frameworks").exists, id) }
        try auditScreen("frameworks")
    }

    /// The new structures open: a model its publisher does not number shows titles alone, a level that is a set opens its
    /// members counted against its own edition, and references to a standard Lensatic does not list are identifiers only.
    func testTheNewStructuresOpenAsTheirPublishersPrintThem() throws {
        launch(door: nil, ["-LensaticNav", "framework/cisa-ztmm"])
        XCTAssertTrue(element("framework-screen").waitForExistence(timeout: 10))
        XCTAssertEqual(reveal("framework-depth", in: "framework-screen").label, "Lensatic shows 40 of 40 functions and capabilities, each at four stages.")
        tap("node-row-identity", in: "framework-screen")
        XCTAssertTrue(element("node-screen").waitForExistence(timeout: 5))
        XCTAssertEqual(title(), "Identity", "a pillar CISA does not number shows its name alone")
        tap("node-row-identity.authentication", in: "node-screen")
        XCTAssertTrue(element("node-row-identity.authentication.optimal").waitForExistence(timeout: 5))
        tap("node-row-identity.authentication.optimal", in: "node-screen")
        XCTAssertTrue(element("node-text").waitForExistence(timeout: 5))
        XCTAssertTrue(element("node-text").label.hasPrefix("Agency continuously validates identity"), element("node-text").label)
        try auditScreen("node-screen")
        // CMMC: the rule's own levels, and Level 2 as a set on SP 800-171 Revision 2
        launch(door: nil, ["-LensaticNav", "framework/cmmc"])
        XCTAssertTrue(element("framework-screen").waitForExistence(timeout: 10))
        try auditScreen("framework-screen")
        tap("baseline-row-level-2", in: "framework-screen")
        XCTAssertTrue(element("baseline-screen").waitForExistence(timeout: 5))
        XCTAssertEqual(title(), "CMMC Level 2")
        XCTAssertEqual(element("baseline-count").label, "110 of the 110 requirements in SP 800-171 Revision 2")
        // the department's activities, with Target Level as a set of its own
        launch(door: nil, ["-LensaticNav", "baseline/dod-zt/target"])
        XCTAssertTrue(element("baseline-screen").waitForExistence(timeout: 10))
        XCTAssertEqual(title(), "Target Level Activities")
        XCTAssertEqual(element("baseline-count").label, "91 of the 152 activities in DoD ZT Strategy")
        try auditScreen("baseline-screen")
        // a CSF outcome: NIST's references to ISO/IEC 27001 are identifiers, and open nothing but the card
        launch(door: nil, ["-LensaticNav", "node/csf20/GV.OC-01"])
        XCTAssertTrue(element("node-screen").waitForExistence(timeout: 10))
        let iso = reveal("node-unlisted-iso27001", in: "node-screen")
        XCTAssertTrue(iso.label.contains("Clause 4.1") && iso.label.contains("does not list"), iso.label)
        XCTAssertTrue(reveal("node-row-P-2", in: "node-screen").label.contains("Risk Management Strategy"), "and its RMF tasks open")
        try auditScreen("node-screen")
        // the adversary column lists identifiers and names under each publisher's notice
        launch(door: nil, ["-LensaticNav", "node/attack/T1059"])
        XCTAssertTrue(element("node-row-T1059.001").waitForExistence(timeout: 10), "a technique lists its sub-techniques")
        launch(door: nil, ["-LensaticNav", "framework/d3fend"])
        XCTAssertTrue(reveal("framework-notice", in: "framework-screen").label.contains("MIT License"), "D3FEND carries every notice its publisher prints")
        launch(door: nil, ["-LensaticNav", "framework/aml"])
        XCTAssertEqual(title(), "MITRE ATLAS\u{2122}")
        XCTAssertTrue(reveal("framework-notice", in: "framework-screen").label.contains("Apache License"))
    }

    /// The routes in: the sixth trailhead offers its own self-check on My Path; Explore's layers list the navigator's
    /// cards and reach the adversary column; an entry's card leads to its framework, which takes a bookmark that Home
    /// keeps; and Search finds an element by its identifier.
    func testTheRoutesIntoTheNavigator() throws {
        launch(door: "cloud-provider")
        XCTAssertTrue(element("my-path").waitForExistence(timeout: 10))
        let check = element("path-check-check-fedramp")
        XCTAssertTrue(check.waitForExistence(timeout: 5))
        XCTAssertTrue(check.label.contains("FedRAMP 20x Readiness Check") && check.label.contains("0 of 10 answered"), check.label)
        try auditScreen("my-path")
        check.tap()
        XCTAssertTrue(element("check-screen").waitForExistence(timeout: 5))
        XCTAssertTrue(element("check-honest").label.contains("not a FedRAMP assessment"), element("check-honest").label)
        tap("check-KSI-IAM-partly", in: "check-screen")
        XCTAssertTrue(element("check-KSI-IAM-partly").isSelected)
        try auditScreen("check-screen")
        // Explore: Layer 5 lists the cards that sit on it, FedRAMP once, as its entry
        showTab("tab-explore")
        XCTAssertTrue(element("explore").waitForExistence(timeout: 5))
        tap("layer-l5", in: "explore")
        XCTAssertTrue(element("layer-screen-l5").waitForExistence(timeout: 5))
        XCTAssertTrue(reveal("entry-fedramp", in: "layer-screen-l5").exists, "FedRAMP is on the stack")
        XCTAssertTrue(reveal("framework-row-il", in: "layer-screen-l5").exists, "and the cards the stack does not hold are listed too")
        XCTAssertFalse(element("framework-row-fedramp").exists, "a card that is an entry is listed once")
        try auditScreen("layer-screen-l5")
        tap("entry-fedramp", in: "layer-screen-l5")
        XCTAssertTrue(element("entity-card-fedramp").waitForExistence(timeout: 5))
        let link = element("card-framework")
        XCTAssertTrue(link.waitForExistence(timeout: 5), "the card names its framework")
        XCTAssertTrue(link.isHittable, "on the card's first screen")
        link.tap()
        XCTAssertTrue(element("framework-screen").waitForExistence(timeout: 5), "the entry's card leads to its framework")
        XCTAssertTrue(element("tab-frameworks").isSelected)
        // the bookmark saves the framework, and Home lists it
        element("bookmark").tap()
        XCTAssertTrue(element("bookmark").isSelected)
        showTab("tab-home")
        XCTAssertTrue(reveal("saved-framework:fedramp", in: "home").label.contains("FedRAMP"), "Home keeps the saved framework")
        // the widget's countdown is chosen on Home (ruling 8): Automatic until the reader picks a deadline
        let countdown = reveal("home-widget-deadline", in: "home")
        XCTAssertTrue(countdown.label.contains("Automatic"), countdown.label)
        countdown.tap()
        let choice = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Target Level zero trust'")).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5), "the menu offers the dated deadlines")
        choice.tap()
        XCTAssertTrue(element("home-widget-deadline").label.contains("Target Level"), element("home-widget-deadline").label)
        // the adversary column, from the stack
        launch(door: "cloud-provider", ["-LensaticTab", "explore"])
        XCTAssertTrue(element("explore").waitForExistence(timeout: 10))
        tap("layer-adversary", in: "explore")
        XCTAssertTrue(element("group-screen").waitForExistence(timeout: 5))
        for id in ["attack", "d3fend", "aml"] { XCTAssertTrue(element("framework-row-\(id)").exists, id) }
        try auditScreen("group-screen")
        // Search by identifier
        launch(door: "cloud-provider", ["-LensaticTab", "search", "-LensaticQuery", "AC-2"])
        XCTAssertTrue(element("result-node:sp800-53:AC-2").waitForExistence(timeout: 10), "an identifier finds its element")
        element("result-node:sp800-53:AC-2").tap()
        XCTAssertTrue(element("node-screen").waitForExistence(timeout: 5))
        XCTAssertEqual(title(), "AC-2 Account Management")
    }
}
