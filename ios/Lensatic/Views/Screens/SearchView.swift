import SwiftUI

/// Search (the redesign, R2; the top of Widget.dc.html): one field across the entries, the steps on the reader's path,
/// the guide's chapters, the plays and the glossary, with the results grouped by kind. A result opens what it names.
struct SearchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
        let groups = model.search.search(model.query)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: AppTab.search.title)
                HStack(spacing: 10) {
                    Icon(.search, size: 18, color: Palette.fg2)
                    // a field that grows with the text size (a one-line field keeps its height and clips at the larger
                    // sizes); Return searches rather than starting a new line
                    TextField("Search Lensatic", text: $model.query, prompt: Text("Search Lensatic").foregroundStyle(Palette.fg2), axis: .vertical)
                        .lineLimit(1...3)
                        // VoiceOver names the field even when it holds a query, which replaces the prompt (R4)
                        .accessibilityLabel("Search Lensatic")
                        .onChange(of: model.query) {
                            if model.query.contains("\n") {
                                model.query = model.query.replacingOccurrences(of: "\n", with: "")
                                focused = false
                                model.progress.remember(search: model.query)
                            }
                        }
                        .font(DS.searchField)
                        .foregroundStyle(Palette.fg)
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("search-field")
                        // a growing field keeps the height it had at a larger text size when the size comes back down
                        // (an empty field two lines tall, the prompt on the first); a new field per text size measures afresh
                        .id(typeSize)
                    if !model.query.isEmpty {
                        Button { model.query = "" } label: {
                            Icon(.close, size: 16, color: Palette.fg2).frame(width: 44, height: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, -6)
                        .accessibilityLabel("Clear")
                        .accessibilityIdentifier("search-clear")
                    }
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 46)
                .card(radius: 12, stroke: Palette.lineStrong)
                .onTapGesture { focused = true }
                if model.query.trimmingCharacters(in: .whitespaces).isEmpty {
                    emptyState
                } else if groups.isEmpty {
                    Text("Nothing matches \u{201C}\(model.query)\u{201D}.").font(DS.note).foregroundStyle(Palette.fg2)
                        .accessibilityIdentifier("search-empty")
                } else {
                    ForEach(groups, id: \.kind) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            CountedLabel(text: title(group.kind), count: group.results.count)
                            ForEach(group.results) { item in
                                let line = SearchIndex.excerpt(item, query: model.query).map { "\(item.subtitle)\(model.store.label("metaSeparator"))\($0)" }
                                Button { focused = false; model.progress.remember(search: model.query); model.open(item.opens) } label: {
                                    ResultRow(title: item.title, line: line ?? item.subtitle)
                                }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("result-\(item.id)")
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("results-\(group.kind)")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Palette.bg)
        .hardTopEdge()
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("search")
    }

    /// Before a query (content release 1.0.1, Ken's finding of 7 November 2026: a near-empty screen): queries to start with,
    /// drawn from the content; the next step on the reader's path; their last searches; and, at the foot, what the field
    /// searches.
    @ViewBuilder private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Start with")
            FlowLayout(spacing: 8) {
                ForEach(model.store.content.ui.search.starters, id: \.self) { q in
                    Button { run(q) } label: { Pill(text: q) }
                        .buttonStyle(.plain)
                        .accessibilityHint("Searches for \(q)")
                        .accessibilityIdentifier("starter-\(q)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search-starters")
        if let door = model.door {
            let plan = model.plan(door)
            if let next = plan.next(model.progress.checked(door.id)), let first = next.entityIds.first {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "On your path")
                    Button { focused = false; model.push(.entity(first)) } label: {
                        ResultRow(title: "Step \(next.order): \(next.title)", line: model.store.entities[first]?.displayName ?? "")
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the step's source")
                    .accessibilityIdentifier("search-next-step")
                }
            }
        }
        let recent = model.progress.state.recent
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    SectionLabel(text: "Recent")
                    Spacer()
                    Button { model.progress.clearRecent() } label: {
                        Text("Clear").font(DS.link).foregroundStyle(Palette.link).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear recent searches")
                    .accessibilityIdentifier("recent-clear")
                }
                ForEach(recent, id: \.self) { q in
                    Button { run(q) } label: {
                        HStack(spacing: 10) {
                            Icon(.search, size: 16, color: Palette.fg2)
                            Text(q).font(DS.step).foregroundStyle(Palette.fg).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recent-\(q)")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("search-recent")
        }
        Text(hint).font(DS.caption).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
            .accessibilityIdentifier("search-hint")
    }

    /// Run a query from a chip or the Recent list: it fills the field and is kept as a recent search.
    private func run(_ q: String) {
        focused = false
        model.query = q
        model.progress.remember(search: q)
    }

    /// What the field searches, counted from the content.
    private var hint: String {
        let s = model.search.items
        func n(_ k: SearchIndex.Kind) -> Int { s.filter { $0.kind == k }.count }
        var parts = ["\(n(.framework)) frameworks and sources", "\(n(.guide)) guide chapters", "\(n(.play)) plays", "\(n(.term)) glossary terms"]
        if n(.step) > 0 { parts.insert("the \(n(.step)) steps on your path", at: 1) }
        return "Searches " + parts.dropLast().joined(separator: ", ") + " and " + (parts.last ?? "") + "."
    }

    private func title(_ kind: SearchIndex.Kind) -> String {
        switch kind {
        case .framework: return "Frameworks"
        case .step: return "On your path"
        case .guide: return model.library.site.guidesName
        case .play: return model.library.site.playsName
        case .term: return model.store.navTitle(.glossary)
        }
    }
}
