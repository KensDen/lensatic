import LinkPresentation
import SwiftUI
import UIKit

/// The share card (R3): a clean image of a framework card or a step, drawn from the same content as the screen, with
/// the source link beside it in the share sheet. The image is made on the device when the reader taps Share and goes
/// only where they send it.
struct ShareCard: View {
    enum Subject: Hashable, Sendable {
        case entity(String)
        case step(Door.ID, Int)
    }

    struct Face: Sendable, Equatable {
        let eyebrow: String
        let title: String
        let body: String
        let facts: [(label: String, value: String)]
        let source: String
        let url: URL?

        static func == (a: Face, b: Face) -> Bool {
            a.eyebrow == b.eyebrow && a.title == b.title && a.body == b.body && a.source == b.source && a.url == b.url
                && a.facts.map(\.label) == b.facts.map(\.label) && a.facts.map(\.value) == b.facts.map(\.value)
        }
    }

    let face: Face
    /// The width the image is drawn at, in points; the image is three times that in pixels.
    static let width: CGFloat = 360

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Icon(.compass, size: 18, color: Palette.secGuides, lineWidth: 2.2)
                Text("Lensatic").font(DS.caption).foregroundStyle(Palette.fg2)
            }
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: face.eyebrow, small: true).fixedSize(horizontal: false, vertical: true)
                // the last two words kept together, so the title never ends on one word (nit 2)
                Text(keepWhole(ShareCard.lastTwoTogether(face.title))).font(DS.cardTitle).foregroundStyle(Palette.fg).fixedSize(horizontal: false, vertical: true)
            }
            Text(keepWhole(face.body)).font(DS.summary).foregroundStyle(Palette.fg).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            if !face.facts.isEmpty {
                // the card's own tile row (nit 3): each tile sized to its value, none breaking a word
                StatTileRow {
                    ForEach(Array(face.facts.enumerated()), id: \.offset) { _, f in StatTile(label: f.label, value: f.value) }
                }
            }
            Rectangle().fill(Palette.line).frame(height: 1)
            Text(face.source).font(DS.caption).foregroundStyle(Palette.fg2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(width: ShareCard.width, alignment: .leading)
        .background(Palette.bg2)
        .overlay(alignment: .top) { Rectangle().fill(Palette.secMaps).frame(height: 4) }
        .environment(\.colorScheme, .dark)
        .environment(\.dynamicTypeSize, .large)
    }

    /// What the card shows for a subject, from the content: an entry's layer and kind, name, short summary, what binds
    /// and when it is due, and its publisher and address; a step's place on the path, title, text and source.
    @MainActor static func face(_ subject: Subject, model: AppModel) -> Face? {
        let store = model.store
        let sep = store.label("metaSeparator")
        switch subject {
        case .entity(let id):
            guard let e = store.entities[id] else { return nil }
            let facts = EntityFacts(e, store: store)
            return Face(eyebrow: facts.eyebrow, title: e.displayName, body: e.shortSummary,
                        facts: [(store.label("binds"), facts.binds), ("Due", facts.due), ("Type", facts.type)],
                        source: [e.publisher, URL(string: e.url).flatMap(host)].compactMap { $0 }.joined(separator: sep), url: URL(string: e.url))
        case .step(let d, let order):
            guard let door = model.door(d), let step = door.steps.first(where: { $0.order == order }) else { return nil }
            let first = step.entityIds.first.flatMap { store.entities[$0] }
            return Face(eyebrow: "Step \(order) of \(door.steps.count)\(sep)\(door.shortTitle)", title: step.title,
                        body: step.text, facts: [],
                        source: [first?.displayName, first.flatMap { URL(string: $0.url) }.flatMap(host)].compactMap { $0 }.joined(separator: sep),
                        url: first.flatMap { URL(string: $0.url) })
        }
    }

    static func lastTwoTogether(_ s: String) -> String {
        guard let r = s.range(of: " ", options: .backwards) else { return s }
        return s.replacingCharacters(in: r, with: "\u{00A0}")
    }

    static func host(_ url: URL) -> String? { url.host().map { $0.hasPrefix("www.") ? String($0.dropFirst(4)) : $0 } }

    /// The card as an image, three pixels to the point.
    @MainActor static func image(_ face: Face) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCard(face: face))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return renderer.uiImage
    }

    /// Share a subject: its card's image and its source link, through the system share sheet over whatever is on top.
    @MainActor static func share(_ subject: Subject, model: AppModel) {
        guard let face = face(subject, model: model), let top = Reader.topController() else { return }
        let image = image(face)
        // each item brings its own preview (the card's title and image), so the share sheet never fetches the source's
        // address to build one: sharing makes no network request
        let meta = LPLinkMetadata()
        meta.title = face.title
        meta.originalURL = face.url
        meta.url = face.url
        if let image { meta.imageProvider = NSItemProvider(object: image); meta.iconProvider = NSItemProvider(object: image) }
        // the image's own preview names the card and carries no address, so the sheet reads it as an image and a link
        let card = LPLinkMetadata()
        card.title = face.title
        if let image { card.imageProvider = NSItemProvider(object: image) }
        var items: [Any] = []
        if let image { items.append(ShareItem(item: image, meta: card)) }
        if let url = face.url { items.append(ShareItem(item: url, meta: meta)) }
        let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = top.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
        top.present(sheet, animated: !UIAccessibility.isReduceMotionEnabled)
    }
}

/// The share button on a card or a step: a round control, as the bookmark beside it.
struct ShareButton: View {
    @Environment(AppModel.self) private var model
    let subject: ShareCard.Subject
    var compact = false

    var body: some View {
        Button { ShareCard.share(subject, model: model) } label: {
            if compact {
                Icon(.share, size: 20, color: Palette.fg).frame(width: 44, height: 44).contentShape(Rectangle())
            } else {
                CircleIconLabel(icon: .share)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share")
        .accessibilityHint("Shares a card image and the source link")
        .accessibilityIdentifier("share")
    }
}

/// One thing in the share sheet, with the preview the app made for it.
final class ShareItem: NSObject, UIActivityItemSource {
    let item: Any
    let meta: LPLinkMetadata

    init(item: Any, meta: LPLinkMetadata) {
        self.item = item
        self.meta = meta
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any { item }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? { item }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? { meta }
}
