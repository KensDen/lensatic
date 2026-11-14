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
        (["-LensaticTab", "frameworks", "-LensaticFrameworks", "compare"], "frameworks"),
        (["-LensaticNav", "framework/fedramp"], "framework-screen"),
        (["-LensaticNav", "node/csf20/GV.OC-01"], "node-screen"),
        (["-LensaticNav", "baseline/fedramp/rev5-class-b"], "baseline-screen"),
        (["-LensaticNav", "compare/compare-csf20-sp800-53"], "compare-screen"),
        (["-LensaticNav", "check/check-csf20", "-LensaticAnswers", "check-csf20:yes,partly,no"], "check-screen"),
        (["-LensaticNav", "landing/soc2"], "landing-screen"),
    ]

    /// The pushed screen's title as its words: the app keeps a designation and its number on one line with a no-break space.
    func title() -> String { element("screen-title").label.replacingOccurrences(of: "\u{00A0}", with: " ") }

    static let frameworkIds = ["csf20", "iso27001", "sp800-207", "dod-zt", "cisa-ztmm", "sp800-53", "sp800-171", "cis", "rmf", "fedramp", "il", "cmmc",
                               "govramp", "cjis", "ai-rmf", "ir8596", "attack", "d3fend"]

    /// Home (Lensatic 2.0): the countdown opens the framework that sets it; the frameworks card says how many there are
    /// and its three controls open Browse, Compare and the readiness check.
    func testHomeLeadsWithTheCountdownAndTheFrameworks() throws {
        launch(door: nil)
        XCTAssertTrue(element("home").waitForExistence(timeout: 10))
        let countdown = element("home-countdown")
        XCTAssertTrue(countdown.label.contains("days: Target Level zero trust"), countdown.label)
        XCTAssertTrue(countdown.label.contains("2027"), countdown.label)
        XCTAssertTrue(element("home-frameworks").label.contains("\(Self.frameworkIds.count) frameworks"), element("home-frameworks").label)
        // a reader's own framework is named on the first screen and is one tap away
        XCTAssertTrue(element("home-framework-fedramp").isHittable && element("home-framework-iso27001").isHittable)
        element("home-framework-fedramp").tap()
        XCTAssertTrue(element("framework-screen").waitForExistence(timeout: 5))
        XCTAssertTrue(element("framework-note").label.contains("FedRAMP Authorized"), "the new words are tied to the old ones")
        showTab("tab-home")
        element("home-frameworks-compare").tap()
        XCTAssertTrue(element("frameworks").waitForExistence(timeout: 5))
        XCTAssertTrue(element("tab-frameworks").isSelected)
        XCTAssertTrue(element("compare-card-compare-csf20-sp800-53").waitForExistence(timeout: 5), "Compare opens on the comparisons")
        showTab("tab-home")
        element("home-frameworks-check").tap()
        XCTAssertTrue(element("check-screen").waitForExistence(timeout: 5), "Self-Check opens the readiness check")
        showTab("tab-home")
        element("home-frameworks-browse").tap()
        XCTAssertTrue(element("framework-card-csf20").waitForExistence(timeout: 5), "Browse opens on the cards")
        showTab("tab-home")
        element("home-countdown").tap()
        XCTAssertTrue(element("framework-screen").waitForExistence(timeout: 5), "the countdown opens its framework")
        XCTAssertEqual(title(), "DoD Zero Trust Strategy")
        XCTAssertTrue(element("framework-countdown").exists)
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
        XCTAssertTrue(element("framework-countdown").label.contains("days: "), element("framework-countdown").label)
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
}
