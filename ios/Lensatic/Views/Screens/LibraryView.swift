import SwiftUI

// The screens Home's doors and rows open (build 6: the Library tab's own screen became Home, HomeView.swift): the saved
// list, the Field Guide and its chapters, the plays and one play, and the blocks they are drawn from.

struct SavedRow: View {
    @Environment(AppModel.self) private var model
    let item: SavedItem

    var body: some View {
        if let d = model.describe(item) {
            Button { model.open(item) } label: { ResultRow(title: d.title, line: d.line, bar: sectionColor(d.section)) }
                .buttonStyle(.plain)
                .accessibilityIdentifier("saved-\(item.key)")
        }
    }
}

/// A saved item as a native row in Home's Saved section (6.19): its title, and its kind and place as secondary text.
struct SavedListRow: View {
    @Environment(AppModel.self) private var model
    let item: SavedItem

    var body: some View {
        if let d = model.describe(item) {
            Button { model.open(item) } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(keepWhole(d.title)).font(DS.style(.body)).foregroundStyle(.primary)
                        Text(d.line).font(DS.style(.footnote)).foregroundStyle(Palette.fg2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("saved-\(item.key)")
        }
    }
}

/// A Reference row, as Settings draws one (section 7.3): an icon tile, the title, the value as trailing secondary text and
/// the chevron of the system's navigation link.
struct ReferenceRow: View {
    let icon: (String, Color)
    let title: String
    let detail: String
    let nav: Nav
    let id: String

    var body: some View {
        NavigationLink(value: nav) {
            TileRow(icon: icon, title: title, value: detail)
        }
        .accessibilityIdentifier(id)
    }
}

/// Every saved item, newest first.
struct SavedListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let saved = model.progress.saved.filter { model.describe($0) != nil }
        DetailScreen(title: "Saved", identifier: "saved-screen") {
            ForEach(saved, id: \.key) { SavedRow(item: $0) }
        }
    }
}

// MARK: the guide

/// The Field Guide (native): the reader's eight weeks, each with what to read, what to apply and the self-check, marked
/// done on the device; then the guide's chapters. A system inset-grouped list (build 6: the section 7 rule). Before a
/// trailhead is picked there are no weeks to show, since the last four are a track's: the screen says so and leads to
/// the trailhead question.
struct GuideView: View {
    @Environment(AppModel.self) private var model
    @State private var openWeek: Int?

    var body: some View {
        let lib = model.library
        let site = lib.site
        ListScreen(eyebrow: site.guidesName, eyebrowColor: Palette.secGuides, title: site.guideTitle, identifier: "guide-screen") {
            SwiftUI.Section {
                // who the route is for (4.2 and 4.5): the Field Guides intro, on the screen Home's door opens
                Text(site.intro("guides", actions: lib.actionCount) ?? site.guides.first?.line ?? "").font(DS.style(.subheadline))
                    .foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 2)
                    .accessibilityIdentifier("guide-intro")
            }
            if let door = model.door {
                let weeks = lib.weeks(for: door.id)
                let done = weeks.filter { model.progress.weeksDone(lib.weekKey($0, door: door.id)).contains($0.week) }.map(\.week)
                let current = weeks.first { !done.contains($0.week) }?.week
                SwiftUI.Section {
                    ForEach(weeks, id: \.week) { w in
                        WeekRow(week: w, done: done.contains(w.week), current: w.week == current, open: openWeek == w.week,
                                toggle: { model.progress.toggleWeek(lib.weekKey(w, door: door.id), w.week) },
                                expand: { openWeek = openWeek == w.week ? nil : w.week })
                    }
                } header: {
                    HStack(alignment: .firstTextBaseline) {
                        ListNote("Your Weeks")
                        Spacer()
                        ListNote("\(weeks.count)")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                } footer: {
                    if let track = lib.track(for: door.id), let c0 = lib.guide.core.first?.week, let c1 = lib.guide.core.last?.week,
                       let t0 = track.weeks.first?.week, let t1 = track.weeks.last?.week {
                        // the ranges are read from the guide's plans, never typed
                        ListNote("Weeks \(c0) to \(c1) are the shared core; \(t0) to \(t1) are the \(track.name).").font(DS.style(.footnote))
                    }
                }
            } else {
                SwiftUI.Section {
                    Button { model.changingDoor = true } label: {
                        Text(model.store.label("homeChoose")).font(DS.style(.body)).foregroundStyle(Palette.link)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("guide-choose")
                } header: {
                    ListNote("Your Weeks")
                } footer: {
                    ListNote(model.store.label("guideNoTrailhead")).font(DS.style(.footnote))
                }
            }
            SwiftUI.Section {
                ForEach(lib.guide.chapters) { c in
                    NavigationLink(value: Nav.chapter(c.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(noOrphan(keepWhole(c.displayTitle))).font(DS.style(.body)).foregroundStyle(.primary)
                            if let part = c.part, !part.isEmpty { Text(part).font(DS.style(.footnote)).foregroundStyle(Palette.fg2) }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 2)
                    }
                    .accessibilityIdentifier("chapter-\(c.id)")
                }
            } header: {
                ListNote("Chapters")
            } footer: {
                ListNote(lib.guide.edition).font(DS.style(.footnote))
            }
        }
    }
}

/// One of the reader's weeks as a list row: its check (its own 44-point control), the week and what to read, and, opened,
/// what to apply and the self-check. The first week not marked done says This Week, as My Path calls out the next step.
struct WeekRow: View {
    let week: Guide.Week
    let done: Bool
    /// The first week not marked done.
    var current = false
    let open: Bool
    let toggle: () -> Void
    let expand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button(action: toggle) {
                    Group { if done { DoneMark() } else { Icon(.circle, size: 24, color: current ? Palette.secGuides : Palette.fg2) } }
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(-10)
                .accessibilityLabel("Week \(week.week)")
                .accessibilityValue(done ? "Done" : "Not done")
                .accessibilityAddTraits(.isToggle)
                .accessibilityIdentifier("week-check-\(week.week)")
                Button(action: expand) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if current { Text("This Week").font(DS.style(.footnote).weight(.semibold)).foregroundStyle(Palette.secGuides) }
                            Text("Week \(week.week)").font(DS.style(.body)).foregroundStyle(done ? Palette.fg2 : Color.primary)
                            Text(keepWhole(week.read)).font(DS.style(.footnote)).foregroundStyle(Palette.fg2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        Icon(.chevronRight, size: 14, color: Palette.fg2).rotationEffect(.degrees(open ? 90 : 0)).accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(open ? "Expanded" : "Collapsed")
                .accessibilityIdentifier("week-\(week.week)")
            }
            if open {
                VStack(alignment: .leading, spacing: 8) {
                    labeled("Apply on the Job", week.apply)
                    labeled("Self-Check", week.check)
                }
                .padding(.leading, 36)
                .padding(.bottom, 4)
            }
        }
        .padding(.vertical, 2)
    }

    private func labeled(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(DS.style(.footnote)).foregroundStyle(Palette.fg2).accessibilityAddTraits(.isHeader)
            Text(keepWhole(text)).font(DS.style(.subheadline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ChapterView: View {
    @Environment(AppModel.self) private var model
    let id: String

    var body: some View {
        if let c = model.library.guide.chapter(id) {
            let sep = model.store.label("metaSeparator")
            DetailScreen(eyebrow: [model.library.site.guideName, c.part].compactMap { $0 }.joined(separator: sep), eyebrowColor: Palette.secGuides,
                         title: c.displayTitle, identifier: "chapter-screen") {
                SummaryFirst(summary: c.summary, outline: c.outline, accent: Palette.secGuides)
                BlocksView(blocks: c.blocks, accent: Palette.secGuides)
            }
        } else {
            Palette.bg
        }
    }
}

// MARK: the plays

/// The plays (native): the groups in their order, each play a row under its group. A system inset-grouped list (build 6:
/// the section 7 rule), one section per group.
struct PlaysView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let lib = model.library
        ListScreen(eyebrow: lib.site.playsName, eyebrowColor: Palette.secPurple, title: lib.site.playsTitle, identifier: "plays-screen") {
            SwiftUI.Section {
                // who the playbook is for (4.3 and 4.5), on the screen Home's door opens
                Text(lib.site.intro("playbook", actions: lib.actionCount) ?? lib.site.section("playbook")?.line ?? "").font(DS.style(.subheadline))
                    .foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 2)
                    .accessibilityIdentifier("plays-intro")
            }
            ForEach(lib.plays.groups, id: \.label) { g in
                SwiftUI.Section {
                    ForEach(lib.plays(in: g)) { p in
                        NavigationLink(value: Nav.play(p.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(noOrphan(keepWhole(p.name))).font(DS.style(.body)).foregroundStyle(.primary)
                                Text(noOrphan(keepWhole(p.subtitle))).font(DS.style(.footnote)).foregroundStyle(Palette.fg2)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 2)
                        }
                        .accessibilityIdentifier("play-\(p.id)")
                    }
                } header: {
                    HStack(alignment: .firstTextBaseline) {
                        ListNote(g.label)
                        Spacer()
                        ListNote("\(g.playIds.count)")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                }
            }
        }
    }
}

struct PlayView: View {
    @Environment(AppModel.self) private var model
    let id: String

    var body: some View {
        if let p = model.library.play(id) {
            DetailScreen(eyebrow: model.library.group(of: id)?.label, eyebrowColor: Palette.secPurple, title: p.name, identifier: "play-screen") {
                BookmarkButton(item: .play(id))
            } content: {
                SummaryFirst(summary: p.summary, outline: p.outline, accent: Palette.secPurple)
                BlocksView(blocks: p.blocks, accent: Palette.secPurple)
            }
            // a play opened counts as read on Home's playbook door (content release 1.0.1)
            .onAppear { model.progress.markRead(play: id) }
        } else {
            Palette.bg
        }
    }
}

// MARK: summary first

/// The top of a chapter or a play (R3): its summary in one to three lines, then its outline, which jumps to a section.
/// The outline is closed at first, so the summary leads.
struct SummaryFirst: View {
    @Environment(\.scrollProxy) private var proxy
    let summary: String?
    let outline: [Outline]
    let accent: Color
    @State private var open = false

    var body: some View {
        if let summary {
            Text(keepWhole(summary)).font(DS.summary).foregroundStyle(Palette.fg).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("summary")
        }
        if outline.count > 1 {
            VStack(alignment: .leading, spacing: 0) {
                Button { open.toggle() } label: {
                    HStack {
                        Text("Outline").font(DS.stepStrong).foregroundStyle(Palette.fg)
                        Text("\(outline.count) sections").font(DS.caption).foregroundStyle(Palette.fg2)
                        Spacer()
                        Icon(.chevronRight, size: 16, color: Palette.fg2).rotationEffect(.degrees(open ? 90 : 0))
                    }
                    .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Outline, \(outline.count) sections")
                .accessibilityValue(open ? "Expanded" : "Collapsed")
                .accessibilityIdentifier("outline")
                if open {
                    ForEach(Array(outline.enumerated()), id: \.offset) { i, entry in
                        Divider().overlay(Palette.line)
                        Button {
                            withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut) { proxy?.scrollTo(entry.anchor, anchor: .top) }
                        } label: {
                            Text(keepWhole(entry.title)).font(DS.step).foregroundStyle(Palette.link)
                                .frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 10).frame(minHeight: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityHint("Goes to the section")
                        .accessibilityIdentifier("outline-\(i)")
                    }
                }
            }
            .padding(.horizontal, 12)
            .card(radius: 12)
        }
    }
}

// MARK: blocks

/// A guide chapter's or a play's blocks, drawn natively: headings, paragraphs, callouts, lists, cards, tables as
/// stacked rows, figures and links. Outside links open in the system browser.
struct BlocksView: View {
    let blocks: [LibraryBlock]
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // each block carries its place, so the outline can scroll to it
            ForEach(Array(blocks.enumerated()), id: \.offset) { i, b in BlockView(block: b, accent: accent, index: i).id("block-\(i)") }
        }
    }
}

struct BlockView: View {
    let block: LibraryBlock
    let accent: Color
    /// The block's place in its chapter or play, so its cards carry anchors for the outline.
    var index = 0

    var body: some View {
        switch block.kind {
        case .heading:
            Text(block.text ?? "").font(block.level == 4 ? DS.nextTitle : DS.readerHeading).foregroundStyle(Palette.fg)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader).padding(.top, 4)
        case .text:
            VStack(alignment: .leading, spacing: 4) {
                if let h = block.heading {
                    Text(h).font(DS.readerHeading).foregroundStyle(Palette.fg).fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                BlockView.led(block.lead, block.text ?? "", font: DS.readerBody, leadFont: DS.readerLead)
                    .foregroundStyle(Palette.fg).lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .callout:
            VStack(alignment: .leading, spacing: 4) {
                if let l = block.label, !l.isEmpty { Eyebrow(text: l, color: accent, small: true) }
                BlockView.led(block.lead, block.text ?? "", font: DS.answer, leadFont: DS.readerLead).foregroundStyle(Palette.fg).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.bg3, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .leading) { Rectangle().fill(accent).frame(width: 3).accessibilityHidden(true) }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .list:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(block.lines.enumerated()), id: \.offset) { i, line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(block.ordered ? "\(i + 1)." : "\u{2022}").font(DS.step).foregroundStyle(accent).accessibilityHidden(true)
                        BlockView.led(i < block.leads.count ? block.leads[i] : nil, line, font: DS.step, leadFont: DS.stepStrong)
                            .foregroundStyle(Palette.fg).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .cards:
            VStack(alignment: .leading, spacing: 8) {
                if let h = block.heading { SectionLabel(text: h) }
                if let t = block.text { Text(keepWhole(t)).font(DS.step).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true) }
                ForEach(Array(block.cards.enumerated()), id: \.offset) { j, c in CardBlock(card: c, accent: accent).id("block-\(index)-card-\(j)") }
            }
        case .table:
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(block.rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(row.cells.enumerated()), id: \.offset) { i, cell in
                            if !cell.isEmpty {
                                if i == 0 {
                                    Text(keepWhole(cell)).font(DS.stepStrong).foregroundStyle(Palette.fg).fixedSize(horizontal: false, vertical: true)
                                } else {
                                    VStack(alignment: .leading, spacing: 1) {
                                        if i < block.columns.count, !block.columns[i].isEmpty {
                                            Text(block.columns[i]).font(DS.keyLabel).foregroundStyle(Palette.fg2)
                                        }
                                        Text(keepWhole(cell)).font(DS.step).foregroundStyle(Palette.fg).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        if let url = row.url.flatMap(URL.init(string:)) { OutsideLink(url: url) }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(radius: 12)
                    .accessibilityElement(children: .combine)
                }
            }
        case .stats:
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(block.stats.enumerated()), id: \.offset) { _, s in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(s.value).font(DS.countdown).foregroundStyle(accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.label).font(DS.step).foregroundStyle(Palette.fg)
                            Text(s.source).font(DS.caption).foregroundStyle(Palette.fg2)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(radius: 12)
                    .accessibilityElement(children: .combine)
                }
            }
        case .links:
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(block.links.enumerated()), id: \.offset) { _, l in
                    if let url = URL(string: l.url) { OutsideLink(url: url, label: l.label) }
                }
            }
        case .figure:
            if let f = block.figure { FigureView(figure: f) }
        }
    }
}

extension BlockView {
    /// Text with its run-in label set bold before it ("What it is. A ..."); the text alone when it has none.
    static func led(_ lead: String?, _ text: String, font: Font, leadFont: Font) -> Text {
        guard let lead, !lead.isEmpty else { return Text(keepWhole(text)).font(font) }
        if text.isEmpty { return Text(keepWhole(lead)).font(leadFont) }
        return Text(keepWhole(lead)).font(leadFont) + Text(" " + keepWhole(text)).font(font)
    }
}

struct CardBlock: View {
    @Environment(AppModel.self) private var model
    let card: LibraryBlock.Card
    let accent: Color
    @State private var open = false

    var body: some View {
        let bullets = card.bullets ?? []
        VStack(alignment: .leading, spacing: 6) {
            if let e = card.eyebrow, !e.isEmpty { Eyebrow(text: e, color: accent, small: true) }
            Text(keepWhole(card.title)).font(DS.stepStrong).foregroundStyle(Palette.fg).fixedSize(horizontal: false, vertical: true)
            if let t = card.text, !t.isEmpty {
                Text(keepWhole(t)).font(DS.step).foregroundStyle(Palette.fg2).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
            if !bullets.isEmpty {
                // a long list shows its first two points, the rest one tap down, so a card reads as a summary first
                ForEach(Array((open ? bullets : Array(bullets.prefix(2))).enumerated()), id: \.offset) { i, b in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\u{2022}").font(DS.step).foregroundStyle(accent).accessibilityHidden(true)
                            BlockView.led(card.leads.flatMap { i < $0.count ? $0[i] : nil }, b, font: DS.step, leadFont: DS.stepStrong)
                                .foregroundStyle(Palette.fg).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        }
                }
                if bullets.count > 2 {
                    Button { open.toggle() } label: {
                        Text(open ? "Show Less" : "Show All \(bullets.count) Points").font(DS.link).foregroundStyle(Palette.link)
                            .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if let m = card.meta, !m.isEmpty {
                Text(keepWhole(m)).font(DS.caption).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
            }
            if let url = card.url.flatMap(URL.init(string:)) { OutsideLink(url: url) }
            if let id = card.play, let play = model.library.play(id) {
                Button { model.push(.play(id)) } label: {
                    Text("Open \(play.name)").font(DS.link).foregroundStyle(Palette.link).multilineTextAlignment(.leading)
                        .frame(minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 12)
    }
}

/// An outside address: named by its site, opened in the in-app reader (R3).
struct OutsideLink: View {
    let url: URL
    var label: String?

    var body: some View {
        let host = url.host().map { $0.hasPrefix("www.") ? String($0.dropFirst(4)) : $0 } ?? url.absoluteString
        Button { Reader.open(url) } label: {
            Text(label ?? "Open \(host)").font(DS.link).foregroundStyle(Palette.link)
                .multilineTextAlignment(.leading)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens \(host) in Safari, inside the app")
    }
}

#if DEBUG
extension View {
    /// Scrolls the list inside to the view -LensaticScrollTo names, as DetailScreen does (the empty-state captures:
    /// Home's Saved section, which sits below the fold at the largest text sizes).
    func debugScrollTo() -> some View {
        ScrollViewReader { proxy in
            self.task {
                if let target = AppModel.debugScrollTo {
                    try? await Task.sleep(for: .milliseconds(600))
                    // centred, so the section's header stays clear of the status bar
                    proxy.scrollTo(target, anchor: .center)
                }
            }
        }
    }
}
#endif
