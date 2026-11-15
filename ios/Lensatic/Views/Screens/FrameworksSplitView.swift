import SwiftUI

/// Frameworks on the iPad (Lensatic 2.0, Round 3): two panes. The sidebar is the tab's own first screen in a narrow
/// column, Browse as a compact list, Compare and the self-checks as they are; the detail pane shows the sidebar's pick
/// with no way back drawn, since there is nothing behind it, and every screen opened from there pushes inside the pane.
/// The sidebar marks the pick and follows it. With a keyboard, the up and down arrows move the pick through the
/// sidebar's list (the sidebar holds the keyboard's focus), and the app's other shortcuts are the Shell's; with a
/// pointer, rows and cards highlight under it.
/// Shown where the width is regular and the text is at a standard size; in a narrow window, and at the accessibility
/// sizes, the tab is the phone's one column.
struct FrameworksSplitView<Destination: View>: View {
    @Environment(AppModel.self) private var model
    /// The sidebar holds the keyboard's focus, so the arrow keys reach it.
    @FocusState private var sidebarFocused: Bool
    /// The Shell's own destinations, so a screen is built in one place for both layouts.
    @ViewBuilder let destination: (Nav) -> Destination

    var body: some View {
        @Bindable var model = model
        GeometryReader { geo in
            HStack(spacing: 0) {
                FrameworksView(pane: true)
                    .frame(width: FrameworksSplitView.sidebarWidth(geo.size.width))
                    // the keyboard (Round 3): the up and down arrows move the sidebar's pick. The sidebar takes the
                    // keyboard's focus when the panes appear and after each pick, and draws no ring for it: the pick's
                    // own mark shows where it is
                    .focusable()
                    .focused($sidebarFocused)
                    .focusEffectDisabled()
                    .onKeyPress(.downArrow) { model.movePane(by: 1); return .handled }
                    .onKeyPress(.upArrow) { model.movePane(by: -1); return .handled }
                Rectangle().fill(Palette.line).frame(width: 1).ignoresSafeArea(edges: .top).accessibilityHidden(true)
                NavigationStack(path: Binding(get: { model.paths[.frameworks] ?? [] }, set: { model.paths[.frameworks] = $0 })) {
                    Group {
                        if let root = model.paneRoot {
                            destination(root)
                                // a new pick is a new screen: it starts at its top, with its own state
                                .id(root)
                                .environment(\.paneRoot, true)
                        } else {
                            Palette.bg
                        }
                    }
                    .navigationDestination(for: Nav.self) { destination($0).environment(\.paneRoot, false) }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Palette.bg)
        // a screen of the sidebar's own kind opened from elsewhere becomes the pick
        .onChange(of: model.paths[.frameworks], initial: true) {
            model.foldPane()
            sidebarFocused = true
        }
        .onChange(of: model.frameworksMode) { model.foldPane() }
        .onChange(of: model.frameworksPane) { sidebarFocused = true }
        .onAppear { sidebarFocused = true }
    }

    /// The sidebar's width: a little over a third of the window, between 320 and 400 points.
    static func sidebarWidth(_ total: CGFloat) -> CGFloat { min(max(total * 0.36, 320), 400) }
}
