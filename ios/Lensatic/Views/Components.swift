import SwiftUI
import UIKit

/// A run of text after the first-use rule: expansions in the secondary colour as on the web, glossary terms linked
/// to their entry with a dotted underline, links to entries and outside addresses underlined. Labels inside a control
/// describe it with the expansions they carry (the hint).
struct RunText: View {
    let run: Run
    var style: TextStyle = .body
    var font: Font?
    var color: Color = Palette.fg
    /// The face for mono spans, where the text around them has its own size (a screen title).
    var mono: Font?
    /// Mono bold spans (codes, numbers) take the accent colour, as the web's .code and .num do.
    var accentCodes = true

    var body: some View {
        let text = Text(attributed)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHint(run.described.joined(separator: ", "))
        if let spoken = run.spoken {
            // Voice Control still answers to the visible words
            text.accessibilityLabel(spoken).accessibilityInputLabels([Text(spoken), Text(run.text)])
        } else {
            text
        }
    }

    private var attributed: AttributedString {
        let segments = run.segments.isEmpty ? run.spans.map { Segment.text($0.text, $0.style, $0.link) } : run.segments
        var out = AttributedString()
        for seg in segments {
            var a = AttributedString(seg.string)
            switch seg {
            case .text(_, let s, let target):
                a.font = face(s)
                if s == .monoStrong && accentCodes { a.foregroundColor = Palette.accent }
                if let url = target?.url {
                    a.link = url
                    a.underlineStyle = .single
                }
            case .term(_, let slug, let s):
                a.font = face(s)
                a.link = Target.glossary(slug).url
                a.underlineStyle = Text.LineStyle(pattern: .dot)
            case .expansion(_, let s, let target):
                a.font = face(s)
                a.foregroundColor = Palette.fg2
                if let url = target?.url { a.link = url }
            }
            out += a
        }
        return out
    }

    private func face(_ s: SpanStyle) -> Font {
        if let font, s == .plain || s == .strong || s == .url { return font }
        if let mono, s == .mono || s == .monoStrong { return mono }
        return Typo.font(s, in: style)
    }
}

struct TextBlock: View {
    let run: Run
    let style: TextStyle

    var body: some View {
        switch style {
        case .elevator:
            HStack(alignment: .top, spacing: 12) {
                Rectangle().fill(Palette.accent).frame(width: 3).accessibilityHidden(true)
                RunText(run: run, style: style)
            }
            .fixedSize(horizontal: false, vertical: true)
        case .lede:
            RunText(run: run, style: style, color: Palette.fg2)
        case .small, .note:
            RunText(run: run, style: style, color: Palette.fg2)
        case .body, .strong, .question:
            RunText(run: run, style: style)
        }
    }
}

/// A control: a push goes through the navigation stack, anything else through the page's action.
struct ControlButton: View {
    let control: Control
    let act: (Target) -> Void
    var plain = false
    var tag = false

    var body: some View {
        Group {
            if case .push(let route) = control.target {
                NavigationLink(value: route) { label }
            } else {
                Button { act(control.target) } label: { label }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(control.identifier)
        .accessibilityHint(control.label.described.joined(separator: ", "))
    }

    @ViewBuilder private var label: some View {
        if tag {
            Text(control.label.text)
                .font(Typo.metaBold)
                .foregroundStyle(Palette.accent)
                .padding(.horizontal, 8)
                .frame(minHeight: 44)
                // the outline in the text's own colour: the accessibility audit reads the whole tag, outline included
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Palette.accent).padding(.vertical, 10))
                .contentShape(Rectangle())
        } else if plain {
            // laid out by its text; the version line's TapTarget makes it 44 points tall, centered on the text
            Text(control.label.text)
                .font(Typo.stamp)
                .foregroundStyle(Palette.link)
                .underline()
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        } else {
            Text(control.label.text)
                .font(Typo.button)
                .multilineTextAlignment(.leading)
                .foregroundStyle(control.prominent ? Palette.accentFg : Palette.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .background(control.prominent ? Palette.accent : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.accent))
                .contentShape(Rectangle())
        }
    }
}

/// A chip on the stack: solid for a framework, dashed for a source the doors cite, dotted for a solution. The border
/// is the only cue to its type, as on the web.
struct ChipView: View {
    let chip: Chip
    let act: (Target) -> Void

    var body: some View {
        ControlButtonShell(target: chip.target, act: act) {
            Text(chip.label.text)
                .font(Typo.chip)
                .foregroundStyle(Palette.fg)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .frame(minHeight: 44)
                .background(Palette.chipBg, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.fg2, style: border))
                .contentShape(Capsule())
        }
        .accessibilityHint(chip.label.described.joined(separator: ", "))
    }

    private var border: StrokeStyle {
        switch chip.kind {
        case .framework: return StrokeStyle(lineWidth: 1)
        case .source: return StrokeStyle(lineWidth: 1, dash: [5, 3])
        case .solution: return StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 3.5])
        }
    }
}

struct ControlButtonShell<Label: View>: View {
    let target: Target
    let act: (Target) -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        if case .push(let route) = target {
            NavigationLink(value: route, label: label).buttonStyle(.plain)
        } else {
            Button(action: { act(target) }, label: label).buttonStyle(.plain)
        }
    }
}

/// A row that opens a door, a layer, an entry or a matrix cell: one control, read as one line by VoiceOver.
struct RowView: View {
    let row: NavRow
    let act: (Target) -> Void

    var body: some View {
        ControlButtonShell(target: row.target, act: act) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    if let lead = row.lead {
                        RunText(run: lead, style: .small, font: Typo.secNum, color: Palette.accent)
                    }
                    if row.style == .layer {
                        // the web's band: the layer name in the mono label face, the question as the main line
                        RunText(run: row.title, style: .small, color: Palette.fg2, mono: Typo.metaBold, accentCodes: false)
                            .textCase(.uppercase)
                        ForEach(Array(row.lines.enumerated()), id: \.offset) { _, line in
                            RunText(run: line, style: .body, font: Typo.rowTitle)
                        }
                    } else {
                        RunText(run: row.title, style: .body, font: Typo.rowTitle)
                        ForEach(Array(row.lines.enumerated()), id: \.offset) { _, line in
                            RunText(run: line, style: .small, color: Palette.fg2)
                        }
                    }
                    if let meta = row.meta {
                        // the step count reads in capitals; a sentence keeps its own case, as the web's .door-meta.sentence
                        RunText(run: meta, style: .small, font: Typo.meta, color: Palette.accent)
                            .textCase(row.metaIsSentence ? nil : .uppercase)
                    }
                    if !row.badges.isEmpty {
                        Flow(spacing: 6) { ForEach(Array(row.badges.enumerated()), id: \.offset) { _, b in BadgeView(badge: b) } }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(Typo.meta)
                    .foregroundStyle(Palette.fg2)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(minHeight: 44)
            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityHint(([row.lead, row.title, row.meta].compactMap { $0 } + row.lines).flatMap(\.described).joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(row.identifier)
    }
}

/// A door's step: its number, its layer tag, its text, and the entries it names as links.
struct StepView: View {
    let number: Int
    let step: StepItem
    let act: (Target) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 10) {
                Text("\(number)").font(Typo.secNum).foregroundStyle(Palette.accent).accessibilityHidden(true)
                if let tag = step.tag { ControlButton(control: tag, act: act, tag: true) }
            }
            RunText(run: step.text, style: .body)
                .accessibilityLabel("\(number). \(step.text.text)")
            if let links = step.links { LinkButtons(run: links, act: act) }
        }
        .padding(.leading, 2)
    }
}

/// The links in a run as buttons, one per entry, big enough to tap.
struct LinkButtons: View {
    let run: Run
    let act: (Target) -> Void

    var body: some View {
        Flow(spacing: 14) {
            ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                ControlButtonShell(target: g.target, act: act) {
                    Text(g.text)
                        .font(Typo.rowLine)
                        .foregroundStyle(Palette.link)
                        .underline()
                        .multilineTextAlignment(.leading)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier(identifier(g.target))
                // the entry's name is a label: the expansions of its abbreviations describe the link (session 11)
                .accessibilityHint((run.linkDescribed[g.target] ?? []).joined(separator: ", "))
            }
        }
    }

    private func identifier(_ target: Target) -> String {
        if case .push(.entity(let id)) = target { return "entity-link-\(id)" }
        return "link"
    }

    /// Consecutive segments that share a link are one link (an entry's name with an expansion inside it).
    private var groups: [(target: Target, text: String)] {
        var out: [(target: Target, text: String)] = []
        var last: Target?
        for seg in run.segments {
            let target: Target?
            switch seg {
            case .text(_, _, let t), .expansion(_, _, let t): target = t
            case .term: target = nil
            }
            guard let target else { last = nil; continue }
            if target == last, !out.isEmpty {
                out[out.count - 1].text += seg.string
            } else {
                out.append((target, seg.string))
            }
            last = target
        }
        return out
    }
}

struct KeyValueView: View {
    let kv: KeyValue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RunText(run: kv.key, style: .small, color: Palette.fg2)
            if !kv.value.isEmpty { RunText(run: kv.value, style: .body) }
            if !kv.badges.isEmpty {
                Flow(spacing: 6) { ForEach(Array(kv.badges.enumerated()), id: \.offset) { _, b in BadgeView(badge: b) } }
            }
            if let extra = kv.extra { RunText(run: extra, style: .small, color: Palette.fg2) }
        }
    }
}

/// A verification status in words, never colour alone: the border and colour only repeat what the words say.
struct BadgeView: View {
    let badge: Badge

    var body: some View {
        Text(badge.run.text)
            .font(Typo.badge)
            .foregroundStyle(text)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .overlay(Capsule().strokeBorder(border, style: StrokeStyle(lineWidth: 1, dash: badge.status == .unverified ? [4, 3] : [])))
    }

    private var text: Color {
        switch badge.status {
        case .verified: return Palette.fg
        case .conflict: return Palette.bad
        case .authored, .unverified: return Palette.fg2
        }
    }

    private var border: Color {
        switch badge.status {
        case .verified: return Palette.accent
        case .conflict: return Palette.bad
        case .authored, .unverified: return Palette.lineStrong
        }
    }
}

struct GlossaryItemView: View {
    let item: GlossaryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RunText(run: item.term, style: .body, font: Typo.heading).accessibilityAddTraits(.isHeader)
            RunText(run: item.body, style: .body)
            if let badge = item.badge { BadgeView(badge: badge) }
        }
    }
}

struct DisclosureView: View {
    let item: Disclosure
    @State private var open = false

    var body: some View {
        DisclosureGroup(isExpanded: $open) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(item.body.enumerated()), id: \.offset) { i, run in
                    RunText(run: run, style: i == 0 ? .body : .small, color: i == 0 ? Palette.fg : Palette.fg2)
                }
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            RunText(run: item.summary, style: .body, font: Typo.rowTitle)
                .frame(minHeight: 44, alignment: .leading)
        }
        .tint(Palette.accent)
        .padding(14)
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line))
        .accessibilityIdentifier(item.identifier)
    }
}

/// The matrix's two projected views, as two buttons like the web's control; the pressed one is selected.
struct PillarViewPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let controls: [Control]
    let selected: Int

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        layout {
            ForEach(Array(controls.enumerated()), id: \.offset) { i, c in
                let on = i == selected
                Button { model.matrixView = PillarView.allCases[i] } label: {
                    Text(c.label.text)
                        .font(Typo.button)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(on ? Palette.accentFg : Palette.accent)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(on ? Palette.accent : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.accent))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityHint(c.label.described.joined(separator: ", "))
                .accessibilityIdentifier(c.identifier)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.store.label("pillarView"))
    }
}

/// The mark from web/src/mark.svg, in the text colour: the About header's only decoration.
struct MarkImage: View {
    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 30

    var body: some View {
        Image("Mark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(Palette.fg)
            .accessibilityHidden(true)
    }
}

/// Why the name: the heading, the maker's photo and the story, the photo beside the text in a regular-width layout
/// and above it in a compact one, scaled to fit without cropping.
struct StoryView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    let heading: Run
    let alt: String
    let paragraphs: [Run]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RunText(run: heading, style: .body, font: Typo.heading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("about-name")
            if sizeClass == .regular && !typeSize.isAccessibilitySize {
                Split(ratio: 0.4, spacing: 20) {
                    photo
                    text
                }
            } else {
                photo
                text
            }
        }
        .padding(.top, 12)
    }

    @ViewBuilder private var photo: some View {
        if let image = UIImage(named: "about-photo.jpg") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line))
                .accessibilityLabel(Text(alt))
                .accessibilityAddTraits(.isImage)
                .accessibilityIdentifier("about-photo")
        }
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, p in RunText(run: p, style: .body) }
        }
    }
}

/// A control laid out by its text but tappable over at least 44 points: it reports its text's height to the line it
/// sits in, and is placed at least 44 points tall, centered on that text, reaching into the space above and below. A
/// line of such controls wraps like running text (session 11, EX-009) and keeps full-size targets.
struct TapTarget: Layout {
    var minimum: CGFloat = 44

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        subviews.first?.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil)) ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let s = subviews.first else { return }
        s.place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
                proposal: ProposedViewSize(width: bounds.width, height: max(minimum, bounds.height)))
    }
}

/// Marks a piece of a LinkLine as a link whose target is at least 44 points tall, centered on its text.
struct LinkLineTarget: LayoutValueKey { static let defaultValue = false }
/// Marks a piece of a LinkLine that never starts a line alone after the piece before it: the two wrap together.
struct LinkLineKeep: LayoutValueKey { static let defaultValue = false }

/// The front door's version line: its pieces laid out left to right and wrapped like running text, each line one text
/// line below the last. A link's 44-point target (TapTarget) reaches past its text into the space around it, over plain
/// text but never over another link's target: a line moves down only as far as it must for that. A piece marked to keep
/// with the one before it wraps with it, so Why the name? never starts a line alone under the version link (session 11,
/// EX-009 and its review).
struct LinkLine: Layout {
    var spacing: CGFloat = 7
    var lineSpacing: CGFloat = 2
    var minimum: CGFloat = 44

    struct Piece: Equatable {
        var size: CGSize
        var target = false
        var keep = false
    }

    /// Where each piece goes in a line of this width, by the pieces' own text sizes: rows as a Flow makes them, a
    /// keep-with-previous piece taking the piece before it onto a new row with it, then each row moved down as far as
    /// needed so no target's box overlaps a target's box in an earlier row.
    static func arrange(_ pieces: [Piece], width: CGFloat, spacing: CGFloat, lineSpacing: CGFloat, minimum: CGFloat) -> [CGRect] {
        var rows: [[Int]] = [[]]
        var x: CGFloat = 0
        for (i, p) in pieces.enumerated() {
            let w = min(p.size.width, width)
            if x > 0 && x + w > width {
                if p.keep, rows[rows.count - 1].count > 1, let prev = rows[rows.count - 1].popLast() {
                    let pw = min(pieces[prev].size.width, width)
                    if pw + spacing + w <= width {
                        rows.append([prev, i])
                        x = pw + spacing + w + spacing
                        continue
                    }
                    rows[rows.count - 1].append(prev)
                }
                rows.append([i])
                x = w + spacing
            } else {
                rows[rows.count - 1].append(i)
                x += w + spacing
            }
        }
        var frames = Array(repeating: CGRect.zero, count: pieces.count)
        var y: CGFloat = 0
        for (r, row) in rows.enumerated() {
            var px: CGFloat = 0
            for i in row {
                let w = min(pieces[i].size.width, width)
                frames[i] = CGRect(x: px, y: y, width: w, height: pieces[i].size.height)
                px += w + spacing
            }
            // a target's box: at least `minimum` tall, centered on its text
            func box(_ f: CGRect) -> (CGFloat, CGFloat) { let h = max(minimum, f.height); return (f.midY - h / 2, f.midY + h / 2) }
            var shift: CGFloat = 0
            for b in row where pieces[b].target {
                for earlier in rows[..<r] {
                    for a in earlier where pieces[a].target && frames[a].minX < frames[b].maxX && frames[b].minX < frames[a].maxX {
                        shift = max(shift, box(frames[a]).1 - box(frames[b]).0)
                    }
                }
            }
            if shift > 0 { for i in row { frames[i].origin.y += shift } }
            y = (row.map { frames[$0].maxY }.max() ?? y) + lineSpacing
        }
        return frames
    }

    private func frames(_ subviews: Subviews, width: CGFloat) -> [CGRect] {
        let pieces = subviews.map { Piece(size: $0.sizeThatFits(ProposedViewSize(width: width, height: nil)), target: $0[LinkLineTarget.self],
                                          keep: $0[LinkLineKeep.self]) }
        return LinkLine.arrange(pieces, width: width, spacing: spacing, lineSpacing: lineSpacing, minimum: minimum)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let f = frames(subviews, width: width)
        return CGSize(width: min(f.map(\.maxX).max() ?? 0, width), height: f.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (s, f) in zip(subviews, frames(subviews, width: bounds.width)) {
            s.place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY), proposal: ProposedViewSize(width: f.width, height: f.height))
        }
    }
}

/// Wraps its children onto as many lines as they need.
struct Flow: Layout {
    var spacing: CGFloat = 8
    /// The gap between rows, when it differs from the gap between items.
    var lineSpacing: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + (lineSpacing ?? spacing)
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + (lineSpacing ?? spacing)
                rowHeight = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Two children side by side, the first taking `ratio` of the width.
struct Split: Layout {
    var ratio: CGFloat
    var spacing: CGFloat

    private func widths(_ total: CGFloat) -> (CGFloat, CGFloat) {
        let w = max(total - spacing, 0)
        return (w * ratio, w * (1 - ratio))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let total = proposal.width ?? 600
        let (a, b) = widths(total)
        let heights = zip(subviews, [a, b]).map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }
        return CGSize(width: total, height: heights.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (a, b) = widths(bounds.width)
        var x = bounds.minX
        for (s, w) in zip(subviews, [a, b]) {
            s.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: w, height: nil))
            x += w + spacing
        }
    }
}
