/// Stable identity for a movable entity within one level run.
///
/// IDs are assigned deterministically at ``SokobanRules/start(level:)`` (and later
/// cave start). Within a run they may appear in semantic checkpoints; they are not
/// a cross-run progress key.
public struct EntityID: Hashable, Codable, Sendable {
    public let rawValue: UInt64

    public init(_ rawValue: UInt64) {
        self.rawValue = rawValue
    }
}
