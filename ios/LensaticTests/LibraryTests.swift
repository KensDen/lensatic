import SwiftUI
import XCTest
@testable import Lensatic

/// The redesign's second round (R2): the short texts, search and its ranking, saved items, the Spotlight entries and
/// the Library's guide and plays. Every expected count is read from the bundled files.
@MainActor
final class LibraryTests: XCTestCase {
    static let store = try! ContentStore.bundled()
    static let library = try! Library.bundled()
    var store: ContentStore { Self.store }
    var library: Library { Self.library }
    var entries: [Entity] { store.frameworks + store.sources + store.solutions }

    func tempStore() -> ProgressStore {
        ProgressStore(url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lensatic-tests-\(UUID().uuidString)")
            .appendingPathComponent("progress.json"))
    }

    func door(_ id: Door.ID) throws -> Door { try XCTUnwrap(store.content.doors.first { $0.id == id }) }

    // MARK: short text (content 1.2.19)

    /// The rules tools/validate.py holds the short texts to, checked again on what the app decoded: a short summary on
    /// every entry, a short note exactly where the note runs past 160 characters, the limits, the writing rules, and no
    /// number the long text does not state.
    func testShortTextsKeepTheirRules() throws {
        let numbers = try NSRegularExpression(pattern: #"\d+(?:\.\d+)*"#)
        func nums(_ s: String) -> [String] {
            numbers.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { String(s[Range($0.range, in: s)!]) }
        }
        for e in entries {
            XCTAssertLessThanOrEqual(e.shortSummary.count, 140, e.id)
            XCTAssertLessThan(e.shortSummary.count, e.oneLiner.count, "\(e.id): the short summary is not shorter")
            XCTAssertEqual(e.shortNote != nil, (e.note?.count ?? 0) > 160, "\(e.id): a short note only where the note is long")
            for (short, long) in [(e.shortSummary, e.oneLiner), (e.shortNote ?? "", e.note ?? "")] where !short.isEmpty {
                XCTAssertLessThanOrEqual(short.count, 160, e.id)
                XCTAssertFalse(short.contains("\u{2014}") || short.contains("\u{2013}"), "\(e.id): a dash")
                XCTAssertFalse(short.unicodeScalars.contains { $0.properties.isEmojiPresentation }, "\(e.id): an emoji")
                XCTAssertTrue(short.hasSuffix(".") && !short.hasSuffix(".."), "\(e.id): ends in one full stop")
                for n in nums(short) { XCTAssertTrue(nums(long).contains(n), "\(e.id): \(n) is not in the long text") }
            }
        }
    }

    /// How many lines a text takes in the app's own type at a width, laid out by SwiftUI as the screen lays it out.
    func lines(_ text: String, font: Font, spacing: CGFloat, width: CGFloat) -> Int {
        func height(_ s: String) -> CGFloat {
            let view = Text(keepWhole(s)).font(font).lineSpacing(spacing).fixedSize(horizontal: false, vertical: true)
                .frame(width: width, alignment: .leading)
            let host = UIHostingController(rootView: view)
            return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
        }
        let one = height("A")
        return Int(((height(text) + spacing) / (one + spacing)).rounded())
    }

    /// On a 390-point phone at the default text size, the card's short summary (350 points wide) takes at most three
    /// lines and the Sources sheet's short note (326 points, the sheet less its margins and padding) at most four, and neither ends
    /// on one word: dropping the last word must not take a line away.
    func testShortTextsFitAPhoneWithNoOneWordLastLine() {
        let cases: [(String, String, Font, CGFloat, CGFloat, Int)] = entries.flatMap { e in
            [(e.id, e.shortSummary, DS.summary, 4, 350, 3)] + (e.shortNote.map { [(e.id + " note", $0, DS.note, 3, 326, 4)] } ?? [])
        }
        // the measure agrees with the card as the simulator draws it: this summary takes three lines across 350 points
        let strategy = store.entities["dod-zt-strategy"]?.shortSummary ?? ""
        XCTAssertEqual(lines(strategy, font: DS.summary, spacing: 4, width: 350), 3)
        XCTAssertEqual(lines(strategy, font: DS.summary, spacing: 4, width: 1000), 1)
        for (id, text, font, spacing, width, most) in cases {
            let n = lines(text, font: font, spacing: spacing, width: width)
            print("SHORT \(id): \(n) lines")
            XCTAssertLessThanOrEqual(n, most, "\(id): \(n) lines")
            if n > 1 {
                let shorter = text.split(separator: " ").dropLast().joined(separator: " ")
                XCTAssertEqual(lines(shorter, font: font, spacing: spacing, width: width), n, "\(id) ends on one word")
            }
        }
    }

    // MARK: search

    var index: SearchIndex { SearchIndex(store: store, library: library, door: try? door(.dow), labels: .init()) }

    func testSearchFindsEveryKindAndGroupsThemInOrder() throws {
        let groups = index.search("overlays")
        XCTAssertEqual(groups.first?.kind, .framework)
        XCTAssertEqual(groups.first?.results.first?.id, "entity:dod-zt-overlays", "the entry named for the word comes first")
        XCTAssertTrue(groups.contains { $0.kind == .step }, "the step that names the overlays is on the path")
        XCTAssertEqual(groups.map(\.kind), groups.map(\.kind).sorted(), "groups keep the kinds' order")
        XCTAssertEqual(index.search("containment").first { $0.kind == .play }?.results.first?.id, "play:containment")
        XCTAssertEqual(index.search("CUI").first { $0.kind == .term }?.results.first?.id, "term:cui")
        XCTAssertNotNil(index.search("weekly plan").first { $0.kind == .guide })
        XCTAssertTrue(index.search("   ").isEmpty)
        XCTAssertTrue(index.search("zzqx").isEmpty)
    }

    func testAChapterOrPlayFoundInItsBodySaysWhy() throws {
        // the chapter that mentions the overlays in its prose says so; one that names them only in a table does not (R5)
        let hits = try XCTUnwrap(index.search("overlays").first { $0.kind == .guide }?.results)
        let line = try XCTUnwrap(hits.lazy.compactMap { SearchIndex.excerpt($0, query: "overlays") }.first)
        XCTAssertTrue(line.localizedCaseInsensitiveContains("overlays"), line)
        XCTAssertLessThan(line.count, 140)
        let titled = try XCTUnwrap(index.search("containment").first { $0.kind == .play }?.results.first)
        XCTAssertNil(SearchIndex.excerpt(titled, query: "containment"), "a title match needs no excerpt")
    }

    /// An excerpt comes from a chapter's or a play's prose, never a source table's row (R5, item 23): the guide's
    /// archived-copy row is found, and says nothing of its address.
    func testAnExcerptIsNeverASourceRow() throws {
        let hit = try XCTUnwrap(index.search("wayback").first { $0.kind == .guide }?.results.first, "the row's words are still searched")
        let line = SearchIndex.excerpt(hit, query: "wayback")
        XCTAssertFalse(line?.contains("web.archive.org") ?? false, line ?? "")
        for group in index.search("archive") {
            for item in group.results {
                XCTAssertFalse(SearchIndex.excerpt(item, query: "archive")?.contains("web.archive.org") ?? false, item.id)
            }
        }
    }

    func testEntryNamesShowInTitleCase() {
        XCTAssertEqual(store.entities["nsa-zt"]?.displayName, "NSA Zero Trust Guidance Series")
        XCTAssertEqual(store.entities["dod-zt-strategy"]?.displayName, store.entities["dod-zt-strategy"]?.name, "a name already in Title Case is kept")
    }

    func testSearchRanksTitleOverBodyAndWholeWordsOverParts() {
        func item(_ id: String, title: String, body: String = "") -> SearchIndex.Item {
            .init(kind: .framework, id: id, title: title, subtitle: "", aliases: [], body: body, opens: .nav(.entity(id)))
        }
        let i = SearchIndex(items: [item("body", title: "Something else", body: "zero trust in the body"),
                                    item("part", title: "Trustworthy systems"),
                                    item("word", title: "Zero Trust Strategy"),
                                    item("exact", title: "Zero trust")])
        XCTAssertEqual(i.search("zero trust").first?.results.map(\.id), ["exact", "word", "body"])
        XCTAssertEqual(i.search("trust").first?.results.map(\.id), ["exact", "word", "part", "body"])
        // every word must match somewhere; case and accents do not matter
        XCTAssertEqual(i.search("ZÉRO strategy").first?.results.map(\.id), ["word"])
        XCTAssertEqual(SearchIndex.fold("SP 800-207, Rev. 1"), "sp 800 207 rev 1")
    }

    func testOnlyTheReadersStepsAreSearched() throws {
        let none = SearchIndex(store: store, library: library, door: nil, labels: .init())
        XCTAssertFalse(none.items.contains { $0.kind == .step })
        let dow = try door(.dow)
        XCTAssertEqual(index.items.filter { $0.kind == .step }.count, dow.steps.count)
        XCTAssertEqual(index.items.filter { $0.kind == .framework }.count, entries.count)
        XCTAssertEqual(index.items.filter { $0.kind == .play }.count, library.plays.plays.count)
        XCTAssertEqual(index.items.filter { $0.kind == .guide }.count, library.guide.chapters.count)
        XCTAssertEqual(index.items.filter { $0.kind == .term }.count, store.terms.count)
    }

    // MARK: saved

    func testSavedItemsKeepTheirOrderAndSurviveARelaunch() throws {
        let p = tempStore()
        let items: [SavedItem] = [.entity("dod-zt-strategy"), .play("containment"), .step(.dow, 5)]
        for i in items { p.toggleSaved(i) }
        XCTAssertEqual(p.saved, items.reversed(), "newest first")
        XCTAssertTrue(p.isSaved(.play("containment")))
        p.toggleSaved(.play("containment"))
        XCTAssertFalse(p.isSaved(.play("containment")))
        let again = ProgressStore(url: try XCTUnwrap(p.url))
        XCTAssertEqual(again.saved, [.step(.dow, 5), .entity("dod-zt-strategy")])
        for i in items { XCTAssertEqual(SavedItem(key: i.key), i) }
        for bad in ["", "entity:", "step:dow", "step:nowhere:1", "step:dow:x", "play", "other:x"] { XCTAssertNil(SavedItem(key: bad), bad) }
    }

    func testAnR1FileReadsWithNothingSaved() {
        let state = ProgressStore.state(from: Data(#"{"door":"dow","checked":{"dow":[1]}}"#.utf8))
        XCTAssertEqual(state, .init(door: "dow", checked: ["dow": [1]]))
        XCTAssertTrue(state.saved.isEmpty)
        XCTAssertTrue(state.weeks.isEmpty)
    }

    func testTheLibraryDescribesEachSavedItemFromTheContent() throws {
        let model = AppModel(store: store, library: library, progress: tempStore())
        let e = try XCTUnwrap(store.entities["dod-zt-strategy"])
        XCTAssertEqual(model.describe(.entity(e.id))?.title, e.displayName)
        XCTAssertEqual(model.describe(.entity(e.id))?.line, "Framework\(store.label("metaSeparator"))\(store.layerTag(e.layerId) ?? "")")
        let play = try XCTUnwrap(library.play("containment"))
        XCTAssertEqual(model.describe(.play("containment"))?.title, play.name)
        XCTAssertTrue(model.describe(.play("containment"))?.line.hasSuffix(library.group(of: "containment")?.label ?? "-") == true)
        XCTAssertEqual(model.describe(.step(.dow, 5))?.title, try door(.dow).steps[4].title)
        XCTAssertNil(model.describe(.entity("nothing")))
        XCTAssertNil(model.describe(.step(.dow, 99)))
    }

    // MARK: Spotlight

    func testSpotlightIndexesEveryEntryTheReadersStepsAndEveryPlay() throws {
        let dow = try door(.dow)
        let all = Spotlight.entries(store: store, library: library, door: dow)
        XCTAssertEqual(all.filter { $0.domain == Spotlight.entities }.count, entries.count)
        XCTAssertEqual(all.filter { $0.domain == Spotlight.steps }.map(\.id), dow.steps.map { SavedItem.step(.dow, $0.order).key })
        XCTAssertEqual(all.filter { $0.domain == Spotlight.plays }.count, library.plays.plays.count)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "identifiers are unique")
        XCTAssertTrue(all.allSatisfy { SavedItem(key: $0.id) != nil }, "every identifier opens as a saved item does")
        XCTAssertFalse(Spotlight.entries(store: store, library: library, door: nil).contains { $0.domain == Spotlight.steps })
        let item = Spotlight.item(try XCTUnwrap(all.first))
        XCTAssertEqual(item.uniqueIdentifier, all.first?.id)
        XCTAssertEqual(item.attributeSet.title, all.first?.title)
    }

    func testASpotlightTapOpensTheItem() throws {
        let p = tempStore()
        p.choose(.dow)
        let model = AppModel(store: store, library: library, progress: p)
        model.openSpotlight("entity:sp800-207")
        XCTAssertEqual(model.tab, .explore)
        XCTAssertEqual(model.paths[.explore], [.entity("sp800-207")])
        model.openSpotlight("play:containment")
        XCTAssertEqual(model.tab, .library)
        XCTAssertEqual(model.paths[.library], [.play("containment")])
        model.openSpotlight("step:dow:4")
        XCTAssertEqual(model.tab, .path)
        XCTAssertEqual(model.pathFocus, 4)
        model.openSpotlight("play:no-such-play")
        XCTAssertEqual(model.tab, .path, "an unknown item changes nothing")
    }

    // MARK: the guide and the plays

    func testTheGuideHasEightWeeksForEveryTrailhead() throws {
        for d in store.content.doors {
            let weeks = library.weeks(for: d.id)
            XCTAssertEqual(weeks.map(\.week), Array(1...weeks.count), d.id.rawValue)
            XCTAssertEqual(weeks.count, 8)
            XCTAssertTrue(weeks.allSatisfy { !$0.read.isEmpty && !$0.apply.isEmpty && !$0.check.isEmpty })
        }
        XCTAssertEqual(library.track(for: .dow)?.id, "dow")
        XCTAssertEqual(library.track(for: .defenseContractor)?.id, "private-sector")
        // the core's weeks are shared: marking week 1 on one trailhead marks it on all
        let w1 = try XCTUnwrap(library.weeks(for: .dow).first)
        XCTAssertEqual(library.weekKey(w1, door: .dow), library.weekKey(w1, door: .federalCivilian))
        let w5 = try XCTUnwrap(library.weeks(for: .dow).first { $0.week == 5 })
        XCTAssertNotEqual(library.weekKey(w5, door: .dow), library.weekKey(w5, door: .federalCivilian))
        XCTAssertFalse(library.guide.chapters.isEmpty)
        XCTAssertTrue(library.guide.chapters.allSatisfy { !$0.blocks.isEmpty })
    }

    func testEveryPlayIsInOneGroupAndNoTextCarriesAnEmojiOrADash() {
        let grouped = library.plays.groups.flatMap(\.playIds)
        XCTAssertEqual(grouped.count, Set(grouped).count)
        XCTAssertEqual(Set(grouped), Set(library.plays.plays.map(\.id)))
        let texts = library.plays.plays.flatMap { [$0.name, $0.title, $0.subtitle] + $0.blocks.map(\.searchText) }
            + library.guide.chapters.flatMap { [$0.title] + $0.blocks.map(\.searchText) } + library.plays.groups.map(\.label)
        for t in texts {
            XCTAssertFalse(t.unicodeScalars.contains { $0.properties.isEmojiPresentation }, String(t.prefix(60)))
            XCTAssertFalse(t.contains("\u{2014}"), String(t.prefix(60)))
        }
        XCTAssertFalse(library.plays.groups.contains { $0.label.contains("&") })
    }

    func testTheSectionNamesComeFromTheSiteFile() {
        let site = library.site
        XCTAssertFalse(site.guidesName.isEmpty)
        XCTAssertFalse(site.playsName.isEmpty)
        XCTAssertFalse(site.playsTitle.isEmpty)
        XCTAssertTrue(site.guideTitle.hasPrefix(site.guideName))
        XCTAssertEqual(TitleCase.apply(site.guideTitle), site.guideTitle)
    }
}
