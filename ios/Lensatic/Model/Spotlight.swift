import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// The app's entries, the reader's steps and the plays in iOS search (the redesign, R2). The index lives on the device:
/// Core Spotlight keeps it in the system's own on-device index, nothing is sent anywhere, and only the app's published
/// content is indexed, never what the reader checked or saved. Each item's identifier is the key a saved item uses
/// (entity:id, step:door:order, play:id), so a tap in iOS search opens the same screen a saved item does.
enum Spotlight {
    static let entities = "entities", steps = "steps", plays = "plays"

    struct Entry: Sendable, Equatable {
        let id: String
        let domain: String
        let title: String
        let detail: String
        let keywords: [String]
    }

    /// What the index holds for this content and this trailhead: every entry, the trailhead's steps and every play.
    static func entries(store: ContentStore, library: Library, door: Door?) -> [Entry] {
        var out: [Entry] = []
        for e in store.frameworks + store.sources + store.solutions {
            out.append(Entry(id: SavedItem.entity(e.id).key, domain: entities, title: e.displayName, detail: e.shortSummary,
                             keywords: [e.shortName, e.publisher]))
        }
        if let door {
            for s in door.steps {
                out.append(Entry(id: SavedItem.step(door.id, s.order).key, domain: steps, title: s.title, detail: door.shortTitle,
                                 keywords: s.entityIds.compactMap { store.entities[$0]?.shortName }))
            }
        }
        for g in library.plays.groups {
            for p in library.plays(in: g) {
                out.append(Entry(id: SavedItem.play(p.id).key, domain: plays, title: p.name, detail: p.subtitle, keywords: [g.label, p.title]))
            }
        }
        return out
    }

    /// Replace the app's items in the on-device index with these. The steps are replaced whole, so a change of
    /// trailhead leaves no step of the last one behind.
    static func index(_ entries: [Entry]) {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [entities, steps, plays]) { _ in
            CSSearchableIndex.default().indexSearchableItems(entries.map(item)) { _ in }
        }
    }

    static func item(_ e: Entry) -> CSSearchableItem {
        let set = CSSearchableItemAttributeSet(contentType: .text)
        set.title = e.title
        set.contentDescription = e.detail
        set.keywords = e.keywords
        return CSSearchableItem(uniqueIdentifier: e.id, domainIdentifier: e.domain, attributeSet: set)
    }
}
