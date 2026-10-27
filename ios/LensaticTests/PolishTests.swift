import SwiftUI
import XCTest
@testable import Lensatic

/// The redesign's last round (R4): the light theme from the same tokens, the figures in both appearances with a text
/// description each, the six figures the app draws itself, and the share card in the reader's appearance.
@MainActor
final class PolishTests: XCTestCase {
    static let store = try! ContentStore.bundled()
    static let library = try! Library.bundled()
    static let changes = try! Changes.bundled()

    // MARK: Light theme

    /// The colours text is set in, on every ground the app lays them on.
    static let textColours = ["fg", "fg-2", "accent", "link", "sec-maps", "sec-guides", "sec-playbook", "bad"]
    static let grounds = ["bg", "bg-2", "bg-3"]
    /// The labels that sit on a filled colour: the primary button, the mark tile.
    static let onFills = [("accent-fg", "accent"), ("on-sec-maps", "sec-maps"), ("tile-fg", "tile-bg")]

    static func rgb(_ name: String, _ style: UIUserInterfaceStyle) -> (Double, Double, Double)? {
        guard let c = UIColor(named: name, in: .main, compatibleWith: UITraitCollection(userInterfaceStyle: style)) else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.resolvedColor(with: UITraitCollection(userInterfaceStyle: style)).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    /// WCAG 2's contrast ratio between two colours.
    static func contrast(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        func lum(_ c: (Double, Double, Double)) -> Double {
            func f(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * f(c.0) + 0.7152 * f(c.1) + 0.0722 * f(c.2)
        }
        let (x, y) = (lum(a), lum(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    /// Every text colour clears 4.5 to 1 on every ground, and every label on its fill, in light and in dark: the light
    /// theme adds no colour, only the tokens' light values.
    func testEveryTextColourClearsFourAndAHalfOnItsGroundInBothAppearances() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            var pairs = Self.textColours.flatMap { t in Self.grounds.map { (t, $0) } } + Self.onFills
            pairs.append(("fg", "chip-bg"))
            for (text, ground) in pairs {
                let ratio = Self.contrast(try XCTUnwrap(Self.rgb(text, style), text), try XCTUnwrap(Self.rgb(ground, style), ground))
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(text) on \(ground), \(style == .light ? "light" : "dark"): \(String(format: "%.2f", ratio))")
            }
        }
    }

    /// The two appearances differ for every ground and text colour: the app is not dark in light mode.
    func testTheLightValuesAreTheirOwn() throws {
        for name in Self.textColours + Self.grounds {
            let l = try XCTUnwrap(Self.rgb(name, .light)), d = try XCTUnwrap(Self.rgb(name, .dark))
            XCTAssertFalse(l == d, name)
        }
        // the light ground is light and the dark one dark
        XCTAssertGreaterThan(Self.contrast(try XCTUnwrap(Self.rgb("bg", .light)), (0, 0, 0)), 15)
        XCTAssertGreaterThan(Self.contrast(try XCTUnwrap(Self.rgb("bg", .dark)), (1, 1, 1)), 15)
    }

    // MARK: Figures

    var figures: [(play: String, figure: LibraryBlock.Figure)] {
        Self.library.plays.plays.flatMap { p in p.blocks.compactMap { b in b.figure.map { (p.id, $0) } } }
    }

    /// Every figure has a text description for VoiceOver beyond its name; a drawn one has its dark and light PNGs, the
    /// light the dark one's size; a native one has its caption and its words, and no PNG.
    func testEveryFigureHasADescriptionAndBothAppearances() throws {
        XCTAssertEqual(figures.count, 20)
        for (play, f) in figures {
            XCTAssertGreaterThan(f.description.count, f.alt.count + 40, "\(f.id): a description, not just its name")
            XCTAssertTrue(f.description.hasSuffix("."), f.id)
            XCTAssertFalse(f.description.contains("\u{2014}") || f.description.contains("\u{2013}"), f.id)
            if f.native {
                XCTAssertNil(Figures.url(f.id), "\(f.id) is drawn by the app")
                XCTAssertFalse(f.parts.isEmpty, f.id)
                XCTAssertFalse(f.caption?.isEmpty ?? true, f.id)
            } else {
                let dark = try XCTUnwrap(Figures.image(f.id), "\(play)/\(f.id) dark")
                let light = try XCTUnwrap(Figures.image(f.id, light: true), "\(play)/\(f.id) light")
                XCTAssertEqual(dark.size.width * dark.scale, CGFloat(f.width), accuracy: 1, f.id)
                XCTAssertEqual(light.size.width, dark.size.width, accuracy: 2, f.id)
                XCTAssertEqual(light.size.height, dark.size.height, accuracy: max(3, dark.size.height / 100), f.id)
                XCTAssertNil(f.caption, f.id)
            }
        }
    }

    /// The six small drawings are the app's own, and each lays out at a phone's width at the default size and at AX5.
    func testTheNativeFiguresDrawAtEverySize() throws {
        let native = figures.filter(\.figure.native)
        XCTAssertEqual(Set(native.map(\.figure.id)), ["autonomy-spectrum", "three-faces", "lethal-trifecta", "purple-loop", "blast-radius", "patching-deficit"])
        for (_, f) in native {
            for size in [DynamicTypeSize.large, .accessibility5] {
                let renderer = ImageRenderer(content: NativeFigure(figure: f).frame(width: 350).environment(\.dynamicTypeSize, size))
                renderer.scale = 1
                let image = try XCTUnwrap(renderer.uiImage, "\(f.id) at \(size)")
                XCTAssertEqual(image.size.width, 350, accuracy: 1, f.id)
                XCTAssertGreaterThan(image.size.height, 80, f.id)
            }
        }
        // the patching deficit's bars are drawn to the scale of the figure's own numbers
        let deficit = try XCTUnwrap(native.first { $0.figure.id == "patching-deficit" }?.figure)
        XCTAssertTrue(deficit.parts.contains("1,596"))
        XCTAssertTrue(deficit.parts.contains { $0.hasPrefix("97 ") })
    }

    // MARK: Widget

    /// VoiceOver reads the widget as one sentence, in the order it is drawn: the trailhead, the countdown, the next step
    /// and the steps done; before a trailhead, what to do first; a finished path says so.
    func testTheWidgetReadsAsOneSentence() throws {
        let cal = Calendar.lensatic
        let day = cal.date(from: PathPlan.day("2026-10-27")!)!
        let g = Glance(store: Self.store, state: .init(door: "dow", checked: ["dow": [1, 2]]), today: day)
        let door = try XCTUnwrap(g.door), next = try XCTUnwrap(g.next), c = try XCTUnwrap(g.countdown)
        XCTAssertEqual(g.voiceOver, "Lensatic, \(door). \(c.days) days to \(c.label). Next, step \(next.order) of \(g.total): \(next.title). 2 of \(g.total) steps done.")
        XCTAssertEqual(Glance(store: Self.store, state: .init(door: nil, checked: [:]), today: day).voiceOver,
                       "Lensatic. Pick a trailhead to start your path.")
        let all = Array(1...g.total)
        let done = Glance(store: Self.store, state: .init(door: "dow", checked: ["dow": all]), today: day)
        XCTAssertTrue(done.voiceOver.contains("Path complete") && done.voiceOver.hasSuffix("\(g.total) of \(g.total) steps done."), done.voiceOver)
        XCTAssertFalse(g.voiceOver.contains("\u{2014}") || g.voiceOver.contains("\u{00B7}"))
    }

    // MARK: Share card

    /// The share card follows the reader's appearance: the light card is light, the dark one dark, same size.
    func testTheShareCardTakesTheReadersAppearance() throws {
        let model = AppModel(store: Self.store, library: Self.library, changes: Self.changes, progress: ProgressStore(url: nil))
        model.choose(.dow)
        let face = try XCTUnwrap(ShareCard.face(.entity("dod-zt-strategy"), model: model))
        let light = try XCTUnwrap(ShareCard.image(face, scheme: .light)), dark = try XCTUnwrap(ShareCard.image(face, scheme: .dark))
        XCTAssertEqual(light.size, dark.size)
        func corner(_ image: UIImage) throws -> Double {
            let cg = try XCTUnwrap(image.cgImage)
            var px = [UInt8](repeating: 0, count: 4)
            let ctx = try XCTUnwrap(CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            // a pixel of the card's ground, below its top rule
            ctx.draw(cg, in: CGRect(x: -10, y: -(CGFloat(cg.height) - 40), width: CGFloat(cg.width), height: CGFloat(cg.height)))
            return (Double(px[0]) + Double(px[1]) + Double(px[2])) / 3
        }
        XCTAssertGreaterThan(try corner(light), 200)
        XCTAssertLessThan(try corner(dark), 60)
        for (image, name) in [(light, "share-card-light"), (dark, "share-card-dark")] {
            let a = XCTAttachment(image: image)
            a.name = name
            a.lifetime = .keepAlways
            add(a)
        }
    }
}
