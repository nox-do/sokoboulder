import Foundation

/// Rejects Cave level JSON objects that contain keys outside the V1 allow-list.
enum StrictCaveLevelJSON {
    enum Error: Swift.Error, Equatable, Sendable {
        case notAnObject
        case unknownKeys([String])
        case missingKeys([String])
        case rulesNotObject
        case unknownRuleKeys([String])
        case missingRuleKeys([String])
    }

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

        let allowedRules: Set<String> = [
            "requiredDiamonds",
            "timeLimitTicks",
            "diamondValue",
            "extraDiamondValue",
        ]
        let requiredRules: Set<String> = [
            "requiredDiamonds",
            "timeLimitTicks",
        ]
        let ruleKeys = Set(rulesObject.keys)
        let unknownRules = ruleKeys.subtracting(allowedRules).sorted()
        guard unknownRules.isEmpty else {
            throw Error.unknownRuleKeys(unknownRules)
        }
        let missingRules = requiredRules.subtracting(ruleKeys).sorted()
        guard missingRules.isEmpty else {
            throw Error.missingRuleKeys(missingRules)
        }
    }
}
