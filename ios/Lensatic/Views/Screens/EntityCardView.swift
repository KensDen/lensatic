import SwiftUI

/// The Framework card (the redesign, R1; Framework.dc.html), for every framework, source and solution: the layer, the
/// name, the one-line summary, three stat tiles (Binds, Due, Type), what it answers, what it goes with, one Verified
/// row and one primary button. Provenance lives behind the Verified row and the button, in the Sources sheet.
struct EntityCardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The Type tile's one-line meaning, shown under the tiles (build 6).
    @State private var showType = false
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
        #if DEBUG
        // -LensaticType opens the Type tile's meaning at launch, for the screenshots
        .onAppear { if CommandLine.arguments.contains("-LensaticType") { showType = true } }
        #endif
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
                        ShareButton(subject: .entity(e.id))
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
                    // the one-liner; the short summary (content 1.2.19) stands for it only where the Read More rule holds,
                    // which no entry meets today (each one-liner adds 4 to 16 words), so the card shows the one-liner whole
                    ExpandableText(short: e.shortSummary, full: e.oneLiner, identifier: "card-summary")
                    StatTileRow {
                        StatTile(label: model.store.label("binds"), value: facts.binds)
                        StatTile(label: "Due", value: facts.due)
                        // the Type tile opens what its word means, in one line from the content (build 6)
                        if facts.typeMeaning != nil {
                            Button { showType.toggle() } label: { StatTile(label: "Type", value: facts.type, opens: true) }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Type, \(facts.type)")
                                .accessibilityValue(showType ? "Expanded" : "Collapsed")
                                .accessibilityHint("Says what this type of document is")
                                .accessibilityIdentifier("type-tile")
                        } else {
                            StatTile(label: "Type", value: facts.type)
                        }
                    }
                    if showType, let meaning = facts.typeMeaning {
                        Text(meaning).font(DS.style(.subheadline)).foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, -4)
                            .lxCard(radius: 12)
                            .padding(.top, -8)
                            .accessibilityIdentifier("type-meaning")
                    }
                    // the card's lists (build 6: the section 7 rule): what it answers, and what it goes with, each in the one
                    // card style under a header in the system's type
                    if let answers = facts.answers {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(answers.label).font(DS.style(.footnote)).foregroundStyle(Palette.fg2).accessibilityAddTraits(.isHeader)
                            Text(answers.text).font(DS.style(.callout)).foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .lxCard(radius: 14)
                    }
                    let goes = model.store.goesWith(e.id)
                    if !goes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Goes With").font(DS.style(.footnote)).foregroundStyle(Palette.fg2).padding(.leading, 16)
                                .accessibilityAddTraits(.isHeader)
                            // chips, so every entry it goes with is in view above the card's foot (as rows, two showed
                            // where four chips had: the fresh-eyes review of build 6, finding 14), inside the one card
                            FlowLayout {
                                ForEach(goes, id: \.self) { other in
                                    Button { model.push(.entity(other)) } label: { Pill(text: model.store.entities[other]?.shortName ?? other) }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("goes-with-\(other)")
                                }
                            }
                            .padding(.vertical, -8)
                            .lxCard(radius: 14)
                        }
                    }
                    if typeSize.isAccessibilitySize { footer(e, facts).padding(.horizontal, -20) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .hardTopEdge()
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
    /// What the type means, in one line from ui.natureMeaning (build 6).
    let typeMeaning: String?
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
        typeMeaning = ui.natureMeaning[e.authority.nature.rawValue]
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
    var isPDF: Bool { entity.opensPDF }
}

/// The Sources sheet (Sources.dc.html): where the entry comes from, its check and the next one, the citation, any
/// caveat, and the button that opens the source.
struct SourcesSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var documentsOpen = false
    let id: String

    var body: some View {
        if let e = model.store.entities[id] {
            let facts = EntityFacts(e, store: model.store)
            let v = e.verification
            BottomSheet {
                HStack {
                    Text("Where This Comes From").font(DS.style(.title3)).foregroundStyle(.primary).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button { model.sourcesFor = nil } label: {
                        Text("Done").font(DS.style(.body)).foregroundStyle(Palette.link).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sources-done")
                }
                // the sheet's groups (build 6: the section 7 rule): each a card in the one card style on the page colour, as an
                // inset-grouped list draws its sections, in the system's Dynamic Type styles
                HStack(alignment: .center, spacing: 10) {
                    Icon(facts.statusIcon, size: 22, color: facts.statusColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.store.content.ui.status[v.status.rawValue] ?? v.status.rawValue).font(DS.style(.headline)).foregroundStyle(.primary)
                        Text(checkLine(v)).font(DS.style(.footnote)).foregroundStyle(Palette.fg2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .lxCard(radius: 12)
                .accessibilityElement(children: .combine)
                VStack(spacing: 0) {
                    fact(model.store.label("publisher"), e.publisher)
                    Divider().overlay(Palette.line)
                    fact(model.store.label("edition"), e.edition)
                    Divider().overlay(Palette.line)
                    fact("Published", Rules.formatDate(e.date))
                    Divider().overlay(Palette.line)
                    fact("Format", facts.isPDF ? "PDF" : "Web page")
                }
                .padding(.vertical, -16)
                .lxCard(radius: 12)
                if let note = e.note {
                    // the short note (content 1.2.19), and the whole note one tap down where the Read More rule holds;
                    // its control reads Full note, so it never reads like the card's own (6.15)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.store.label("note")).font(DS.style(.footnote)).foregroundStyle(Palette.fg2).accessibilityAddTraits(.isHeader)
                        ExpandableText(short: e.shortNote, full: note, font: DS.style(.subheadline), lineSpacing: 2, moreLabel: "Full Note", identifier: "sources-note")
                    }
                    .lxCard(radius: 12)
                }
                if let url = URL(string: e.url) {
                    Button { Reader.open(url) } label: {
                        HStack(spacing: 8) {
                            Icon(.doc, size: 18, color: Palette.onSecMaps)
                            Text(facts.isPDF ? "Open the PDF" : "Open the Web Page")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(minHeight: 50, font: DS.sheetButton))
                    .accessibilityIdentifier("sources-open")
                    // web pages first (content release 1.0.1): the publication's PDF, where it has a page too, one link down
                    if let pdf = e.pdf.flatMap(URL.init(string:)) {
                        Button { Reader.open(pdf) } label: {
                            HStack(spacing: 8) {
                                Text("Open the PDF").font(DS.style(.subheadline)).foregroundStyle(Palette.link)
                                PDFTag()
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the PDF in Safari, inside the app")
                        .accessibilityIdentifier("sources-open-pdf")
                    }
                    Text(model.store.label("opensInReader")).font(DS.style(.caption)).foregroundStyle(Palette.fg2)
                        .frame(maxWidth: .infinity)
                }
                if let docs = e.documents, !docs.isEmpty { documents(docs) }
            }
        }
    }

    /// The entry's documents (R3), one tap down: each with its edition and date, opening in the reader. Nothing showed
    /// them since R1 replaced the entry screen with the card.
    private func documents(_ docs: [Document]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { documentsOpen.toggle() } label: {
                HStack {
                    Text("Documents").font(DS.style(.body)).foregroundStyle(.primary)
                    Spacer()
                    Text("\(docs.count)").font(DS.style(.body)).foregroundStyle(Palette.fg2)
                    Icon(.chevronRight, size: 14, color: Palette.fg2).rotationEffect(.degrees(documentsOpen ? 90 : 0))
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Documents, \(docs.count)")
            .accessibilityValue(documentsOpen ? "Expanded" : "Collapsed")
            .accessibilityIdentifier("sources-documents")
            if documentsOpen {
                ForEach(Array(docs.enumerated()), id: \.offset) { i, d in
                    Divider().overlay(Palette.line)
                    Button { if let url = URL(string: d.url) { Reader.open(url) } } label: {
                        HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(keepWhole(d.title)).font(DS.style(.subheadline)).foregroundStyle(Palette.link)
                                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                                if d.opensPDF { PDFTag() }
                            }
                            Text("\(d.edition)\(model.store.label("metaSeparator"))\(unbroken(Rules.formatDate(d.date)))").font(DS.style(.footnote))
                                .foregroundStyle(Palette.fg2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.up.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Opens in Safari, inside the app")
                    .accessibilityIdentifier("sources-document-\(i)")
                    // the document's PDF where its link is a web page (content release 1.0.1), labelled PDF
                    if let pdf = d.pdf.flatMap(URL.init(string:)) {
                        Button { Reader.open(pdf) } label: {
                            HStack(spacing: 8) {
                                Text("Open the PDF").font(DS.style(.footnote)).foregroundStyle(Palette.link)
                                PDFTag()
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, -8)
                        .accessibilityHint("Opens the PDF in Safari, inside the app")
                        .accessibilityIdentifier("sources-document-\(i)-pdf")
                    }
                }
            }
        }
        .padding(.vertical, -16)
        .lxCard(radius: 12)
    }

    private func checkLine(_ v: Verification) -> String {
        guard v.status == .verified, let on = v.verifiedOn else { return v.note }
        return "Checked against the publisher’s copy on \(unbroken(Rules.formatDate(on)))."
            + (v.recheckAfter.map { " Next check by \(unbroken(Rules.formatDate($0)))." } ?? "")
    }

    /// A fact as a list row: the label, and its value at the trailing edge; at the accessibility sizes the value goes
    /// under the label, so neither is cut.
    private func fact(_ label: String, _ value: String) -> some View {
        (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))) {
            Text(label).font(DS.style(.body)).foregroundStyle(.primary)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Text(value).font(DS.style(.body)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
