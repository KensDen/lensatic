import SwiftUI

/// My Path (the redesign, R1; MyPath.dc.html): the trailhead's progress ring and either the countdown to the next
/// dated deadline on the path or, where none lies ahead, the next step; then every step in order, checked off on the
/// device, the next one called out. A step opens in place to its full text and the entries it names. Under the steps,
/// What Changed (R3, MyPath.dc.html) lists what the content releases changed since the reader last cleared it. A
/// check-off taps lightly and finishing the path gives the success pattern (the system's haptics, so its setting holds).
struct MyPathView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var phase
    @State private var expanded: Set<Int> = []
    @State private var now = Date()
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if let door = model.door {
                content(door, model.plan(door))
            } else {
                Palette.bg
            }
        }
        .background(Palette.bg)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: phase) { if phase == .active { now = Date() } }
    }

    private func content(_ door: Door, _ plan: PathPlan) -> some View {
        let checked = model.progress.checked(door.id)
        let next = plan.next(checked)
        return ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(eyebrow: door.shortTitle, title: "My Path") {
                    Button { model.changingDoor = true } label: {
                        Text("Change").font(DS.link).foregroundStyle(Palette.link).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Change trailhead")
                    .accessibilityIdentifier("change-door")
                }
                hero(door, plan, checked)
                if plan.steps.isEmpty {
                    noPath(door)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Your steps")
                        ForEach(plan.steps, id: \.order) { step in
                            StepRow(door: door.id, step: step, isDone: checked.contains(step.order), isNext: step.order == next?.order,
                                    layer: model.store.layerTag(step.layerId), names: names(step.entityIds),
                                    expanded: expanded.contains(step.order),
                                    toggle: { model.progress.toggle(door.id, step.order) },
                                    expand: { toggleExpanded(step.order) },
                                    open: { model.push(.entity($0)) })
                            .id("step-row-\(step.order)")
                        }
                    }
                }
                let changes = model.newChanges
                if !changes.isEmpty { WhatChanged(items: changes, door: door) }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .accessibilityIdentifier("my-path")
        .hardTopEdge()
        .sensoryFeedback(trigger: checked) { old, new in
            switch PathHaptic.after(old, new, plan: plan) {
            case .check?: return .impact(weight: .light)
            case .finish?: return .success
            case nil: return nil
            }
        }
        // a step opened from Search, a saved item or iOS search: open it in place and bring it into view
        .onAppear { focus(proxy) }
        .onChange(of: model.pathFocus) { focus(proxy) }
        }
    }

    private func focus(_ proxy: ScrollViewProxy) {
        guard let order = model.pathFocus else { return }
        model.pathFocus = nil
        expanded.insert(order)
        DispatchQueue.main.async { proxy.scrollTo("step-row-\(order)", anchor: .top) }
    }

    private func names(_ ids: [String]) -> [(id: String, name: String)] {
        ids.compactMap { id in model.store.entities[id].map { (id, $0.shortName) } }
    }

    private func toggleExpanded(_ order: Int) {
        if expanded.contains(order) { expanded.remove(order) } else { expanded.insert(order) }
    }

    /// The card at the top: the ring and the countdown, or the ring and the next step, or the path complete.
    @ViewBuilder private func hero(_ door: Door, _ plan: PathPlan, _ checked: Set<Int>) -> some View {
        let progress = plan.progress(checked)
        let upcoming = plan.upcoming(today: now)
        let next = plan.next(checked)
        let sep = model.store.label("metaSeparator")
        Button {
            if let upcoming { model.push(.entity(upcoming.sourceId)) } else if let next { expanded.insert(next.order) }
        } label: {
            // at the accessibility sizes the ring sits above the words, so they keep the card's width
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 16))) {
                if progress.total > 0 { ProgressRing(done: progress.done, total: progress.total) }
                VStack(alignment: .leading, spacing: 4) {
                    if let upcoming, let days = PathPlan.days(from: now, to: upcoming.day) {
                        Text("\(upcoming.due.label) due").font(DS.caption).foregroundStyle(Palette.fg2)
                        Text(Countdown.text(days: days)).font(DS.countdown).foregroundStyle(Palette.fg)
                        Text(upcoming.due.stated(separator: sep)).font(DS.caption).foregroundStyle(Palette.fg2)
                    } else if let next {
                        Text("Next step").font(DS.caption).foregroundStyle(Palette.fg2)
                        Text(keepDesignations(next.title)).font(DS.heroStep).foregroundStyle(Palette.fg)
                        Text("Step \(next.order) of \(progress.total)" + (model.store.layerTag(next.layerId).map { "\(sep)\($0)" } ?? ""))
                            .font(DS.caption).foregroundStyle(Palette.fg2)
                    } else if progress.isComplete {
                        Text("Path complete").font(DS.caption).foregroundStyle(Palette.fg2)
                        Text(progress.total == 1 ? "The step is done" : "All \(progress.total) steps done").font(DS.heroStep).foregroundStyle(Palette.fg)
                    } else {
                        Text("No required path").font(DS.caption).foregroundStyle(Palette.fg2)
                        Text(Rules.firstSentence(door.paragraph.value ?? door.whoYouAre).first).font(DS.step).foregroundStyle(Palette.fg)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .card(radius: 16)
        }
        .buttonStyle(.plain)
        .disabled(upcoming == nil && next == nil)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("path-hero")
    }

    /// A trailhead with no ordered steps (Everyone Else): the rest of its paragraph and its two cases.
    @ViewBuilder private func noPath(_ door: Door) -> some View {
        let rest = Rules.firstSentence(door.paragraph.value ?? "").rest
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Where to start")
            if !rest.isEmpty {
                Text(rest).font(DS.step).foregroundStyle(Palette.fg).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).card(radius: 12)
            }
            ForEach(door.landings ?? [], id: \.id) { landing in
                VStack(alignment: .leading, spacing: 6) {
                    Text(TitleCase.apply(landing.label)).font(DS.nextTitle).foregroundStyle(Palette.fg)
                    Text(landing.text).font(DS.step).foregroundStyle(Palette.fg2).lineSpacing(2)
                    FlowLayout {
                        ForEach(names(landing.entityIds), id: \.id) { e in
                            Button { model.push(.entity(e.id)) } label: { Pill(text: e.name) }.buttonStyle(.plain)
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).card(radius: 12)
            }
        }
    }
}

/// One step: the check (its own 44-point control), the title, and, opened, the full step and the entries it names.
/// The next step is called out on the second surface with the section's outline, its layer and what it applies to.
struct StepRow: View {
    @Environment(AppModel.self) private var model
    let door: Door.ID
    let step: Door.Step
    let isDone: Bool
    let isNext: Bool
    let layer: String?

    /// The row as VoiceOver reads it: the title, and on the next step its layer and the line under the title.
    private var spokenTitle: String {
        guard isNext else { return step.title }
        let place: String = layer.map { ", " + $0 } ?? ""
        let line: String = step.when ?? names.map(\.name).joined(separator: model.store.label("listSeparator"))
        return "Next step\(place). \(step.title). \(line)"
    }
    let names: [(id: String, name: String)]
    let expanded: Bool
    let toggle: () -> Void
    let expand: () -> Void
    let open: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(action: toggle) {
                    Group {
                        if isDone {
                            DoneMark()
                        } else {
                            Icon(.circle, size: 24, color: isNext ? Palette.secMaps : Palette.fg2)  // the check's edge at 3:1 or more in both themes (R4)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(-10)
                .accessibilityLabel("Step \(step.order): \(step.title)")
                .accessibilityValue(isDone ? "Done" : "Not done")
                .accessibilityAddTraits(.isToggle)
                .accessibilityIdentifier("step-check-\(step.order)")

                Button(action: expand) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            if isNext {
                                Eyebrow(text: "Next" + (layer.map { model.store.label("metaSeparator") + $0 } ?? ""), small: true)
                            }
                            Text(keepDesignations(step.title))
                                .font(isNext ? DS.nextTitle : DS.step)
                                .foregroundStyle(isDone ? Palette.fg2 : Palette.fg)
                                .strikethrough(isDone, color: Palette.fg2)
                            if isNext {
                                Text(step.when ?? names.map(\.name).joined(separator: model.store.label("listSeparator")))
                                    .font(DS.caption).foregroundStyle(Palette.fg2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        // the mockup marks only the next step with a chevron; every row still opens in place
                        if isNext || expanded {
                            Icon(.chevronRight, size: 18, color: Palette.fg2)
                                .rotationEffect(.degrees(expanded ? 90 : 0))
                        }
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // VoiceOver reads what the row shows: on the next step, its layer and the line under the title too (R4)
                .accessibilityLabel(spokenTitle)
                .accessibilityValue(expanded ? "Expanded" : "Collapsed")
                .accessibilityHint("Shows the step in full")
                .accessibilityIdentifier("step-\(step.order)")
            }
            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(step.text).font(DS.step).foregroundStyle(Palette.fg).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .top, spacing: 8) {
                        FlowLayout {
                            ForEach(names, id: \.id) { e in
                                Button { open(e.id) } label: { Pill(text: e.name) }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("step-\(step.order)-entity-\(e.id)")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        ShareButton(subject: .step(door, step.order), compact: true)
                        BookmarkButton(item: .step(door, step.order), compact: true)
                    }
                }
                .padding(.leading, 36)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, isNext ? 14 : 2)
        .card(radius: 12, fill: isNext ? Palette.bg3 : Palette.bg2, stroke: isNext ? Palette.secMaps : Palette.line)
    }
}

/// What Changed (R3; MyPath.dc.html): the content releases' items newer than the reader's last view, newest first, at
/// most three here and every one in the Library's list. Each opens its entry's card; Clear marks them all seen.
struct WhatChanged: View {
    @Environment(AppModel.self) private var model
    let items: [Changes.Item]
    let door: Door
    static let shown = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: "What changed")
                Spacer()
                Button { model.clearChanges() } label: {
                    Text("Clear").font(DS.link).foregroundStyle(Palette.link).frame(minWidth: 44, minHeight: 44, alignment: .trailing).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, -12)
                .accessibilityLabel("Clear What Changed")
                .accessibilityHint("Marks these changes as seen")
                .accessibilityIdentifier("changes-clear")
            }
            ForEach(items.prefix(WhatChanged.shown)) { item in ChangeRow(item: item, door: door) }
            if items.count > WhatChanged.shown {
                Button { model.push(.changes) } label: { ResultRow(title: "See All Changes", trailing: true) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("changes-all")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("what-changed")
    }
}

/// One change: a dot, what changed, and its day with the steps it affects.
struct ChangeRow: View {
    @Environment(AppModel.self) private var model
    let item: Changes.Item
    let door: Door?
    var isNew = true

    var body: some View {
        Button { model.push(.entity(item.entityId)) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle().fill(isNew ? Palette.accent : Palette.lineStrong).frame(width: 8, height: 8).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(keepWhole(item.title)).font(DS.layerTitle).foregroundStyle(Palette.fg)
                    Text(keepWhole(Changes.line(item, door: door, store: model.store))).font(DS.caption).foregroundStyle(Palette.fg2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .card(radius: 12)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("change-\(item.id)")
    }
}

/// Every change the content carries, release by release (Library, Reference), with the reader's last view.
struct ChangesListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let changes = model.changes
        let fresh = Set(model.newChanges.map(\.id))
        let sep = model.store.label("metaSeparator")
        DetailScreen(title: "What Changed", identifier: "changes-screen") {
            Text(viewed).font(DS.note).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("changes-viewed")
            ForEach(changes.releases, id: \.release) { r in
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Content \(r.release)\(sep)\(Rules.formatDate(r.released))", tracked: false)
                    ForEach(Changes.newestFirst(r.items)) { item in ChangeRow(item: item, door: model.door, isNew: fresh.contains(item.id)) }
                }
            }
        }
    }

    private var viewed: String {
        let lead = "Changes to the map, newest release first. A dot marks what is new since you last cleared the list."
        guard let v = model.progress.state.changesViewed else { return lead }
        return lead + "\nLast cleared on \(unbroken(Rules.formatDate(v.on))), at content \(v.through)."
    }
}
