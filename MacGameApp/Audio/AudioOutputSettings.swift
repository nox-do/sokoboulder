import Foundation

/// User-facing gain / mute applied to music and effect buses.
///
/// Phase 3.5 audio themes reuse this surface; they do not own persistence.
struct AudioOutputSettings: Equatable, Sendable {
    var musicVolume: Double
    var effectsVolume: Double
    var isMuted: Bool

    static let `default` = AudioOutputSettings(
        musicVolume: 0.8,
        effectsVolume: 1.0,
        isMuted: false
    )

    /// Effective music gain after mute.
    var effectiveMusicGain: Float {
        isMuted ? 0 : Float(Self.clampVolume(musicVolume))
    }

    /// Effective effects gain after mute.
    var effectiveEffectsGain: Float {
        isMuted ? 0 : Float(Self.clampVolume(effectsVolume))
    }

    static func clampVolume(_ value: Double) -> Double {
        min(1, max(0, value.isFinite ? value : 0))
    }

    static func from(settings: AppSettingsSnapshot) -> AudioOutputSettings {
        AudioOutputSettings(
            musicVolume: settings.musicVolume,
            effectsVolume: settings.effectsVolume,
            isMuted: settings.isMuted
        )
    }
}
