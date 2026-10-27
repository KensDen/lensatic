import SwiftUI

/// A pushed screen as the redesign draws them (R2): a round back button and any trailing controls on one row, an
/// eyebrow over the title, then the content, on the ground colour, scrolling. The system bar steps aside, as on the card.
struct DetailScreen<Trailing: View, Content: View>: View {
    var eyebrow: String?
    var eyebrowColor: Color = Palette.secMaps
    let title: String
    var identifier: String
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Button { dismiss() } label: { CircleIconLabel(icon: .chevronLeft) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back")
                        .accessibilityIdentifier("back")
                    Spacer()
                    trailing
                }
                VStack(alignment: .leading, spacing: 4) {
                    if let eyebrow { Eyebrow(text: eyebrow, color: eyebrowColor, small: true) }
                    Text(keepWhole(title)).font(DS.cardTitle).foregroundStyle(Palette.fg)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("screen-title")
                }
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            .environment(\.scrollProxy, proxy)
        }
        // a screen scrolled under the status bar meets a hard edge in the page colour, never the clock over text
        .hardTopEdge()
        #if DEBUG
        .task {
            if let target = AppModel.debugScrollTo {
                try? await Task.sleep(for: .milliseconds(600))
                proxy.scrollTo(target, anchor: .top)
            }
        }
        #endif
        }
        .background(Palette.bg)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

/// The scroll view a screen's content sits in, so a control inside it can scroll to a place (the outline, R3).
extension EnvironmentValues {
    @Entry var scrollProxy: ScrollViewProxy?
}

extension DetailScreen where Trailing == EmptyView {
    init(eyebrow: String? = nil, eyebrowColor: Color = Palette.secMaps, title: String, identifier: String, @ViewBuilder content: () -> Content) {
        self.init(eyebrow: eyebrow, eyebrowColor: eyebrowColor, title: title, identifier: identifier, trailing: { EmptyView() }, content: content)
    }
}

/// The bookmark: saves the item to the Library's list, or takes it off (Framework.dc.html's filled mark when saved).
struct BookmarkButton: View {
    @Environment(AppModel.self) private var model
    let item: SavedItem
    var compact = false
    // grows with the text as the other round buttons do (R4), from 44 points to at most 60
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 44

    var body: some View {
        let saved = model.progress.isSaved(item)
        let d = min(max(side, 44), 60), glyph = 20 * d / 44
        Button { model.progress.toggleSaved(item) } label: {
            ZStack {
                if saved {
                    IconShape(paths: IconName.bookmark.paths).fill(Palette.secMaps).frame(width: glyph, height: glyph)
                } else {
                    IconShape(paths: IconName.bookmark.paths)
                        .stroke(Palette.fg, style: StrokeStyle(lineWidth: 2 * glyph / 24, lineCap: .round, lineJoin: .round))
                        .frame(width: glyph, height: glyph)
                }
            }
            .accessibilityHidden(true)
            .frame(width: d, height: d)
            .background(compact ? Color.clear : Palette.bg2, in: Circle())
            .overlay(Circle().strokeBorder(compact ? Color.clear : Palette.line, lineWidth: 1))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(saved ? "Saved" : "Save")
        .accessibilityHint(saved ? "Removes it from Saved in the Library" : "Adds it to Saved in the Library")
        .accessibilityAddTraits(saved ? .isSelected : [])
        .accessibilityIdentifier("bookmark")
        .accessibilityShowsLargeContentViewer()
    }
}

/// A segmented control as Explore.dc.html draws it: the segments share a surface, the chosen one raised. Each segment
/// is at least 44 points tall; at the accessibility sizes they stack.
struct Segmented<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    var identifier: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 2)) : AnyLayout(HStackLayout(spacing: 0))
        layout {
            ForEach(Array(options.enumerated()), id: \.element.0) { i, option in
                let (value, label) = option
                let on = value == selection
                // stacked, a hairline between the segments keeps them apart as rows (R4)
                if stacked, i > 0 { Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 10).accessibilityHidden(true) }
                Button { selection = value } label: {
                    Text(label)
                        .font(DS.segment)
                        .foregroundStyle(on ? Palette.fg : Palette.fg2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(on ? Palette.bg3 : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        // the chosen segment's edge, so it stands apart in the dark theme too (R4)
                        .overlay { if on { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.fg2, lineWidth: 1) } }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
                .accessibilityIdentifier("\(identifier)-\(value)")
            }
        }
        .padding(3)
        .frame(minHeight: 46)
        .card(radius: 10)
        .accessibilityElement(children: .contain)
    }
}

/// A small caps label with a count at its end (SAVED 4).
struct CountedLabel: View {
    let text: String
    let count: Int

    var body: some View {
        // one element that reads as it shows: the label, then the count
        HStack(alignment: .firstTextBaseline) {
            SectionLabel(text: text)
            Spacer()
            Text("\(count)").font(DS.sectionLabel).foregroundStyle(Palette.fg2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A row in a list of results or saved items: a title and a line under it, an optional colour bar at the lead, on a
/// card. The whole row is one control.
struct ResultRow: View {
    let title: String
    var line: String?
    var bar: Color?
    /// A chevron at the end, for a row that opens a list.
    var trailing = false

    var body: some View {
        HStack(spacing: 12) {
            if let bar {
                RoundedRectangle(cornerRadius: 3).fill(bar).frame(width: 6, height: 28).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(noOrphan(keepWhole(title))).font(DS.layerTitle).foregroundStyle(Palette.fg)
                if let line, !line.isEmpty { Text(noOrphan(keepWhole(line))).font(DS.caption).foregroundStyle(Palette.fg2) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            if trailing { Icon(.chevronRight, size: 16, color: Palette.fg2) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .card(radius: 12)
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// The colour of a section: the map's teal, the guides' green, the plays' purple.
func sectionColor(_ key: String) -> Color {
    switch key {
    case "guides": return Palette.secGuides
    case "playbook": return Palette.secPurple
    case "path": return Palette.accent
    default: return Palette.secMaps
    }
}
