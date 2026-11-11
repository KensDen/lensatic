import SwiftUI

/// Search (the redesign, R2; the top of Widget.dc.html): one field across the entries, the steps on the reader's path,
/// the guide's chapters, the plays and the glossary, with the results grouped by kind. A result opens what it names.
/// Since build 6 a system inset-grouped list on the app's own surfaces (the section 7 rule), each kind a section.
struct SearchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
        let groups = model.search.search(model.query)
        // a system inset-grouped list on the app's own surfaces (build 6: the section 7 rule), as Home and Explore
        List {
            Group {
                SwiftUI.Section {
                    ScreenHeader(title: AppTab.search.title)
                        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                // the field is a row of its own, on the card fill, as the system's own search rows are
                SwiftUI.Section { field.listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 8)) }
                if model.query.trimmingCharacters(in: .whitespaces).isEmpty {
                    emptyState
                } else if groups.isEmpty {
                    SwiftUI.Section {
                        Text("Nothing matches \u{201C}\(model.query)\u{201D}.").font(DS.style(.subheadline)).foregroundStyle(Palette.fg2)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("search-empty")
                    }
                } else {
                    ForEach(groups, id: \.kind) { group in
                        SwiftUI.Section {
                            ForEach(group.results) { item in
                                let line = SearchIndex.excerpt(item, query: model.query).map { "\(item.subtitle)\(model.store.label("metaSeparator"))\($0)" }
                                Button { focused = false; model.progress.remember(search: model.query); model.open(item.opens) } label: {
                                    SearchRow(title: item.title, line: line ?? item.subtitle)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("result-\(item.id)")
                            }
                        } header: {
                            // one element that reads as it shows: the kind, then how many
                            HStack(alignment: .firstTextBaseline) {
                                ListNote(title(group.kind))
                                Spacer()
                                ListNote("\(group.results.count)")
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isHeader)
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("results-\(group.kind)")
                    }
                }
            }
            .lxRows()
        }
        .listStyle(.insetGrouped)
        .lxListSurface()
        .environment(\.defaultMinListRowHeight, 44)
        .scrollDismissesKeyboard(.immediately)
        .hardTopEdge()
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("search")
    }

    /// The field: a list row on the app's card fill, the width of the sections under it.
    private var field: some View {
        @Bindable var model = model
        return HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.body).foregroundStyle(Palette.fg2).accessibilityHidden(true)
            // a field that grows with the text size (a one-line field keeps its height and clips at the larger
            // sizes); Return searches rather than starting a new line
            TextField("Search Lensatic", text: $model.query, prompt: Text("Search Lensatic").foregroundStyle(Palette.fg2), axis: .vertical)
                .lineLimit(1...3)
                // in a list row a growing field asks for all three lines unless it is held to its text
                .fixedSize(horizontal: false, vertical: true)
                // VoiceOver names the field even when it holds a query, which replaces the prompt (R4)
                .accessibilityLabel("Search Lensatic")
                .onChange(of: model.query) {
                    if model.query.contains("\n") {
                        model.query = model.query.replacingOccurrences(of: "\n", with: "")
                        focused = false
                        model.progress.remember(search: model.query)
                    }
                }
                .font(DS.style(.body))
                .foregroundStyle(.primary)
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
                    Image(systemName: "xmark.circle.fill").font(.body).foregroundStyle(Palette.fg2)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, -6)
                .accessibilityLabel("Clear")
                .accessibilityIdentifier("search-clear")
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }

    /// Before a query (content release 1.0.1, Ken's finding of 7 November 2026: a near-empty screen): the reader's last
    /// searches, when there are any; queries to start with, drawn from the content; the next step on the reader's path;
    /// and, at the foot, what the field searches.
    @ViewBuilder private var emptyState: some View {
        // the reader's own searches come first when there are any (build 6: at the accessibility sizes they sat below the
        // fold, under Start With and On Your Path)
        let recent = model.progress.state.recent
        if !recent.isEmpty {
            SwiftUI.Section {
                ForEach(recent, id: \.self) { q in
                    Button { run(q) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "clock.arrow.circlepath").font(.subheadline).foregroundStyle(Palette.fg2).accessibilityHidden(true)
                            Text(q).font(DS.style(.body)).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recent-\(q)")
                }
            } header: {
                HStack(alignment: .firstTextBaseline) {
                    ListNote("Recent").accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button { model.progress.clearRecent() } label: {
                        Text("Clear").font(DS.style(.subheadline)).foregroundStyle(Palette.link)
                            .frame(minWidth: 44, minHeight: 44, alignment: .trailing).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear recent searches")
                    .accessibilityIdentifier("recent-clear")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("search-recent")
        }
        SwiftUI.Section {
            Group {
                if typeSize.isAccessibilitySize {
                    // one row that scrolls sideways, so the chips never fill the screen at the largest sizes (build 6)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) { starters }
                    }
                } else {
                    FlowLayout(spacing: 8) { starters }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } header: {
            ListNote("Start With")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search-starters")
        if let door = model.door {
            let plan = model.plan(door)
            if let next = plan.next(model.progress.checked(door.id)), let first = next.entityIds.first {
                SwiftUI.Section {
                    Button { focused = false; model.push(.entity(first)) } label: {
                        SearchRow(title: "Step \(next.order): \(next.title)", line: model.store.entities[first]?.displayName ?? "")
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the step's source")
                    .accessibilityIdentifier("search-next-step")
                } header: {
                    ListNote("On Your Path")
                }
            }
        }
        // at the foot, what the field searches
        SwiftUI.Section {
            Text(hint).font(DS.style(.footnote)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                // inside the row's rounded corners, which clip a clear row's content as they do a filled one's
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .accessibilityIdentifier("search-hint")
        }
    }

    /// The Start With chips, each a query drawn from the content.
    private var starters: some View {
        ForEach(model.store.content.ui.search.starters, id: \.self) { q in
            Button { run(q) } label: { Pill(text: q) }
                .buttonStyle(.plain)
                .accessibilityHint("Searches for \(q)")
                .accessibilityIdentifier("starter-\(q)")
        }
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
        case .step: return "On Your Path"
        case .guide: return model.library.site.guidesName
        case .play: return model.library.site.playsName
        case .term: return model.store.navTitle(.glossary)
        }
    }
}

/// A result, or the next step on the reader's path, as a list row: the title, the line under it and the list's chevron.
struct SearchRow: View {
    let title: String
    var line: String?

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(noOrphan(keepWhole(title))).font(DS.style(.body)).foregroundStyle(.primary)
                if let line, !line.isEmpty { Text(noOrphan(keepWhole(line))).font(DS.style(.footnote)).foregroundStyle(Palette.fg2) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
