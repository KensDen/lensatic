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

    /// Every colour set the views read, for the test that each one resolves.
    static let names = ["bg", "bg-2", "fg", "fg-2", "line", "line-strong", "accent", "accent-fg", "link", "focus", "seam", "bad", "chip-bg"]
}

/// IBM Plex Sans for text and IBM Plex Mono for the label roles the web gives it. Every face is scaled with Dynamic
/// Type: each size is relative to a system text style. The names are the PostScript names in IBM's own TrueType files.
enum Typo {
    static let sans = "IBMPlexSans", sansBold = "IBMPlexSans-Bold"
    static let mono = "IBMPlexMono", monoBold = "IBMPlexMono-Bold"
    static let faces = [sans, sansBold, mono, monoBold]

    static func font(_ face: String, _ size: CGFloat, _ style: Font.TextStyle) -> Font {
        Font.custom(face, size: size, relativeTo: style)
    }

    /// The size and text style behind each paragraph style.
    static func metrics(_ style: TextStyle) -> (CGFloat, Font.TextStyle) {
        switch style {
        case .body, .strong: return (17, .body)
        case .lede: return (19, .title3)
        case .small: return (15, .subheadline)
        case .note: return (15, .subheadline)
        case .question: return (18, .headline)
        case .elevator: return (17, .body)
        }
    }

    static func font(_ span: SpanStyle, in style: TextStyle) -> Font {
        let (size, ts) = metrics(style)
        switch span {
        case .plain, .url: return font(style == .strong || style == .question ? sansBold : sans, size, ts)
        case .strong: return font(sansBold, size, ts)
        case .mono: return font(mono, size - 2, ts)
        case .monoStrong: return font(monoBold, size - 2, ts)
        }
    }

    static let stamp = font(mono, 13, .footnote)
    static let secNum = font(monoBold, 13, .footnote)
    static let sectionTitle = font(sansBold, 26, .title2)
    static let heroName = font(sansBold, 40, .largeTitle)
    static let title = font(sansBold, 24, .title2)
    static let titleMono = font(monoBold, 22, .title2)
    static let heading = font(sansBold, 18, .headline)
    static let rowTitle = font(sansBold, 17, .headline)
    static let rowLine = font(sans, 15, .subheadline)
    static let meta = font(mono, 12, .caption)
    static let metaBold = font(monoBold, 12, .caption)
    static let badge = font(mono, 12, .caption)
    static let chip = font(sans, 15, .subheadline)
    static let button = font(sansBold, 17, .body)
    static let navTitle = font(sansBold, 17, .headline)

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
