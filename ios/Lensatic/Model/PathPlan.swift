import Foundation

/// A trailhead as the app's path (the redesign, R1): its ordered steps, the reader's progress through them, the step
/// that comes next, and the dated deadlines along it. Every number the path shows is computed here from the content and
/// the reader's checks; nothing is typed by hand.
struct PathPlan: Sendable {
    let door: Door
    /// The dated deadlines on the entries the steps name that bind this trailhead's audience, earliest first, each once
    /// (content 1.2.18: a date exists only where the deadline's own source prints it). A step may cite an entry that
    /// binds someone else (the contractor path cites the department's strategy); its deadline is not this path's.
    let deadlines: [Deadline]

    struct Deadline: Sendable, Hashable {
        let due: Authority.Due
        let sourceId: String
        let day: DateComponents
    }

    struct Progress: Sendable, Equatable {
        let done: Int
        let total: Int
        var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
        var isComplete: Bool { total > 0 && done == total }
    }

    init(door: Door, entities: [String: Entity]) {
        self.door = door
        var seen = Set<String>(), out: [Deadline] = []
        for step in door.steps {
            for id in step.entityIds {
                guard let entity = entities[id], !Set(entity.authority.binds).isDisjoint(with: door.id.audience),
                      let deadline = entity.authority.deadline.value, let due = deadline.due,
                      let day = PathPlan.day(due.date), seen.insert("\(deadline.sourceId)|\(due.date)").inserted else { continue }
                out.append(Deadline(due: due, sourceId: deadline.sourceId, day: day))
            }
        }
        deadlines = out.sorted { $0.due.date < $1.due.date }
    }

    var steps: [Door.Step] { door.steps }

    /// The steps checked off, counted only where the step exists (a check left from an older content file with more
    /// steps is not counted).
    func progress(_ checked: Set<Int>) -> Progress {
        Progress(done: steps.filter { checked.contains($0.order) }.count, total: steps.count)
    }

    /// The first step, in order, that is not checked off; nil when every step is.
    func next(_ checked: Set<Int>) -> Door.Step? { steps.first { !checked.contains($0.order) } }

    /// The earliest dated deadline on the path that falls today or later; nil when none does (the path then shows its
    /// next step instead of a countdown).
    func upcoming(today: Date, calendar: Calendar = .lensatic) -> Deadline? {
        deadlines.first { PathPlan.days(from: today, to: $0.day, calendar: calendar).map { $0 >= 0 } ?? false }
    }

    /// Whole days from the start of today to the start of the due day, in the calendar's time zone.
    static func days(from today: Date, to day: DateComponents, calendar: Calendar = .lensatic) -> Int? {
        guard let due = calendar.date(from: day) else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: due)).day
    }

    /// An ISO calendar date (2027-09-30) as a day; nil for anything else.
    static func day(_ iso: String) -> DateComponents? {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, iso.count == 10 else { return nil }
        let c = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        // a date the calendar would roll over (30 February) is not a date
        let cal = Calendar.lensatic
        guard let d = cal.date(from: c), cal.component(.year, from: d) == parts[0], cal.component(.month, from: d) == parts[1],
              cal.component(.day, from: d) == parts[2] else { return nil }
        return c
    }
}

extension Door.ID {
    /// Whom each trailhead speaks to, in the content's authority vocabulary (authority.binds): the deadlines that are
    /// this path's own. Everyone Else is bound by nothing on the stack.
    var audience: Set<Authority.Binds> {
        switch self {
        case .federalCivilian: return [.federalCivilian]
        case .dow: return [.dowComponents]
        case .defenseContractor: return [.defenseContractorsCUI, .defenseContractorsFCICUI]
        case .other: return []
        }
    }
}

extension Calendar {
    /// The Gregorian calendar in the device's time zone: a deadline day turns over at the reader's midnight.
    static var lensatic: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }
}

extension Authority.Due {
    /// When it is due, as the source states it and as a day: "End of FY2027 · 30 Sep 2027", or the day alone.
    func stated(separator: String) -> String {
        let day = Rules.formatDate(date)
        guard let fiscalYear else { return day }
        return "End of FY\(fiscalYear)\(separator)\(day)"
    }

    /// The short form for one-line places: "Target Level by FY2027", or by the day.
    var byLine: String { "\(short) by \(fiscalYear.map { "FY\($0)" } ?? Rules.formatDate(date))" }
}

enum Countdown {
    /// "339 days", "1 day", or "Due today".
    static func text(days: Int) -> String {
        switch days {
        case 0: return "Due today"
        case 1: return "1 day"
        default: return "\(days) days"
        }
    }
}

/// Title Case for names and labels the content writes in sentence case (the nit list's rules 1 and 4): every word
/// capitalized except short joining words after the first, and a word that already holds a capital (an abbreviation
/// such as DoW or CUI) left as it is.
extension Entity {
    /// The entry's name as a title on screen: in Title Case (nit 1), its own capitals kept.
    var displayName: String { TitleCase.apply(name) }
}

enum TitleCase {
    static let small: Set<String> = ["a", "an", "and", "as", "at", "by", "for", "in", "of", "on", "or", "the", "to", "with"]

    static func apply(_ s: String) -> String {
        var out = "", word = "", index = 0
        func flush() {
            guard !word.isEmpty else { return }
            if word.contains(where: \.isUppercase) || (index > 0 && small.contains(word)) {
                out += word
            } else {
                out += word.prefix(1).uppercased() + word.dropFirst()
            }
            index += 1
            word = ""
        }
        for ch in s {
            if ch.isLetter || ch.isNumber || ch == "'" || ch == "\u{2019}" {
                word.append(ch)
            } else {
                flush()
                out.append(ch)
            }
        }
        flush()
        return out
    }
}

extension PathPlan {
    /// The line under a trailhead's name on the welcome screen: its step count and, when a dated deadline lies ahead
    /// on the path, that deadline ("7 steps · Target Level by FY2027"); otherwise the trailhead's own line. A trailhead
    /// with no steps shows its own line alone.
    func cardLine(today: Date, labels L: [String: String], calendar: Calendar = .lensatic) -> String {
        guard !steps.isEmpty else { return door.cardLine }
        let count = steps.count == 1 ? (L["doorMetaStep"] ?? "1 step")
            : (L["doorMetaSteps"] ?? "{n} steps").replacingOccurrences(of: "{n}", with: String(steps.count))
        return count + (L["metaSeparator"] ?? " · ") + (upcoming(today: today, calendar: calendar)?.due.byLine ?? door.cardLine)
    }
}

extension ContentStore {
    /// The entries a card's Goes With row names: those that share a trailhead step with it, the most shared first, then
    /// in the order the steps first name them; at most four.
    func goesWith(_ id: String, limit: Int = 4) -> [String] {
        var count: [String: Int] = [:], first: [String: Int] = [:], seen = 0
        for door in content.doors {
            for step in door.steps where step.entityIds.contains(id) {
                for other in step.entityIds where other != id && entities[other] != nil {
                    count[other, default: 0] += 1
                    if first[other] == nil { first[other] = seen; seen += 1 }
                }
            }
        }
        return Array(count.keys.sorted { a, b in
            count[a]! != count[b]! ? count[a]! > count[b]! : first[a]! < first[b]!
        }.prefix(limit))
    }
}
