import SwiftUI

/// A run of the map's prose after the first-use rule: expansions in the secondary colour, glossary terms linked to
/// their entry with a dotted underline, links to entries and outside addresses underlined. Links inside text carry
/// their target as an address (Target.url); the Shell's `openURL` follows internal ones in the app and hands outside
/// ones to the system browser. Labels inside a control describe it with the expansions they carry (the hint).
struct ProseText: View {
    let run: Run
    var font: Font = DS.summary
    var mono: Font = DS.monoText
    var color: Color = Palette.fg
    var lineSpacing: CGFloat = 3

    var body: some View {
        Text(attributed)
            .foregroundStyle(color)
            .lineSpacing(lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHint(run.described.joined(separator: ", "))
    }

    private var attributed: AttributedString {
        let segments = run.segments.isEmpty ? run.spans.map { Segment.text($0.text, $0.style, $0.link) } : run.segments
        var out = AttributedString()
        for seg in segments {
            var a = AttributedString(keepWhole(seg.string))
            switch seg {
            case .text(_, let s, let target):
                a.font = face(s)
                if s == .monoStrong { a.foregroundColor = Palette.accent }
                if let url = target?.url {
                    a.link = url
                    a.foregroundColor = Palette.link
                }
            case .term(_, let slug, let s):
                a.font = face(s)
                a.link = Target.glossary(slug).url
                a.foregroundColor = color
                a.underlineStyle = Text.LineStyle(pattern: .dot, color: Palette.fg2)
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
        switch s {
        case .plain, .url: return font
        case .strong: return font.weight(.semibold)
        case .mono, .monoStrong: return mono
        }
    }
}
