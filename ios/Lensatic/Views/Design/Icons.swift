import SwiftUI

/// The redesign's icons, drawn from the mockups' own SVG paths on a 24-point grid (handoffs, the R1 mockups), so the
/// app shows the same marks the approved screens show. Each icon is one or more path strings; `SVGPath` reads them.
enum IconName: String, CaseIterable, Sendable {
    case compass, layers, search, library, shield, shieldCheck, building, briefcase, globe, landmark
    case chevronRight, chevronLeft, check, circle, checkCircle, bookmark, share, info, doc
    case map, star, chip, close, expand, loop

    var paths: [String] {
        switch self {
        case .compass: return [SVGPath.circle(12, 12, 9), "M15.5 8.5l-2 5-5 2 2-5z"]
        case .layers: return ["M12 3l9 5-9 5-9-5z", "M3 13l9 5 9-5"]
        case .search: return [SVGPath.circle(11, 11, 7), "M20 20l-4-4"]
        case .library: return ["M4 19V5a2 2 0 012-2h12v18H6a2 2 0 01-2-2z", "M8 7h6"]
        case .shield: return ["M12 3l8 4v5c0 5-3.5 8-8 9-4.5-1-8-4-8-9V7z"]
        case .shieldCheck: return ["M12 3l8 4v5c0 5-3.5 8-8 9-4.5-1-8-4-8-9V7z", "M9 12l2 2 4-4"]
        case .building: return ["M3 21h18M5 21V10l7-5 7 5v11M9 21v-6h6v6"]
        case .briefcase: return ["M5 7h14a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9a2 2 0 012-2z", "M8 7V5a2 2 0 012-2h4a2 2 0 012 2v2"]
        case .globe: return [SVGPath.circle(12, 12, 9), "M3 12h18M12 3a14 14 0 010 18M12 3a14 14 0 000 18"]
        case .landmark: return ["M3 21h18M4 9h16M12 3l8 4H4z", "M6 9v9M10 9v9M14 9v9M18 9v9M4 18h16"]
        case .chevronRight: return ["M9 6l6 6-6 6"]
        case .chevronLeft: return ["M15 6l-6 6 6 6"]
        case .check: return ["M7 12.5l3 3 7-7"]
        case .circle: return [SVGPath.circle(12, 12, 10)]
        case .checkCircle: return [SVGPath.circle(12, 12, 10), "M8 12.5l3 3 5-6"]
        case .bookmark: return ["M6 3h12v18l-6-4-6 4z"]
        case .share: return ["M12 3v12M7 8l5-5 5 5M5 14v6h14v-6"]
        case .info: return [SVGPath.circle(12, 12, 10), "M12 11v6M12 7.5v.5"]
        case .doc: return ["M6 3h9l4 4v14H6z", "M14 3v5h5"]
        case .map: return ["M3 6l6-3 6 3 6-3v15l-6 3-6-3-6 3z", "M9 3v15M15 6v15"]
        case .star: return ["M12 3l3 6 6 1-4.5 4 1 6-5.5-3-5.5 3 1-6L3 10l6-1z"]
        case .chip: return ["M8 5h8a3 3 0 013 3v8a3 3 0 01-3 3H8a3 3 0 01-3-3V8a3 3 0 013-3z", "M9 1v4M15 1v4M9 19v4M15 19v4M1 9h4M1 15h4M19 9h4M19 15h4"]
        case .close: return ["M6 6l12 12M18 6L6 18"]
        case .expand: return ["M14 4h6v6", "M10 20H4v-6", "M20 4l-7 7", "M4 20l7-7"]
        case .loop: return ["M19 12a7 7 0 1 1-2.05-4.95", "M19 4v4h-4"]
        }
    }
}

/// One icon, stroked as the mockups stroke it (round caps and joins). It is decoration: the control around it carries
/// the accessible name.
struct Icon: View {
    let name: IconName
    var size: CGFloat = 24
    var color: Color = Palette.fg
    var lineWidth: CGFloat = 2
    /// Scales with Dynamic Type beside the text it sits with.
    var relativeTo: Font.TextStyle = .body
    @ScaledMetric private var scale: CGFloat = 1

    init(_ name: IconName, size: CGFloat = 24, color: Color = Palette.fg, lineWidth: CGFloat = 2, relativeTo: Font.TextStyle = .body) {
        self.name = name
        self.size = size
        self.color = color
        self.lineWidth = lineWidth
        self.relativeTo = relativeTo
        _scale = ScaledMetric(wrappedValue: 1, relativeTo: relativeTo)
    }

    var body: some View {
        let side = size * min(scale, 2)
        IconShape(paths: name.paths)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth * side / 24, lineCap: .round, lineJoin: .round))
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}

/// A filled disc with a check knocked out of it: a step that is done (the mockup's filled check).
struct DoneMark: View {
    var size: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let side = size * min(scale, 2)
        ZStack {
            Circle().fill(Palette.secMaps).frame(width: side * 22 / 24, height: side * 22 / 24)
            IconShape(paths: IconName.check.paths)
                .stroke(Palette.onSecMaps, style: StrokeStyle(lineWidth: 2.2 * side / 24, lineCap: .round, lineJoin: .round))
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

struct IconShape: Shape {
    let paths: [String]

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var out = Path()
        for p in paths { out.addPath(SVGPath.parse(p), transform: CGAffineTransform(scaleX: s, y: s).translatedBy(x: rect.minX / s, y: rect.minY / s)) }
        return out
    }
}

/// A small reader for the SVG path syntax the mockups use: move, line, horizontal, vertical, cubic, smooth cubic,
/// quadratic, arc and close, absolute and relative. Arcs become cubic curves (the SVG specification's appendix on arc
/// implementation, F.6).
enum SVGPath {
    static func circle(_ cx: Double, _ cy: Double, _ r: Double) -> String {
        "M\(cx - r) \(cy)a\(r) \(r) 0 1 0 \(2 * r) 0a\(r) \(r) 0 1 0 \(-2 * r) 0z"
    }

    static func parse(_ d: String) -> Path {
        var tokens: [String] = []
        var num = ""
        func flush() { if !num.isEmpty { tokens.append(num); num = "" } }
        for ch in d {
            if ch.isLetter && ch != "e" {
                flush()
                tokens.append(String(ch))
            } else if ch == "-" && !num.isEmpty && num.last != "e" {
                flush()
                num = "-"
            } else if ch == "." && num.contains(".") {
                flush()
                num = "."
            } else if ch == "," || ch == " " || ch == "\n" {
                flush()
            } else {
                num.append(ch)
            }
        }
        flush()

        var path = Path()
        var i = 0, cmd: Character = "M"
        var cur = CGPoint.zero, start = CGPoint.zero, lastCtrl: CGPoint?
        func n() -> CGFloat { defer { i += 1 }; return CGFloat(Double(tokens[i]) ?? 0) }
        // arc flags may be written together with the next number ("010" is 0, 1, 0): read one digit
        func flag() -> Bool {
            let t = tokens[i]
            if t.count > 1 && (t.hasPrefix("0") || t.hasPrefix("1")) && !t.hasPrefix("0.") {
                tokens[i] = String(t.dropFirst())
                return t.hasPrefix("1")
            }
            i += 1
            return t == "1"
        }
        while i < tokens.count {
            if let c = tokens[i].first, tokens[i].count == 1, c.isLetter { cmd = c; i += 1 }
            let rel = cmd.isLowercase
            let base = rel ? cur : .zero
            switch cmd.uppercased().first! {
            case "M":
                cur = CGPoint(x: base.x + n(), y: base.y + n()); start = cur; path.move(to: cur)
                cmd = rel ? "l" : "L"; lastCtrl = nil
            case "L":
                cur = CGPoint(x: base.x + n(), y: base.y + n()); path.addLine(to: cur); lastCtrl = nil
            case "H":
                cur = CGPoint(x: (rel ? cur.x : 0) + n(), y: cur.y); path.addLine(to: cur); lastCtrl = nil
            case "V":
                cur = CGPoint(x: cur.x, y: (rel ? cur.y : 0) + n()); path.addLine(to: cur); lastCtrl = nil
            case "C":
                let c1 = CGPoint(x: base.x + n(), y: base.y + n()), c2 = CGPoint(x: base.x + n(), y: base.y + n())
                cur = CGPoint(x: base.x + n(), y: base.y + n())
                path.addCurve(to: cur, control1: c1, control2: c2); lastCtrl = c2
            case "S":
                let c1 = lastCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = CGPoint(x: base.x + n(), y: base.y + n())
                cur = CGPoint(x: base.x + n(), y: base.y + n())
                path.addCurve(to: cur, control1: c1, control2: c2); lastCtrl = c2
            case "Q":
                let c = CGPoint(x: base.x + n(), y: base.y + n())
                cur = CGPoint(x: base.x + n(), y: base.y + n())
                path.addQuadCurve(to: cur, control: c); lastCtrl = nil
            case "A":
                let rx = n(), ry = n(), rot = n(), large = flag(), sweep = flag()
                let end = CGPoint(x: base.x + n(), y: base.y + n())
                arc(&path, from: cur, to: end, rx: rx, ry: ry, rotation: rot, large: large, sweep: sweep)
                cur = end; lastCtrl = nil
            case "Z":
                path.closeSubpath(); cur = start; lastCtrl = nil
                if i < tokens.count, Double(tokens[i]) != nil { cmd = rel ? "l" : "L" }  // numbers after a close: a line
            default:
                i += 1
            }
        }
        return path
    }

    private static func arc(_ path: inout Path, from p0: CGPoint, to p1: CGPoint, rx rx0: CGFloat, ry ry0: CGFloat,
                            rotation: CGFloat, large: Bool, sweep: Bool) {
        if p0 == p1 { return }
        var rx = abs(rx0), ry = abs(ry0)
        if rx == 0 || ry == 0 { path.addLine(to: p1); return }
        let phi = rotation * .pi / 180, cosp = cos(phi), sinp = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1 = cosp * dx + sinp * dy, y1 = -sinp * dx + cosp * dy
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 { rx *= sqrt(lambda); ry *= sqrt(lambda) }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var coef = sqrt(max(0, num / den))
        if large == sweep { coef = -coef }
        let cxp = coef * rx * y1 / ry, cyp = -coef * ry * x1 / rx
        let cx = cosp * cxp - sinp * cyp + (p0.x + p1.x) / 2, cy = sinp * cxp + cosp * cyp + (p0.y + p1.y) / 2
        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let a = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
            return a
        }
        let t1 = angle(1, 0, (x1 - cxp) / rx, (y1 - cyp) / ry)
        var dt = angle((x1 - cxp) / rx, (y1 - cyp) / ry, (-x1 - cxp) / rx, (-y1 - cyp) / ry)
        if !sweep && dt > 0 { dt -= 2 * .pi } else if sweep && dt < 0 { dt += 2 * .pi }
        let segments = Int(ceil(abs(dt) / (.pi / 2)))
        let delta = dt / CGFloat(segments)
        let k = 4.0 / 3.0 * tan(delta / 4)
        var t = t1
        func point(_ a: CGFloat) -> CGPoint {
            CGPoint(x: cx + rx * cos(a) * cosp - ry * sin(a) * sinp, y: cy + rx * cos(a) * sinp + ry * sin(a) * cosp)
        }
        func deriv(_ a: CGFloat) -> CGPoint {
            CGPoint(x: -rx * sin(a) * cosp - ry * cos(a) * sinp, y: -rx * sin(a) * sinp + ry * cos(a) * cosp)
        }
        for _ in 0..<segments {
            let a = point(t), b = point(t + delta), da = deriv(t), db = deriv(t + delta)
            path.addCurve(to: b, control1: CGPoint(x: a.x + k * da.x, y: a.y + k * da.y),
                          control2: CGPoint(x: b.x - k * db.x, y: b.y - k * db.y))
            t += delta
        }
    }
}
