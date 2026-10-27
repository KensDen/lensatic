import SwiftUI

/// Search (the redesign, R2; the top of Widget.dc.html): one field across the entries, the steps on the reader's path,
/// the guide's chapters, the plays and the glossary, with the results grouped by kind. A result opens what it names.
struct SearchView: View {
    @Environment(AppModel.self) private var model
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
                        .onChange(of: model.query) {
                            if model.query.contains("\n") {
                                model.query = model.query.replacingOccurrences(of: "\n", with: "")
                                focused = false
                            }
                        }
                        .font(DS.searchField)
                        .foregroundStyle(Palette.fg)
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("search-field")
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
                    Text(hint).font(DS.note).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                } else if groups.isEmpty {
                    Text("Nothing matches \u{201C}\(model.query)\u{201D}.").font(DS.note).foregroundStyle(Palette.fg2)
                        .accessibilityIdentifier("search-empty")
                } else {
                    ForEach(groups, id: \.kind) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            CountedLabel(text: title(group.kind), count: group.results.count)
                            ForEach(group.results) { item in
                                let line = SearchIndex.excerpt(item, query: model.query).map { "\(item.subtitle)\(model.store.label("metaSeparator"))\($0)" }
                                Button { focused = false; model.open(item.opens) } label: { ResultRow(title: item.title, line: line ?? item.subtitle) }
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
