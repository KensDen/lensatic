import SwiftUI
import WidgetKit

/// The home screen widget (the redesign, R3; Widget.dc.html): the days to the next dated deadline on the reader's path
/// and the next step, or the next step alone when no deadline lies ahead. Small and medium. A tap opens that step on My
/// Path. It reads the progress file the app keeps in the App Group's container, and the content bundled with it; it
/// makes no network call.
@main
struct LensaticWidgets: WidgetBundle {
    var body: some Widget { PathWidget() }
}

struct PathWidget: Widget {
    static let kind = "io.github.kensden.lensatic.path"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: PathWidget.kind, provider: PathProvider()) { entry in
            PathWidgetView(entry: entry)
                .containerBackground(Palette.bg2, for: .widget)
                .widgetURL(entry.glance.link)
        }
        .configurationDisplayName("Next Step")
        .description("Your next deadline and next step, at a glance. Tap it to jump straight to that step.")
        .supportedFamilies([.systemSmall, .systemMedium])
        // the widget's own ground, as the mockup draws it, kept where the system allows
        .containerBackgroundRemovable(false)
    }
}

struct PathEntry: TimelineEntry {
    let date: Date
    let glance: Glance
}

struct PathProvider: TimelineProvider {
    /// The gallery's sample: the department's path from the content, its third step next, as the mockup shows it.
    func placeholder(in context: Context) -> PathEntry {
        PathEntry(date: Date(), glance: PathProvider.sample() ?? Glance(door: nil, done: 0, total: 0, next: nil, countdown: nil))
    }

    func getSnapshot(in context: Context, completion: @escaping (PathEntry) -> Void) {
        let now = Date()
        let live = PathProvider.glance(now)
        // the widget gallery shows the sample until the reader has picked a trailhead
        let shown = context.isPreview && live?.door == nil ? PathProvider.sample() : live
        completion(PathEntry(date: now, glance: shown ?? placeholder(in: context).glance))
    }

    /// Today's glance, then one at each of the next seven midnights, so the countdown turns over with the day; the app
    /// reloads the timeline whenever the reader checks a step.
    func getTimeline(in context: Context, completion: @escaping (Timeline<PathEntry>) -> Void) {
        let cal = Calendar.lensatic
        let now = Date()
        var entries: [PathEntry] = []
        if let g = PathProvider.glance(now) { entries.append(PathEntry(date: now, glance: g)) }
        var day = cal.startOfDay(for: now)
        for _ in 0..<7 {
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            if let g = PathProvider.glance(day) { entries.append(PathEntry(date: day, glance: g)) }
        }
        completion(Timeline(entries: entries, policy: .after(day)))
    }

    static func glance(_ day: Date) -> Glance? {
        guard let store = try? ContentStore.bundled() else { return nil }
        let state = ProgressStore.state(from: ProgressStore.sharedURL.flatMap { try? Data(contentsOf: $0) })
        return Glance(store: store, state: state, today: day)
    }

    static func sample() -> Glance? {
        guard let store = try? ContentStore.bundled() else { return nil }
        return Glance(store: store, state: .init(door: "dow", checked: ["dow": [1, 2]]), today: Date())
    }
}

/// The widget's two sizes, in the app's type and colours.
struct PathWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PathEntry

    private static func font(_ face: String, _ size: CGFloat, _ style: Font.TextStyle) -> Font { Typo.font(face, size, style) }
    private let brand = font(Typo.sans, 11, .caption)
    private let big = font(Typo.sansBold, 36, .largeTitle)
    private let small = font(Typo.sans, 12, .caption)
    private let next = font(Typo.sans, 11, .caption)
    private let title = font(Typo.sansSemi, 15, .subheadline)
    private let eyebrow = font(Typo.monoMedium, 10, .caption2)

    var body: some View {
        let g = entry.glance
        if family == .systemMedium {
            HStack(alignment: .top, spacing: 16) {
                lead(g).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                trail(g).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            lead(g).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// The small widget, and the medium one's left half: the brand, the countdown or the next step, and the next step's
    /// few words.
    @ViewBuilder private func lead(_ g: Glance) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Icon(.compass, size: 16, color: Palette.secGuides, lineWidth: 2.2)
                Text("Lensatic").font(brand).foregroundStyle(Palette.fg2)
            }
            Spacer(minLength: 4)
            if let c = g.countdown {
                Text("\(c.days)").font(big).foregroundStyle(Palette.fg).minimumScaleFactor(0.6).lineLimit(1)
                Text(c.days == 1 ? "day to \(c.label)" : "days to \(c.label)").font(small).foregroundStyle(Palette.fg2).lineLimit(2)
            } else if family == .systemMedium, g.next != nil, g.total > 0 {
                // no deadline ahead: the medium widget's right half names the next step, so its left counts the steps
                Text("\(g.done)/\(g.total)").font(big).foregroundStyle(Palette.fg).minimumScaleFactor(0.6).lineLimit(1)
                Text("steps done").font(small).foregroundStyle(Palette.fg2)
            } else if g.door == nil {
                Text("Pick a trailhead").font(title).foregroundStyle(Palette.fg).lineLimit(3)
            } else if let n = g.next {
                Text("NEXT · STEP \(n.order) OF \(g.total)").font(eyebrow).foregroundStyle(Palette.secMaps).lineLimit(1).minimumScaleFactor(0.8)
                Text(n.title).font(title).foregroundStyle(Palette.fg).lineLimit(3).minimumScaleFactor(0.85)
            } else if g.isComplete {
                Text("\(g.done)/\(g.total)").font(big).foregroundStyle(Palette.fg).minimumScaleFactor(0.6).lineLimit(1)
                Text("Path complete").font(small).foregroundStyle(Palette.fg2)
            } else {
                Text("Explore the map").font(title).foregroundStyle(Palette.fg).lineLimit(3)
            }
            Spacer(minLength: 4)
            if g.countdown != nil, let n = g.next, family == .systemSmall {
                Text("Next: \(n.short)").font(next).foregroundStyle(Palette.secMaps).lineLimit(2)
            } else if let door = g.door, family == .systemSmall {
                Text(door).font(next).foregroundStyle(Palette.fg2).lineLimit(2)
            }
        }
    }

    /// The medium widget's right half: the next step in full, its place on the path, and the trailhead.
    @ViewBuilder private func trail(_ g: Glance) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let n = g.next {
                Text("NEXT · STEP \(n.order) OF \(g.total)").font(eyebrow).foregroundStyle(Palette.secMaps).lineLimit(1).minimumScaleFactor(0.8)
                Text(n.title).font(title).foregroundStyle(Palette.fg).lineLimit(3)
            } else if g.isComplete {
                Text("ALL STEPS DONE").font(eyebrow).foregroundStyle(Palette.secMaps)
            }
            Spacer(minLength: 4)
            // the bar, unless the left half already counts the steps (no deadline ahead)
            if g.total > 0, g.countdown != nil || g.next == nil {
                ProgressView(value: Double(g.done), total: Double(g.total)).tint(Palette.secMaps)
                    .accessibilityLabel("\(g.done) of \(g.total) steps done")
            }
            if let door = g.door { Text(door).font(next).foregroundStyle(Palette.fg2).lineLimit(1).minimumScaleFactor(0.8) }
        }
    }
}
