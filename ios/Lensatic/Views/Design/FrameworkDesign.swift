import SwiftUI

// The framework navigator's own pieces (Lensatic 2.0, Round 1; the direction called Bearing): a card with a spine in the
// framework's one colour, its symbol on a tile of that colour, the three card facts, the stack glyph that shows where it
// sits, and the countdown, drawn as a bearing on the compass. Built on the app's own surfaces, type and card style.

/// A framework's symbol on a tile of its colour. The symbol takes the card surface's colour, so it is light on the
/// light theme's deep tone and dark on the dark theme's bright one.
struct FrameworkTile: View {
    let framework: Framework
    var base: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let side = base * min(scale, 1.5)
        Image(systemName: framework.symbol)
            .font(.system(.subheadline, weight: .semibold))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .foregroundStyle(Palette.bg2)
            .frame(width: side, height: side)
            .background(framework.tone, in: RoundedRectangle(cornerRadius: side * 0.26, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Where a framework sits, as a glyph: the stack's five layers as bars, top to bottom, with the ones it sits on in its
/// colour, and the columns beside them (the AI column, and the adversary column for the knowledge bases). The words are
/// in the card's accessibility label and on the detail screen.
struct StackGlyph: View {
    @Environment(AppModel.self) private var model
    let framework: Framework
    var width: CGFloat = 30
    @ScaledMetric(relativeTo: .caption) private var scale: CGFloat = 1

    var body: some View {
        let layers = model.store.content.layers.filter { !$0.isColumn }.sorted { $0.order < $1.order }
        let on = Set(framework.sits.layers)
        let inColumn = model.store.content.layers.contains { $0.isColumn && on.contains($0.id) } || !framework.compliance
        let w = width * min(scale, 1.6), bar = w * 0.13, gap = w * 0.07
        HStack(alignment: .center, spacing: gap) {
            VStack(spacing: gap) {
                ForEach(layers, id: \.id) { layer in
                    RoundedRectangle(cornerRadius: bar / 2, style: .continuous)
                        .fill(on.contains(layer.id) ? framework.tone : Palette.lineStrong.opacity(0.55))
                        .frame(width: w * 0.72, height: bar)
                }
            }
            RoundedRectangle(cornerRadius: bar / 2, style: .continuous)
                .fill(inColumn ? framework.tone : Palette.lineStrong.opacity(0.55))
                .frame(width: bar, height: bar * CGFloat(layers.count) + gap * CGFloat(max(layers.count - 1, 0)))
        }
        .accessibilityHidden(true)
    }
}

extension AppModel {
    /// Where a framework sits, in words: "Layer 4, Controls", "Layers 1, 4 and 5", "AI column", "Adversary column".
    func sitsLabel(_ f: Framework) -> String {
        let all = store.content.layers
        let on = f.sits.layers.compactMap { id in all.first { $0.id == id } }.sorted { $0.order < $1.order }
        let rows = on.filter { !$0.isColumn }, columns = on.filter(\.isColumn)
        var parts: [String] = []
        if rows.count == 1, let l = rows.first {
            parts.append("\(store.label("layer")) \(l.order), \(l.shortName)")
        } else if rows.count > 1 {
            let n = rows.map { String($0.order) }
            parts.append("\(frameworks.label("layers")) \(n.dropLast().joined(separator: ", ")) and \(n.last ?? "")")
        }
        parts += columns.map(\.name)
        if !f.compliance { parts.append(frameworks.label("adversaryColumn")) }
        return parts.joined(separator: ", ")
    }

    /// The short form for a chip: "L4", "L1 · L4 · L5", "AI", "ADV".
    func sitsShort(_ f: Framework) -> String {
        let all = store.content.layers
        let on = f.sits.layers.compactMap { id in all.first { $0.id == id } }.sorted { $0.order < $1.order }
        var parts = on.filter { !$0.isColumn }.map { "L\($0.order)" }
        if on.contains(where: \.isColumn) { parts.append(frameworks.label("aiShort")) }
        if !f.compliance { parts.append(frameworks.label("adversaryShort")) }
        return parts.joined(separator: " ")
    }
}

/// The countdown as a bearing: the days left on a compass dial whose arc runs down as the day comes, beside what is
/// due, who it binds and the date. On Home, on a framework's screen and, in its one-line form, on a card.
struct CountdownDial: View {
    let days: Int
    let tone: Color
    var base: CGFloat = 68
    @ScaledMetric(relativeTo: .title2) private var scale: CGFloat = 1

    /// The arc shows the share of the last two years still to run: full at 730 days or more, empty on the day.
    static func share(_ days: Int) -> Double { min(max(Double(days) / 730, 0), 1) }

    var body: some View {
        let side = base * min(scale, 1.5), line = side * 0.085
        ZStack {
            Circle().stroke(Palette.line, lineWidth: line)
            Circle().trim(from: 0, to: CountdownDial.share(days))
                .stroke(tone, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            // the compass's north and south ticks; east and west are left clear for the number
            ForEach(0..<2, id: \.self) { i in
                Capsule().fill(Palette.lineStrong).frame(width: line * 0.45, height: side * 0.07)
                    .offset(y: -side * 0.5 + line * 1.8).rotationEffect(.degrees(Double(i) * 180))
            }
            Text("\(days)").font(DS.dial).foregroundStyle(Palette.fg).minimumScaleFactor(0.5).lineLimit(1)
                .padding(.horizontal, line * 1.6)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

/// The countdown card: the dial, then what is due, who it binds and the day. One control when it opens something.
struct CountdownCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let deadline: DatedDeadline
    let days: Int
    let tone: Color
    var eyebrow: String?
    var chevron = false
    /// Fills the height it is given (beside a taller card on the iPad).
    var tall = false
    /// The card's corner: a card in a system list's row takes the list's own (LxCard.inList).
    var radius: CGFloat = 18

    var body: some View {
        let L = model.frameworks
        let stacked = typeSize.isAccessibilitySize
        (stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .center, spacing: 14))) {
            CountdownDial(days: days, tone: tone)
            VStack(alignment: .leading, spacing: 2) {
                // the count again in words beside the dial, then what is due as a line of its own
                Eyebrow(text: dotted([eyebrow, CountdownCard.count(days, labels: L)].compactMap { $0 }, separator: model.store.label("metaSeparator")), color: tone, small: true)
                Text(deadline.label).font(DS.style(.headline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                Text(dotted([unbroken(Rules.formatDate(deadline.date)), deadline.binds], separator: model.store.label("metaSeparator")))
                    .font(DS.style(.footnote)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            if chevron, !stacked {
                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
            }
        }
        .frame(maxHeight: tall ? .infinity : nil, alignment: .leading)
        .lxCard(radius: radius, tint: tone)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(CountdownCard.spoken(deadline, days: days, labels: L))
    }

    /// "320 days", "1 day", or "Due today".
    static func count(_ days: Int, labels L: FrameworkLibrary) -> String {
        days == 0 ? L.label("dueToday") : "\(days) \(days == 1 ? L.label("day") : L.label("days"))"
    }

    static func spoken(_ d: DatedDeadline, days: Int, labels L: FrameworkLibrary) -> String {
        "\(count(days, labels: L)): \(d.label), \(Rules.formatDate(d.date)), \(d.binds)"
    }
}

/// The countdown in one line, for a card: a small clock and "320 days to Target Level".
struct CountdownChip: View {
    @Environment(AppModel.self) private var model
    let deadline: DatedDeadline
    let days: Int
    let tone: Color

    var body: some View {
        let L = model.frameworks
        HStack(spacing: 6) {
            Image(systemName: "timer").font(DS.style(.footnote).weight(.semibold)).foregroundStyle(tone).accessibilityHidden(true)
            Text(dotted([CountdownCard.count(days, labels: L), deadline.short], separator: model.store.label("metaSeparator")))
                .font(DS.style(.footnote).weight(.semibold)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A framework as a card: the spine and tile in its colour, its short name and kind, what it is for, and the three
/// facts, who it binds, how it is verified and how big it is, with the stack glyph at the corner and the countdown where
/// it has a dated deadline. One control; VoiceOver reads it as one sentence in that order.
struct FrameworkCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let framework: Framework
    var today = Date()

    var body: some View {
        let f = framework, L = model.frameworks
        let deadline = L.upcoming(f, store: model.store, today: today)
        let days = deadline.flatMap { $0.days(from: today) }
        let big = typeSize.isAccessibilitySize
        HStack(alignment: .top, spacing: 0) {
            // the spine: the framework's colour down the card's leading edge
            Rectangle().fill(f.tone).frame(width: 6).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    FrameworkTile(framework: f)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(keepDesignations(f.shortName)).font(DS.cardShort).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                        Eyebrow(text: f.kind, color: f.tone, small: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if !big {
                        VStack(alignment: .trailing, spacing: 3) {
                            StackGlyph(framework: f)
                            Text(model.sitsShort(f)).font(DS.eyebrowSmall).foregroundStyle(Palette.fg2).lineLimit(1)
                        }
                    }
                }
                Text(f.purpose).font(DS.style(.subheadline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                (big ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(alignment: .top, spacing: 8))) {
                    fact(L.label("binds"), f.binds.short)
                    fact(L.label("verified"), f.verifiedBy.short)
                    fact(L.label("size"), FrameworkCard.sizeShort(f))
                }
                if big {
                    HStack(spacing: 8) {
                        StackGlyph(framework: f)
                        Text(model.sitsLabel(f)).font(DS.style(.footnote)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let deadline, let days { CountdownChip(deadline: deadline, days: days, tone: f.tone) }
            }
            .padding(.leading, 12).padding(.trailing, 14).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .multilineTextAlignment(.leading)
        .background(Palette.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(FrameworkCard.spoken(f, model: model, deadline: deadline, days: days))
        .accessibilityAddTraits(.isButton)
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased()).font(DS.factLabel).foregroundStyle(Palette.fg2)
            Text(value).font(DS.style(.footnote).weight(.semibold)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The card's size fact: the last and largest count ("106 Subcategories").
    static func sizeShort(_ f: Framework) -> String {
        f.cardSize ?? f.size.last.map { "\(Rules.grouped($0.count)) \($0.unit)" } ?? ""
    }

    static func spoken(_ f: Framework, model: AppModel, deadline: DatedDeadline?, days: Int?) -> String {
        let L = model.frameworks
        var parts = ["\(f.shortName), \(f.kind)", f.purpose,
                     "\(L.label("binds")): \(f.binds.short)", "\(L.label("verified")): \(f.verifiedBy.short)",
                     "\(L.label("size")): " + f.size.map { "\(Rules.grouped($0.count)) \($0.unit)" }.joined(separator: ", "),
                     model.sitsLabel(f)]
        if let deadline, let days { parts.append(CountdownCard.spoken(deadline, days: days, labels: L)) }
        return parts.map { $0.hasSuffix(".") ? String($0.dropLast()) : $0 }.joined(separator: ". ") + "."
    }
}

extension Rules {
    /// A count with its thousands grouped: 1,014.
    static func grouped(_ n: Int) -> String {
        let digits = String(abs(n))
        var out = ""
        for (i, ch) in digits.reversed().enumerated() {
            if i > 0, i % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        return (n < 0 ? "-" : "") + String(out.reversed())
    }
}

extension DS {
    /// A framework card's short name: the designation, large enough to scan a list by.
    static let cardShort = font(Typo.sansBold, 20, .title3)
    static let nodeId = font(Typo.monoMedium, 13, .footnote)
    /// A card fact's small caps label: semibold, so its thin strokes keep their contrast at 11 points.
    static let factLabel = font(Typo.sansSemi, 11, .caption)
    /// The number in the countdown dial.
    static let dial = font(Typo.sansBold, 21, .title3)
}

/// A node's identifier as the publisher prints it, in mono on a chip of the framework's colour.
struct NodeBadge: View {
    let id: String
    let tone: Color

    var body: some View {
        Text(id).font(DS.nodeId).foregroundStyle(tone)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(tone.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(tone.opacity(0.35), lineWidth: 1))
            .fixedSize()
    }
}
