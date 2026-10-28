import SwiftUI

/// The redesign's type ramp (R1), from the brief: large titles 32 to 34, body 16 to 17, labels 11 to 13 in mono caps.
/// IBM Plex in IBM's own faces; every size is relative to a system text style, so it scales with Dynamic Type. The 11-point
/// labels scale with the caption style, not caption 2, which stops shrinking at the small sizes and so scales only in part.
enum DS {
    static func font(_ face: String, _ size: CGFloat, _ style: Font.TextStyle) -> Font { Typo.font(face, size, style) }

    static let largeTitle = font(Typo.sansBold, 34, .largeTitle)
    static let welcomeTitle = font(Typo.sansBold, 32, .largeTitle)
    static let cardTitle = font(Typo.sansBold, 24, .title2)
    static let countdown = font(Typo.sansBold, 24, .title2)
    static let sheetTitle = font(Typo.sansBold, 20, .title3)
    static let heroStep = font(Typo.sansBold, 20, .title3)
    static let summary = font(Typo.sans, 17, .body)
    static let rowTitle = font(Typo.sansSemi, 17, .headline)
    static let button = font(Typo.sansSemi, 17, .headline)
    static let sheetButton = font(Typo.sansSemi, 16, .headline)
    static let ring = font(Typo.sansBold, 17, .headline)
    static let lede = font(Typo.sans, 16, .callout)
    static let answer = font(Typo.sans, 16, .callout)
    static let nextTitle = font(Typo.sansSemi, 16, .callout)
    static let step = font(Typo.sans, 15, .subheadline)
    static let stepStrong = font(Typo.sansSemi, 15, .subheadline)
    static let link = font(Typo.sans, 15, .subheadline)
    static let value = font(Typo.sans, 15, .subheadline)
    static let chip = font(Typo.sans, 14, .subheadline)
    static let note = font(Typo.sans, 14, .subheadline)
    static let tileValue = font(Typo.sansSemi, 14, .subheadline)
    static let caption = font(Typo.sans, 13, .footnote)
    static let sectionLabel = font(Typo.sansSemi, 13, .footnote)
    static let keyLabel = font(Typo.sans, 12, .caption)
    static let eyebrow = font(Typo.monoMedium, 12, .caption)
    static let eyebrowSmall = font(Typo.monoMedium, 11, .caption)
    static let tileLabel = font(Typo.sans, 11, .caption)
    static let tab = font(Typo.sans, 11, .caption)
    static let segment = font(Typo.sansSemi, 14, .subheadline)
    static let layerTitle = font(Typo.sansSemi, 15, .subheadline)
    static let layerNames = font(Typo.sans, 12, .caption)
    static let libraryTitle = font(Typo.sansSemi, 16, .callout)
    static let searchField = font(Typo.sans, 16, .callout)
    static let monoText = font(Typo.mono, 14, .subheadline)
    static let readerBody = font(Typo.sans, 16, .callout)
    static let readerHeading = font(Typo.sansBold, 18, .headline)
    static let readerLead = font(Typo.sansSemi, 16, .callout)
}

/// A mono caps label in a section colour: the screen's eyebrow (CHOOSE A TRAILHEAD, the trailhead's name, LAYER 3).
struct Eyebrow: View {
    let text: String
    var color: Color = Palette.secMaps
    var small = false
    /// Letter-spaced, as most eyebrows are; the stack's layer cards set theirs untracked, as Explore.dc.html does.
    var tracked = true
    // the mockups' 0.12em and 0.08em letter spacing, scaled with the text so it stays in proportion at every size
    @ScaledMetric(relativeTo: .caption) private var spacing: CGFloat = 1.44
    @ScaledMetric(relativeTo: .caption) private var spacingSmall: CGFloat = 0.88

    var body: some View {
        Text(text.uppercased())
            .font(small ? DS.eyebrowSmall : DS.eyebrow)
            .kerning(tracked ? (small ? spacingSmall : spacing) : 0)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A plain caps label over a group (YOUR STEPS, ANSWERS, GOES WITH).
struct SectionLabel: View {
    let text: String
    var tracked = true
    @ScaledMetric(relativeTo: .footnote) private var spacing: CGFloat = 0.52

    var body: some View {
        Text(text.uppercased())
            .font(DS.sectionLabel)
            .kerning(tracked ? spacing : 0)
            .foregroundStyle(Palette.fg2)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A card: the surface colour, a 1-point hairline and the card radius (12 to 16 in the mockups).
extension View {
    func card(radius: CGFloat = 14, fill: Color = Palette.bg2, stroke: Color = Palette.line) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(stroke, lineWidth: 1))
    }
}

/// One stat tile: a small caps label over a one-line value (BINDS, DUE, TYPE).
struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(DS.tileLabel).foregroundStyle(Palette.fg2)
            // one line by the row's arrangement (StatTileRow), never by a line limit, so the value scales in full
            Text(value).font(DS.tileValue).foregroundStyle(Palette.fg).fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("stat-tile-\(label.lowercased())")
    }
}

/// A row of stat tiles that sizes to its content (the nit list's rule 3): the tiles share the row by weight (the first
/// one wider, 1.6 to 1 to 1, as on the canvas) when every value then fits on one line; when they do not, each tile
/// takes at least its own width and the rest is shared; when even that is too wide, the first tile takes its own row
/// and the others share the next, and at the largest text sizes every tile takes a row. A value never wraps or truncates.
struct StatTileRow: Layout {
    var weights: [CGFloat] = [1.6, 1, 1]
    var spacing: CGFloat = 8

    private enum Arrangement { case row([CGFloat]), firstAlone, stacked }

    private func arrange(_ width: CGFloat, _ ideals: [CGFloat]) -> Arrangement {
        let n = ideals.count
        guard n > 0 else { return .stacked }
        let avail = width - spacing * CGFloat(n - 1)
        let w = (0..<n).map { weights[min($0, weights.count - 1)] }
        let total = w.reduce(0, +)
        let byWeight = w.map { avail * $0 / total }
        if zip(byWeight, ideals).allSatisfy({ $0 >= $1 - 0.5 }) { return .row(byWeight) }
        let sum = ideals.reduce(0, +)
        if sum <= avail {
            let extra = (avail - sum) / CGFloat(n)
            return .row(ideals.map { $0 + extra })
        }
        if n > 1, ideals[0] <= width, ideals.dropFirst().reduce(0, +) + spacing * CGFloat(n - 2) <= width { return .firstAlone }
        return .stacked
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.reduce(0, +)
        let ideals = subviews.map { $0.sizeThatFits(.unspecified).width }
        return CGSize(width: width, height: frames(width, ideals, subviews).map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let ideals = subviews.map { $0.sizeThatFits(.unspecified).width }
        for (sv, f) in zip(subviews, frames(bounds.width, ideals, subviews)) {
            sv.place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY), proposal: ProposedViewSize(f.size))
        }
    }

    private func frames(_ width: CGFloat, _ ideals: [CGFloat], _ subviews: Subviews) -> [CGRect] {
        func height(_ i: Int, _ w: CGFloat) -> CGFloat { subviews[i].sizeThatFits(ProposedViewSize(width: w, height: nil)).height }
        switch arrange(width, ideals) {
        case .row(let widths):
            let h = (0..<subviews.count).map { height($0, widths[$0]) }.max() ?? 0
            var x: CGFloat = 0
            return widths.map { w in defer { x += w + spacing }; return CGRect(x: x, y: 0, width: w, height: h) }
        case .firstAlone:
            let h0 = height(0, width)
            let rest = subviews.count - 1
            let w = (width - spacing * CGFloat(rest - 1)) / CGFloat(rest)
            let h1 = (1..<subviews.count).map { height($0, w) }.max() ?? 0
            return [CGRect(x: 0, y: 0, width: width, height: h0)]
                + (0..<rest).map { CGRect(x: CGFloat($0) * (w + spacing), y: h0 + spacing, width: w, height: h1) }
        case .stacked:
            var y: CGFloat = 0
            return (0..<subviews.count).map { i in
                let h = height(i, width)
                defer { y += h + spacing }
                return CGRect(x: 0, y: y, width: width, height: h)
            }
        }
    }
}

/// A pill: a short name that opens what it names (GOES WITH, a step's entries).
struct Pill: View {
    let text: String

    var body: some View {
        // drawn at the mockup's height, tapped across 44 points: the target reaches past the drawn capsule
        Text(text)
            .font(DS.chip)
            .foregroundStyle(Palette.fg)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Palette.bg3, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}

/// Wraps its children onto as many lines as they need, left to right.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = layout(proposal.width ?? .infinity, subviews)
        return CGSize(width: proposal.width ?? rows.map(\.maxX).max() ?? 0, height: rows.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (sv, f) in zip(subviews, layout(bounds.width, subviews)) {
            sv.place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY), proposal: ProposedViewSize(f.size))
        }
    }

    private func layout(_ width: CGFloat, _ subviews: Subviews) -> [CGRect] {
        var out: [CGRect] = [], x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0
        for sv in subviews {
            var s = sv.sizeThatFits(.unspecified)
            s.width = min(s.width, width)
            if x > 0 && x + s.width > width { x = 0; y += line + spacing; line = 0 }
            if s.width == width { s.height = sv.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
            out.append(CGRect(x: x, y: y, width: s.width, height: s.height))
            x += s.width + spacing
            line = max(line, s.height)
        }
        return out
    }
}

/// The progress ring: a track in the line colour and the done share in the section colour, starting at the top,
/// with the count inside.
struct ProgressRing: View {
    let done: Int
    let total: Int
    var size: CGFloat = 64
    var lineWidth: CGFloat = 6
    @ScaledMetric(relativeTo: .headline) private var scale: CGFloat = 1

    var body: some View {
        let side = size * min(scale, 1.6)
        ZStack {
            Circle().stroke(Palette.line, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: total == 0 ? 0 : CGFloat(done) / CGFloat(total))
                .stroke(Palette.secMaps, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(done)/\(total)").font(DS.ring).foregroundStyle(Palette.fg).minimumScaleFactor(0.6).lineLimit(1)
                .padding(lineWidth)
        }
        .padding(lineWidth / 2)
        .frame(width: side, height: side)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) steps done")
    }
}

/// The primary button: the Framework Maps accent with its label colour, 52 points tall at the default size.
struct PrimaryButtonStyle: ButtonStyle {
    var minHeight: CGFloat = 52
    var font: Font = DS.button

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(Palette.onSecMaps)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(Palette.secMaps, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// A round 44-point control on the surface colour: back, share.
struct CircleIconLabel: View {
    let icon: IconName
    // the symbol grows with the text (R4), and the circle with it from 44 points to at most 60; past that, a long press
    // shows the control in the large content viewer, as the system's bar buttons do
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 44

    var body: some View {
        let d = min(max(side, 44), 60)
        let glyph = 20 * d / 44
        IconShape(paths: icon.paths)
            .stroke(Palette.fg, style: StrokeStyle(lineWidth: 2 * glyph / 24, lineCap: .round, lineJoin: .round))
            .frame(width: glyph, height: glyph)
            .accessibilityHidden(true)
            .frame(width: d, height: d)
            .background(Palette.bg2, in: Circle())
            .overlay(Circle().strokeBorder(Palette.line, lineWidth: 1))
            .contentShape(Circle())
            .accessibilityShowsLargeContentViewer()
    }
}

/// The tab bar as the mockups draw it: the surface colour over a hairline, the selected tab in the Framework Maps
/// colour, every tab at least 64 by 44 points.
struct TabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 2) {
                        Icon(tab.icon, size: 24, color: selection == tab ? Palette.secMaps : Palette.fg2, relativeTo: .caption)
                        Text(tab.title).font(DS.tab).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    }
                    // as the system's tab bars do: the labels stop growing at the largest standard size, and a long
                    // press at the accessibility sizes shows the tab in the large content viewer
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .foregroundStyle(selection == tab ? Palette.secMaps : Palette.fg2)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? [.isSelected, .isButton] : .isButton)
                .accessibilityIdentifier("tab-\(tab.rawValue)")
                .accessibilityShowsLargeContentViewer {
                    Icon(tab.icon, size: 24, color: Palette.fg2)
                    Text(tab.title)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Palette.bg2.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main")
    }
}

/// The bottom sheet as the Sources mockup draws it: the surface colour, 22-point top corners, a short handle, sized to
/// its content up to the full height (then it scrolls). The height is measured once, when the sheet opens: a sheet that
/// followed its content as the text size changed would chase its own layout, so a later change scrolls instead.
struct BottomSheet<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var height: CGFloat = 400
    @State private var measured = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Capsule().fill(Palette.lineStrong).frame(width: 40, height: 5).frame(maxWidth: .infinity).padding(.top, 10)
                    .accessibilityHidden(true)
                content
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(GeometryReader { g in Color.clear.preference(key: SheetHeight.self, value: g.size.height) })
        }
        .accessibilityIdentifier("sheet")
        .onPreferenceChange(SheetHeight.self) { h in
            guard !measured, h > 0 else { return }
            height = h
            measured = true
        }
        .presentationDetents([.height(height), .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(22)
        .presentationBackground(Palette.bg2)
    }
}

/// The measured height of a bottom sheet's content.
private struct SheetHeight: PreferenceKey {
    static let defaultValue: CGFloat = 400
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Short text that never ends on a one-word line (nit 2, R4): its last two words are kept together, when they are short
/// enough to wrap as one (24 characters or fewer).
func noOrphan(_ s: String) -> String {
    guard let last = s.range(of: " ", options: .backwards) else { return s }
    let start = s[..<last.lowerBound].range(of: " ", options: .backwards)?.upperBound ?? s.startIndex
    guard s.distance(from: start, to: s.endIndex) <= 24 else { return s }
    return s.replacingCharacters(in: last, with: "\u{00A0}")
}

/// A date as one unbreakable run ("9 Sep 2026"), for the lines the app composes: a date never splits across lines.
func unbroken(_ date: String) -> String { date.replacingOccurrences(of: " ", with: "\u{00A0}") }

/// Parts joined by the content's separator (" · "), each part kept whole and each dot kept with the part after it, so a
/// line breaks only before a dot and never ends on one (R5, item 23).
func dotted(_ parts: [String], separator: String) -> String {
    parts.map(unbroken).joined(separator: " " + separator.trimmingCharacters(in: .whitespaces) + "\u{00A0}")
}

/// A short title with each designation kept whole ("SP 800-207", "EO 14028", "CSF 2.0"): the space between a capitalized
/// designation and its number does not break, so a line never ends on "SP".
func keepDesignations(_ s: String) -> String {
    s.replacingOccurrences(of: #"\b([A-Z]{2,}) (?=\d)"#, with: "$1\u{00A0}", options: .regularExpression)
}

/// Short text as the content's layout check lays it out (tools/validate.py, keep_whole): each designation kept whole
/// with its number, and each date on one line, so the line breaks the check measured are the ones a reader sees.
func keepWhole(_ s: String) -> String {
    keepDesignations(s).replacingOccurrences(of: #"\b(\d{1,2}) (January|February|March|April|May|June|July|August|September|October|November|December) (\d{4})\b"#,
                                             with: "$1\u{00A0}$2\u{00A0}$3", options: .regularExpression)
}

/// The faint grid on the welcome screen's ground, dark theme only (hub/DESIGN.md: --grid).
struct GridGround: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Palette.bg.overlay {
            if scheme == .dark {
                Canvas { ctx, size in
                    var p = Path()
                    stride(from: 0, through: size.width, by: 28).forEach { p.addRect(CGRect(x: $0, y: 0, width: 1, height: size.height)) }
                    stride(from: 0, through: size.height, by: 28).forEach { p.addRect(CGRect(x: 0, y: $0, width: size.width, height: 1)) }
                    ctx.fill(p, with: .color(Palette.accent.opacity(0.05)))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// A list row: an optional leading icon, a title and an optional line under it, and a chevron, on a card; at least 44
/// points tall. The door cards on the welcome screen and the Library's rows are list rows.
struct ListRow: View {
    let title: String
    var subtitle: String?
    var icon: IconName?
    var iconColor: Color = Palette.secMaps
    var highlighted = false

    var body: some View {
        HStack(spacing: 14) {
            if let icon { Icon(icon, size: 28, color: iconColor, lineWidth: 1.8) }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DS.rowTitle).foregroundStyle(Palette.fg)
                if let subtitle { Text(subtitle).font(DS.caption).foregroundStyle(Palette.fg2) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            Icon(.chevronRight, size: 18, color: Palette.fg2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(minHeight: 44)
        .card(radius: 14, stroke: highlighted ? Palette.secMaps : Palette.line)
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// A screen's header: an eyebrow over a large title, with an optional control at the trailing edge (Change).
struct ScreenHeader<Trailing: View>: View {
    var eyebrow: String?
    let title: String
    @ViewBuilder var trailing: Trailing
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // at the accessibility sizes the control goes under the title, so the eyebrow and title keep the full width
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .bottom))
        layout {
            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow { Eyebrow(text: eyebrow) }
                Text(title).font(DS.largeTitle).foregroundStyle(Palette.fg).accessibilityAddTraits(.isHeader)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 12) }
            trailing
        }
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(eyebrow: String? = nil, title: String) {
        self.init(eyebrow: eyebrow, title: title) { EmptyView() }
    }
}
