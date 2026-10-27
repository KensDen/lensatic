import Foundation
import Observation

/// The reader's progress, kept on this device only (the redesign, R1 to R3): the trailhead they picked, for each
/// trailhead the steps they checked off, the items they saved, the guide's weeks they marked done, and their last view of
/// What Changed. One small JSON file, written atomically and protected by the device's data protection. From R3 it sits
/// in the App Group's container, which only the app and its own widget can open, so the widget can show the next step;
/// a file an earlier build kept in the app's own Application Support folder moves there once, whole. There is no account,
/// nothing leaves the device, and no API the privacy manifest would declare is used. This is the app's only file write
/// (tools/check_ios.py holds it to this file).
@Observable @MainActor
final class ProgressStore {
    /// The App Group the app and its widget share (both targets' entitlements name it; tools/check_ios.py holds them to it).
    nonisolated static let appGroup = "group.io.github.kensden.lensatic"

    struct State: Codable, Equatable, Sendable {
        var door: String?
        /// Checked step numbers per trailhead id. Each trailhead keeps its own, so switching back finds them again.
        var checked: [String: [Int]] = [:]
        /// Saved items, newest first, by their keys (SavedItem.key).
        var saved: [String] = []
        /// The guide's weeks marked done: the core's under "core", a track's under the track's id.
        var weeks: [String: [Int]] = [:]
        /// The reader's last view of What Changed (R3): the content release it showed and the day; nil before any.
        var changesViewed: ChangesViewed?

        struct ChangesViewed: Codable, Equatable, Sendable {
            /// The content release the list was cleared at (contentVersion): items of later releases are new.
            var through: String
            /// The day of that view, as an ISO date (2026-10-27).
            var on: String
        }

        init(door: String? = nil, checked: [String: [Int]] = [:], saved: [String] = [], weeks: [String: [Int]] = [:],
             changesViewed: ChangesViewed? = nil) {
            self.door = door
            self.checked = checked
            self.saved = saved
            self.weeks = weeks
            self.changesViewed = changesViewed
        }

        private enum CodingKeys: String, CodingKey { case door, checked, saved, weeks, changesViewed }

        /// A file from before saved items and weeks (R1), or before What Changed (R2), reads with none of them.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            door = try c.decodeIfPresent(String.self, forKey: .door)
            checked = try c.decodeIfPresent([String: [Int]].self, forKey: .checked) ?? [:]
            saved = try c.decodeIfPresent([String].self, forKey: .saved) ?? []
            weeks = try c.decodeIfPresent([String: [Int]].self, forKey: .weeks) ?? [:]
            changesViewed = try c.decodeIfPresent(ChangesViewed.self, forKey: .changesViewed)
        }
    }

    private(set) var state: State
    @ObservationIgnored let url: URL?
    /// Called after each save (the app reloads its widget's timeline).
    @ObservationIgnored var onSave: (@MainActor () -> Void)?

    /// The store at a file: the App Group's file by default (moving an earlier build's file there first), or another file
    /// (the unit tests use a temporary one); nil keeps everything in memory.
    init(url: URL? = ProgressStore.defaultURL) {
        self.url = url
        state = ProgressStore.state(from: url.flatMap { try? Data(contentsOf: $0) })
    }

    /// The saved state, or a fresh one when there is no file or it cannot be read.
    nonisolated static func state(from data: Data?) -> State {
        data.flatMap { try? JSONDecoder().decode(State.self, from: $0) } ?? State()
    }

    /// The file the app and the widget share, after moving an earlier build's file into it; the app's own file when the
    /// App Group is not available (it then stays where it is).
    static var defaultURL: URL? {
        let legacy = legacyURL
        guard let shared = sharedURL else { return legacy }
        if let legacy { migrate(from: legacy, to: shared) }
        return shared
    }

    /// The App Group's file, as the widget reads it: Library/Application Support/Lensatic/progress.json in the group's
    /// container.
    nonisolated static var sharedURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("Library/Application Support/Lensatic", isDirectory: true).appendingPathComponent("progress.json")
    }

    /// Where R1 and R2 kept the file: the app's own Application Support folder.
    nonisolated static var legacyURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Lensatic", isDirectory: true).appendingPathComponent("progress.json")
    }

    /// Move an earlier build's file into the shared place, once and whole: only when the shared file does not exist yet,
    /// only a file that reads, and the old file is removed only after the new one is written. A file that does not read
    /// stays where it is, untouched.
    @discardableResult
    static func migrate(from old: URL, to new: URL) -> Bool {
        guard !FileManager.default.fileExists(atPath: new.path), let data = try? Data(contentsOf: old),
              (try? JSONDecoder().decode(State.self, from: data)) != nil else { return false }
        guard write(data, to: new) else { return false }
        try? FileManager.default.removeItem(at: old)
        return true
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

    // MARK: What Changed

    /// Clear What Changed: the reader has seen everything up to this content release, on this day.
    func viewChanges(through release: String, on day: String) {
        state.changesViewed = State.ChangesViewed(through: release, on: day)
        save()
    }

    /// Forget the last view of What Changed (a Debug launch argument uses it, for the tests and screenshots).
    func setChangesViewed(_ viewed: State.ChangesViewed?) {
        state.changesViewed = viewed
        save()
    }

    /// Forget everything: no trailhead, no checks, nothing saved (a Debug launch argument uses it, for the tests and screenshots).
    func reset() {
        state = State()
        if let url { try? FileManager.default.removeItem(at: url) }
        onSave?()
    }

    private func save() {
        guard let url, let data = try? JSONEncoder().encode(state) else { return }
        // a failed save keeps the progress in memory for this launch; the next change tries again
        _ = ProgressStore.write(data, to: url)
        onSave?()
    }

    /// The one write: atomic, under data protection, into the file's folder (made if missing).
    nonisolated private static func write(_ data: Data, to url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
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
