import SwiftUI
import UIKit

/// The web's colour tokens, one colour set each (tools/gen_ios_colors.py): paper in light mode, dial in dark mode,
/// following the system appearance. The same foreground and background pairs as the page, so the same contrast.
enum Palette {
    static let bg = Color("bg")
    static let bg2 = Color("bg-2")
    static let fg = Color("fg")
    static let fg2 = Color("fg-2")
    static let line = Color("line")
    static let lineStrong = Color("line-strong")
    static let accent = Color("accent")
    static let accentFg = Color("accent-fg")
    static let link = Color("link")
    static let focus = Color("focus")
    static let seam = Color("seam")
    static let bad = Color("bad")
    static let chipBg = Color("chip-bg")
    // the redesign (R1): the field system's second surface, the mark tile and the section accents (hub/DESIGN.md)
    static let bg3 = Color("bg-3")
    static let tileBg = Color("tile-bg")
    static let tileFg = Color("tile-fg")
    static let secMaps = Color("sec-maps")
    static let secGuides = Color("sec-guides")
    static let secPurple = Color("sec-playbook")
    static let onSecMaps = Color("on-sec-maps")

    /// Every colour set the views read, for the test that each one resolves.
    static let names = ["bg", "bg-2", "fg", "fg-2", "line", "line-strong", "accent", "accent-fg", "link", "focus", "seam", "bad", "chip-bg",
                        "bg-3", "tile-bg", "tile-fg", "sec-maps", "sec-guides", "sec-playbook", "on-sec-maps"]
}

/// IBM Plex Sans for text and IBM Plex Mono for the label roles the web gives it. Every face is scaled with Dynamic
/// Type: each size is relative to a system text style. The names are the PostScript names in IBM's own TrueType files.
enum Typo {
    static let sans = "IBMPlexSans", sansSemi = "IBMPlexSans-SmBld", sansBold = "IBMPlexSans-Bold"
    static let mono = "IBMPlexMono", monoMedium = "IBMPlexMono-Medm", monoBold = "IBMPlexMono-Bold"
    static let faces = [sans, sansSemi, sansBold, mono, monoMedium, monoBold]

    static func font(_ face: String, _ size: CGFloat, _ style: Font.TextStyle) -> Font {
        Font.custom(face, size: size, relativeTo: style)
    }

    /// The navigation bar's titles in Plex Sans too, scaled with Dynamic Type by UIKit's font metrics.
    static func uiFont(_ face: String, _ size: CGFloat, _ style: UIFont.TextStyle) -> UIFont {
        let base = UIFont(name: face, size: size) ?? UIFont.preferredFont(forTextStyle: style)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }
}

enum Appearance {
    /// A solid bar in the page colour over a hairline, at rest and while scrolling: text never passes under a
    /// translucent bar, where it would lose its contrast with the page.
    @MainActor static func configure() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(named: "bg")
        nav.shadowColor = UIColor(named: "line")
        let fg = UIColor(named: "fg") ?? .label
        nav.titleTextAttributes = [.font: Typo.uiFont(Typo.sansBold, 17, .headline), .foregroundColor: fg]
        nav.largeTitleTextAttributes = [.font: Typo.uiFont(Typo.sansBold, 34, .largeTitle), .foregroundColor: fg]
        let bar = UINavigationBar.appearance()
        bar.standardAppearance = nav
        bar.compactAppearance = nav
        bar.scrollEdgeAppearance = nav
        bar.compactScrollEdgeAppearance = nav
    }
}

extension View {
    /// The page's top edge is a hard line under the solid bar, not a soft fade of the text beneath it (iOS 26 and later).
    @ViewBuilder func hardTopEdge() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectStyle(.hard, for: .top)
        } else {
            self
        }
    }
}
