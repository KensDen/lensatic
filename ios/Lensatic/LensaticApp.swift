import SwiftUI

@main
struct LensaticApp: App {
    @State private var model: AppModel

    init() {
        let store: ContentStore
        do {
            store = try ContentStore.bundled()
        } catch {
            // the content ships inside the app and the unit tests decode it on every build, so this cannot happen in a release
            preconditionFailure("content/stack.json did not decode: \(error)")
        }
        _model = State(initialValue: AppModel(store: store))
        Appearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
