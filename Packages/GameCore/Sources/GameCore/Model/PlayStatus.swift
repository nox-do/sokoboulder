/// High-level run status shared by game modes.
public enum PlayStatus: Equatable, Sendable {
    case playing
    case completed
    case failed
}
