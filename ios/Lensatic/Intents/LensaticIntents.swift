import AppIntents
import Foundation

/// Siri and Shortcuts (R3): "What's my next Lensatic step?" answers from the progress file on the device; "Open
/// Lensatic search" opens Search; and an item (an entry, a step on the reader's path, or a play) opens by the key
/// Saved, iOS search and the widget use. Nothing is fetched; the answers come from the bundled content and the file.

/// The content the intents read, loaded once.
enum IntentContent {
    static let shared: (store: ContentStore, library: Library)? = {
        guard let store = try? ContentStore.bundled(), let library = try? Library.bundled() else { return nil }
        return (store, library)
    }()
}

/// Hands an intent's link to the app: at once when the app is running, or when its model is made.
@MainActor
enum IntentRouter {
    static weak var model: AppModel? {
        didSet { if let model, let link = pending { pending = nil; model.open(link: link) } }
    }
    static var pending: URL?

    static func open(_ url: URL) {
        if let model { model.open(link: url) } else { pending = url }
    }
}

struct NextStepIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Lensatic Step"
    static let description = IntentDescription("Says your next step on your Lensatic path, and the days to the next deadline when one lies ahead.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: NextStepIntent.answer(today: Date())))
    }

    /// The answer from the progress file and the content.
    @MainActor static func answer(today: Date, url: URL? = ProgressStore.defaultURL) -> String {
        guard let store = IntentContent.shared?.store else { return "Lensatic could not read its content." }
        let state = ProgressStore.state(from: url.flatMap { try? Data(contentsOf: $0) })
        return Glance(store: store, state: state, today: today).spoken
    }
}

struct OpenSearchIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Lensatic Search"
    static let description = IntentDescription("Opens Search in Lensatic, ready to type.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.open(DeepLink.search)
        return .result()
    }
}

/// An item the app can open: an entry, a step on the reader's path or a play, by its saved-item key.
struct LensaticItem: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Lensatic Item"
    static let defaultQuery = LensaticItemQuery()

    let id: String
    let title: String
    let kind: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(kind)")
    }

    /// Every item, as iOS search lists them: the entries, the reader's steps and the plays.
    @MainActor static func all(url: URL? = ProgressStore.defaultURL) -> [LensaticItem] {
        guard let (store, library) = IntentContent.shared else { return [] }
        let state = ProgressStore.state(from: url.flatMap { try? Data(contentsOf: $0) })
        let door = state.door.flatMap(Door.ID.init(rawValue:)).flatMap { id in store.content.doors.first { $0.id == id } }
        return Spotlight.entries(store: store, library: library, door: door).map {
            LensaticItem(id: $0.id, title: $0.title, kind: $0.domain == Spotlight.entities ? "Framework" : $0.domain == Spotlight.steps ? "Step" : "Play")
        }
    }
}

struct LensaticItemQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [LensaticItem.ID]) async throws -> [LensaticItem] {
        let all = LensaticItem.all()
        return identifiers.compactMap { id in all.first { $0.id == id } }
    }

    @MainActor
    func entities(matching string: String) async throws -> [LensaticItem] {
        LensaticItemQuery.matching(string, in: LensaticItem.all())
    }

    @MainActor
    func suggestedEntities() async throws -> [LensaticItem] { LensaticItem.all() }

    /// Items whose title holds every word of the string, in the index's order.
    static func matching(_ string: String, in items: [LensaticItem]) -> [LensaticItem] {
        let words = string.lowercased().split(whereSeparator: \.isWhitespace)
        return items.filter { item in words.allSatisfy { item.title.lowercased().contains($0) } }
    }
}

struct OpenItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Open in Lensatic"
    static let description = IntentDescription("Opens a framework, a step on your path or a play in Lensatic.")
    static let openAppWhenRun = true

    @Parameter(title: "Item")
    var item: LensaticItem

    init() {}

    init(item: LensaticItem) {
        self.item = item
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let saved = SavedItem(key: item.id) else { return .result() }
        IntentRouter.open(DeepLink.open(saved))
        return .result()
    }
}

struct LensaticShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: NextStepIntent(), phrases: [
            "What's my next \(.applicationName) step?",
            "What is my next step in \(.applicationName)?",
        ], shortTitle: "Next Step", systemImageName: "location.north.circle")
        AppShortcut(intent: OpenSearchIntent(), phrases: [
            "Open \(.applicationName) search",
            "Search \(.applicationName)",
        ], shortTitle: "Search", systemImageName: "magnifyingglass")
        AppShortcut(intent: OpenItemIntent(), phrases: [
            "Open \(\.$item) in \(.applicationName)",
        ], shortTitle: "Open an Item", systemImageName: "book")
    }
}
