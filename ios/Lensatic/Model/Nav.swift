import Foundation

/// The tabs (the brief's information architecture): My Path, Explore, Search, Library.
enum AppTab: String, CaseIterable, Hashable, Sendable {
    case path, explore, search, library

    var title: String {
        switch self {
        case .path: return "My Path"
        case .explore: return "Explore"
        case .search: return "Search"
        case .library: return "Library"
        }
    }

    var icon: IconName {
        switch self {
        case .path: return .compass
        case .explore: return .layers
        case .search: return .search
        case .library: return .library
        }
    }
}

/// One screen pushed inside a tab (the redesign, R2): an entry's card, a layer, a cell of the matrix, the Library's
/// reference screens, the guide and its chapters, the plays and one play, the saved list.
enum Nav: Hashable, Sendable {
    case entity(String)
    case layer(String)
    case cell(PillarView, String, FunctionID)
    case glossary
    case sources
    case about
    case saved
    case guide
    case chapter(String)
    case plays
    case play(String)
    case changes

    /// The screen as the parts of an address (Target.url), and back.
    var pathParts: [String] {
        switch self {
        case .entity(let id): return ["entity", id]
        case .layer(let id): return ["layer", id]
        case .cell(let v, let p, let f): return ["cell", v.rawValue, p, f.rawValue]
        case .glossary: return ["glossary-list"]
        case .sources: return ["sources"]
        case .about: return ["about"]
        case .saved: return ["saved"]
        case .guide: return ["guide"]
        case .chapter(let id): return ["chapter", id]
        case .plays: return ["plays"]
        case .play(let id): return ["play", id]
        case .changes: return ["changes"]
        }
    }

    init?(pathParts parts: [String]) {
        switch (parts.first, parts.count) {
        case ("entity", 2): self = .entity(parts[1])
        case ("layer", 2): self = .layer(parts[1])
        case ("cell", 4):
            guard let v = PillarView(rawValue: parts[1]), let f = FunctionID(rawValue: parts[3]) else { return nil }
            self = .cell(v, parts[2], f)
        case ("glossary-list", 1): self = .glossary
        case ("sources", 1): self = .sources
        case ("about", 1): self = .about
        case ("saved", 1): self = .saved
        case ("guide", 1): self = .guide
        case ("chapter", 2): self = .chapter(parts[1])
        case ("plays", 1): self = .plays
        case ("play", 2): self = .play(parts[1])
        case ("changes", 1): self = .changes
        default: return nil
        }
    }

    /// The tab a screen lives under when it is opened from elsewhere (iOS search, a saved item, a link).
    var home: AppTab {
        switch self {
        case .entity, .layer, .cell: return .explore
        case .glossary, .sources, .about, .saved, .guide, .chapter, .plays, .play, .changes: return .library
        }
    }
}

/// Explore's three views of the map.
enum ExploreMode: String, CaseIterable, Hashable, Sendable {
    case stack, matrix, functions
}
