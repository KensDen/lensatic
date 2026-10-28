import CryptoKit
import UIKit
import XCTest
@testable import Lensatic

/// The repository's files as the build found them: the test bundle carries content/stack.json and tools/validate.py by
/// reference (ios/project.yml), so the tests compare the app with its sources without reading outside their sandbox.
enum Repo {
    static func file(_ name: String, _ ext: String) throws -> URL {
        try XCTUnwrap(Bundle(for: ContentTests.self).url(forResource: name, withExtension: ext), "\(name).\(ext) is not in the test bundle")
    }
}

func sha256(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

final class ContentTests: XCTestCase {
    static let store = try! ContentStore.bundled()
    var store: ContentStore { Self.store }

    func bundledData() throws -> Data {
        try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "stack", withExtension: "json")))
    }

    // MARK: the content

    func testRealContentDecodesStrictly() throws {
        let content = try Strict.decode(Content.self, from: bundledData())
        XCTAssertEqual(content.meta.name, "Lensatic")
        XCTAssertEqual(content.layers.count, 6)
        XCTAssertEqual(content.matrix.cells.count, 48)
        XCTAssertFalse(store.content.glossary.isEmpty)
    }

    func testBundledContentIsTheRepositoryFile() throws {
        XCTAssertEqual(sha256(try bundledData()), sha256(try Data(contentsOf: Repo.file("stack", "json"))))
    }

    /// Edit the real file's tree and decode it again.
    func mutated(_ edit: (inout [String: Any]) -> Void) throws -> Data {
        var tree = try XCTUnwrap(JSONSerialization.jsonObject(with: bundledData()) as? [String: Any])
        edit(&tree)
        return try JSONSerialization.data(withJSONObject: tree)
    }

    func first(_ tree: inout [String: Any], _ key: String, _ edit: (inout [String: Any]) -> Void) {
        var list = tree[key] as! [[String: Any]]
        edit(&list[0])
        tree[key] = list
    }

    func testUnknownFieldFailsAtEveryLevel() throws {
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { $0["extra"] = 1 }))
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.first(&$0, "frameworks") { $0["oneliner"] = "x" } }))
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.first(&$0, "doors") { d in
            var steps = d["steps"] as! [[String: Any]]
            steps[0]["extra"] = true
            d["steps"] = steps
        } }))
        // a field another kind of entry may carry is still unknown here: a framework has no role
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.first(&$0, "frameworks") { $0["role"] = "x" } }))
    }

    func testMissingFieldFails() throws {
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.first(&$0, "frameworks") { $0["answersQuestion"] = nil } }))
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.first(&$0, "sources") { $0["role"] = nil } }))
        // required but nullable: present as null decodes, absent does not
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.first(&$0, "doors") { $0["pillarView"] = nil } }))
        XCTAssertNoThrow(try Strict.decode(Content.self, from: mutated { self.first(&$0, "doors") { $0["pillarView"] = NSNull() } }))
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { $0["elevator"] = nil }))
    }

    func testNullWhereTheSchemaAllowsNoNullFails() throws {
        // an optional field may be absent, never null
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.first(&$0, "doors") { $0["landings"] = NSNull() } }))
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.first(&$0, "frameworks") { $0["note"] = NSNull() } }))
        // a field a kind of entry requires may not be null
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.first(&$0, "frameworks") { $0["layerId"] = NSNull() } }))
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.first(&$0, "solutions") { $0["validatedAgainst"] = NSNull() } }))
        // the elevator is derived from the layers: its text must stay null
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { t in
            var e = t["elevator"] as! [String: Any]
            e["text"] = "hand-written"
            t["elevator"] = e
        }))
    }

    func testOnlyAnAuthoredRecordFitsWhereTheSchemaAsksForOne() throws {
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.first(&$0, "doors") { d in
            d["verification"] = ["status": "verified", "verifiedOn": "2026-09-01", "method": "primary-fetch", "note": ""]
        } }))
    }

    func testAViewThatNamesAPillarWithoutItsNameFailsAtLoad() throws {
        let data = try mutated { t in
            var p = t["pillars"] as! [String: Any]
            var canonical = p["canonical"] as! [[String: Any]]
            let i = canonical.firstIndex { $0["id"] as? String == "data" }!
            canonical[i]["dowName"] = NSNull()
            p["canonical"] = canonical
            t["pillars"] = p
        }
        XCTAssertNoThrow(try Strict.decode(Content.self, from: data), "the schema allows a null name")
        XCTAssertThrowsError(try ContentStore(data: data), "but a view that lists the pillar needs it")
    }

    func testUnknownEnumeratedValueFails() throws {
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.first(&$0, "doors") { $0["pillarView"] = "nato" } }))
    }

    func testAuthoredRecordShapeIsHeldToItsFields() throws {
        XCTAssertThrowsError(try Strict.decode(Content.self, from: mutated { self.first(&$0, "doors") { d in
            var v = d["verification"] as! [String: Any]
            v["basisIds"] = nil
            d["verification"] = v
        } }))
    }

    // MARK: the map's screens (the first-use rule)

    lazy var screens: [(String, Prose)] = MapScreens.all(store)

    func testNoTokenSurvivesInAnyRenderedString() {
        for (key, prose) in screens {
            for s in prose.accessibilityLabels + prose.runs.map(\.source) { XCTAssertFalse(s.contains("{{"), "\(key): \(s.prefix(80))") }
        }
        for e in store.frameworks + store.sources + store.solutions {
            for s in [e.shortSummary, e.shortNote ?? "", e.oneLiner, e.note ?? ""] { XCTAssertFalse(s.contains("{{"), e.id) }
        }
    }

    func expansions(_ prose: Prose) -> [String] {
        prose.runs.flatMap(\.segments).compactMap { if case .expansion(let s, _, _) = $0 { return s } else { return nil } }
    }

    /// The first running use of a form on a screen is the one spelled out, and only that one.
    func assertFirstUseOnly(_ name: String, form: String, expansion: String) throws {
        let prose = try XCTUnwrap(screens.first { $0.0 == name }?.1, name)
        let source = prose.runs.map(\.source).joined(separator: "\n")
        XCTAssertGreaterThan(source.components(separatedBy: form).count - 1, 1, "\(form) should appear more than once on \(name)")
        let running = prose.runs.filter { $0.spans.contains { $0.role == .running } }.map(\.text).joined(separator: "\n")
        let first = try XCTUnwrap(running.range(of: #"(?<![A-Za-z0-9.])\#(form)(?![A-Za-z0-9])"#, options: .regularExpression))
        let after = running[first.upperBound...]
        XCTAssertTrue(after.hasPrefix(" (\(expansion))") || after.hasPrefix(" [\(expansion)]"), "the first \(form) on \(name) is not the one spelled out")
        XCTAssertEqual(expansions(prose).filter { $0.contains(expansion) }.count, 1)
    }

    func testFirstUseOnTheControlsLayer() throws {
        try assertFirstUseOnly("layer l4", form: "SP", expansion: "Special Publication")
    }

    func testFirstUseOnTheTargetStateLayer() throws {
        try assertFirstUseOnly("layer l3", form: "NIST", expansion: "National Institute of Standards and Technology")
    }

    func testTheDepartmentIsSpelledOutNameFirstAtMostOncePerScreen() {
        var seen = 0
        for (key, prose) in screens {
            let n = prose.runs.map(\.text).joined(separator: "\n").components(separatedBy: "Department of War (DoW)").count - 1
            XCTAssertLessThanOrEqual(n, 1, key)
            seen += n
        }
        XCTAssertGreaterThan(seen, 0)
    }

    func testNoTermIsSpelledOutTwiceOnAnyScreen() {
        for (key, prose) in screens {
            let exps = expansions(prose).filter { $0.hasPrefix(" (") || $0.hasPrefix(" [") }
            XCTAssertEqual(exps.count, Set(exps).count, "\(key) spells a term out twice")
        }
    }

    func testWellKnownTermsAreNeverSpelledOut() {
        let wellKnown = store.terms.filter(\.wellKnown)
        // GPS since content 1.2.21 (R5), so the maker's paragraph in Why the name reads word for word
        XCTAssertEqual(wellKnown.map(\.term), ["AI", "GPS"])
        for t in wellKnown {
            let exp = (t.expansion ?? "").lowercased()
            for (key, prose) in screens where !key.hasPrefix("glossary") {
                for s in prose.accessibilityLabels {
                    XCTAssertFalse(s.lowercased().contains("(\(exp))") || s.lowercased().contains("[\(exp)]"), "\(key): \(s.prefix(80))")
                }
                let own = expansions(prose).map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " ()[]")).lowercased() }
                XCTAssertFalse(own.contains { $0 == exp || $0 == exp + "s" }, "\(key) expands \(t.term)")
            }
        }
    }

    /// Session 17: AI links to its glossary entry on one screen only, the AI column, and once there.
    func testAILinksOnceAndOnlyOnTheAIColumnScreen() throws {
        let column = try XCTUnwrap(store.content.layers.first(where: \.isColumn))
        var linked: [String] = []
        for (key, prose) in screens {
            let n = prose.runs.flatMap(\.segments).filter { if case .term("AI", _, _) = $0 { return true } else { return false } }.count
            if n > 0 { linked.append("\(key) \(n)") }
        }
        XCTAssertEqual(linked, ["layer \(column.id) 1"])
        // GPS, the other well-known term, links nowhere
        XCTAssertFalse(screens.contains { $0.1.runs.flatMap(\.segments).contains { if case .term("GPS", _, _) = $0 { return true } else { return false } } })
        // the glossary keeps its expansion
        let glossary = try XCTUnwrap(screens.first { $0.0 == "glossary" }?.1)
        XCTAssertTrue(glossary.runs.contains { $0.source.hasPrefix("artificial intelligence. ") })
    }

    /// The AI column is tagged by its name, never as a sixth layer: on its screen, on its entries' cards, in search and
    /// in the Library's saved list.
    func testTheAIColumnIsTaggedByItsNameNotAsASixthLayer() throws {
        let column = try XCTUnwrap(store.content.layers.first(where: \.isColumn))
        let sixth = "\(store.label("layer")) \(column.order)"
        let entries = (store.frameworks + store.sources + store.solutions).filter { $0.layerId == column.id }
        XCTAssertFalse(entries.isEmpty)
        for e in entries {
            XCTAssertEqual(store.layerTag(e.layerId), column.name)
            XCTAssertEqual(EntityFacts(e, store: store).eyebrow, column.name, e.id)
        }
        for (key, prose) in screens { XCTAssertFalse(prose.runs.contains { $0.text.contains(sixth) }, "\(key) shows \(sixth)") }
    }

    /// A glossary entry carries a badge only by exception (session 20): none for a verified spelling, on the glossary and
    /// in the sheet a term opens; an entry set to any other status shows it in both.
    func testGlossaryEntriesCarryABadgeOnlyByException() throws {
        let items = GlossaryScreen(store: store).items
        XCTAssertEqual(items.count, store.content.glossary.count)
        for item in items {
            let term = try XCTUnwrap(store.terms.first { $0.slug == item.slug })
            let entry = try XCTUnwrap(store.content.glossary.first { $0.term == term.term })
            XCTAssertEqual(item.status != nil, entry.verification.status != .verified, item.slug)
            XCTAssertEqual(GlossaryScreen(store: store, only: item.slug).items.map(\.slug), [item.slug])
        }
        let verifiedNow = Set(store.content.glossary.filter { $0.verification.status == .verified }.map(\.term))
        for status in [Verification.Status.unverified, .conflict, .authored] {
            let data = try mutated { tree in
                self.first(&tree, "glossary") { g in
                    var v = g["verification"] as! [String: Any]
                    v["status"] = status.rawValue
                    if status == .authored {
                        v["method"] = "synthesis"
                        v["verifiedOn"] = NSNull()
                        v["basisIds"] = [self.store.frameworks[0].id]
                        v["recheckAfter"] = nil
                    }
                    g["verification"] = v
                }
            }
            let mutant = try ContentStore(data: data)
            let changed = try XCTUnwrap(mutant.content.glossary.first { verifiedNow.contains($0.term) && $0.verification.status != .verified })
            let slug = try XCTUnwrap(mutant.terms.first { $0.term == changed.term }?.slug)
            let screen = GlossaryScreen(store: mutant).items
            XCTAssertEqual(screen.first { $0.slug == slug }?.status?.status, status, status.rawValue)
            XCTAssertEqual(screen.filter { $0.status != nil }.count, items.filter { $0.status != nil }.count + 1, status.rawValue)
            XCTAssertEqual(GlossaryScreen(store: mutant, only: slug).items.first?.status?.status, status, status.rawValue)
        }
    }

    /// The citation-line rule on the real content, as All sources gives it.
    func testCitationLinesOnTheRealContent() throws {
        let nsa = try XCTUnwrap(store.entities["nsa-zt"])
        XCTAssertTrue(Run(SourcesScreen.cite(nsa)).source.contains(
            "NSA, nine cybersecurity information sheets (2021 to 2026) and four implementation guidelines (2026), 28 May 2026."))
        let screen = SourcesScreen(store: store)
        XCTAssertEqual(screen.groups.flatMap(\.entries).count, store.entities.count)
    }

    func testAboutCarriesTheStoryTheLicensingTheMakerAndTheVersions() throws {
        let about = AboutScreen(store: store)
        let text = about.prose.runs.map(\.source)
        XCTAssertTrue(text.contains(store.content.meta.about.licensing))
        XCTAssertEqual(about.story.count, store.content.meta.about.nameStory?.count)
        XCTAssertTrue(about.version.contains(store.content.meta.contentVersion))
        XCTAssertTrue(about.version.contains("\(store.label("releasedOn")) \(Rules.formatDate(store.content.meta.builtOn))"))
        XCTAssertFalse(store.appVersion.isEmpty)
        XCTAssertTrue(about.version.contains(store.appVersion))
        XCTAssertEqual(about.madeBy, "\(store.label("madeBy")) \(store.maker)")
        XCTAssertEqual(about.counts.map(\.count).reduce(0, +), store.counts.values.reduce(0, +))
    }

    /// The tagline and the pitch are for link previews, the README, the repository and the store listing: no screen
    /// shows them. The wayfinder line is on About, and no other screen shows it (session 15).
    func testThePitchLinesStayOffScreenAndTheWayfinderIsOnAbout() {
        let meta = store.content.meta
        for (key, prose) in screens {
            let shown = prose.runs.map(\.source).joined(separator: "\n")
            for line in [meta.tagline, meta.pitch] { XCTAssertFalse(shown.contains(line), "\(key) shows: \(line)") }
            XCTAssertEqual(shown.contains(meta.wayfinder), key == "about", key)
        }
    }

    /// The compass on a world map (Map_TopDown, v1.1 since R6, oriented to map north), 1200 px square.
    func testPhotoIsThePinnedFileAt1200OnItsLongestSide() throws {
        let data = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "about-photo", withExtension: "jpg")))
        let validator = try String(contentsOf: Repo.file("validate", "py"), encoding: .utf8)
        let pin = try XCTUnwrap(validator.firstMatch(of: /ABOUT_PHOTO_SHA256 = "([0-9a-f]{64})"/)?.1)
        XCTAssertEqual(sha256(data), String(pin))
        let image = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(image.size.width * image.scale, 1200)
        XCTAssertEqual(image.size.height * image.scale, 1200)
        XCTAssertEqual(store.label("aboutPhotoAlt"), "My lensatic compass, open on a world map, with its lanyard coiled around it.")
    }

    func testEveryFaceIsRegistered() {
        for face in Typo.faces { XCTAssertNotNil(UIFont(name: face, size: 17), face) }
    }

    func testEveryColourResolvesInBothAppearances() {
        for name in Palette.names {
            for style in [UIUserInterfaceStyle.light, .dark] {
                XCTAssertNotNil(UIColor(named: name, in: .main, compatibleWith: UITraitCollection(userInterfaceStyle: style)), name)
            }
        }
    }
}
