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
        }
        .background(Palette.bg)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
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

    var body: some View {
        let saved = model.progress.isSaved(item)
        Button { model.progress.toggleSaved(item) } label: {
            ZStack {
                if saved {
                    IconShape(paths: IconName.bookmark.paths).fill(Palette.secMaps).frame(width: 20, height: 20)
                } else {
                    Icon(.bookmark, size: 20, color: Palette.fg)
                }
            }
            .frame(width: 44, height: 44)
            .background(compact ? Color.clear : Palette.bg2, in: Circle())
            .overlay(Circle().strokeBorder(compact ? Color.clear : Palette.line, lineWidth: 1))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(saved ? "Saved" : "Save")
        .accessibilityHint(saved ? "Removes it from Saved in the Library" : "Adds it to Saved in the Library")
        .accessibilityAddTraits(saved ? .isSelected : [])
        .accessibilityIdentifier("bookmark")
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
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 2)) : AnyLayout(HStackLayout(spacing: 0))
        layout {
            ForEach(options, id: \.0) { value, label in
                let on = value == selection
                Button { selection = value } label: {
                    Text(label)
                        .font(DS.segment)
                        .foregroundStyle(on ? Palette.fg : Palette.fg2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(on ? Palette.bg3 : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    var body: some View {
        HStack(spacing: 12) {
            if let bar {
                RoundedRectangle(cornerRadius: 3).fill(bar).frame(width: 6, height: 28).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(keepWhole(title)).font(DS.layerTitle).foregroundStyle(Palette.fg)
                if let line, !line.isEmpty { Text(keepWhole(line)).font(DS.caption).foregroundStyle(Palette.fg2) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
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
