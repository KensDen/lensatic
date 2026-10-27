import Foundation
import Observation

/// The reader's progress, kept on this device only (the redesign, R1 and R2): the trailhead they picked, for each
/// trailhead the steps they checked off, the items they saved, and the guide's weeks they marked done. One small JSON file in the app's own Application Support folder, written
/// atomically and protected by the device's data protection. There is no account, nothing leaves the device, and no
/// API the privacy manifest would declare is used. This is the app's only file write (tools/check_ios.py holds it to
/// this file).
@Observable @MainActor
final class ProgressStore {
    struct State: Codable, Equatable, Sendable {
        var door: String?
        /// Checked step numbers per trailhead id. Each trailhead keeps its own, so switching back finds them again.
        var checked: [String: [Int]] = [:]
        /// Saved items, newest first, by their keys (SavedItem.key).
        var saved: [String] = []
        /// The guide's weeks marked done: the core's under "core", a track's under the track's id.
        var weeks: [String: [Int]] = [:]

        init(door: String? = nil, checked: [String: [Int]] = [:], saved: [String] = [], weeks: [String: [Int]] = [:]) {
            self.door = door
            self.checked = checked
            self.saved = saved
            self.weeks = weeks
        }

        private enum CodingKeys: String, CodingKey { case door, checked, saved, weeks }

        /// A file from before saved items and weeks (R1) reads with none of either.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            door = try c.decodeIfPresent(String.self, forKey: .door)
            checked = try c.decodeIfPresent([String: [Int]].self, forKey: .checked) ?? [:]
            saved = try c.decodeIfPresent([String].self, forKey: .saved) ?? []
            weeks = try c.decodeIfPresent([String: [Int]].self, forKey: .weeks) ?? [:]
        }
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

    // MARK: saved items

    var saved: [SavedItem] { state.saved.compactMap(SavedItem.init(key:)) }

    func isSaved(_ item: SavedItem) -> Bool { state.saved.contains(item.key) }

    /// Save an item at the top of the list, or take it off.
    func toggleSaved(_ item: SavedItem) {
        if let i = state.saved.firstIndex(of: item.key) {
            state.saved.remove(at: i)
        } else {
            state.saved.insert(item.key, at: 0)
        }
        save()
    }

    // MARK: the guide's weeks

    func weeksDone(_ key: String) -> Set<Int> { Set(state.weeks[key] ?? []) }

    func toggleWeek(_ key: String, _ week: Int) {
        var set = weeksDone(key)
        if set.contains(week) { set.remove(week) } else { set.insert(week) }
        state.weeks[key] = set.sorted()
        save()
    }

    /// Forget everything: no trailhead, no checks, nothing saved (a Debug launch argument uses it, for the tests and screenshots).
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

/// Something the reader saved: an entry (its card), a step on a trailhead, or a play. Kept in the file by its key.
enum SavedItem: Hashable, Sendable {
    case entity(String)
    case step(Door.ID, Int)
    case play(String)

    var key: String {
        switch self {
        case .entity(let id): return "entity:\(id)"
        case .step(let door, let order): return "step:\(door.rawValue):\(order)"
        case .play(let id): return "play:\(id)"
        }
    }

    init?(key: String) {
        let parts = key.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        switch (parts.first, parts.count) {
        case ("entity", 2) where !parts[1].isEmpty: self = .entity(parts[1])
        case ("play", 2) where !parts[1].isEmpty: self = .play(parts[1])
        case ("step", 3):
            guard let door = Door.ID(rawValue: parts[1]), let order = Int(parts[2]) else { return nil }
            self = .step(door, order)
        default: return nil
        }
    }
}
