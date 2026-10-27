import SwiftUI

/// The Framework card (the redesign, R1; Framework.dc.html), for every framework, source and solution: the layer, the
/// name, the one-line summary, three stat tiles (Binds, Due, Type), what it answers, what it goes with, one Verified
/// row and one primary button. Provenance lives behind the Verified row and the button, in the Sources sheet.
struct EntityCardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var summaryOpen = false
    let id: String

    var body: some View {
        Group {
            if let e = model.store.entities[id] {
                card(e)
            } else {
                Palette.bg
            }
        }
        .background(Palette.bg)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func card(_ e: Entity) -> some View {
        let facts = EntityFacts(e, store: model.store)
        return ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button { dismiss() } label: { CircleIconLabel(icon: .chevronLeft) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Back")
                            .accessibilityIdentifier("card-back")
                        Spacer()
                        BookmarkButton(item: .entity(e.id))
                        if let url = URL(string: e.url) {
                            ShareLink(item: url, subject: Text(e.name)) { CircleIconLabel(icon: .share) }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Share the source link")
                        }
                    }
                    // at the accessibility sizes the mark sits above the name, so a long word never breaks
                    (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 14))) {
                        Icon(.shieldCheck, size: 30, color: Palette.secMaps, lineWidth: 1.8)
                            .frame(width: 56, height: 56)
                            .background(Palette.bg3, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.secMaps, lineWidth: 1))
                        VStack(alignment: .leading, spacing: 2) {
                            Eyebrow(text: facts.eyebrow, small: true)
                            Text(e.displayName).font(DS.cardTitle).foregroundStyle(Palette.fg)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier("card-title")
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    // the short summary (content 1.2.19), and the whole one-liner one tap down
                    VStack(alignment: .leading, spacing: 0) {
                        Text(keepWhole(summaryOpen ? e.oneLiner : e.shortSummary)).font(DS.summary).foregroundStyle(Palette.fg).lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("card-summary")
                        Button { summaryOpen.toggle() } label: {
                            Text(summaryOpen ? "Show Less" : "Read More").font(DS.link).foregroundStyle(Palette.link)
                                .frame(minHeight: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("card-summary-more")
                    }
                    StatTileRow {
                        StatTile(label: model.store.label("binds"), value: facts.binds)
                        StatTile(label: "Due", value: facts.due)
                        StatTile(label: "Type", value: facts.type)
                    }
                    if let answers = facts.answers {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(text: answers.label, tracked: false)
                            Text(answers.text).font(DS.answer).foregroundStyle(Palette.fg).lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(radius: 14)
                    }
                    let goes = model.store.goesWith(e.id)
                    if !goes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Goes with", tracked: false)
                            FlowLayout {
                                ForEach(goes, id: \.self) { other in
                                    Button { model.push(.entity(other)) } label: { Pill(text: model.store.entities[other]?.shortName ?? other) }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("goes-with-\(other)")
                                }
                            }
                        }
                    }
                    if typeSize.isAccessibilitySize { footer(e, facts).padding(.horizontal, -20) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        // the Verified row and the one primary button stay at the foot of the screen, as the mockup places them; at
        // the accessibility sizes they end the scrolling content instead, so they never cover half the screen
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !typeSize.isAccessibilitySize {
                footer(e, facts)
                    .background(Palette.bg)
                    // a short fade above the foot says the card goes on beneath it
                    .overlay(alignment: .top) {
                        LinearGradient(colors: [Palette.bg.opacity(0), Palette.bg], startPoint: .top, endPoint: .bottom)
                            .frame(height: 24).offset(y: -24).allowsHitTesting(false).accessibilityHidden(true)
                    }
            }
        }
        // a container of its own, so the identifier names the card and the controls in its pinned foot keep theirs
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("entity-card-\(e.id)")
    }

    private func footer(_ e: Entity, _ facts: EntityFacts) -> some View {
        VStack(spacing: 12) {
            Button { model.sourcesFor = e.id } label: {
                HStack(spacing: 10) {
                    Icon(facts.statusIcon, size: 20, color: facts.statusColor)
                    Text(facts.verifiedLine).font(DS.note).foregroundStyle(Palette.fg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    Icon(.info, size: 20, color: Palette.fg2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
                .card(radius: 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows where this comes from")
            .accessibilityIdentifier("verified-row")
            Button { model.sourcesFor = e.id } label: { Text(facts.readLabel) }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("card-read")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Palette.bg)
    }
}

/// What a card and its sheet say about an entry, computed from the content (unit-tested in PathTests).
struct EntityFacts {
    let entity: Entity
    let eyebrow: String
    let binds: String
    let due: String
    let type: String
    let answers: (label: String, text: String)?
    let verifiedLine: String
    let statusIcon: IconName
    let statusColor: Color
    let readLabel: String

    init(_ e: Entity, store: ContentStore) {
        entity = e
        let ui = store.content.ui
        let sep = store.label("metaSeparator")
        let nature = ui.nature[e.authority.nature.rawValue] ?? e.authority.nature.rawValue
        if let layer = e.layerId.flatMap({ store.layers[$0] }) {
            eyebrow = layer.isColumn ? layer.name : "\(store.label("layer")) \(layer.order)\(sep)\(layer.name)"
        } else {
            eyebrow = "Source\(sep)\(nature)"
        }
        binds = TitleCase.apply(e.authority.binds.map { ui.binds[$0.rawValue] ?? $0.rawValue }.joined(separator: store.label("listSeparator")))
        if let deadline = e.authority.deadline.value {
            if let due = deadline.due {
                self.due = due.fiscalYear.map { "FY\($0)" } ?? Rules.formatDate(due.date)
            } else {
                self.due = "Not Dated"
            }
        } else {
            due = TitleCase.apply(store.label("noDeadline"))
        }
        type = TitleCase.apply(nature)
        if let q = e.answersQuestion {
            answers = (store.label("answers"), q)
        } else if let role = e.role {
            answers = (store.label("role"), role)
        } else {
            answers = nil
        }
        let v = e.verification
        switch v.status {
        case .verified:
            verifiedLine = "Verified against the source" + (v.verifiedOn.map { "\(sep)\(unbroken(Rules.formatDate($0)))" } ?? "")
            statusIcon = .checkCircle
            statusColor = Palette.secMaps
        case .conflict:
            verifiedLine = "The sources disagree on a detail"
            statusIcon = .info
            statusColor = Palette.bad
        case .unverified, .authored:
            verifiedLine = "Not yet confirmed against the source"
            statusIcon = .info
            statusColor = Palette.fg2
        }
        readLabel = "Read the \(TitleCase.apply(nature))"
    }

    /// The format of the source the button opens: a PDF by its address, otherwise a web page.
    var isPDF: Bool { entity.url.lowercased().hasSuffix(".pdf") }
}

/// The Sources sheet (Sources.dc.html): where the entry comes from, its check and the next one, the citation, any
/// caveat, and the button that opens the source.
struct SourcesSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var noteOpen = false
    let id: String

    var body: some View {
        if let e = model.store.entities[id] {
            let facts = EntityFacts(e, store: model.store)
            let v = e.verification
            BottomSheet {
                HStack {
                    Text("Where This Comes From").font(DS.sheetTitle).foregroundStyle(Palette.fg).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button { model.sourcesFor = nil } label: {
                        Text("Done").font(DS.link).foregroundStyle(Palette.link).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sources-done")
                }
                HStack(alignment: .center, spacing: 10) {
                    Icon(facts.statusIcon, size: 22, color: facts.statusColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.store.content.ui.status[v.status.rawValue] ?? v.status.rawValue).font(DS.stepStrong).foregroundStyle(Palette.fg)
                        Text(checkLine(v)).font(DS.caption).foregroundStyle(Palette.fg2).lineSpacing(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Palette.bg3, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityElement(children: .combine)
                Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        fact(model.store.label("publisher"), e.publisher)
                        fact(model.store.label("edition"), e.edition)
                    }
                    GridRow {
                        fact("Published", Rules.formatDate(e.date))
                        fact("Format", facts.isPDF ? "PDF" : "Web page")
                    }
                }
                if let note = e.note {
                    // the short note (content 1.2.19), and the whole note one tap down; a note short enough has none
                    let short = e.shortNote
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(text: model.store.label("note"), tracked: false)
                        Text(noteOpen || short == nil ? note : keepWhole(short ?? note)).font(DS.note).foregroundStyle(Palette.fg).lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("sources-note")
                        if short != nil {
                            Button { noteOpen.toggle() } label: {
                                Text(noteOpen ? "Show Less" : "Read More").font(DS.link).foregroundStyle(Palette.link)
                                    .frame(minHeight: 44).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("sources-note-more")
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(radius: 12, fill: .clear)
                }
                if let url = URL(string: e.url) {
                    Button { openURL(url) } label: {
                        HStack(spacing: 8) {
                            Icon(.doc, size: 18, color: Palette.onSecMaps)
                            Text(facts.isPDF ? "Open the PDF" : "Open the Web Page")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(minHeight: 50, font: DS.sheetButton))
                    .accessibilityIdentifier("sources-open")
                    Text("Opens in your browser.").font(DS.keyLabel).foregroundStyle(Palette.fg2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func checkLine(_ v: Verification) -> String {
        guard v.status == .verified, let on = v.verifiedOn else { return v.note }
        return "Checked against the publisher's copy on \(unbroken(Rules.formatDate(on)))."
            + (v.recheckAfter.map { " Next check by \(unbroken(Rules.formatDate($0)))." } ?? "")
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(DS.keyLabel).foregroundStyle(Palette.fg2)
            Text(value).font(DS.value).foregroundStyle(Palette.fg).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
