import Foundation

// The content model: Codable types that match content/schema/stack.schema.json. Decoded with `Strict`, so a missing
// or unknown field fails. A field the schema requires but lets be null is `Nullable`; a field the schema lets be
// absent is optional. Enumerated values are Swift enums, so an unknown value fails too.

struct Content: Decodable, Sendable {
    let meta: Meta
    let orgs: Orgs
    let layers: [Layer]
    let frameworks: [FrameworkEntry]
    let sources: [SourceEntry]
    let solutions: [SolutionEntry]
    let functions: [CSFFunction]
    let pillars: Pillars
    let matrix: Matrix
    let doors: [Door]
    let helper: [HelperEntry]
    let glossary: [GlossaryEntry]
    let ai: AIColumn
    let elevator: Elevator
    let ui: UIText
    let pages: Pages
}

struct Meta: Decodable, Sendable {
    let name: String
    let contentVersion: String
    let builtOn: String
    let sources: [String]
    let changelog: [ChangelogEntry]
    let description: String
    /// The pitch lines are for link previews, the README, the repository and the store listing: decoded, since the
    /// decoding is strict, and shown on no screen.
    let tagline: String
    let pitch: String
    let wayfinder: String
    let about: About
    let licenses: Licenses

    struct ChangelogEntry: Decodable, Sendable {
        let version: String
        let date: String
        let summary: String
    }

    struct About: Decodable, Sendable {
        let notAffiliated: String
        let offline: String
        let licensing: String
        let builtWith: String
        let nameStory: [String]?
    }

    struct Licenses: Decodable, Sendable {
        let code: License
        let content: License
        let fonts: License
    }

    struct License: Decodable, Sendable {
        let name: String
        let spdx: String
        let file: String
        let url: String
        let covers: [String]
    }
}

struct Orgs: Decodable, Sendable {
    let dow: Department
    let cisa: Org
    let nist: Org
    let nsa: Org
    let omb: Org
    let ztPfmo: Office

    struct Department: Decodable, Sendable {
        let current: String
        let abbr: String
        let statutory: String
        let basis: String
        let verifiedOn: String
        let renderRule: String
        let statusNote: String
        let url: String
        let verification: Verification

        /// The fields a `{{dow.<field>}}` token can name, as the web build reads them.
        var fields: [String: String] {
            ["current": current, "abbr": abbr, "statutory": statutory, "basis": basis, "verifiedOn": verifiedOn,
             "renderRule": renderRule, "statusNote": statusNote, "url": url]
        }
    }

    struct Org: Decodable, Sendable {
        let name: String
        let abbr: String
        let url: String
    }

    struct Office: Decodable, Sendable {
        let name: String
        let abbr: String
        let url: String
        let established: String
        let role: String
        let verification: Verification
    }
}

/// A verification record: either a check against the publisher (verified, unverified, conflict) or the app's own
/// synthesis (authored), the schema's two shapes. Each shape is held to its own fields.
struct Verification: Decodable, Sendable {
    enum Status: String, Decodable, Sendable, CaseIterable {
        case verified, authored, unverified, conflict
    }

    let status: Status
    let verifiedOn: String?
    let method: String
    let note: String
    let recheckAfter: String?
    let basisIds: [String]?

    private enum CodingKeys: String, CodingKey {
        case status, verifiedOn, method, note, recheckAfter, basisIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try c.decode(Status.self, forKey: .status)
        verifiedOn = try c.decode(Nullable<String>.self, forKey: .verifiedOn).value
        method = try c.decode(String.self, forKey: .method)
        note = try c.decode(String.self, forKey: .note)
        if status == .authored {
            basisIds = try c.decode([String].self, forKey: .basisIds)
            recheckAfter = nil
            guard !c.contains(.recheckAfter), method == "synthesis", verifiedOn == nil, !(basisIds ?? []).isEmpty else {
                throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "an authored record has basisIds, method synthesis, a null verifiedOn and no recheckAfter"))
            }
        } else {
            basisIds = nil
            recheckAfter = c.contains(.recheckAfter) ? try c.decode(Nullable<String>.self, forKey: .recheckAfter).value : nil
            guard !c.contains(.basisIds), ["primary-fetch", "none"].contains(method) else {
                throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "a checked record has no basisIds and method primary-fetch or none"))
            }
        }
    }
}

/// A verification field the schema limits to the app's own synthesis (authoredRecord): any other shape fails.
struct Authored: Decodable, Sendable {
    let record: Verification

    init(from decoder: Decoder) throws {
        record = try Verification(from: decoder)
        guard record.status == .authored else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "an authored record is required here"))
        }
    }
}

/// A field the schema allows only as null (the elevator's text: nothing is hand-written).
struct JSONNull: Decodable, Sendable {
    init(from decoder: Decoder) throws {
        guard try decoder.singleValueContainer().decodeNil() else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "must be null"))
        }
    }
}

struct Authority: Decodable, Sendable {
    enum Nature: String, Decodable, Sendable {
        case mandate, strategy, model, definition, catalog, overlay, assessment, guidance, service
    }

    enum Binds: String, Decodable, Sendable {
        case federalCivilian = "federal-civilian", dowComponents = "dow-components"
        case defenseContractorsCUI = "defense-contractors-cui", defenseContractorsFCICUI = "defense-contractors-fci-cui"
        case voluntaryAll = "voluntary-all", adopters
    }

    struct Deadline: Decodable, Sendable {
        let text: String
        let sourceId: String
    }

    let nature: Nature
    let binds: [Binds]
    let deadline: Nullable<Deadline>
    let note: String
    let verification: Verification
}

struct Document: Decodable, Sendable {
    let title: String
    let edition: String
    let date: String
    let url: String
    let verification: Verification
    let note: String?
    let authors: [String]?
}

struct Layer: Decodable, Sendable {
    let id: String
    let order: Int
    let name: String
    let question: String
    let oneLiner: String
    let frameworkIds: [String]
    let isColumn: Bool
}

/// A framework, a source or a solution: the three share one shape on screen, but the schema gives each its own
/// fields, so each decodes through its own entry type and is held to them.
struct Entity: Sendable {
    enum Kind: Sendable { case framework, source, solution }

    struct ValidatedAgainst: Decodable, Sendable {
        let entityId: String
        let scope: String
        let date: String
        let verification: Verification
    }

    struct Responsibility: Decodable, Sendable {
        let text: String
        let verification: Verification
    }

    let kind: Kind
    let id: String
    let layerId: String?
    let name: String
    let shortName: String
    let oneLiner: String
    let answersQuestion: String?
    let role: String?
    let publisher: String
    let title: String
    let edition: String
    let date: String
    let url: String
    let verification: Verification
    let authority: Authority
    let documents: [Document]?
    let note: String?
    let authors: [String]?
    let license: String?
    let attributionRequired: Bool?
    let validatedAgainst: ValidatedAgainst?
    let adopterResponsibilities: [Responsibility]?

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case id, layerId, name, shortName, oneLiner, answersQuestion, role, publisher, title, edition, date, url
        case verification, authority, documents, note, authors, license, attributionRequired, validatedAgainst, adopterResponsibilities
    }

    /// The fields each kind may carry, and the ones it must.
    private static let allowed: [Kind: Set<CodingKeys>] = {
        let common: Set<CodingKeys> = [.id, .name, .shortName, .oneLiner, .publisher, .title, .edition, .date, .url, .verification,
                                       .authority, .documents, .note, .authors, .license, .attributionRequired]
        return [.framework: common.union([.layerId, .answersQuestion]),
                .source: common.union([.role, .layerId]),
                .solution: common.union([.layerId, .answersQuestion, .validatedAgainst, .adopterResponsibilities])]
    }()

    private static let required: [Kind: Set<CodingKeys>] = [
        .framework: [.layerId, .answersQuestion], .source: [.role],
        .solution: [.layerId, .answersQuestion, .validatedAgainst, .adopterResponsibilities],
    ]

    fileprivate init(from decoder: Decoder, kind: Kind) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let allowed = Entity.allowed[kind] ?? []
        if let extra = c.allKeys.first(where: { !allowed.contains($0) }) {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath + [extra], debugDescription: "field \"\(extra.stringValue)\" is not allowed here"))
        }
        if let missing = (Entity.required[kind] ?? []).first(where: { !c.contains($0) }) {
            throw DecodingError.keyNotFound(missing, .init(codingPath: c.codingPath, debugDescription: "missing field \"\(missing.stringValue)\""))
        }
        let required = Entity.required[kind] ?? []
        func must(_ key: CodingKeys) -> Bool { required.contains(key) }
        self.kind = kind
        id = try c.decode(String.self, forKey: .id)
        layerId = must(.layerId) ? try c.decode(String.self, forKey: .layerId) : try c.decodeIfPresent(String.self, forKey: .layerId)
        name = try c.decode(String.self, forKey: .name)
        shortName = try c.decode(String.self, forKey: .shortName)
        oneLiner = try c.decode(String.self, forKey: .oneLiner)
        answersQuestion = must(.answersQuestion) ? try c.decode(String.self, forKey: .answersQuestion) : nil
        role = must(.role) ? try c.decode(String.self, forKey: .role) : nil
        publisher = try c.decode(String.self, forKey: .publisher)
        title = try c.decode(String.self, forKey: .title)
        edition = try c.decode(String.self, forKey: .edition)
        date = try c.decode(String.self, forKey: .date)
        url = try c.decode(String.self, forKey: .url)
        verification = try c.decode(Verification.self, forKey: .verification)
        authority = try c.decode(Authority.self, forKey: .authority)
        documents = try c.decodeIfPresent([Document].self, forKey: .documents)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        authors = try c.decodeIfPresent([String].self, forKey: .authors)
        license = try c.decodeIfPresent(String.self, forKey: .license)
        attributionRequired = try c.decodeIfPresent(Bool.self, forKey: .attributionRequired)
        validatedAgainst = must(.validatedAgainst) ? try c.decode(ValidatedAgainst.self, forKey: .validatedAgainst) : nil
        adopterResponsibilities = must(.adopterResponsibilities) ? try c.decode([Responsibility].self, forKey: .adopterResponsibilities) : nil
    }

    /// Every verification record inside the entry other than its own, as the web's conflict badge reads them.
    var innerVerifications: [Verification] {
        var out = [authority.verification]
        out += (documents ?? []).map(\.verification)
        if let v = validatedAgainst { out.append(v.verification) }
        out += (adopterResponsibilities ?? []).map(\.verification)
        return out
    }
}

struct FrameworkEntry: Decodable, Sendable {
    let entity: Entity
    init(from decoder: Decoder) throws { entity = try Entity(from: decoder, kind: .framework) }
}

struct SourceEntry: Decodable, Sendable {
    let entity: Entity
    init(from decoder: Decoder) throws { entity = try Entity(from: decoder, kind: .source) }
}

struct SolutionEntry: Decodable, Sendable {
    let entity: Entity
    init(from decoder: Decoder) throws { entity = try Entity(from: decoder, kind: .solution) }
}

enum FunctionID: String, Decodable, Sendable, CaseIterable {
    case GV, ID, PR, DE, RS, RC
}

struct CSFFunction: Decodable, Sendable {
    struct Category: Decodable, Sendable {
        let code: String
        let name: String
    }

    let id: FunctionID
    let name: String
    let question: String
    let categories: [Category]
    let ztLanding: String
}

struct Pillars: Decodable, Sendable {
    struct Views: Decodable, Sendable {
        struct CISA: Decodable, Sendable {
            let pillars: [String]
            let crossCutting: [String]
        }

        let dow: [String]
        let cisa: CISA
    }

    let canonical: [Pillar]
    let views: Views
}

struct Pillar: Decodable, Sendable {
    enum CisaKind: String, Decodable, Sendable { case pillar, crossCutting }

    struct Capability: Decodable, Sendable {
        let id: String
        let name: String
    }

    let id: String
    let name: String
    let dowName: Nullable<String>
    let cisaName: Nullable<String>
    let cisaKind: Nullable<CisaKind>
    let mapping: String
    let capabilities: [Capability]?
}

struct Matrix: Decodable, Sendable {
    struct Cell: Decodable, Sendable {
        let pillarId: String
        let functionId: FunctionID
        let text: String
        let categories: [String]
        let verification: Verification
        let capabilityIds: [String]?
    }

    let cells: [Cell]
}

enum PillarView: String, Decodable, Sendable, Hashable, CaseIterable {
    case dow, cisa
}

struct Door: Decodable, Sendable {
    enum ID: String, Decodable, Sendable {
        case federalCivilian = "federal-civilian", dow, defenseContractor = "defense-contractor", other
    }

    struct Step: Decodable, Sendable {
        let order: Int
        let layerId: String
        let entityIds: [String]
        let text: String
        let verification: Authored
    }

    struct Landing: Decodable, Sendable {
        let id: String
        let label: String
        let text: String
        let entityIds: [String]
        let verification: Authored
    }

    let id: ID
    let title: String
    let whoYouAre: String
    let steps: [Step]
    let pillarView: Nullable<PillarView>
    let paragraph: Nullable<String>
    let verification: Authored
    let landings: [Landing]?
}

struct HelperEntry: Decodable, Sendable {
    let id: String
    let question: String
    let answer: String
    let layerId: String
    let entityIds: [String]
    let verification: Authored
}

struct GlossaryEntry: Decodable, Sendable {
    let term: String
    let forms: [String]
    let prefix: Bool?
    let notAbbreviation: Bool?
    let wellKnown: Bool?
    let expansion: Nullable<String>
    let oneLine: String
    let entityIds: [String]
    let verification: Verification
}

struct AIColumn: Decodable, Sendable {
    struct Item: Decodable, Sendable {
        enum Kind: String, Decodable, Sendable {
            case framework, quickStartGuide = "quick-start-guide", governance
        }

        let id: String
        let kind: Kind
    }

    struct SocRow: Decodable, Sendable {
        let functionId: FunctionID
        let outcome: String
        let verification: Authored
    }

    let column: [Item]
    let socProfile: [SocRow]
    let note: String
}

struct Elevator: Decodable, Sendable {
    let derivedFrom: String
    let omits: [String]
    let frameworkIds: [String]
    let text: JSONNull
}

struct UIText: Decodable, Sendable {
    let sections: [String: String]
    let nav: [String: String]
    let labels: [String: String]
    let binds: [String: String]
    let nature: [String: String]
    let status: [String: String]
    let kind: [String: String]
}

struct Pages: Decodable, Sendable {
    struct Page: Decodable, Sendable {
        let title: String
        let description: String
        let paragraphs: [String]
    }

    let privacy: Page
    let support: Page
}
