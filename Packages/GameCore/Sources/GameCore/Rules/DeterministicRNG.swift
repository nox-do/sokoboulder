/// Replay-stable PRNG for cave rules that need classic-style chance (amoeba).
///
/// xorshift32; state `0` is remapped so the generator never locks.
public struct DeterministicRNG: Equatable, Sendable {
    public private(set) var state: UInt32

    public init(seed: UInt32) {
        self.state = seed == 0 ? 1 : seed
    }

    /// Advances and returns the next 32-bit value.
    public mutating func next() -> UInt32 {
        var x = state
        x ^= x << 13
        x ^= x >> 17
        x ^= x << 5
        state = x == 0 ? 1 : x
        return state
    }

    /// Inclusive range `0...upperBound` (BDCFF `GetRandomNumber(0, factor)` style).
    public mutating func nextInt(upperBound: UInt32) -> UInt32 {
        precondition(upperBound < UInt32.max)
        return next() % (upperBound + 1)
    }
}
