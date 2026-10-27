import SwiftUI
import WidgetKit

@main
struct LensaticApp: App {
    @State private var model: AppModel

    init() {
        let store: ContentStore
        let library: Library
        let changes: Changes
        do {
            store = try ContentStore.bundled()
            library = try Library.bundled()
            changes = try Changes.bundled()
        } catch {
            // the content ships inside the app and the unit tests decode it on every build, so this cannot happen in a release
            preconditionFailure("the bundled content did not decode: \(error)")
        }
        let progress = ProgressStore()
        // the widget shows the next step and the countdown from the same file, so each save refreshes it
        progress.onSave = { WidgetCenter.shared.reloadAllTimelines() }
        let model = AppModel(store: store, library: library, changes: changes, progress: progress)
        _model = State(initialValue: model)
        // Siri and Shortcuts open items through the model (R3)
        IntentRouter.model = model
        Appearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
