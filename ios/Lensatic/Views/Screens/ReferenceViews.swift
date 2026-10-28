import SwiftUI
import UIKit

/// The glossary (Library, Reference): every abbreviation the map uses, spelled out, with a plain sentence and the
/// entries it names.
struct GlossaryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let screen = model.screen("glossary") { GlossaryScreen(store: model.store) }
        DetailScreen(title: model.store.navTitle(.glossary), identifier: "glossary-screen") {
            if let intro = screen.intro { ProseText(run: screen.prose[intro], font: DS.answer, color: Palette.fg2) }
            ForEach(screen.items, id: \.slug) { item in GlossaryItemView(item: item, prose: screen.prose) }
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
                Text(model.store.navTitle(.glossary)).font(DS.sheetTitle).foregroundStyle(Palette.fg).accessibilityAddTraits(.isHeader)
                Spacer()
                Button { model.glossaryEntry = nil } label: {
                    Text("Done").font(DS.link).foregroundStyle(Palette.link).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("glossary-done")
            }
            ForEach(screen.items, id: \.slug) { item in GlossaryItemView(item: item, prose: screen.prose) }
        }
    }
}

struct GlossaryItemView: View {
    @Environment(AppModel.self) private var model
    let item: GlossaryScreen.Item
    let prose: Prose

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProseText(run: prose[item.term], font: DS.readerHeading, mono: DS.readerHeading).accessibilityAddTraits(.isHeader)
            ProseText(run: prose[item.body], font: DS.step)
            if !item.entityIds.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(item.entityIds, id: \.self) { eid in
                        if let e = model.store.entities[eid] {
                            Button {
                                model.glossaryEntry = nil
                                model.push(.entity(eid))
                            } label: { Pill(text: e.shortName) }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            if let v = item.status {
                Text(Rules.badgeText(v, ui: model.store.content.ui)).font(DS.caption).foregroundStyle(v.status == .conflict ? Palette.bad : Palette.fg2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("gl-\(item.slug)")
    }
}

/// All sources (Library, Reference): every framework, source and solution with its citation and its check; each opens
/// its card.
struct SourcesListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let screen = model.screen("sources") { SourcesScreen(store: model.store) }
        DetailScreen(title: "All Sources", identifier: "sources-screen") {
            ProseText(run: screen.prose[screen.intro], font: DS.answer, color: Palette.fg2)
            ForEach(screen.groups, id: \.title) { g in
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: g.title)
                    ForEach(g.entries, id: \.entity.id) { e, cite in
                        Button { model.push(.entity(e.id)) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(keepWhole(e.displayName)).font(DS.layerTitle).foregroundStyle(Palette.fg)
                                ProseText(run: screen.prose[cite], font: DS.caption, color: Palette.fg2, lineSpacing: 2)
                                Text(status(e.verification)).font(DS.caption).foregroundStyle(e.verification.status == .conflict ? Palette.bad : Palette.secMaps)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .padding(12)
                            .card(radius: 12)
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("ent-row-\(e.id)")
                    }
                }
            }
        }
    }

    private func status(_ v: Verification) -> String {
        let name = model.store.content.ui.status[v.status.rawValue] ?? v.status.rawValue
        return v.verifiedOn.map { "\(name)\(model.store.label("metaSeparator"))\(unbroken(Rules.formatDate($0)))" } ?? name
    }
}

/// The story of the name with the maker's photo (the compass on a world map since R5): About's, and the Welcome
/// screen's sheet's.
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
        ForEach(screen.story, id: \.self) { ProseText(run: screen.prose[$0], font: DS.answer) }
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
                Text("Why \u{201C}\(s.name)\u{201D}").font(DS.sheetTitle).foregroundStyle(Palette.fg).accessibilityAddTraits(.isHeader)
                Spacer()
                Button { dismiss() } label: {
                    Text("Done").font(DS.link).foregroundStyle(Palette.link).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
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

/// Why "Lensatic" (Library, Reference): the name and versions, what the map is, how it was checked, the counts, the
/// links, and the story of the name with the maker's photo.
struct AboutView: View {
    @Environment(AppModel.self) private var model

    /// A heading without its quotation marks, in lower case, to compare two headings.
    static func plain(_ s: String) -> String {
        s.filter { !"\"'\u{2018}\u{2019}\u{201C}\u{201D}".contains($0) }.lowercased()
    }

    var body: some View {
        let s = model.screen("about") { AboutScreen(store: model.store) }
        DetailScreen(eyebrow: model.store.navTitle(.about), title: "Why \u{201C}\(s.name)\u{201D}", identifier: "about-screen") {
            // each part kept whole, the release date with the word before it, and each dot with the part after it (R5)
            Text(dotted(s.version.components(separatedBy: model.store.label("metaSeparator")), separator: model.store.label("metaSeparator"))).font(DS.eyebrowSmall).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("about-version")
            VStack(alignment: .leading, spacing: 14) {
                // the story's heading is the screen's own title here (Why "Lensatic"), so it is not said twice (R4)
                if AboutView.plain(s.storyHeading) != AboutView.plain("Why \(s.name)") {
                    Text(s.storyHeading).font(DS.readerHeading).foregroundStyle(Palette.fg).accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("about-name")
                }
                NameStory(screen: s)
            }
            ForEach(s.paragraphs, id: \.self) { ProseText(run: s.prose[$0], font: DS.answer) }
            ForEach(s.small, id: \.self) { ProseText(run: s.prose[$0], font: DS.step, color: Palette.fg2) }
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: model.store.label("counts"), tracked: false)
                FlowLayout(spacing: 6) {
                    ForEach(s.counts, id: \.status) { c in
                        Text("\(c.label) \(c.count)").font(DS.eyebrowSmall).foregroundStyle(Palette.fg)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .overlay(Capsule().strokeBorder(c.status == .verified ? Palette.secMaps : Palette.lineStrong, lineWidth: 1))
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("counts")
            if let made = s.madeBy { Text(made).font(DS.step).foregroundStyle(Palette.fg2) }
            ProseText(run: s.prose[s.builtWith], font: DS.step, color: Palette.fg2)
            VStack(alignment: .leading, spacing: 0) {
                OutsideLink(url: Site.privacy, label: model.store.label("pagesPrivacy")).accessibilityIdentifier("link-privacy")
                OutsideLink(url: Site.support, label: model.store.label("pagesSupport")).accessibilityIdentifier("link-support")
                OutsideLink(url: Site.source, label: model.store.label("sourceCode")).accessibilityIdentifier("link-source")
            }
            Text(model.store.label("footerLicenses")).font(DS.eyebrowSmall).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
        }
    }
}
