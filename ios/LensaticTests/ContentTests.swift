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

/// The same normalisation tools/check_web.py applies to its texts: whitespace collapsed, and the department's
/// spelled-out name read as its abbreviation.
func webNorm(_ s: String) -> String {
    s.replacingOccurrences(of: "Department of War (DoW)", with: "DoW").replacingOccurrences(of: "Department of War", with: "DoW")
        .split(whereSeparator: \.isWhitespace).joined(separator: " ")
}

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

    // MARK: the pages

    lazy var pages: [PageKey: Page] = {
        let b = PageBuilder(store: store)
        return Dictionary(uniqueKeysWithValues: b.allKeys().map { ($0, b.page($0)) })
    }()

    func testNoTokenSurvivesInAnyRenderedString() {
        for (key, page) in pages {
            for s in page.accessibilityLabels + [page.title] + page.runs.map(\.source) {
                XCTAssertFalse(s.contains("{{"), "\(key): \(s.prefix(80))")
            }
        }
    }

    func testSectionsAreTheWebsInOrderWithItsTitles() throws {
        let fixture = try WebFixture.load()
        XCTAssertEqual(store.sections.map(\.rawValue), fixture.sections)
        guard case .rows(let rows)? = pages[.root]?.blocks.first?.kind else { return XCTFail("the root list is not a list of rows") }
        XCTAssertEqual(rows.map(\.title.text), fixture.sections.map { store.content.ui.sections[$0] ?? "" })
        XCTAssertEqual(rows.map(\.lead?.text), (1...fixture.sections.count).map { String(format: "%02d", $0) })
    }

    func testEveryLoggedTextIsOnItsPage() {
        for (key, page) in pages {
            let body = webNorm(page.runs.map(\.source).joined(separator: " "))
            for t in page.texts { XCTAssertTrue(body.contains(webNorm(t)), "\(key) logs a text it does not place: \(t.prefix(60))") }
        }
    }

    /// Parity with the web: every string the static render places on the page (web_texts.json, written by
    /// tools/build_web.py --texts) is one the app renders. App-only strings are printed for the report.
    func testParityWithTheWebPage() throws {
        let fixture = try WebFixture.load()
        XCTAssertEqual(fixture.contentVersion, store.content.meta.contentVersion)
        let web = fixture.texts.map(webNorm)
        let app = Set(pages.values.flatMap(\.texts).map(webNorm))
        // a label whose words describe the web page's layout has an app version (ui.labels.<key>App) that describes the
        // app's screens: the web's text counts as placed when its app version is placed
        let labels = store.content.ui.labels
        let versions = labels.keys.filter { labels[$0 + "App"] != nil }.sorted()
        XCTAssertFalse(versions.isEmpty)
        for key in versions {
            XCTAssertTrue(app.contains(webNorm(labels[key + "App"] ?? "")), "ui.labels.\(key)App is placed")
        }
        // the web strings the app does not place because an app version stands in for them
        let byVersion = Set(versions.compactMap { labels[$0] }.map(webNorm)).subtracting(app).intersection(web)
        let missing = Set(web).subtracting(app).subtracting(byVersion)
        let appOnly = app.subtracting(web).sorted()
        print("PARITY web strings \(web.count) (\(Set(web).count) distinct); app strings \(app.count) distinct; missing \(missing.count); "
              + "web strings placed by an app version \(byVersion.count) (app versions: \(versions.joined(separator: ", "))); app-only \(appOnly.count)")
        for s in appOnly { print("PARITY app-only: \(s.prefix(160))") }
        XCTAssertEqual(missing.count, 0, "missing from the app: \(missing.sorted().prefix(5))")
    }

    // MARK: first use, on two screens with known abbreviations

    func expansions(_ page: Page) -> [String] {
        page.runs.flatMap(\.segments).compactMap { if case .expansion(let s, _, _) = $0 { return s } else { return nil } }
    }

    func assertFirstUseOnly(_ key: PageKey, form: String, expansion: String) throws {
        let page = try XCTUnwrap(pages[key])
        let text = page.runs.map(\.text).joined(separator: "\n")
        let source = page.runs.map(\.source).joined(separator: "\n")
        XCTAssertGreaterThan(source.components(separatedBy: form).count - 1, 1, "\(form) should appear more than once on \(key)")
        // the first use in running text (labels never take an expansion) is the one spelled out
        let running = page.runs.filter { $0.spans.contains { $0.role == .running } }.map(\.text).joined(separator: "\n")
        let first = try XCTUnwrap(running.range(of: #"(?<![A-Za-z0-9.])\#(form)(?![A-Za-z0-9])"#, options: .regularExpression))
        let after = running[first.upperBound...]
        XCTAssertTrue(after.hasPrefix(" (\(expansion))") || after.hasPrefix(" [\(expansion)]"), "the first \(form) on \(key) is not the one spelled out")
        let spelled = text.components(separatedBy: "\(form) (\(expansion))").count + text.components(separatedBy: "\(form) [\(expansion)]").count - 2
        XCTAssertEqual(spelled, 1, "\(form) is spelled out once on \(key)")
        XCTAssertEqual(expansions(page).filter { $0.contains(expansion) }.count, 1)
    }

    func testFirstUseOnTheQuestionsScreen() throws {
        try assertFirstUseOnly(.section(.helper, .dow), form: "NIST", expansion: "National Institute of Standards and Technology")
    }

    func testFirstUseOnTheStackScreen() throws {
        try assertFirstUseOnly(.section(.stack, .dow), form: "SP", expansion: "Special Publication")
    }

    func testTheDepartmentIsSpelledOutNameFirstOncePerScreen() throws {
        let page = try XCTUnwrap(pages[.section(.doors, .dow)])
        let text = page.runs.map(\.text).joined(separator: "\n")
        XCTAssertEqual(text.components(separatedBy: "Department of War (DoW)").count - 1, 1)
    }

    func testNoTermIsSpelledOutTwiceOnAnyScreen() {
        for (key, page) in pages {
            let exps = expansions(page).filter { $0.hasPrefix(" (") || $0.hasPrefix(" [") }
            XCTAssertEqual(exps.count, Set(exps).count, "\(key) spells a term out twice")
        }
    }

    // MARK: well-known terms

    func testWellKnownTermsAreNeverSpelledOut() {
        let wellKnown = store.terms.filter(\.wellKnown)
        XCTAssertEqual(wellKnown.map(\.term), ["AI"])
        for t in wellKnown {
            let exp = (t.expansion ?? "").lowercased()
            for (key, page) in pages {
                for s in page.accessibilityLabels {
                    XCTAssertFalse(s.lowercased().contains("(\(exp))") || s.lowercased().contains("[\(exp)]"), "\(key): \(s.prefix(80))")
                }
                // no expansion on any screen is this term's own (another term's expansion may contain its words, as AI RMF's does)
                let own = expansions(page).map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " ()[]")).lowercased() }
                XCTAssertFalse(own.contains { $0 == exp || $0 == exp + "s" }, "\(key) expands \(t.term)")
            }
        }
    }

    func testFirstUseOfAIOnTheAIColumnScreenLinksToItsEntry() throws {
        let page = try XCTUnwrap(pages[.section(.ai, .dow)])
        // the first running text on the screen that uses AI is the column's note
        let note = try XCTUnwrap(page.runs.first { $0.source == store.content.ai.note })
        let at = try XCTUnwrap(note.segments.firstIndex { if case .term("AI", "ai", _) = $0 { return true } else { return false } },
                               "AI is not linked to its glossary entry in the note")
        // before it, AI appears only inside other glossary terms (AI RMF), never on its own
        let before = note.segments[..<at].map(\.string).joined()
        let pattern = try XCTUnwrap(store.rules.pattern)
        let forms = pattern.matches(in: before, range: NSRange(location: 0, length: (before as NSString).length)).map { (before as NSString).substring(with: $0.range) }
        XCTAssertFalse(forms.contains("AI"), "an earlier AI in the note is not linked")
        // the glossary keeps its expansion
        let glossary = try XCTUnwrap(pages[.section(.glossary, .dow)])
        XCTAssertTrue(glossary.runs.contains { $0.source.hasPrefix("artificial intelligence. ") })
    }

    // MARK: the photo, the fonts and the colours

    func testPhotoIsThePinnedFileAt1200By800() throws {
        let data = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "about-photo", withExtension: "jpg")))
        let validator = try String(contentsOf: Repo.file("validate", "py"), encoding: .utf8)
        let pin = try XCTUnwrap(validator.firstMatch(of: /ABOUT_PHOTO_SHA256 = "([0-9a-f]{64})"/)?.1)
        XCTAssertEqual(sha256(data), String(pin))
        let image = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(image.size.width * image.scale, 1200)
        XCTAssertEqual(image.size.height * image.scale, 800)
        XCTAssertEqual(store.label("aboutPhotoAlt"), "The maker's lensatic compass, open, with the sighting wire raised.")
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

    func testAboutCarriesTheLicensingParagraphTheMakerAndTheVersions() throws {
        let page = try XCTUnwrap(pages[.section(.about, .dow)])
        XCTAssertTrue(page.texts.contains(store.content.meta.about.licensing))
        let text = page.runs.map(\.source).joined(separator: "\n")
        XCTAssertTrue(text.contains(store.content.meta.contentVersion))
        XCTAssertTrue(text.contains(Rules.formatDate(store.content.meta.builtOn)))
        XCTAssertFalse(store.appVersion.isEmpty)
        XCTAssertTrue(text.contains(store.appVersion))
        XCTAssertFalse(store.maker.isEmpty)
    }
}

struct WebFixture: Decodable {
    let contentVersion: String
    let sections: [String]
    let texts: [String]

    static func load() throws -> WebFixture {
        let url = try XCTUnwrap(Bundle(for: ContentTests.self).url(forResource: "web_texts", withExtension: "json"))
        return try JSONDecoder().decode(WebFixture.self, from: Data(contentsOf: url))
    }
}
