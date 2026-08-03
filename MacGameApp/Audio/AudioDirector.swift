import Foundation
import GameCore

/// Session-facing audio service: revisioned ``AudioUpdate``s plus shell lifecycle.
///
/// Pause / focus loss / fault use ``interrupt()`` / ``resumePlayback()`` /
/// ``reset()`` — they are not revisioned ``AudioUpdate``s.
///
/// User volumes / mute (Phase 3.3) are applied via ``applyOutputSettings(_:)``.
/// Theme selection is mode-driven from ``AudioContext.game`` (Phase 3.5).
/// Background music within a game may be overridden via ``applyMusicTrackID(_:for:)``.
@MainActor
final class AudioDirector {
    private let backend: any AudioPlaybackBackend
    private let catalog: AudioThemeCatalog
    private let musicCatalog: MusicTrackCatalog

    private(set) var lastAppliedRevision: UInt64?
    private(set) var outputSettings: AudioOutputSettings = .default
    private(set) var activeTheme: AudioTheme
    private(set) var selectedMusicTrackIDs: [AudioGameMode: String]
    private var desiredMusic: MusicPlaybackState = .stopped
    private var interrupted = false

    /// Selected track for the currently active game theme.
    var selectedMusicTrackID: String {
        selectedMusicTrackIDs[activeTheme.game]
            ?? musicCatalog.defaultTrackID(for: activeTheme.game)
    }

    init(
        backend: any AudioPlaybackBackend = ProceduralAudioPlaybackBackend(),
        catalog: AudioThemeCatalog? = nil,
        musicCatalog: MusicTrackCatalog? = nil
    ) {
        self.backend = backend
        let resources = BundleContentResources(bundle: Bundle(for: AudioDirector.self))
        let resolvedCatalog =
            catalog
            ?? AudioThemeCatalogLoader.load(from: resources)
        let resolvedMusic =
            musicCatalog
            ?? MusicTrackCatalogLoader.load(from: resources)
        self.catalog = resolvedCatalog
        self.musicCatalog = resolvedMusic
        self.selectedMusicTrackIDs = resolvedMusic.defaultTrackIDs
        self.activeTheme = Self.effectiveTheme(
            base: resolvedCatalog.resolvedTheme(for: .sokoban),
            musicTrackID: resolvedMusic.defaultTrackID(for: .sokoban),
            musicCatalog: resolvedMusic
        )
        backend.applyTheme(activeTheme)
        backend.applyOutputSettings(outputSettings)
    }

    /// Live user settings from the Phase 3.3 store. Does not affect revisions.
    func applyOutputSettings(_ settings: AudioOutputSettings) {
        outputSettings = settings
        backend.applyOutputSettings(settings)
    }

    /// Applies the user's selected background track for one game. Reloads music when active.
    func applyMusicTrackID(_ id: String, for game: AudioGameMode) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selectedMusicTrackIDs[game] = trimmed
        guard activeTheme.game == game else { return }
        pushEffectiveTheme(for: game)
        alignMusicIfAudible()
    }

    /// Applies one session audio emission. Never blocks presentation.
    func apply(_ update: AudioUpdate) {
        if let last = lastAppliedRevision, update.targetRevision <= last {
            // Duplicate or stale: drop entirely (no cues, no revision rewind).
            return
        }

        selectTheme(for: update.context.game)
        desiredMusic = Self.musicState(for: update.context)

        if let last = lastAppliedRevision, update.targetRevision > last + 1 {
            // Forward gap: ignore transient events; cut voices and align music.
            lastAppliedRevision = update.targetRevision
            backend.stopAllEffects()
            alignMusicIfAudible()
            return
        }

        // Contiguous (or first applied update).
        lastAppliedRevision = update.targetRevision

        switch update.delivery {
        case .perform:
            if !interrupted {
                playCues(from: update.events)
            }
        case .synchronize:
            // Hard-resync / undo / redo / restart: never leave old cues ringing.
            backend.stopAllEffects()
        }

        // Win: keep the jingle; soft-fade BGM immediately (overlay timing is independent).
        // Death / synchronize-completed (restore): stop immediately.
        if update.context.status == .completed, update.delivery == .perform {
            if !interrupted {
                backend.setMusic(.stopped, fadeOutDuration: Self.winMusicFadeOut)
            }
            return
        }
        alignMusicIfAudible()
    }

    /// Pause / focus loss: stop effect voices and silence music without forgetting
    /// the desired music state.
    func interrupt() {
        interrupted = true
        backend.stopAllEffects()
        backend.setMusic(.stopped, fadeOutDuration: 0)
    }

    /// Resume after ``interrupt()``: restore music from the last known context.
    func resumePlayback() {
        interrupted = false
        alignMusicIfAudible()
    }

    /// Fault / level reload: forget revision tracking and silence everything.
    func reset() {
        interrupted = false
        lastAppliedRevision = nil
        desiredMusic = .stopped
        backend.stopAll()
    }

    // MARK: - Mapping

    /// Music soft-fade under the win jingle (seconds).
    static let winMusicFadeOut: TimeInterval = 0.9

    static func musicState(for context: AudioContext) -> MusicPlaybackState {
        switch context.status {
        case .playing:
            return .themeLoop
        case .completed, .failed:
            return .stopped
        }
    }

    /// Maps ordered events to shared cues. A push plays only the push cue (no step).
    static func cues(from events: [GameEvent]) -> [AudioCue] {
        let pushed = events.contains { event in
            if case .objectPushed = event { return true }
            return false
        }
        let died = events.contains { event in
            if case .playerDied = event { return true }
            return false
        }

        var cues: [AudioCue] = []
        for event in events {
            switch event {
            case .movementBlocked:
                cues.append(.movementBlocked)
            case .objectPushed:
                cues.append(.objectPushed)
            case .entityMoved(let entity, _, _) where entity.kind == .player:
                if !pushed {
                    cues.append(.movementStep)
                }
            case .crateEnteredGoal, .diamondCollected:
                cues.append(.collectiblePickedUp)
            case .crateLeftGoal:
                cues.append(.goalLeft)
            case .exitOpened:
                cues.append(.exitOpened)
            case .playerDied:
                cues.append(.playerDied)
            case .timeExpired:
                // Usually paired with `playerDied`; avoid a double hit.
                if !died {
                    cues.append(.timeExpired)
                }
            case .levelCompleted:
                cues.append(.objectiveCompleted)
            case .objectLanded:
                cues.append(.objectLanded)
            case .objectStartedFalling, .explosion:
                break
            default:
                break
            }
        }
        return cues
    }

    private func selectTheme(for game: AudioGameMode) {
        pushEffectiveTheme(for: game)
    }

    private func pushEffectiveTheme(for game: AudioGameMode) {
        let trackID =
            selectedMusicTrackIDs[game]
            ?? musicCatalog.defaultTrackID(for: game)
        let theme = Self.effectiveTheme(
            base: catalog.resolvedTheme(for: game),
            musicTrackID: trackID,
            musicCatalog: musicCatalog
        )
        guard theme != activeTheme else { return }
        activeTheme = theme
        backend.applyTheme(theme)
    }

    static func effectiveTheme(
        base: AudioTheme,
        musicTrackID: String,
        musicCatalog: MusicTrackCatalog
    ) -> AudioTheme {
        guard let track = musicCatalog.resolvedTrack(preferredID: musicTrackID, for: base.game)
        else {
            return base
        }
        return base.replacingMusicPlayingPath(track.resourcePath)
    }

    private func playCues(from events: [GameEvent]) {
        for cue in Self.cues(from: events) {
            backend.playEffect(cue)
        }
    }

    private func alignMusicIfAudible() {
        guard !interrupted else { return }
        backend.setMusic(desiredMusic, fadeOutDuration: 0)
    }
}
