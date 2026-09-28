import SwiftUI

/// The sections in the web's order: on iPhone a list that pushes each section, on iPad the same list as the sidebar
/// of a split view. Every section is one tap from the list; every entry is reachable within three.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var columns = NavigationSplitViewVisibility.all

    var body: some View {
        @Bindable var model = model
        NavigationSplitView(columnVisibility: $columns) {
            SectionList()
        } detail: {
            NavigationStack(path: $model.path) {
                Group {
                    if let s = model.selection {
                        // one identity per section, so a jump between sections starts a fresh page (and its scroll)
                        PageScreen(key: .section(s, s == .matrix ? model.matrixView : .dow)).id(s)
                    } else {
                        Palette.bg.ignoresSafeArea()
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    PageScreen(key: .route(route))
                        .onAppear { model.opened(route) }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(Palette.link)
        .sheet(item: $model.glossaryEntry) { entry in
            GlossarySheetView(slug: entry.slug)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .tint(Palette.link)
        }
        .onAppear {
            // iPad opens with the list beside the front door; iPhone opens on the list
            if sizeClass == .regular && model.selection == nil { model.selection = .doors }
        }
        .onChange(of: model.selection) { model.path = [] }
    }
}

struct SectionList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let page = model.page(.root)
        List(selection: $model.selection) {
            if case .rows(let rows)? = page.blocks.first?.kind {
                ForEach(Array(zip(model.store.sections, rows)), id: \.0) { section, row in
                    NavigationLink(value: section) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            if let lead = row.lead {
                                Text(lead.text).font(Typo.secNum).foregroundStyle(Palette.accent)
                            }
                            Text(row.title.text).font(Typo.rowTitle).foregroundStyle(Palette.fg)
                        }
                        .padding(.vertical, 6)
                        .frame(minHeight: 44)
                    }
                    .accessibilityLabel(row.title.text)
                    .accessibilityHint(row.title.described.joined(separator: ", "))
                    .accessibilityIdentifier(row.identifier)
                    .listRowBackground(Palette.bg2)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle(page.title)
    }
}

/// One screen: its page, built once and drawn by `PageView`.
struct PageScreen: View {
    @Environment(AppModel.self) private var model
    let key: PageKey

    var body: some View {
        let page = model.page(key)
        PageView(page: page)
            .navigationTitle(page.title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct GlossarySheetView: View {
    @Environment(\.dismiss) private var dismiss
    let slug: String

    var body: some View {
        // Done sits in the sheet, in the app's type, so it scales with Dynamic Type like everything else
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Text("Done").font(Typo.button).foregroundStyle(Palette.link).padding(.horizontal, 20).frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("glossary-done")
            }
            .padding(.top, 8)
            PageScreen(key: .glossaryEntry(slug))
        }
        .background(Palette.bg)
    }
}
