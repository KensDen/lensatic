import SwiftUI

/// The six small playbook diagrams the app draws itself (R4): the autonomy dial, one capability's three faces, the lethal
/// trifecta, the purple loop, the blast radius and the patching deficit. On the website they are small inline drawings
/// whose words shrink to a few points at a phone's width; here they are drawn in the app's type, which scales with
/// Dynamic Type, and in its colours, which follow the theme. Their words (the figure's parts) and the caption under each
/// come from the playbook's source through the generator, in drawing order; nothing is typed here. VoiceOver reads each
/// as one image: its name and its description.
struct NativeFigure: View {
    let figure: LibraryBlock.Figure

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            drawing
            if let caption = figure.caption {
                Text(keepWhole(caption)).font(DS.caption).foregroundStyle(Palette.fg2).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(figure.alt)
        .accessibilityValue(figure.description)
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("figure-\(figure.id)")
    }

    private var p: [String] { figure.parts }
    private func part(_ i: Int) -> String { i < p.count ? p[i] : "" }

    @ViewBuilder private var drawing: some View {
        switch figure.id {
        case "autonomy-spectrum": AutonomyDial(title: part(0), stops: Array(p.dropFirst()))
        case "three-faces": ThreeFaces(source: (part(0), part(1)), faces: [(part(2), part(3), Palette.bad), (part(4), part(5), Palette.accent),
                                                                             (part(6), part(7), Palette.secPurple)])
        case "lethal-trifecta": Trifecta(legs: [(part(0), Palette.accent), (part(1), Palette.secGuides), (part(2), Palette.bad)], center: part(3))
        case "purple-loop": PurpleLoop(title: part(0), subtitle: part(1), steps: Array(p.dropFirst(2)))
        case "blast-radius": ContainmentRing(title: part(0))
        case "patching-deficit": PatchingDeficit(rows: [(part(0), part(1), Palette.bad), (part(2), part(3), Palette.accent)], note: part(4))
        default: EmptyView()
        }
    }
}

/// A label in the figures' small mono caps, letter-spaced with the text's size.
private struct FigureLabel: View {
    let text: String
    var color: Color = Palette.fg2
    var body: some View { Eyebrow(text: text, color: color, small: true) }
}

/// The autonomy dial: a track from muted to accent, its marker at the midpoint, and the four notches named under it (or
/// listed, when the text is too large for one line).
private struct AutonomyDial: View {
    let title: String
    let stops: [String]
    @ScaledMetric(relativeTo: .caption) private var knob: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FigureLabel(text: title, color: Palette.accent)
            ZStack {
                Capsule().fill(LinearGradient(colors: [Palette.fg2, Palette.accent], startPoint: .leading, endPoint: .trailing)).frame(height: 8)
                Circle().fill(Palette.bg2).overlay(Circle().strokeBorder(Palette.accent, lineWidth: 2.5)).frame(width: knob, height: knob)
            }
            .frame(height: knob)
            ViewThatFits(in: .horizontal) {
                // one line with room between the notches' names, or the list
                HStack(spacing: 0) {
                    ForEach(Array(stops.enumerated()), id: \.offset) { i, s in
                        if i > 0 { Spacer(minLength: 14) }
                        FigureLabel(text: s, color: i == stops.count - 1 ? Palette.accent : Palette.fg2).fixedSize()
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(stops.enumerated()), id: \.offset) { i, s in
                        FigureLabel(text: "\(i + 1)  \(s)", color: i == stops.count - 1 ? Palette.accent : Palette.fg2)
                    }
                }
            }
        }
    }
}

/// One capability and its three faces: the source box, and a branch to each face in its colour.
private struct ThreeFaces: View {
    let source: (String, String)
    let faces: [(String, String, Color)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            box(source.0, source.1, Palette.accent)
            ForEach(Array(faces.enumerated()), id: \.offset) { i, f in
                HStack(alignment: .top, spacing: 0) {
                    Branch(last: i == faces.count - 1).frame(width: 28)
                    box(f.0, f.1, f.2).padding(.top, 10)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func box(_ title: String, _ text: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            FigureLabel(text: title, color: color)
            Text(text).font(DS.caption).foregroundStyle(Palette.fg).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.bg, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(color, lineWidth: 1.2))
    }

    /// The tree's line: down the left, and across to the box at its first line.
    private struct Branch: View {
        let last: Bool
        var body: some View {
            GeometryReader { g in
                Path { path in
                    let x: CGFloat = 12, y: CGFloat = 10 + 18
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: last ? y : g.size.height))
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: g.size.width, y: y))
                }
                .stroke(Palette.lineStrong, lineWidth: 1.3)
            }
        }
    }
}

/// The lethal trifecta: three overlapping circles in the legs' colours, the centre where all three meet named, and the
/// legs named in a key under the drawing, so their words never sit on the lines.
private struct Trifecta: View {
    let legs: [(String, Color)]
    let center: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { g in
                let s = min(g.size.width, g.size.height * 1.1)
                let r = s * 0.24
                let cx = g.size.width / 2, cy = g.size.height / 2
                let centres = [CGPoint(x: cx - r * 0.55, y: cy - r * 0.42), CGPoint(x: cx + r * 0.55, y: cy - r * 0.42), CGPoint(x: cx, y: cy + r * 0.5)]
                ZStack {
                    ForEach(0..<min(3, legs.count), id: \.self) { i in
                        Circle().fill(legs[i].1.opacity(0.08)).overlay(Circle().strokeBorder(legs[i].1, lineWidth: 1.6))
                            .frame(width: 2 * r, height: 2 * r).position(centres[i])
                    }
                    Text(center).font(DS.font(Typo.monoBold, 12, .caption)).foregroundStyle(Palette.bad)
                        .lineLimit(1).minimumScaleFactor(0.5).frame(width: r * 1.3)
                        .padding(.horizontal, 4).background(Palette.bg2.opacity(0.85), in: Capsule())
                        .position(x: cx, y: cy - r * 0.08)
                }
            }
            .frame(height: 200)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(legs.enumerated()), id: \.offset) { _, leg in
                    HStack(spacing: 8) {
                        Circle().strokeBorder(leg.1, lineWidth: 2).frame(width: 12, height: 12)
                        FigureLabel(text: leg.0, color: leg.1)
                    }
                }
            }
        }
    }
}

/// The purple loop: its five steps in order, joined down a line, and the line back to the first; continuous, on every
/// TTP and every change.
private struct PurpleLoop: View {
    let title: String
    let subtitle: String
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Icon(.loop, size: 14, color: Palette.secPurple, lineWidth: 2)
                FigureLabel(text: title, color: Palette.secPurple)
            }
            FigureLabel(text: subtitle)
            HStack(alignment: .top, spacing: 10) {
                // the line back from the last step to the first
                LoopReturn().stroke(Palette.secPurple, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)).frame(width: 16)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                        HStack(spacing: 8) {
                            Text("\(i + 1)").font(DS.font(Typo.monoBold, 11, .caption)).foregroundStyle(Palette.secPurple)
                            FigureLabel(text: s, color: Palette.fg)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Palette.bg, in: Capsule())
                        .overlay(Capsule().strokeBorder(Palette.secPurple, lineWidth: 1.2))
                    }
                }
            }
        }
    }

    private struct LoopReturn: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            // from the last step's middle, round the left, into the first step's middle
            let top = rect.minY + 15, bottom = rect.maxY - 15, x = rect.minX + 2
            p.move(to: CGPoint(x: rect.maxX - 2, y: bottom))
            p.addLine(to: CGPoint(x: x, y: bottom))
            p.addLine(to: CGPoint(x: x, y: top))
            p.addLine(to: CGPoint(x: rect.maxX - 2, y: top))
            // the arrowhead into the first step
            p.move(to: CGPoint(x: rect.maxX - 7, y: top - 4))
            p.addLine(to: CGPoint(x: rect.maxX - 2, y: top))
            p.addLine(to: CGPoint(x: rect.maxX - 7, y: top + 4))
            return p
        }
    }
}

/// The blast radius, bounded: five agents joined by lines, the compromised one in red inside its ring, and the line that
/// would carry it on broken. Illustrative, as the caption says.
private struct ContainmentRing: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FigureLabel(text: title, color: Palette.secPurple)
            Canvas { ctx, size in
                // the website's 200 by 120 drawing, scaled to fit
                let k = min(size.width / 200, size.height / 120)
                let ox = (size.width - 200 * k) / 2, oy = (size.height - 120 * k) / 2
                func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * k, y: oy + y * k) }
                func line(_ a: CGPoint, _ b: CGPoint, _ c: Color, dash: [CGFloat] = []) {
                    var p = Path(); p.move(to: a); p.addLine(to: b)
                    ctx.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: 1.5 * k, dash: dash.map { $0 * k }))
                }
                func dot(_ c: CGPoint, _ r: CGFloat, _ color: Color) { ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * k, y: c.y - r * k, width: 2 * r * k, height: 2 * r * k)), with: .color(color)) }
                line(pt(30, 60), pt(80, 32), Palette.fg2)
                line(pt(30, 60), pt(80, 88), Palette.fg2)
                line(pt(80, 32), pt(150, 32), Palette.fg2)
                line(pt(80, 88), pt(150, 88), Palette.bad, dash: [3, 3])
                line(pt(150, 32), pt(150, 88), Palette.fg2)
                dot(pt(30, 60), 5, Palette.accent)
                dot(pt(80, 32), 4, Palette.fg2)
                dot(pt(80, 88), 4, Palette.fg2)
                dot(pt(150, 32), 4, Palette.link)
                dot(pt(150, 88), 6, Palette.bad)
                ctx.stroke(Path(ellipseIn: CGRect(x: pt(150, 88).x - 13 * k, y: pt(150, 88).y - 13 * k, width: 26 * k, height: 26 * k)),
                           with: .color(Palette.bad.opacity(0.5)), lineWidth: k)
            }
            .frame(height: 150)
        }
    }
}

/// The patching deficit, drawn to scale: each bar's length is its count's share of the larger, from the figure's own
/// numbers ("1,596", "97 · 6.1%").
private struct PatchingDeficit: View {
    let rows: [(String, String, Color)]
    let note: String

    private func count(_ s: String) -> Double { Double(s.split(separator: " ").first.map { $0.replacingOccurrences(of: ",", with: "") } ?? "") ?? 0 }

    var body: some View {
        let top = rows.map { count($0.1) }.max() ?? 1
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        FigureLabel(text: row.0)
                        Spacer(minLength: 8)
                        Text(row.1).font(DS.font(Typo.sansBold, 15, .subheadline)).foregroundStyle(row.2)
                    }
                    GeometryReader { g in
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(row.2)
                            .frame(width: max(3, g.size.width * count(row.1) / max(1, top)), height: 12)
                    }
                    .frame(height: 12)
                }
            }
            Text(note).font(DS.caption).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
        }
    }
}
