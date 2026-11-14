import Foundation

/// The app's own links (R3): they only move around the app, nothing is fetched. lensatic://open/<item key> opens an
/// entry, a step or a play by the key Saved and iOS search use (entity:id, step:door:order, play:id); lensatic://search
/// opens Search; lensatic://path opens My Path. The widget's taps and the open intents use them.
enum DeepLink {
    static let scheme = "lensatic"

    static func open(_ item: SavedItem) -> URL { make("open", "/" + item.key) }
    static var search: URL { make("search") }
    static var path: URL { make("path") }

    private static func make(_ host: String, _ path: String = "") -> URL {
        var c = URLComponents()
        c.scheme = scheme
        c.host = host
        c.path = path
        return c.url!
    }
}

/// The reader's path at a glance (R3), as the widget and Siri give it: the trailhead, the steps done, the next step and
/// the days to the next dated deadline on the path. Computed from the content and the progress file, as My Path is.
struct Glance: Sendable, Equatable {
    struct Next: Sendable, Equatable {
        let order: Int
        let title: String
        /// The step's first entry in a few words (the small widget's "Next: ZT for OT").
        let short: String
        let link: URL
    }

    struct Countdown: Sendable, Equatable {
        let days: Int
        /// What is due, in a few words ("Target Level").
        let label: String
        let sourceId: String
    }

    /// The trailhead's name, nil before one is picked.
    let door: String?
    let done: Int
    let total: Int
    let next: Next?
    let countdown: Countdown?

    var link: URL { next?.link ?? DeepLink.path }
    var isComplete: Bool { total > 0 && done == total }

    init(door: String?, done: Int, total: Int, next: Next?, countdown: Countdown?) {
        self.door = door
        self.done = done
        self.total = total
        self.next = next
        self.countdown = countdown
    }

    /// The glance for a progress state on a day.
    init(store: ContentStore, state: ProgressStore.State, today: Date, calendar: Calendar = .lensatic) {
        guard let id = state.door.flatMap(Door.ID.init(rawValue:)), let door = store.content.doors.first(where: { $0.id == id }) else {
            // Lensatic 2.0: before a trailhead is picked the widget still counts down to the next dated zero trust
            // deadline on the stack; once one is picked, only a deadline that binds that trailhead shows (PathPlan)
            self.init(door: nil, done: 0, total: 0, next: nil, countdown: Glance.general(store: store, today: today, calendar: calendar))
            return
        }
        let plan = PathPlan(door: door, entities: store.entities)
        let checked = Set(state.checked[id.rawValue] ?? [])
        let progress = plan.progress(checked)
        let next = plan.next(checked).map { step in
            Next(order: step.order, title: step.title,
                 short: step.entityIds.first.flatMap { store.entities[$0]?.shortName } ?? step.title,
                 link: DeepLink.open(.step(id, step.order)))
        }
        let countdown = plan.upcoming(today: today, calendar: calendar).flatMap { d in
            PathPlan.days(from: today, to: d.day, calendar: calendar).map { Countdown(days: $0, label: d.due.short, sourceId: d.sourceId) }
        }
        self.init(door: door.shortTitle, done: progress.done, total: progress.total, next: next, countdown: countdown)
    }

    /// The next dated deadline among the stack's frameworks, today or later: the zero trust countdown Home leads with.
    static func general(store: ContentStore, today: Date, calendar: Calendar = .lensatic) -> Countdown? {
        let dated = store.frameworks.compactMap { e -> (Authority.Due, String, Int)? in
            guard let d = e.authority.deadline.value, let due = d.due, let day = PathPlan.day(due.date),
                  let days = PathPlan.days(from: today, to: day, calendar: calendar), days >= 0 else { return nil }
            return (due, d.sourceId, days)
        }
        return dated.min { $0.0.date < $1.0.date }.map { Countdown(days: $0.2, label: $0.0.short, sourceId: $0.1) }
    }

    /// What VoiceOver reads for the widget (R4), as one element in the order it is drawn: the countdown, the next step
    /// and how far along the path is; or what to do first.
    var voiceOver: String {
        guard let door else {
            let due = countdown.map { $0.days == 0 ? "\($0.label) is due today. " : "\($0.days) \($0.days == 1 ? "day" : "days") to \($0.label). " } ?? ""
            return "Lensatic. \(due)Pick a trailhead to start your path."
        }
        var parts = ["Lensatic, \(door)"]
        if let c = countdown { parts.append(c.days == 0 ? "\(c.label) is due today" : "\(c.days) \(c.days == 1 ? "day" : "days") to \(c.label)") }
        if let next { parts.append("Next, step \(next.order) of \(total): \(next.title)") } else if isComplete { parts.append("Path complete") }
        if total > 0 { parts.append("\(done) of \(total) steps done") }
        return parts.joined(separator: ". ") + "."
    }

    /// One sentence for Siri: the next step, and the deadline when one lies ahead.
    var spoken: String {
        guard let door else { return "You have not picked a trailhead yet. Open Lensatic to pick one." }
        if total == 0 { return "\(door) has no steps on its path. Open Lensatic to explore the map." }
        guard let next else { return "You have finished all \(total) steps on the \(door) path." }
        var out = "Your next step is step \(next.order) of \(total): \(next.title)."
        if let c = countdown {
            out += c.days == 0 ? " \(c.label) is due today." : " \(c.days) \(c.days == 1 ? "day" : "days") to \(c.label)."
        }
        return out
    }
}

/// The haptic a change in the checks calls for (R3): a step checked off, or the last one finishing the path. Unchecking
/// is silent.
enum PathHaptic: Equatable {
    case check, finish

    static func after(_ old: Set<Int>, _ new: Set<Int>, plan: PathPlan) -> PathHaptic? {
        let before = plan.progress(old), after = plan.progress(new)
        guard after.done > before.done else { return nil }
        return after.isComplete ? .finish : .check
    }
}
