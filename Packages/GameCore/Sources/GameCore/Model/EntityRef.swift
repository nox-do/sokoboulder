/// Presentation-facing reference to a movable entity.
///
/// Carries enough identity and kind for animation and audio without exposing
/// the full domain state.
public struct EntityRef: Equatable, Sendable {
    public let id: EntityID
    public let kind: EntityKind

    public init(id: EntityID, kind: EntityKind) {
        self.id = id
        self.kind = kind
    }
}

/// Render-relevant object kind carried by ``EntityRef``.
public enum EntityKind: Equatable, Sendable {
    case player
    case crate
    case boulder
    case diamond
}
