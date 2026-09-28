import Foundation

/// Strict decoding: every field a type declares must be present unless the type says it is optional, an optional
/// field is absent or a value but never null, and any field the type does not declare fails decoding, at every level
/// of the tree. A field the schema requires but lets be null is `Nullable`. Wraps the JSON decoder's own decoder, so the
/// model types keep their synthesized `Decodable` conformances.
enum Strict {
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(Box<T>.self, from: data).value
    }

    private struct Box<T: Decodable>: Decodable {
        let value: T
        init(from decoder: Decoder) throws {
            value = try T(from: StrictDecoder(base: decoder))
        }
    }
}

/// A field the schema requires but allows to be null: the key must be present, and its value is either null or a `T`.
enum Nullable<T: Decodable & Sendable>: Decodable, Sendable {
    case null
    case value(T)

    init(from decoder: Decoder) throws {
        if try decoder.singleValueContainer().decodeNil() {
            self = .null
        } else {
            self = .value(try T(from: decoder))
        }
    }

    var value: T? {
        if case .value(let v) = self { return v }
        return nil
    }
}

struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

struct StrictDecoder: Decoder {
    let base: Decoder
    var codingPath: [CodingKey] { base.codingPath }
    var userInfo: [CodingUserInfoKey: Any] { base.userInfo }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        // a key the target cannot name is a field the model does not have; dictionaries name every key
        for key in try base.container(keyedBy: AnyKey.self).allKeys where Key(stringValue: key.stringValue) == nil {
            throw DecodingError.dataCorrupted(.init(codingPath: codingPath + [key], debugDescription: "unknown field \"\(key.stringValue)\""))
        }
        return KeyedDecodingContainer(StrictKeyed<Key>(base: try base.container(keyedBy: type), decoder: self))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        StrictUnkeyed(base: try base.unkeyedContainer())
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        StrictSingle(base: try base.singleValueContainer(), decoder: base)
    }
}

private struct StrictKeyed<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K
    let base: KeyedDecodingContainer<K>
    let decoder: StrictDecoder

    var codingPath: [CodingKey] { base.codingPath }
    var allKeys: [K] { base.allKeys }
    func contains(_ key: K) -> Bool { base.contains(key) }
    func decodeNil(forKey key: K) throws -> Bool { try base.decodeNil(forKey: key) }
    func decode(_ type: Bool.Type, forKey key: K) throws -> Bool { try base.decode(type, forKey: key) }
    func decode(_ type: String.Type, forKey key: K) throws -> String { try base.decode(type, forKey: key) }
    func decode(_ type: Double.Type, forKey key: K) throws -> Double { try base.decode(type, forKey: key) }
    func decode(_ type: Float.Type, forKey key: K) throws -> Float { try base.decode(type, forKey: key) }
    func decode(_ type: Int.Type, forKey key: K) throws -> Int { try base.decode(type, forKey: key) }
    func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 { try base.decode(type, forKey: key) }
    func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 { try base.decode(type, forKey: key) }
    func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 { try base.decode(type, forKey: key) }
    func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 { try base.decode(type, forKey: key) }
    func decode(_ type: UInt.Type, forKey key: K) throws -> UInt { try base.decode(type, forKey: key) }
    func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 { try base.decode(type, forKey: key) }
    func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 { try base.decode(type, forKey: key) }
    func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 { try base.decode(type, forKey: key) }
    func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 { try base.decode(type, forKey: key) }

    /// An optional field: absent is nil, but null is not a value the schema allows for it.
    private func present(_ key: K) throws -> Bool {
        guard base.contains(key) else { return false }
        if try base.decodeNil(forKey: key) {
            throw DecodingError.valueNotFound(Any.self, .init(codingPath: codingPath + [key], debugDescription: "null for the optional field \"\(key.stringValue)\""))
        }
        return true
    }

    func decodeIfPresent(_ type: Bool.Type, forKey key: K) throws -> Bool? { try present(key) ? decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: String.Type, forKey key: K) throws -> String? { try present(key) ? decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: Double.Type, forKey key: K) throws -> Double? { try present(key) ? decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: Float.Type, forKey key: K) throws -> Float? { try present(key) ? decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: Int.Type, forKey key: K) throws -> Int? { try present(key) ? decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: Int8.Type, forKey key: K) throws -> Int8? { try present(key) ? decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: Int16.Type, forKey key: K) throws -> Int16? { try present(key) ? decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: Int32.Type, forKey key: K) throws -> Int32? { try present(key) ? decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: Int64.Type, forKey key: K) throws -> Int64? { try present(key) ? decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: UInt.Type, forKey key: K) throws -> UInt? { try present(key) ? decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: UInt8.Type, forKey key: K) throws -> UInt8? { try present(key) ? decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: UInt16.Type, forKey key: K) throws -> UInt16? { try present(key) ? decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: UInt32.Type, forKey key: K) throws -> UInt32? { try present(key) ? decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: UInt64.Type, forKey key: K) throws -> UInt64? { try present(key) ? decode(type, forKey: key) : nil }
    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T? { try present(key) ? decode(type, forKey: key) : nil }

    func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
        // a missing key never decodes, not even as null
        guard base.contains(key) else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "missing field \"\(key.stringValue)\""))
        }
        return try T(from: StrictDecoder(base: base.superDecoder(forKey: key)))
    }

    func nestedContainer<NK: CodingKey>(keyedBy type: NK.Type, forKey key: K) throws -> KeyedDecodingContainer<NK> {
        try StrictDecoder(base: base.superDecoder(forKey: key)).container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        try StrictDecoder(base: base.superDecoder(forKey: key)).unkeyedContainer()
    }

    func superDecoder() throws -> Decoder { StrictDecoder(base: try base.superDecoder()) }
    func superDecoder(forKey key: K) throws -> Decoder { StrictDecoder(base: try base.superDecoder(forKey: key)) }
}

private struct StrictUnkeyed: UnkeyedDecodingContainer {
    var base: UnkeyedDecodingContainer

    var codingPath: [CodingKey] { base.codingPath }
    var count: Int? { base.count }
    var isAtEnd: Bool { base.isAtEnd }
    var currentIndex: Int { base.currentIndex }
    mutating func decodeNil() throws -> Bool { try base.decodeNil() }
    mutating func decode(_ type: Bool.Type) throws -> Bool { try base.decode(type) }
    mutating func decode(_ type: String.Type) throws -> String { try base.decode(type) }
    mutating func decode(_ type: Double.Type) throws -> Double { try base.decode(type) }
    mutating func decode(_ type: Float.Type) throws -> Float { try base.decode(type) }
    mutating func decode(_ type: Int.Type) throws -> Int { try base.decode(type) }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { try base.decode(type) }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { try base.decode(type) }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { try base.decode(type) }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { try base.decode(type) }
    mutating func decode(_ type: UInt.Type) throws -> UInt { try base.decode(type) }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { try base.decode(type) }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { try base.decode(type) }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { try base.decode(type) }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { try base.decode(type) }

    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try T(from: StrictDecoder(base: base.superDecoder()))
    }

    mutating func nestedContainer<NK: CodingKey>(keyedBy type: NK.Type) throws -> KeyedDecodingContainer<NK> {
        try StrictDecoder(base: base.superDecoder()).container(keyedBy: type)
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        try StrictDecoder(base: base.superDecoder()).unkeyedContainer()
    }

    mutating func superDecoder() throws -> Decoder { StrictDecoder(base: try base.superDecoder()) }
}

private struct StrictSingle: SingleValueDecodingContainer {
    let base: SingleValueDecodingContainer
    let decoder: Decoder

    var codingPath: [CodingKey] { base.codingPath }
    func decodeNil() -> Bool { base.decodeNil() }
    func decode(_ type: Bool.Type) throws -> Bool { try base.decode(type) }
    func decode(_ type: String.Type) throws -> String { try base.decode(type) }
    func decode(_ type: Double.Type) throws -> Double { try base.decode(type) }
    func decode(_ type: Float.Type) throws -> Float { try base.decode(type) }
    func decode(_ type: Int.Type) throws -> Int { try base.decode(type) }
    func decode(_ type: Int8.Type) throws -> Int8 { try base.decode(type) }
    func decode(_ type: Int16.Type) throws -> Int16 { try base.decode(type) }
    func decode(_ type: Int32.Type) throws -> Int32 { try base.decode(type) }
    func decode(_ type: Int64.Type) throws -> Int64 { try base.decode(type) }
    func decode(_ type: UInt.Type) throws -> UInt { try base.decode(type) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try base.decode(type) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try base.decode(type) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try base.decode(type) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try base.decode(type) }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try T(from: StrictDecoder(base: decoder))
    }
}
