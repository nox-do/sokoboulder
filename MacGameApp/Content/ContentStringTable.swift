import Foundation

/// Data-driven localization for level titles, hints, and other content keys.
///
/// UI chrome stays in ``AppStrings``; level copy lives in JSON so new levels need
/// no Swift table edits.
struct ContentStringTable: Equatable, Sendable {
    private let values: [String: String]

    init(values: [String: String]) {
        self.values = values
    }

    /// Resolves `id`, falling back to the raw key when missing.
    func text(_ id: String) -> String {
        values[id] ?? id
    }

    func contains(_ id: String) -> Bool {
        values[id] != nil
    }

    static func decodeJSON(_ data: Data) throws -> ContentStringTable {
        let values = try JSONDecoder().decode([String: String].self, from: data)
        return ContentStringTable(values: values)
    }
}
