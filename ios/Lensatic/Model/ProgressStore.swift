import Foundation
import Observation

/// The reader's progress, kept on this device only (the redesign, R1): the trailhead they picked and, for each
/// trailhead, the steps they checked off. One small JSON file in the app's own Application Support folder, written
/// atomically and protected by the device's data protection. There is no account, nothing leaves the device, and no
/// API the privacy manifest would declare is used. This is the app's only file write (tools/check_ios.py holds it to
/// this file).
@Observable @MainActor
final class ProgressStore {
    struct State: Codable, Equatable, Sendable {
        var door: String?
        /// Checked step numbers per trailhead id. Each trailhead keeps its own, so switching back finds them again.
        var checked: [String: [Int]] = [:]
    }

    private(set) var state: State
    @ObservationIgnored let url: URL?

    /// The store at a file: the app's Application Support folder by default, or another file (the unit tests use a
    /// temporary one); nil keeps everything in memory.
    init(url: URL? = ProgressStore.defaultURL) {
        self.url = url
        state = ProgressStore.state(from: url.flatMap { try? Data(contentsOf: $0) })
    }

    /// The saved state, or a fresh one when there is no file or it cannot be read.
    nonisolated static func state(from data: Data?) -> State {
        data.flatMap { try? JSONDecoder().decode(State.self, from: $0) } ?? State()
    }

    static var defaultURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Lensatic", isDirectory: true).appendingPathComponent("progress.json")
    }

    var door: Door.ID? { state.door.flatMap(Door.ID.init(rawValue:)) }

    func choose(_ door: Door.ID) {
        state.door = door.rawValue
        save()
    }

    func checked(_ door: Door.ID) -> Set<Int> { Set(state.checked[door.rawValue] ?? []) }

    func isChecked(_ door: Door.ID, _ order: Int) -> Bool { checked(door).contains(order) }

    func toggle(_ door: Door.ID, _ order: Int) {
        var set = checked(door)
        if set.contains(order) { set.remove(order) } else { set.insert(order) }
        state.checked[door.rawValue] = set.sorted()
        save()
    }

    /// Forget everything: no trailhead, no checks (a Debug launch argument uses it, for the tests and screenshots).
    func reset() {
        state = State()
        if let url { try? FileManager.default.removeItem(at: url) }
    }

    private func save() {
        guard let url else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(state)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            // a failed save keeps the progress in memory for this launch; the next change tries again
        }
    }
}
