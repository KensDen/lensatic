import SwiftUI

// The plays tied into the navigator (Lensatic 2.0, Round 3): on a play, the frameworks it touches and the elements in
// each; on a framework and on an element, the plays that touch it; and Home's lead story. Every link and every word
// comes from content/frameworks/play-links.json, which says on screen whose reading the links are: Lensatic's own, since
// no publisher prints a crosswalk from the plays to these frameworks.

/// A play's way into the navigator: one card for each framework it touches, with the line that says why and the count
/// of elements. A card with elements opens to list them, each a way to that element; a card without opens the framework.
struct PlayLinksSection: View {
    @Environment(AppModel.self) private var model
    let playId: String
    @State private var open: Set<String> = []

    var body: some View {
        let L = model.frameworks
        let links = L.links(forPlay: playId)
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(text: L.label("playsIn"))
                    Text(L.linkLine(forPlay: playId))
                        .font(DS.caption).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("play-links-count")
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                // whose judgment the links are, said before the first of them (the fresh-eyes review, P5-3)
                if let basis = L.playLinks?.basis {
                    Text(basis).font(DS.caption).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("play-links-basis")
                }
                ForEach(links) { link in
                    if let f = L.byId[link.frameworkId], let graph = L.graphs[link.frameworkId] {
                        PlayLinkCard(framework: f, graph: graph, link: link, isOpen: open.contains(link.frameworkId)) {
                            if open.contains(link.frameworkId) { open.remove(link.frameworkId) } else { open.insert(link.frameworkId) }
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("play-links")
            #if DEBUG
            // -LensaticLinksOpen opens the first framework's elements, for the captures
            .onAppear { if CommandLine.arguments.contains("-LensaticLinksOpen"), let first = links.first(where: { !$0.nodeIds.isEmpty }) { open.insert(first.frameworkId) } }
            #endif
        }
    }
}

/// One framework a play touches. The head is one control: it opens the elements where the link names some, and the
/// framework where it names none. Opened, each element is a row to its own screen, and the last row is the framework.
struct PlayLinkCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let framework: Framework
    let graph: FrameworkLibrary.Graph
    let link: PlayLinks.Link
    let isOpen: Bool
    let toggle: () -> Void

    var body: some View {
        let L = model.frameworks, f = framework
        let count = L.countLine(link)
        VStack(alignment: .leading, spacing: 0) {
            Button { if link.nodeIds.isEmpty { model.push(.framework(f.id)) } else { toggle() } } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 10) {
                        FrameworkTile(framework: f, base: 30)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(keepDesignations(f.shortName)).font(DS.stepStrong).foregroundStyle(Palette.fg).fixedSize(horizontal: false, vertical: true)
                            Eyebrow(text: count ?? f.kind, color: f.tone, small: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: link.nodeIds.isEmpty ? "chevron.forward" : "chevron.down")
                            .font(.footnote.weight(.semibold)).foregroundStyle(Palette.fg2)
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    Text(keepWhole(link.line)).font(DS.step).foregroundStyle(Palette.fg2).lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([f.shortName, count, link.line].compactMap { $0 }.joined(separator: ". "))
            .accessibilityValue(link.nodeIds.isEmpty ? "" : (isOpen ? "Expanded" : "Collapsed"))
            .accessibilityHint(link.nodeIds.isEmpty ? L.label("openIt") : L.label(isOpen ? "hideElements" : "showElements"))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("play-link-\(f.id)")
            if isOpen {
                ForEach(link.nodeIds.compactMap { graph.node($0) }) { node in
                    Divider().overlay(Palette.line).padding(.leading, 12)
                    Button { model.push(.node(f.id, node.id)) } label: {
                        (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))) {
                            if graph.identified(node) { NodeBadge(id: node.id, tone: f.tone) }
                            Text(graph.line(node)).font(DS.step).foregroundStyle(Palette.fg)
                                .frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            if !typeSize.isAccessibilitySize {
                                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(graph.name(node))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("play-link-\(f.id)-\(node.id)")
                }
                Divider().overlay(Palette.line).padding(.leading, 12)
                Button { model.push(.framework(f.id)) } label: {
                    Text("\(L.label("openIt")): \(f.shortName)").font(DS.link).foregroundStyle(Palette.link)
                        .frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("play-link-\(f.id)-open")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 12)
    }
}

/// The plays that touch a framework (opened from the framework's screen): each play with the line that says why and the
/// count of this framework's elements it names. A system list on the app's surfaces.
struct PlaysOnFrameworkView: View {
    @Environment(AppModel.self) private var model
    let frameworkId: String

    var body: some View {
        let L = model.frameworks, lib = model.library
        if let f = L.byId[frameworkId] {
            let touching = L.plays(touching: frameworkId)
            ListScreen(eyebrow: f.shortName, eyebrowColor: f.tone, title: L.label("playsOn"), identifier: "plays-on-screen") {
                SwiftUI.Section {
                    Text(PlaysOnFrameworkView.countLine(touching.count, of: lib.plays.plays.count, labels: L))
                        .font(DS.style(.headline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 2)
                        .accessibilityIdentifier("plays-on-count")
                } footer: {
                    if let basis = L.playLinks?.basis { ListNote(basis).accessibilityIdentifier("plays-on-basis") }
                }
                ForEach(lib.plays.groups, id: \.label) { group in
                    let rows = touching.filter { group.playIds.contains($0.playId) }
                    if !rows.isEmpty {
                        SwiftUI.Section {
                            ForEach(rows, id: \.playId) { row in
                                if let play = lib.play(row.playId) { PlayLinkRow(play: play, line: row.link.line, count: L.countLine(row.link)) }
                            }
                        } header: {
                            ListNote(group.label)
                        }
                    }
                }
            }
        }
    }

    /// "8 of the 35 plays touch it", "1 of the 35 plays touches it".
    static func countLine(_ n: Int, of m: Int, labels L: FrameworkLibrary) -> String {
        L.label(n == 1 ? "playsOnLineOne" : "playsOnLine").replacingOccurrences(of: "{n}", with: "\(n)").replacingOccurrences(of: "{m}", with: "\(m)")
    }
}

/// A play as a list row in the navigator: its name, and under it why it is here; opens the play.
struct PlayLinkRow: View {
    let play: Plays.Play
    var line: String?
    var count: String?

    var body: some View {
        NavigationLink(value: Nav.play(play.id)) {
            HStack(alignment: .top, spacing: 12) {
                IconTile(symbol: RowIcon.playbook.0, tint: RowIcon.playbook.1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(noOrphan(keepWhole(play.name))).font(DS.style(.body)).foregroundStyle(.primary)
                    if let count { Text(count).font(DS.style(.footnote).weight(.semibold)).foregroundStyle(Palette.secPurple) }
                    if let line { Text(line).font(DS.style(.footnote)).foregroundStyle(Palette.fg2) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("play-row-\(play.id)")
    }
}

/// Home's lead story (Lensatic 2.0, Round 3): agents as the new insiders. The story's title and line from the content,
/// then the plays to start with, each a control of its own. The card is the way into the plays, so it carries what that
/// door carried: the section's name, the count of plays read, and the way to all of them. On a phone it is compact, so
/// the story, the countdown, the frameworks and the other two doors share the first screen.
struct HomeStory: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let story: PlayLinks.Story
    /// The iPad: the story's full line, and room for the status.
    var wide = false

    var body: some View {
        let site = model.library.site
        let sep = model.store.label("metaSeparator")
        let plays = story.playIds.compactMap { model.library.play($0) }
        let big = typeSize.isAccessibilitySize
        let status = model.playsStatus.line
        VStack(alignment: .leading, spacing: 0) {
            Button { model.push(.plays) } label: {
                (big ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))) {
                    IconTile(symbol: RowIcon.playbook.0, tint: RowIcon.playbook.1)
                    VStack(alignment: .leading, spacing: 3) {
                        Eyebrow(text: dotted([site.playsName, site.playsTitle], separator: sep), color: Palette.secPurple, small: true)
                        Text(story.title).font(DS.style(.headline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                        Text(wide ? story.line : story.short).font(DS.style(.subheadline)).foregroundStyle(Palette.fg2)
                            .fixedSize(horizontal: false, vertical: true)
                        if wide || big {
                            Text(status).font(DS.style(.footnote).weight(.semibold)).foregroundStyle(.primary).padding(.top, 3)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    if !big {
                        Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            .padding(.top, 8).accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            // the status is always said, shown or not: "Agents are the new insiders ... 0 of 35 plays read"
            .accessibilityLabel([dotted([site.playsName, site.playsTitle], separator: ", "), story.title, wide ? story.line : story.short, status].joined(separator: ". "))
            .accessibilityHint(model.frameworks.label("storyAll").replacingOccurrences(of: "{count}", with: "\(model.library.plays.plays.count)"))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("home-door-playbook")
            Divider().overlay(Palette.line).padding(.top, 10)
            // the plays to start with: side by side where there is room for two, each at least 44 points tall
            (big ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0)) : AnyLayout(HStackLayout(alignment: .center, spacing: 10))) {
                ForEach(Array(plays.enumerated()), id: \.element.id) { i, play in
                    Button { model.push(.play(play.id)) } label: {
                        HStack(spacing: 6) {
                            Text("\(i + 1)").font(DS.style(.footnote).weight(.bold)).foregroundStyle(Palette.bg2)
                                .frame(width: 20, height: 20).background(Palette.secPurple, in: Circle())
                                .accessibilityHidden(true)
                            Text(play.name).font(DS.style(.subheadline).weight(.semibold)).foregroundStyle(Palette.link)
                                .frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(model.frameworks.label("storyStart")) \(i + 1): \(play.name)")
                    .accessibilityIdentifier("home-story-play-\(play.id)")
                }
            }
            // the rows' 44 points reach into the card's own bottom padding, so the card ends close under its words
            .padding(.bottom, -10)
        }
        .lxCard(radius: LxCard.inList(18, inset: 4), tint: Palette.secPurple, vertical: wide || big ? 16 : 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-story")
    }
}
