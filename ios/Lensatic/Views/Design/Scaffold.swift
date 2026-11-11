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

/// A pushed screen as a system inset-grouped list (content release 1.0.1, section 7: the screens Explore owns): the
/// detail screen's header, the way back, the section eyebrow and the title, then the screen's own sections, on the
/// app's own surfaces (lxListSurface).
struct ListScreen<Body: View>: View {
    var eyebrow: String?
    var eyebrowColor: Color = Palette.secMaps
    let title: String
    var identifier: String
    @ViewBuilder var sections: Body
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Group {
                SwiftUI.Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Button { dismiss() } label: { CircleIconLabel(icon: .chevronLeft) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Back")
                            .accessibilityIdentifier("back")
                        VStack(alignment: .leading, spacing: 4) {
                            // the section's place in the system's own type (section 7.4: the mono eyebrow is for hero cards)
                            if let eyebrow { Text(eyebrow).font(DS.style(.subheadline).weight(.semibold)).foregroundStyle(eyebrowColor) }
                            Text(keepWhole(title)).font(DS.style(.title2)).foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier("screen-title")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 4, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                sections
            }
            .lxRows()
        }
        .listStyle(.insetGrouped)
        .lxListSurface()
        // the back button starts close under the status bar, as on the card and the reading screens: the list's own top
        // margin left an empty band above it (the fresh-eyes review of build 6, finding 16)
        .contentMargins(.top, 0, for: .scrollContent)
        .environment(\.defaultMinListRowHeight, 44)
        .hardTopEdge()
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

/// The bookmark: saves the item to Home's Saved list, or takes it off (Framework.dc.html's filled mark when saved).
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
        .accessibilityHint(saved ? "Removes it from Saved on Home" : "Adds it to Saved on Home")
        .accessibilityAddTraits(saved ? .isSelected : [])
        .accessibilityIdentifier("bookmark")
        .accessibilityShowsLargeContentViewer()
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

/// The app's own surfaces on a system inset-grouped list (Ken's ruling, 7 November 2026, over section 7.6 of the
/// content release prompt): the list keeps its structure, but its grouped background gives way to the page colour
/// (Palette.bg), so Library, Explore and the layer screens match Welcome, Search, My Path and the rest, and the tab bar,
/// in light and dark. The rows take the card fill and the separators the palette's line through lxRows.
extension View {
    func lxListSurface() -> some View {
        scrollContentBackground(.hidden).background(Palette.bg)
    }

    /// Every row inside: the card fill (Palette.bg2, the fill of .card()) and the palette's hairline for the separators.
    /// A row that sets its own background (a header on the page colour, the AI column's tint) keeps it.
    func lxRows() -> some View {
        listRowBackground(Palette.bg2).listRowSeparatorTint(Palette.line).listSectionSeparatorTint(Palette.line)
    }
}
