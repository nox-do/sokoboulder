import Foundation

/// Rejects Sokoban level JSON objects that contain keys outside the V1 allow-list.
///
/// Note: key validation currently runs before schema-version branching. When a V2
/// schema is introduced, read `schemaVersion` first and only then apply the
/// matching allow-list — otherwise a valid V2 file may surface `unknownKeys`.
enum StrictSokobanLevelJSON {
    enum Error: Swift.Error, Equatable, Sendable {
        case notAnObject
        case unknownKeys([String])
        case missingKeys([String])
        case rulesNotObject
        case unknownRuleKeys([String])
    }

    /// Validates top-level and `rules` keys before Codable decode.
    static func validateKeys(_ data: Data) throws {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw Error.notAnObject
        }
        guard let dict = object as? [String: Any] else {
            throw Error.notAnObject
        }

        let allowed: Set<String> = [
            "schemaVersion",
            "id",
            "game",
            "titleID",
            "goalTextID",
            "tutorialHintID",
            "width",
            "height",
            "rows",
            "rules",
        ]
        let required: Set<String> = [
            "schemaVersion",
            "id",
            "game",
            "titleID",
            "width",
            "height",
            "rows",
            "rules",
        ]

        let keys = Set(dict.keys)
        let unknown = keys.subtracting(allowed).sorted()
        guard unknown.isEmpty else {
            throw Error.unknownKeys(unknown)
        }
        let missing = required.subtracting(keys).sorted()
        guard missing.isEmpty else {
            throw Error.missingKeys(missing)
        }

        guard let rules = dict["rules"] else {
            throw Error.missingKeys(["rules"])
        }
        guard let rulesObject = rules as? [String: Any] else {
            throw Error.rulesNotObject
        }
        let ruleKeys = rulesObject.keys.sorted()
        guard ruleKeys.isEmpty else {
            throw Error.unknownRuleKeys(ruleKeys)
        }
    }
}
