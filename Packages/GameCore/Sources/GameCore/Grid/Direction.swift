/// Cardinal movement on the logical game grid.
///
/// Offsets follow the model convention: row increases downward.
public enum Direction: Hashable, CaseIterable, Codable, Sendable {
    case up
    case down
    case left
    case right

    /// Column delta for one step in this direction.
    public var columnOffset: Int {
        switch self {
        case .up, .down: 0
        case .left: -1
        case .right: 1
        }
    }

    /// Row delta for one step in this direction.
    public var rowOffset: Int {
        switch self {
        case .left, .right: 0
        case .up: -1
        case .down: 1
        }
    }

    public var opposite: Direction {
        switch self {
        case .up: .down
        case .down: .up
        case .left: .right
        case .right: .left
        }
    }

    /// Counter-clockwise turn (Firefly left-wall preference).
    public var turnedLeft: Direction {
        switch self {
        case .up: .left
        case .left: .down
        case .down: .right
        case .right: .up
        }
    }

    /// Clockwise turn (Butterfly right-wall preference).
    public var turnedRight: Direction {
        switch self {
        case .up: .right
        case .right: .down
        case .down: .left
        case .left: .up
        }
    }
}
