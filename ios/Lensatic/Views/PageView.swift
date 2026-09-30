import SwiftUI

/// Draws any page. Links inside text carry their target as an internal address (see `Target.url`): the page's
/// `openURL` action follows internal ones in the app and hands outside ones to the system browser.
struct PageView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var systemOpen
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let page: Page

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(page.blocks.enumerated()), id: \.offset) { i, block in
                        BlockView(kind: block.kind, act: { act($0, proxy) })
                            .id(block.anchor ?? "block-\(i)")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.bg)
            .hardTopEdge()
            .accessibilityIdentifier("page")
            .environment(\.openURL, OpenURLAction { url in
                guard let target = Target(url: url) else { return .discarded }
                if case .external = target { return .systemAction }
                act(target, proxy)
                return .handled
            })
            .onAppear { scrollToPending(proxy) }
            .onChange(of: model.pendingAnchor) { scrollToPending(proxy) }
        }
    }

    /// A heading the reader was sent to (Why the name, a glossary entry): scroll to it once this page is laid out.
    private func scrollToPending(_ proxy: ScrollViewProxy) {
        guard let anchor = model.pendingAnchor, page.blocks.contains(where: { $0.anchor == anchor }) || pageHolds(anchor) else { return }
        model.pendingAnchor = nil
        DispatchQueue.main.async { proxy.scrollTo(anchor, anchor: .top) }
    }

    /// Anchors inside a block (the glossary's entries).
    private func pageHolds(_ anchor: String) -> Bool {
        page.blocks.contains { block in
            if case .glossary(let items) = block.kind { return items.contains { $0.anchor == anchor } }
            return false
        }
    }

    private func act(_ target: Target, _ proxy: ScrollViewProxy) {
        switch target {
        case .anchor(let id):
            if reduceMotion {
                proxy.scrollTo(id, anchor: .top)
            } else {
                withAnimation { proxy.scrollTo(id, anchor: .top) }
            }
        case .external(let url):
            systemOpen(url)
        default:
            model.go(target)
        }
    }
}

/// One block of a page.
struct BlockView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The gap between the eyebrow's phrases: a space in its face, at any text size.
    @ScaledMetric(relativeTo: .footnote) private var eyebrowGap: CGFloat = 8
    let kind: BlockKind
    let act: (Target) -> Void

    var body: some View {
        switch kind {
        case .sectionHead(let number, let title):
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(number.text).font(Typo.secNum).foregroundStyle(Palette.accent).accessibilityHidden(true)
                    RunText(run: title, style: .body, font: Typo.sectionTitle).accessibilityAddTraits(.isHeader)
                }
                Rectangle().fill(Palette.line).frame(height: 1).accessibilityHidden(true)
            }
        case .hero(let eyebrow, let name, let lede):
            VStack(alignment: .leading, spacing: 10) {
                // the eyebrow's phrases wrap only between each other, never inside one, unless a phrase alone is wider than
                // the screen (session 11, REX-04); VoiceOver reads the line as one
                Flow(spacing: eyebrowGap, lineSpacing: 2) {
                    ForEach(Array(eyebrow.enumerated()), id: \.offset) { _, phrase in
                        RunText(run: phrase, style: .small, font: Typo.eyebrow, color: Palette.accent).textCase(.uppercase)
                    }
                }
                .accessibilityElement(children: .combine)
                RunText(run: name, style: .body, font: Typo.heroName).accessibilityAddTraits(.isHeader)
                RunText(run: lede, style: .lede, color: Palette.fg2)
            }
        case .title(let run):
            RunText(run: run, style: .body, font: Typo.title, mono: Typo.titleMono).accessibilityAddTraits(.isHeader)
        case .heading(let run):
            RunText(run: run, style: .body, font: Typo.heading).accessibilityAddTraits(.isHeader).padding(.top, 4)
        case .text(let run, let style):
            TextBlock(run: run, style: style)
        case .controls(let controls):
            Flow(spacing: 10) {
                ForEach(Array(controls.enumerated()), id: \.offset) { _, c in
                    ControlButton(control: c, act: act)
                }
            }
        case .versionLine(let version, let joiner, let line, let why):
            // each link is a full-size target, but the line wraps as running text: the pieces are laid out by their text,
            // so a wrapped line sits one line below the last, and each link's 44-point target reaches past its text into
            // the space around it, never over the other link's (LinkLine; session 11, EX-009). The comma stays with the
            // version, so a narrow screen breaks the line after the comma, never before it; Why the name? keeps with the
            // text before it.
            LinkLine(spacing: 7, lineSpacing: 2) {
                HStack(alignment: .center, spacing: 0) {
                    TapTarget() { ControlButton(control: version, act: act, plain: true) }
                    Text(verbatim: joiner).font(Typo.stamp).foregroundStyle(Palette.fg2).accessibilityHidden(true)
                }
                .layoutValue(key: LinkLineTarget.self, value: true)
                RunText(run: line, style: .small, font: Typo.stamp, color: Palette.fg2)
                TapTarget() { ControlButton(control: why, act: act, plain: true) }
                    .layoutValue(key: LinkLineTarget.self, value: true)
                    .layoutValue(key: LinkLineKeep.self, value: true)
            }
            .padding(.vertical, 12)
        case .chips(let chips):
            Flow(spacing: 8) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                    ChipView(chip: chip, act: act)
                }
            }
        case .rows(let rows):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    RowView(row: row, act: act)
                }
            }
        case .steps(let steps):
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    StepView(number: i + 1, step: step, act: act)
                }
            }
        case .tagLine(let tag, let run):
            Flow(spacing: 8) {
                ControlButton(control: tag, act: act, tag: true)
                if let run { RunText(run: run, style: .small, color: Palette.fg2) }
            }
        case .keyValues(let items):
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, kv in
                    KeyValueView(kv: kv)
                }
            }
        case .bullets(let runs):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(runs.enumerated()), id: \.offset) { _, run in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").font(Typo.rowLine).foregroundStyle(Palette.fg2).accessibilityHidden(true)
                        RunText(run: run, style: .small)
                    }
                }
            }
        case .badges(let badges):
            Flow(spacing: 6) {
                ForEach(Array(badges.enumerated()), id: \.offset) { _, b in BadgeView(badge: b) }
            }
        case .statusKey(let title, let rows):
            VStack(alignment: .leading, spacing: 8) {
                RunText(run: title, style: .small)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 4) {
                        BadgeView(badge: row.0)
                        RunText(run: row.1, style: .small, color: Palette.fg2)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        case .glossary(let items):
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    GlossaryItemView(item: item).id(item.anchor)
                }
            }
        case .disclosures(let items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, d in DisclosureView(item: d) }
            }
        case .pillarViews(let controls, let selected):
            PillarViewPicker(controls: controls, selected: selected)
        case .links(let controls):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(controls.enumerated()), id: \.offset) { _, c in
                    if case .external(let url) = c.target {
                        Link(destination: url) {
                            Text(c.label.text).font(Typo.button).frame(minHeight: 44, alignment: .leading)
                        }
                        .accessibilityIdentifier(c.identifier)
                    }
                }
            }
        case .aboutHeader(let name, let version):
            HStack(alignment: .center, spacing: 12) {
                MarkImage()
                RunText(run: name, style: .body, font: Typo.title)
                Text(version.text).font(Typo.stamp).foregroundStyle(Palette.fg2)
            }
            .accessibilityElement(children: .combine)
        case .story(let heading, let alt, let paragraphs):
            StoryView(heading: heading, alt: alt, paragraphs: paragraphs)
        case .group(let blocks):
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in
                    BlockView(kind: b.kind, act: act)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line))
        }
    }
}
