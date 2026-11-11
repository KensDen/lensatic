import SwiftUI
import UIKit

/// The glossary (Home, Reference): every abbreviation the map uses, spelled out, with a plain sentence and the entries
/// it names. A system inset-grouped list on the app's own surfaces (build 6: the section 7 rule), one row per term.
struct GlossaryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let screen = model.screen("glossary") { GlossaryScreen(store: model.store) }
        ListScreen(title: model.store.navTitle(.glossary), identifier: "glossary-screen") {
            if let intro = screen.intro {
                SwiftUI.Section {
                    ProseText(run: screen.prose[intro], font: DS.style(.subheadline), mono: DS.style(.subheadline), color: Palette.fg2)
                        .padding(.vertical, 2)
                }
            }
            SwiftUI.Section {
                ForEach(screen.items, id: \.slug) { item in GlossaryItemView(item: item, prose: screen.prose) }
            } header: {
                ListNote("\(screen.items.count) terms")
            }
        }
    }
}

/// One glossary entry opened from a linked term, over the screen it was tapped on.
struct GlossarySheetView: View {
    @Environment(AppModel.self) private var model
    let slug: String

    var body: some View {
        let screen = model.screen("glossary-\(slug)") { GlossaryScreen(store: model.store, only: slug) }
        BottomSheet {
            HStack {
                Text(model.store.navTitle(.glossary)).font(DS.style(.title3)).foregroundStyle(.primary).accessibilityAddTraits(.isHeader)
                Spacer()
                Button { model.glossaryEntry = nil } label: {
                    Text("Done").font(DS.style(.body)).foregroundStyle(Palette.link).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("glossary-done")
            }
            ForEach(screen.items, id: \.slug) { item in GlossaryItemView(item: item, prose: screen.prose).lxCard(radius: 12) }
        }
    }
}

/// A glossary entry: the term, its expansion and plain sentence, the entries it names and, where its spelling could not
/// be confirmed, its badge. A row of the glossary's list, and the card in the sheet a linked term opens.
struct GlossaryItemView: View {
    @Environment(AppModel.self) private var model
    let item: GlossaryScreen.Item
    let prose: Prose

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ProseText(run: prose[item.term], font: DS.style(.headline), mono: DS.style(.headline)).accessibilityAddTraits(.isHeader)
            ProseText(run: prose[item.body], font: DS.style(.subheadline), mono: DS.style(.subheadline), color: Palette.fg2)
            if !item.entityIds.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(item.entityIds, id: \.self) { eid in
                        if let e = model.store.entities[eid] {
                            Button {
                                model.glossaryEntry = nil
                                model.push(.entity(eid))
                            } label: { Pill(text: e.shortName) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("gl-\(item.slug)-\(eid)")
                        }
                    }
                }
            }
            if let v = item.status {
                Text(Rules.badgeText(v, ui: model.store.content.ui)).font(DS.style(.footnote)).foregroundStyle(v.status == .conflict ? Palette.bad : Palette.fg2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("gl-\(item.slug)")
    }
}

/// All sources (Home, Reference): every framework, source and solution with its citation and its check; each opens its
/// card. A system inset-grouped list (build 6: the section 7 rule), one section per kind.
struct SourcesListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let screen = model.screen("sources") { SourcesScreen(store: model.store) }
        ListScreen(title: "All Sources", identifier: "sources-screen") {
            SwiftUI.Section {
                ProseText(run: screen.prose[screen.intro], font: DS.style(.subheadline), mono: DS.style(.subheadline), color: Palette.fg2)
                    .padding(.vertical, 2)
            }
            ForEach(screen.groups, id: \.title) { g in
                SwiftUI.Section {
                    ForEach(g.entries, id: \.entity.id) { e, cite in
                        NavigationLink(value: Nav.entity(e.id)) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(keepWhole(e.displayName)).font(DS.style(.body)).foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                ProseText(run: screen.prose[cite], font: DS.style(.footnote), mono: DS.style(.footnote), color: Palette.fg2, lineSpacing: 2)
                                Text(status(e.verification)).font(DS.style(.footnote))
                                    .foregroundStyle(e.verification.status == .conflict ? Palette.bad : Palette.secMaps)
                            }
                            .multilineTextAlignment(.leading)
                            .padding(.vertical, 2)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("ent-row-\(e.id)")
                    }
                } header: {
                    ListNote(g.title)
                }
            }
        }
    }

    private func status(_ v: Verification) -> String {
        let name = model.store.content.ui.status[v.status.rawValue] ?? v.status.rawValue
        return v.verifiedOn.map { "\(name)\(model.store.label("metaSeparator"))\(unbroken(Rules.formatDate($0)))" } ?? name
    }
}

/// The story of the name with the maker's photo (the compass on a world map since R5): About's, and the story
/// sheet's.
struct NameStory: View {
    let screen: AboutScreen

    var body: some View {
        if let image = UIImage(named: "about-photo.jpg") {
            Image(uiImage: image).resizable().scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line))
                .accessibilityLabel(Text(screen.photoAlt))
                .accessibilityAddTraits(.isImage)
                .accessibilityIdentifier("about-photo")
        }
        ForEach(screen.story, id: \.self) { ProseText(run: screen.prose[$0], font: DS.style(.callout), mono: DS.style(.callout), color: .primary) }
    }
}

/// Why "Lensatic" from the Welcome screen (R5, item 17): the compass tile opens the story as a sheet, the photo and the
/// two paragraphs, without leaving the pick.
struct StorySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let s = model.screen("about") { AboutScreen(store: model.store) }
        BottomSheet {
            HStack(alignment: .firstTextBaseline) {
                Text("Why \u{201C}\(s.name)\u{201D}").font(DS.style(.title3)).foregroundStyle(.primary).accessibilityAddTraits(.isHeader)
                Spacer()
                Button { dismiss() } label: {
                    Text("Done").font(DS.style(.body)).foregroundStyle(Palette.link).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("story-done")
            }
            NameStory(screen: s)
        }
        // the photo and two paragraphs are longer than a phone's half sheet: the story opens at full height
        .presentationDetents([.large])
        .accessibilityIdentifier("story-sheet")
    }
}

/// About Lensatic (Home, About): the name and versions, the tagline and zero trust as the spine, the story of the name
/// with the maker's photo, what the map is and is not, the counts, how it was built, and the links. A system inset-grouped
/// list (build 6: the section 7 rule).
struct AboutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let s = model.screen("about") { AboutScreen(store: model.store) }
        let sep = model.store.label("metaSeparator")
        // no eyebrow: the screen is Lensatic's own About, not the map's. Since build 6 Home has a row for the story of the
        // name and a row for About, so this screen takes the About row's name and the story keeps its own heading below
        ListScreen(title: model.store.label("homeAbout").replacingOccurrences(of: "{name}", with: s.name), identifier: "about-screen") {
            SwiftUI.Section {
                VStack(alignment: .leading, spacing: 8) {
                    // the locked tagline, then zero trust as the spine of the map in one sentence (content release 1.0.1, 3.2)
                    let meta = model.store.content.meta
                    Text(keepWhole("\(meta.tagline) \(meta.ztSpine)")).font(DS.style(.body)).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("about-tagline")
                    // each part kept whole, the release date with the word before it, and each dot with the part after it (R5)
                    Text(dotted(s.version.components(separatedBy: sep), separator: sep)).font(DS.style(.footnote)).foregroundStyle(Palette.fg2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("about-version")
                }
                .padding(.vertical, 4)
            }
            SwiftUI.Section {
                VStack(alignment: .leading, spacing: 12) { NameStory(screen: s) }
                    .padding(.vertical, 6)
            } header: {
                // the story's own heading (Why "Lensatic"), under the screen's title
                ListNote(s.storyHeading).accessibilityIdentifier("about-name")
            }
            SwiftUI.Section {
                ForEach(s.paragraphs, id: \.self) { ProseText(run: s.prose[$0], font: DS.style(.callout), mono: DS.style(.callout), color: .primary) }
                ForEach(s.small, id: \.self) { ProseText(run: s.prose[$0], font: DS.style(.subheadline), mono: DS.style(.subheadline), color: Palette.fg2) }
            }
            SwiftUI.Section {
                ForEach(s.counts, id: \.status) { c in
                    HStack {
                        Text(c.label).font(DS.style(.body)).foregroundStyle(.primary)
                        Spacer()
                        Text("\(c.count)").font(DS.style(.body)).foregroundStyle(Palette.fg2)
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                ListNote(model.store.label("counts"))
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("counts")
            SwiftUI.Section {
                aboutLink(Site.privacy, model.store.label("pagesPrivacy"), "link-privacy")
                aboutLink(Site.support, model.store.label("pagesSupport"), "link-support")
                aboutLink(Site.source, model.store.label("sourceCode"), "link-source")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let made = s.madeBy { ListNote(made) }
                    ProseText(run: s.prose[s.builtWith], font: DS.style(.footnote), mono: DS.style(.footnote), color: Palette.fg2)
                    ListNote(model.store.label("footerLicenses"))
                }
                .font(DS.style(.footnote))
                .padding(.top, 4)
            }
        }
    }

    /// An outside address as a list row: its name in the link colour and the mark of a link that leaves the screen. It
    /// opens in the in-app reader.
    private func aboutLink(_ url: URL, _ label: String, _ id: String) -> some View {
        let host = url.host().map { $0.hasPrefix("www.") ? String($0.dropFirst(4)) : $0 } ?? url.absoluteString
        return Button { Reader.open(url) } label: {
            HStack(spacing: 8) {
                Text(label).font(DS.style(.body)).foregroundStyle(Palette.link)
                    .frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                Image(systemName: "arrow.up.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint("Opens \(host) in Safari, inside the app")
        .accessibilityIdentifier(id)
    }
}
