import SwiftUI

/// Library (the redesign, R2; Library.dc.html): the Field Guide and the plays as two cards, what the reader saved, the
/// reference screens (Glossary, All sources, Why "Lensatic") and Settings. Every count is computed: the guide's week
/// from the weeks the reader marked done, the groups and plays from the plays' file, the verified count from the content.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    static let savedShown = 5

    var body: some View {
        let site = model.library.site
        let saved = model.progress.saved.filter { model.describe($0) != nil }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: AppTab.library.title)
                let cards = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
                cards {
                    Button { model.push(.guide) } label: {
                        SectionCard(icon: .map, color: Palette.secGuides, eyebrow: site.guidesName, title: site.guideTitle, line: guideLine)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("library-guide")
                    Button { model.push(.plays) } label: {
                        SectionCard(icon: .star, color: Palette.secPurple, eyebrow: site.playsName, title: site.playsTitle, line: playsLine)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("library-plays")
                }
                // the two cards share one height, as the mockup draws them
                .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    CountedLabel(text: "Saved", count: saved.count)
                    if saved.isEmpty {
                        Text("Tap the bookmark on a framework, a step or a play to keep it here.")
                            .font(DS.note).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading).card(radius: 12, fill: .clear)
                    }
                    ForEach(saved.prefix(LibraryView.savedShown), id: \.key) { item in SavedRow(item: item) }
                    if saved.count > LibraryView.savedShown {
                        NavigationLink(value: Nav.saved) { ResultRow(title: "All \(saved.count) Saved") }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("library-all-saved")
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("library-saved")
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Reference")
                    VStack(spacing: 0) {
                        ReferenceRow(title: model.store.navTitle(.glossary), detail: "\(model.store.terms.count) terms", nav: .glossary, id: "library-glossary")
                        Divider().overlay(Palette.line)
                        ReferenceRow(title: "All Sources", detail: "\(model.store.counts[.verified] ?? 0) verified", nav: .sources, id: "library-sources")
                        Divider().overlay(Palette.line)
                        ReferenceRow(title: "Why \u{201C}\(model.store.content.meta.name)\u{201D}", detail: model.store.navTitle(.about), nav: .about, id: "library-about")
                    }
                    .card(radius: 12)
                }
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Settings")
                    if let door = model.door {
                        Button { model.changingDoor = true } label: {
                            ListRow(title: "Change Path", subtitle: door.shortTitle, icon: door.id.icon, iconColor: door.id.color)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("library-change-door")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Palette.bg)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("library")
    }

    /// Week N of 8: the first week on the reader's route not marked done; every week done says so.
    private var guideLine: String {
        guard let door = model.door else { return "" }
        let weeks = model.library.weeks(for: door.id)
        let done = weeks.filter { model.progress.weeksDone(model.library.weekKey($0, door: door.id)).contains($0.week) }
        if let next = weeks.first(where: { w in !done.contains(w) }) { return "Week \(next.week) of \(weeks.count)" }
        return "All \(weeks.count) weeks done"
    }

    private var playsLine: String {
        let p = model.library.plays
        return "\(p.groups.count) sections\(model.store.label("metaSeparator"))\(p.plays.count) plays"
    }
}

/// One of the Library's two section cards: the section's colour along the top, its icon, name, title and a count.
struct SectionCard: View {
    let icon: IconName
    let color: Color
    let eyebrow: String
    let title: String
    let line: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Icon(icon, size: 28, color: color, lineWidth: 1.8)
            Eyebrow(text: eyebrow, color: color, small: true)
            Text(title).font(DS.libraryTitle).foregroundStyle(Palette.fg).fixedSize(horizontal: false, vertical: true)
            Text(line).font(DS.caption).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: .infinity, alignment: .topLeading)
        .multilineTextAlignment(.leading)
        .background(Palette.bg2)
        // the section's colour along the top follows the card's rounded corners
        .overlay(alignment: .top) { Rectangle().fill(color).frame(height: 3).accessibilityHidden(true) }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

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

struct ReferenceRow: View {
    let title: String
    let detail: String
    let nav: Nav
    let id: String

    var body: some View {
        NavigationLink(value: nav) {
            HStack(spacing: 12) {
                Text(title).font(DS.summary).foregroundStyle(Palette.fg)
                Spacer(minLength: 12)
                Text(detail).font(DS.step).foregroundStyle(Palette.fg2).multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
/// done on the device; then the guide's chapters and its quick reference for the reader's track.
struct GuideView: View {
    @Environment(AppModel.self) private var model
    @State private var openWeek: Int?

    var body: some View {
        let lib = model.library
        let site = lib.site
        DetailScreen(eyebrow: site.guidesName, eyebrowColor: Palette.secGuides, title: site.guideTitle, identifier: "guide-screen") {
            if let door = model.door {
                let weeks = lib.weeks(for: door.id)
                let done = weeks.filter { model.progress.weeksDone(lib.weekKey($0, door: door.id)).contains($0.week) }.map(\.week)
                Text(site.guides.first?.line ?? "").font(DS.answer).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    CountedLabel(text: "Your weeks", count: weeks.count)
                    if let track = lib.track(for: door.id), let c0 = lib.guide.core.first?.week, let c1 = lib.guide.core.last?.week,
                       let t0 = track.weeks.first?.week, let t1 = track.weeks.last?.week {
                        // the ranges are read from the guide's plans, never typed
                        Text("Weeks \(c0) to \(c1) are the shared core; \(t0) to \(t1) are the \(track.name).").font(DS.caption).foregroundStyle(Palette.fg2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    let current = weeks.first { !done.contains($0.week) }?.week
                    ForEach(weeks, id: \.week) { w in
                        WeekRow(week: w, done: done.contains(w.week), current: w.week == current, open: openWeek == w.week,
                                toggle: { model.progress.toggleWeek(lib.weekKey(w, door: door.id), w.week) },
                                expand: { openWeek = openWeek == w.week ? nil : w.week })
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Chapters")
                ForEach(lib.guide.chapters) { c in
                    NavigationLink(value: Nav.chapter(c.id)) { ResultRow(title: c.title, bar: Palette.secGuides) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("chapter-\(c.id)")
                }
            }
            Text(lib.guide.edition).font(DS.caption).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct WeekRow: View {
    let week: Guide.Week
    let done: Bool
    /// The first week not marked done: called out, as My Path calls out the next step.
    var current = false
    let open: Bool
    let toggle: () -> Void
    let expand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button(action: toggle) {
                    Group { if done { DoneMark() } else { Icon(.circle, size: 24, color: current ? Palette.secGuides : Palette.lineStrong) } }
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
                            if current { Eyebrow(text: "This week", color: Palette.secGuides, small: true) }
                            Text("Week \(week.week)").font(DS.stepStrong).foregroundStyle(done ? Palette.fg2 : Palette.fg)
                            Text(keepWhole(week.read)).font(DS.caption).foregroundStyle(Palette.fg2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        Icon(.chevronRight, size: 16, color: Palette.fg2).rotationEffect(.degrees(open ? 90 : 0))
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(open ? "Open" : "Closed")
                .accessibilityIdentifier("week-\(week.week)")
            }
            if open {
                VStack(alignment: .leading, spacing: 8) {
                    labeled("Apply on the job", week.apply)
                    labeled("Self-check", week.check)
                }
                .padding(.leading, 36)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, current ? 12 : 6)
        .card(radius: 12, fill: current ? Palette.bg3 : Palette.bg2, stroke: current ? Palette.secGuides : Palette.line)
    }

    private func labeled(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel(text: label, tracked: false)
            Text(keepWhole(text)).font(DS.step).foregroundStyle(Palette.fg).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ChapterView: View {
    @Environment(AppModel.self) private var model
    let id: String

    var body: some View {
        if let c = model.library.guide.chapter(id) {
            DetailScreen(eyebrow: model.library.site.guideName, eyebrowColor: Palette.secGuides, title: c.title, identifier: "chapter-screen") {
                BlocksView(blocks: c.blocks, accent: Palette.secGuides)
            }
        } else {
            Palette.bg
        }
    }
}

// MARK: the plays

/// The plays (native): the groups in their order, each play a row under its group.
struct PlaysView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let lib = model.library
        DetailScreen(eyebrow: lib.site.playsName, eyebrowColor: Palette.secPurple, title: lib.site.playsTitle, identifier: "plays-screen") {
            Text(lib.site.section("playbook")?.line ?? "").font(DS.answer).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
            ForEach(lib.plays.groups, id: \.label) { g in
                VStack(alignment: .leading, spacing: 8) {
                    CountedLabel(text: g.label, count: g.playIds.count)
                    ForEach(lib.plays(in: g)) { p in
                        NavigationLink(value: Nav.play(p.id)) { ResultRow(title: p.name, line: p.subtitle, bar: Palette.secPurple) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("play-\(p.id)")
                    }
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
                if !p.subtitle.isEmpty {
                    Text(p.subtitle).font(DS.answer).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                }
                BlocksView(blocks: p.blocks, accent: Palette.secPurple)
            }
        } else {
            Palette.bg
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
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in BlockView(block: b, accent: accent) }
        }
    }
}

struct BlockView: View {
    let block: LibraryBlock
    let accent: Color

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
                Text(keepWhole(block.text ?? "")).font(DS.readerBody).foregroundStyle(Palette.fg).lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .callout:
            VStack(alignment: .leading, spacing: 4) {
                if let l = block.label, !l.isEmpty { Eyebrow(text: l, color: accent, small: true) }
                Text(keepWhole(block.text ?? "")).font(DS.answer).foregroundStyle(Palette.fg).lineSpacing(3)
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
                        Text(keepWhole(line)).font(DS.step).foregroundStyle(Palette.fg).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .cards:
            VStack(alignment: .leading, spacing: 8) {
                if let h = block.heading { SectionLabel(text: h) }
                if let t = block.text { Text(keepWhole(t)).font(DS.step).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true) }
                ForEach(Array(block.cards.enumerated()), id: \.offset) { _, c in CardBlock(card: c, accent: accent) }
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
        }
    }
}

struct CardBlock: View {
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
                ForEach(Array((open ? bullets : Array(bullets.prefix(2))).enumerated()), id: \.offset) { _, b in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\u{2022}").font(DS.step).foregroundStyle(accent).accessibilityHidden(true)
                            Text(keepWhole(b)).font(DS.step).foregroundStyle(Palette.fg).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        }
                }
                if bullets.count > 2 {
                    Button { open.toggle() } label: {
                        Text(open ? "Show Less" : "Show All \(bullets.count)").font(DS.link).foregroundStyle(Palette.link)
                            .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if let m = card.meta, !m.isEmpty {
                Text(keepWhole(m)).font(DS.caption).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
            }
            if let url = card.url.flatMap(URL.init(string:)) { OutsideLink(url: url) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 12)
    }
}

/// An outside address: named by its site, opened in the system browser.
struct OutsideLink: View {
    let url: URL
    var label: String?

    var body: some View {
        let host = url.host().map { $0.hasPrefix("www.") ? String($0.dropFirst(4)) : $0 } ?? url.absoluteString
        Link(destination: url) {
            Text(label ?? "Open \(host)").font(DS.link).foregroundStyle(Palette.link)
                .multilineTextAlignment(.leading)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .accessibilityHint("Opens \(host) in your browser")
    }
}
