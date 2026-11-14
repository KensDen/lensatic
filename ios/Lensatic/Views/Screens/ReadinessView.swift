import SwiftUI

/// A readiness check (Lensatic 2.0, Round 1): one question for each of a framework's elements, three answers, and at
/// the end a short list of what to do next. It is a self-check and says so before the first question: the answers stay
/// in the progress file on this device, nobody sees them, and the result is not an assessment.
struct ReadinessView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let id: String

    var body: some View {
        let L = model.frameworks
        if let check = L.check(id), let f = L.byId[check.frameworkId], let graph = L.graphs[check.frameworkId] {
            let given = model.progress.answers(check.id)
            let result = check.result(given)
            ListScreen(eyebrow: L.label("selfCheck"), eyebrowColor: f.tone, title: check.title, identifier: "check-screen") {
                SwiftUI.Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(check.line).font(DS.style(.headline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                        Label {
                            Text(check.honest).font(DS.style(.subheadline)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "lock.iphone").foregroundStyle(f.tone).accessibilityHidden(true)
                        }
                        .accessibilityIdentifier("check-honest")
                    }
                    .padding(.vertical, 4)
                }
                SwiftUI.Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.label("answered").replacingOccurrences(of: "{n}", with: "\(result.answered)").replacingOccurrences(of: "{m}", with: "\(result.total)"))
                            .font(DS.style(.headline)).foregroundStyle(.primary)
                            .accessibilityIdentifier("check-answered")
                        ProgressView(value: Double(result.answered), total: Double(max(result.total, 1))).tint(f.tone).accessibilityHidden(true)
                        (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 14))) {
                            ForEach(check.answers) { a in
                                Text("\(result.counts[a.id] ?? 0) \(a.label)").font(DS.style(.footnote)).foregroundStyle(Palette.fg2)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("check-tally")
                    }
                    .padding(.vertical, 4)
                    // the next steps come after the questions, so an answer never moves the question under the finger
                    Text(L.label("nextAtEnd")).font(DS.style(.subheadline)).foregroundStyle(Palette.fg2)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    ListNote(L.label("whereYouStand"))
                } footer: {
                    ListNote(L.label("checkNotAssessment"))
                }
                // the questions, under the framework's top-level nodes, in the framework's order
                ForEach(graph.roots) { root in
                    let items = check.items.filter { graph.top(of: $0.nodeId) == root.id }
                    if !items.isEmpty {
                        SwiftUI.Section {
                            ForEach(items) { item in
                                ReadinessItemRow(check: check, item: item, framework: f, picked: given[item.id])
                            }
                        } header: {
                            ListNote("\(root.id) \(root.title ?? "")")
                        }
                    }
                }
                if result.answered > 0 {
                    SwiftUI.Section {
                        if result.next.isEmpty, result.isComplete {
                            Text(L.label("checkAllInPlace")).font(DS.style(.subheadline)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("check-all-in-place")
                        } else {
                            ForEach(Array(result.next.enumerated()), id: \.element.id) { i, item in
                                NavigationLink(value: Nav.node(f.id, item.nodeId)) {
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("\(i + 1)").font(DS.style(.headline)).foregroundStyle(f.tone).frame(minWidth: 18, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.next).font(DS.style(.body)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                                            NodeBadge(id: item.nodeId, tone: f.tone)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("check-next-\(item.id)")
                            }
                            if !result.isComplete {
                                Text(L.label("checkFinish")).font(DS.style(.footnote)).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } header: {
                        ListNote(L.label("doNext"))
                    }
                }
                if result.answered > 0 {
                    SwiftUI.Section {
                        Button { model.progress.clearAnswers(check.id) } label: {
                            Text(L.label("startOver")).font(DS.style(.body)).foregroundStyle(Palette.bad)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("check-start-over")
                    } footer: {
                        ListNote(L.label("checkKept"))
                    }
                }
            }
        }
    }
}

/// One question and its three answers. The answers are buttons at least 44 points tall, side by side where they fit and
/// one under the other at the accessibility sizes; the one picked is filled in the framework's colour and says so to
/// VoiceOver. Picking it again takes the answer back.
struct ReadinessItemRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let check: ReadinessCheck
    let item: ReadinessCheck.Item
    let framework: Framework
    let picked: String?

    var body: some View {
        let name = model.frameworks.graphs[framework.id]?.node(item.nodeId)?.title ?? item.nodeId
        VStack(alignment: .leading, spacing: 8) {
            // VoiceOver hears the element's name, not its code: the identifier is for the eye
            NodeBadge(id: item.nodeId, tone: framework.tone).accessibilityHidden(true)
            Text(item.question).font(DS.style(.body)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("\(name): \(item.question)")
                .accessibilityIdentifier("check-question-\(item.id)")
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))) {
                ForEach(check.answers) { a in
                    let on = picked == a.id
                    Button { model.progress.answer(check.id, item.id, a.id) } label: {
                        Text(a.label).font(DS.style(.subheadline).weight(.semibold))
                            .foregroundStyle(on ? Palette.bg2 : Color.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(on ? framework.tone : Palette.bg3, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(on ? framework.tone : Palette.line, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(a.label), \(name)")
                    .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
                    .accessibilityIdentifier("check-\(item.id)-\(a.id)")
                }
            }
        }
        .padding(.vertical, 4)
    }
}
