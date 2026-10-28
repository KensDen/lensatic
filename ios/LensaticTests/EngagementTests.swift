import SwiftUI
import XCTest
@testable import Lensatic

/// The redesign's third round (R3): What Changed, the App Group's file and the move into it, the widget's glance and
/// its link, the intents, the share card, the haptics, and the new short text (the stack's short layer fields and the
/// chapters' and plays' summaries). Every expected count and word is read from the bundled files.
@MainActor
final class EngagementTests: XCTestCase {
    static let store = try! ContentStore.bundled()
    static let library = try! Library.bundled()
    static let changes = try! Changes.bundled()
    var store: ContentStore { Self.store }
    var library: Library { Self.library }
    var changes: Changes { Self.changes }

    func tempURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lensatic-tests-\(UUID().uuidString)").appendingPathComponent("progress.json")
    }

    func door(_ id: Door.ID) throws -> Door { try XCTUnwrap(store.content.doors.first { $0.id == id }) }

    /// A day in the reader's calendar.
    func day(_ iso: String) -> Date { Calendar.lensatic.date(from: PathPlan.day(iso)!)! }

    // MARK: What Changed

    /// The bundled list is the content's own: generated for this release, every item names an entry that exists, is
    /// dated, keeps the list's writing rules, and runs newest release first.
    func testTheListIsThisReleasesAndEveryItemNamesAnEntry() {
        XCTAssertEqual(changes.contentVersion, store.content.meta.contentVersion)
        XCTAssertFalse(changes.items.isEmpty)
        var last: [Int]?
        for item in changes.items {
            XCTAssertNotNil(store.entities[item.entityId], item.id)
            XCTAssertNotNil(PathPlan.day(item.date), "\(item.id): a date")
            XCTAssertFalse(item.title.contains("\u{2014}") || item.title.contains("\u{2013}") || item.title.hasSuffix("."), item.id)
            XCTAssertTrue(item.title.first?.isUppercase ?? false, item.id)
            let v = Changes.version(item.release)
            if let last { XCTAssertFalse(last.lexicographicallyPrecedes(v), "\(item.id): newest release first") }
            last = v
        }
        // the mockup's own item: the NSA sheet on operational technology, dated by the sheet
        let nsa = changes.items.first { $0.kind == .document && $0.entityId == "nsa-zt" }
        XCTAssertEqual(nsa?.date, "2026-10-08")
    }

    /// The news is what moved in the world (R5, item 19): a document, a link, a moved deadline. The source checks are
    /// apart, and the map's own additions are not news: the two deadlines content 1.2.18 dated, which their sources have
    /// stated all along, make no item.
    func testTheNewsLeavesOutChecksAndTheMapsOwnAdditions() {
        XCTAssertFalse(changes.news.isEmpty)
        XCTAssertTrue(changes.news.allSatisfy { !$0.kind.isCheck })
        XCTAssertFalse(changes.items.contains { $0.kind == .deadline && $0.release == "1.2.18" }, "a date the source always stated is not a change")
        XCTAssertTrue(changes.items.contains { $0.kind == .recheck }, "the checks are still in the list, behind the toggle")
    }

    /// Newer than the last visit means a later release, and only news is ever new: never visited shows all the news,
    /// visited at this release shows none, and visited at an older one shows only the news after it.
    func testNewItemsAreTheNewsOfLaterReleases() throws {
        XCTAssertEqual(changes.new(since: nil), changes.news)
        XCTAssertTrue(changes.new(since: .init(through: changes.contentVersion, on: "2026-10-27")).isEmpty)
        let fresh = changes.new(since: .init(through: "1.2.16", on: "2026-10-01"))
        XCTAssertFalse(fresh.isEmpty)
        XCTAssertTrue(fresh.allSatisfy { Changes.version("1.2.16").lexicographicallyPrecedes(Changes.version($0.release)) && !$0.kind.isCheck })
        // 1.2.10 sorts after 1.2.9: versions compare by number, not by text
        XCTAssertTrue(Changes.version("1.2.9").lexicographicallyPrecedes(Changes.version("1.2.10")))
    }

    /// Every row's line is the same three parts: the kind of change, its day, the entry's short name. On My Path the
    /// news that touches the reader's steps comes first; the full list groups by day, newest first.
    func testEveryRowSaysTheKindTheDayAndTheEntry() throws {
        let dow = try door(.dow)
        let sep = store.label("metaSeparator")
        let nsa = try XCTUnwrap(changes.items.first { $0.entityId == "nsa-zt" && $0.kind == .document })
        XCTAssertEqual(Changes.line(nsa, store: store), ["New document", "8 Oct 2026", "NSA ZT guidance"].joined(separator: sep))
        for item in changes.items {
            let parts = Changes.line(item, store: store).components(separatedBy: sep)
            XCTAssertEqual(parts.count, 3, item.id)
            XCTAssertEqual(parts[1], Rules.formatDate(item.date), item.id)
            XCTAssertEqual(parts[2], store.entities[item.entityId]?.shortName, item.id)
            XCTAssertFalse(parts.joined().contains("Layer") || parts.joined().contains("affects"), item.id)
        }
        let ordered = changes.new(since: nil, door: dow)
        let on = ordered.filter { !Changes.steps($0, on: dow).isEmpty }, off = ordered.filter { Changes.steps($0, on: dow).isEmpty }
        XCTAssertEqual(ordered, on + off, "the news on the reader's path first")
        let days = Changes.byDay(changes.items).map(\.day)
        XCTAssertEqual(days, days.sorted(by: >), "grouped by day, newest first")
        XCTAssertEqual(Set(days).count, days.count, "each day once")
        XCTAssertEqual(Changes.byDay(changes.items).flatMap(\.items).count, changes.items.count)
    }

    /// The Library's row counts the new news ("2 New"), or, with none, gives the day of the newest ("Updated 24 Oct").
    func testTheLibraryLineCountsNewNewsOrDatesTheLatest() {
        let fresh = changes.new(since: .init(through: "1.2.16", on: "2026-10-01")).count
        XCTAssertEqual(changes.libraryLine(since: .init(through: "1.2.16", on: "2026-10-01")), "\(fresh) New")
        let latest = Changes.newestFirst(changes.news).first!.date
        let c = PathPlan.day(latest)!
        XCTAssertEqual(changes.libraryLine(since: .init(through: changes.contentVersion, on: "2026-10-28"), today: day(latest)),
                       "Updated \(c.day!) \(Rules.months[c.month! - 1])")
        XCTAssertTrue(changes.libraryLine(since: .init(through: changes.contentVersion, on: "2026-10-28"), today: day("2030-01-01"))
            .hasSuffix(" \(c.year!)"), "another year's day carries its year")
    }

    /// A reader's first trailhead starts the list from this release; a visit to the list keeps the release and the day in
    /// the progress file, and a relaunch reads them back.
    func testFirstPickAndAVisitAreKeptOnTheDevice() {
        let url = tempURL()
        let model = AppModel(store: store, library: library, changes: changes, progress: ProgressStore(url: url))
        XCTAssertEqual(model.newChanges.count, changes.news.count)
        model.choose(.dow)
        XCTAssertTrue(model.newChanges.isEmpty, "what changed before the reader arrived is not news")
        model.progress.setChangesViewed(.init(through: "1.2.16", on: "2026-10-20"))
        XCTAssertFalse(model.newChanges.isEmpty)
        model.markChangesSeen()
        XCTAssertTrue(model.newChanges.isEmpty)
        let again = ProgressStore(url: url)
        XCTAssertEqual(again.state.changesViewed?.through, changes.contentVersion)
        XCTAssertEqual(again.state.changesViewed?.on, Changes.today())
    }

    // MARK: the App Group's file

    /// An earlier build's file moves into the shared place whole: the trailhead, the checks, the saved items and the
    /// weeks; the old file goes only after the new one is written; an existing shared file is never overwritten.
    func testTheR2FileMovesIntoTheAppGroupWithNothingLost() throws {
        let legacy = tempURL(), shared = tempURL()
        let old = ProgressStore(url: legacy)
        old.choose(.dow)
        old.toggle(.dow, 1)
        old.toggle(.dow, 3)
        old.toggleSaved(.entity("sp800-207"))
        old.toggleSaved(.step(.dow, 2))
        old.toggleWeek("core", 1)
        let before = old.state
        XCTAssertNil(before.changesViewed, "an R2 file has no last view")
        XCTAssertTrue(ProgressStore.migrate(from: legacy, to: shared))
        XCTAssertNil(try? Data(contentsOf: legacy), "the old file is gone")
        let moved = ProgressStore(url: shared)
        XCTAssertEqual(moved.state, before)
        XCTAssertEqual(moved.checked(.dow), [1, 3])
        XCTAssertEqual(moved.saved, [.step(.dow, 2), .entity("sp800-207")])
        // a second move finds the shared file there and leaves it alone
        let other = ProgressStore(url: legacy)
        other.choose(.federalCivilian)
        XCTAssertFalse(ProgressStore.migrate(from: legacy, to: shared))
        XCTAssertEqual(ProgressStore(url: shared).state, before)
        XCTAssertNotNil(try? Data(contentsOf: legacy), "a file that was not moved stays where it is")
        // and with nothing to move, nothing happens
        XCTAssertFalse(ProgressStore.migrate(from: tempURL(), to: tempURL()))
    }

    /// An R2 file, as R2 wrote it, reads with its checks and saved items and no last view.
    func testAnR2FileReads() {
        let r2 = #"{"door":"dow","checked":{"dow":[1,2]},"saved":["play:containment"],"weeks":{"core":[1]}}"#
        let state = ProgressStore.state(from: Data(r2.utf8))
        XCTAssertEqual(state.door, "dow")
        XCTAssertEqual(state.checked["dow"], [1, 2])
        XCTAssertEqual(state.saved, ["play:containment"])
        XCTAssertNil(state.changesViewed)
    }

    /// The app reads and writes the App Group's file (the simulator carries the entitlement in the binary).
    func testTheAppUsesTheAppGroupsFile() throws {
        let shared = try XCTUnwrap(ProgressStore.sharedURL, "the App Group's container is available")
        XCTAssertEqual(ProgressStore.defaultURL, shared)
        XCTAssertTrue(shared.path.contains("Library/Application Support/Lensatic/progress.json"))
    }

    // MARK: the widget's glance and the app's links

    /// The department's path with two steps done, on 27 October 2026: 338 days to Target Level, step 3 next, and the
    /// widget's tap opens step 3, the same link Saved and iOS search use.
    func testTheGlanceCountsDownAndLinksToTheNextStep() throws {
        let state = ProgressStore.State(door: "dow", checked: ["dow": [1, 2]])
        let g = Glance(store: store, state: state, today: day("2026-10-27"))
        let dow = try door(.dow)
        let plan = PathPlan(door: dow, entities: store.entities)
        let due = try XCTUnwrap(plan.upcoming(today: day("2026-10-27")))
        XCTAssertEqual(g.countdown?.days, PathPlan.days(from: day("2026-10-27"), to: due.day))
        XCTAssertEqual(g.countdown?.label, due.due.short)
        XCTAssertEqual(g.next?.order, 3)
        XCTAssertEqual(g.next?.short, store.entities[dow.steps[2].entityIds[0]]?.shortName)
        XCTAssertEqual(g.link, DeepLink.open(.step(.dow, 3)))
        XCTAssertEqual(g.link.absoluteString, "lensatic" + "://open/step:dow:3")
        XCTAssertEqual("\(g.done)/\(g.total)", "2/\(dow.steps.count)")
        XCTAssertTrue(g.spoken.contains("step 3 of \(dow.steps.count)"), g.spoken)
        XCTAssertTrue(g.spoken.contains("\(g.countdown!.days) days to \(due.due.short)"), g.spoken)
        // with no deadline ahead the glance gives the next step alone
        let later = Glance(store: store, state: state, today: day("2027-10-01"))
        XCTAssertNil(later.countdown)
        XCTAssertEqual(later.next?.order, 3)
        // no trailhead yet, every step done, and a trailhead without steps
        XCTAssertNil(Glance(store: store, state: .init(), today: Date()).door)
        let all = Glance(store: store, state: .init(door: "dow", checked: ["dow": dow.steps.map(\.order)]), today: Date())
        XCTAssertTrue(all.isComplete)
        XCTAssertNil(all.next)
        XCTAssertEqual(all.link, DeepLink.path)
        // the retired Everyone Else trailhead reads as no trailhead: the widget asks for a pick
        XCTAssertNil(Glance(store: store, state: ProgressStore.state(from: Data(#"{"door":"other"}"#.utf8)), today: Date()).door)
    }

    /// The app's own links open what they name and nothing else.
    func testTheAppsLinksOpenWhatTheyName() throws {
        let model = AppModel(store: store, library: library, changes: changes, progress: ProgressStore(url: nil))
        model.choose(.dow)
        XCTAssertTrue(model.open(link: DeepLink.open(.step(.dow, 4))))
        XCTAssertEqual(model.tab, .path)
        XCTAssertEqual(model.pathFocus, 4)
        XCTAssertTrue(model.open(link: DeepLink.open(.play("containment"))))
        XCTAssertEqual(model.tab, .library)
        XCTAssertEqual(model.paths[.library], [.play("containment")])
        XCTAssertTrue(model.open(link: DeepLink.open(.entity("sp800-207"))))
        XCTAssertEqual(model.paths[.explore], [.entity("sp800-207")])
        model.query = "left over"
        XCTAssertTrue(model.open(link: DeepLink.search))
        XCTAssertEqual(model.tab, .search)
        XCTAssertEqual(model.query, "")
        XCTAssertTrue(model.open(link: DeepLink.path))
        XCTAssertEqual(model.tab, .path)
        for bad in ["lensatic://open/entity:nothing", "lensatic://open/step:dow:99", "lensatic://elsewhere", "https://example.com/open/play:red"] {
            XCTAssertFalse(model.open(link: URL(string: bad)!), bad)
        }
    }

    // MARK: intents

    /// "What's my next Lensatic step?" answers from the progress file; the items are the Spotlight keys, and each opens.
    func testTheIntentsAnswerAndOpenByTheSpotlightKeys() async throws {
        let url = tempURL()
        let p = ProgressStore(url: url)
        p.choose(.dow)
        p.toggle(.dow, 1)
        let answer = NextStepIntent.answer(today: day("2026-10-27"), url: url)
        XCTAssertTrue(answer.hasPrefix("Your next step is step 2"), answer)
        XCTAssertTrue(NextStepIntent.answer(today: Date(), url: tempURL()).contains("not picked a trailhead"))

        let items = LensaticItem.all(url: url)
        let keys = Set(Spotlight.entries(store: store, library: library, door: try door(.dow)).map(\.id))
        XCTAssertEqual(Set(items.map(\.id)), keys, "the intents' items are iOS search's")
        XCTAssertTrue(items.contains { $0.id == "step:dow:2" })
        let found = LensaticItemQuery.matching("zero trust overlays", in: items)
        XCTAssertTrue(found.contains { $0.id == "entity:dod-zt-overlays" }, "\(found.map(\.id))")

        let model = AppModel(store: store, library: library, changes: changes, progress: ProgressStore(url: nil))
        model.choose(.dow)
        IntentRouter.model = model
        defer { IntentRouter.model = nil }
        let play = try XCTUnwrap(items.first { $0.id == "play:containment" })
        _ = try await OpenItemIntent(item: play).perform()
        XCTAssertEqual(model.paths[.library], [.play("containment")])
        _ = try await OpenSearchIntent().perform()
        XCTAssertEqual(model.tab, .search)
    }

    // MARK: share card and haptics

    /// The share card shows the card's own words and carries the source's address; it draws at three pixels a point.
    func testTheShareCardShowsTheCardAndCarriesTheSource() throws {
        let model = AppModel(store: store, library: library, changes: changes, progress: ProgressStore(url: nil))
        model.choose(.dow)
        let e = try XCTUnwrap(store.entities["dod-zt-ot"])
        let face = try XCTUnwrap(ShareCard.face(.entity(e.id), model: model))
        XCTAssertEqual(face.title, e.displayName)
        XCTAssertEqual(face.body, e.shortSummary)
        XCTAssertEqual(face.url, URL(string: e.url))
        XCTAssertTrue(face.source.contains(e.publisher))
        let image = try XCTUnwrap(ShareCard.image(face))
        XCTAssertEqual(image.size.width, ShareCard.width, accuracy: 1)
        XCTAssertEqual(image.scale, 3)
        let attachment = XCTAttachment(image: image)
        attachment.name = "share-card-\(e.id)"
        attachment.lifetime = .keepAlways
        add(attachment)

        let step = try XCTUnwrap(ShareCard.face(.step(.dow, 3), model: model))
        XCTAssertEqual(step.title, try door(.dow).steps[2].title)
        XCTAssertTrue(step.eyebrow.hasPrefix("Step 3 of"))
        let stepImage = try XCTUnwrap(ShareCard.image(step))
        let a2 = XCTAttachment(image: stepImage)
        a2.name = "share-card-step-dow-3"
        a2.lifetime = .keepAlways
        add(a2)
        XCTAssertNil(ShareCard.face(.entity("nothing"), model: model))
    }

    /// A check-off taps; the check that finishes the path gives the success pattern; unchecking is silent.
    func testHapticsOnCheckOffAndOnFinishing() throws {
        let plan = PathPlan(door: try door(.dow), entities: store.entities)
        let all = Set(plan.steps.map(\.order))
        XCTAssertEqual(PathHaptic.after([], [1], plan: plan), .check)
        XCTAssertEqual(PathHaptic.after(all.subtracting([7]), all, plan: plan), .finish)
        XCTAssertNil(PathHaptic.after([1, 2], [1], plan: plan))
        XCTAssertNil(PathHaptic.after([1], [1], plan: plan))
    }

    // MARK: the new short text

    /// How many lines a text takes in the app's type at a width, as SwiftUI lays it out.
    func lines(_ text: String, font: Font, spacing: CGFloat = 0, width: CGFloat) -> Int {
        func height(_ s: String) -> CGFloat {
            let view = Text(keepWhole(s)).font(font).lineSpacing(spacing).fixedSize(horizontal: false, vertical: true)
                .frame(width: width, alignment: .leading)
            return UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
        }
        return Int(((height(text) + spacing) / (height("A") + spacing)).rounded())
    }

    /// The stack's cards (content 1.2.20): each layer's eyebrow, with the "on your path" call-out, on one line and its
    /// short question on two at most with no one-word last line, at the card's width on a 390-point phone (validate.py
    /// check 18 holds the same).
    func testTheShortLayerFieldsFitTheStack() {
        let stack = store.content.layers.filter { !$0.isColumn }
        let sep = store.label("metaSeparator")
        for layer in store.content.layers {
            XCTAssertFalse(layer.shortName.isEmpty || layer.shortQuestion.isEmpty, layer.id)
            XCTAssertTrue(layer.shortQuestion.hasSuffix("?"), layer.id)
            XCTAssertLessThanOrEqual(layer.shortQuestion.count, layer.question.count, layer.id)
        }
        for layer in stack {
            let width = 252 - 8 * CGFloat(stack.count - layer.order)
            let eyebrow = "\(layer.order)\(sep)\(layer.shortName)\(sep)On your path".uppercased()
            XCTAssertEqual(lines(eyebrow, font: DS.eyebrowSmall, width: width), 1, "\(layer.id): \(eyebrow)")
            let n = lines(layer.shortQuestion, font: DS.layerTitle, width: width)
            XCTAssertLessThanOrEqual(n, 2, layer.id)
            if n > 1 {
                let shorter = layer.shortQuestion.split(separator: " ").dropLast().joined(separator: " ")
                XCTAssertEqual(lines(shorter, font: DS.layerTitle, width: width), n, "\(layer.id) ends on one word")
            }
        }
    }

    /// Every chapter and play leads with its summary: one to three lines at the summary's 17 points across 350, no
    /// one-word last line, the writing rules, and no number its own text does not state.
    func testEveryChapterAndPlayLeadsWithASummary() throws {
        let numbers = try NSRegularExpression(pattern: #"\d+(?:\.\d+)*"#)
        func nums(_ s: String) -> [String] { numbers.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { String(s[Range($0.range, in: s)!]) } }
        let items: [(String, String?, String)] = library.guide.chapters.map { c in (c.id, c.summary, ([c.title] + c.blocks.map(\.searchText)).joined(separator: " ")) }
            + library.plays.plays.map { p in (p.id, p.summary, ([p.title, p.subtitle] + p.blocks.map(\.searchText)).joined(separator: " ")) }
        XCTAssertEqual(items.count, library.guide.chapters.count + library.plays.plays.count)
        for (id, summary, text) in items {
            let s = try XCTUnwrap(summary, "\(id) has a summary")
            XCTAssertFalse(s.contains("\u{2014}") || s.contains("\u{2013}"), "\(id): a dash")
            XCTAssertFalse(s.unicodeScalars.contains { $0.properties.isEmojiPresentation }, "\(id): an emoji")
            XCTAssertTrue(s.hasSuffix(".") && !s.hasSuffix(".."), "\(id): one full stop")
            for n in nums(s) { XCTAssertTrue(nums(text).contains(n) || text.contains(n), "\(id): \(n) is not in its text") }
            let n = lines(s, font: DS.summary, spacing: 4, width: 350)
            XCTAssertTrue((1...3).contains(n), "\(id): \(n) lines")
            if n > 1 {
                let shorter = s.split(separator: " ").dropLast().joined(separator: " ")
                XCTAssertEqual(lines(shorter, font: DS.summary, spacing: 4, width: 350), n, "\(id) ends on one word")
            }
        }
    }

    /// Each outline entry opens at a block that carries its heading; a website's wording does not reach the app: no
    /// playbook "tab", no tap-to-expand hint, no "Part 1." before a chapter's title; and the run-in labels are kept apart.
    func testOutlinesAndTheAppsWording() {
        // an entry names its block's heading, or for a section laid out in cards, its card's title
        func titled(_ blocks: [LibraryBlock], _ o: Outline) -> String? {
            let b = blocks[o.block]
            if let card = o.card { return card < b.cards.count ? b.cards[card].title : nil }
            return b.kind == .heading ? b.text : b.heading
        }
        for c in library.guide.chapters {
            XCTAssertFalse(c.title.hasPrefix("Part "), c.id)
            for o in c.outline { XCTAssertEqual(titled(c.blocks, o), o.title, c.id) }
        }
        XCTAssertTrue(library.guide.chapter("part-1")?.outline.allSatisfy { $0.card != nil } ?? false, "Part 1 is outlined by its cards")
        for p in library.plays.plays {
            for o in p.outline { XCTAssertEqual(titled(p.blocks, o), o.title, p.id) }
            let text = p.blocks.map(\.searchText).joined(separator: " ")
            XCTAssertNil(text.range(of: #"\btabs?\b"#, options: .regularExpression), "\(p.id) says tab")
            XCTAssertNil(text.range(of: #"\b[Tt]ap\b[^.;]*\bexpand\b"#, options: .regularExpression), "\(p.id) says tap to expand")
        }
        XCTAssertTrue(library.guide.chapters.contains { $0.part == "Part 1" })
        let leads = library.guide.chapters.flatMap(\.blocks).compactMap(\.lead)
        XCTAssertTrue(leads.contains("Premise."), "run-in labels are leads")
        XCTAssertFalse(library.guide.chapters.flatMap(\.blocks).contains { ($0.text ?? "").hasPrefix("Premise.") })
        // the Action Plan, assembled from every play's actions, each card opening its play
        let plan = library.play("actionplan")
        let cards = plan?.blocks.flatMap(\.cards) ?? []
        XCTAssertFalse(cards.isEmpty)
        XCTAssertTrue(cards.allSatisfy { $0.play.flatMap(library.play) != nil })
    }
}
