import AVFoundation
import Foundation

/// Theme-backed music plus file or procedural effects via AVFoundation.
///
/// Missing/invalid audio and engine failures degrade to silence / procedural
/// tones; they never propagate.
@MainActor
final class ProceduralAudioPlaybackBackend: AudioPlaybackBackend {
    private let resources: any ContentResourceProvider
    private let engine = AVAudioEngine()
    private let effectPlayer = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var engineRunning = false
    private var currentMusic: MusicPlaybackState = .stopped
    private var musicPlayer: AVAudioPlayer?
    /// Bundle-relative path currently loaded into ``musicPlayer`` (if any).
    private var loadedMusicPath: String?
    private var activeTheme: AudioTheme
    private var outputSettings: AudioOutputSettings = .default
    private lazy var proceduralBuffers: [AudioCue: AVAudioPCMBuffer] = Self.makeProceduralBuffers(
        format: format
    )
    /// File-backed cue URLs that decoded successfully. Missing paths stay absent.
    private var fileCueURLs: [AudioCue: URL] = [:]
    private var fileCuePlayers: [AVAudioPlayer] = []
    private var musicFadeTask: Task<Void, Never>?
    private var isMusicFading = false

    /// The source is mastered music; keep headroom for gameplay feedback.
    private var effectiveMusicVolume: Float {
        outputSettings.effectiveMusicGain * 0.5
    }

    init(
        resources: any ContentResourceProvider = BundleContentResources(
            bundle: Bundle(for: ProceduralAudioPlaybackBackend.self)
        ),
        theme: AudioTheme = BuiltInAudioThemes.sokoban
    ) {
        self.resources = resources
        self.activeTheme = theme
        format = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1)
            ?? AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        engine.attach(effectPlayer)
        engine.connect(effectPlayer, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.8
        reloadThemeAssets()
        startEngineIfNeeded()
    }

    func applyTheme(_ theme: AudioTheme) {
        if theme == activeTheme, loadedMusicPath == theme.musicPlayingPath {
            return
        }
        let shouldResumeLoop = currentMusic == .themeLoop
        cancelMusicFade()
        // Stop before replacing the player so a released AVAudioPlayer cannot keep
        // playing the previous track (settings music switches rely on this).
        stopMusicPlayback()
        activeTheme = theme
        reloadThemeAssets()
        if shouldResumeLoop, effectiveMusicVolume > 0 {
            startThemeMusicIfNeeded()
        }
    }

    func playEffect(_ cue: AudioCue) {
        guard outputSettings.effectiveEffectsGain > 0 else { return }
        if let url = fileCueURLs[cue], playFileCue(url: url) {
            return
        }
        guard startEngineIfNeeded(), let buffer = proceduralBuffers[cue] else { return }
        effectPlayer.volume = outputSettings.effectiveEffectsGain
        effectPlayer.scheduleBuffer(buffer, completionHandler: nil)
        if !effectPlayer.isPlaying {
            effectPlayer.play()
        }
    }

    func setMusic(_ state: MusicPlaybackState, fadeOutDuration: TimeInterval) {
        if state == .themeLoop {
            cancelMusicFade()
            let pathMatches =
                musicPlayer != nil
                && loadedMusicPath == activeTheme.musicPlayingPath
            if currentMusic == .themeLoop, pathMatches {
                applyGains()
                return
            }
            if !pathMatches {
                stopMusicPlayback()
                reloadThemeAssets()
            }
            currentMusic = .themeLoop
            startThemeMusicIfNeeded()
            return
        }

        // .stopped
        if fadeOutDuration > 0 {
            if isMusicFading { return }
            if currentMusic == .stopped, musicPlayer?.isPlaying != true { return }
            currentMusic = .stopped
            fadeOutMusic(duration: fadeOutDuration)
        } else {
            currentMusic = .stopped
            musicFadeTask?.cancel()
            musicFadeTask = nil
            isMusicFading = false
            stopMusicPlayback()
        }
    }

    func stopAllEffects() {
        effectPlayer.stop()
        effectPlayer.volume = outputSettings.effectiveEffectsGain
        for player in fileCuePlayers {
            player.stop()
        }
        fileCuePlayers.removeAll()
    }

    func stopAll() {
        stopAllEffects()
        cancelMusicFade()
        stopMusicPlayback()
        currentMusic = .stopped
    }

    func applyOutputSettings(_ settings: AudioOutputSettings) {
        outputSettings = settings
        applyGains()
    }

    private func reloadThemeAssets() {
        fileCueURLs = [:]
        for cue in AudioCue.allCases {
            guard let path = activeTheme.resourcePath(for: cue) else { continue }
            guard let url = try? resources.url(at: path) else { continue }
            // Probe decode once; unloadable files fall back to procedural at play time.
            guard (try? AVAudioFile(forReading: url)) != nil else { continue }
            fileCueURLs[cue] = url
        }

        let previousPath = loadedMusicPath
        let previousTime = musicPlayer?.currentTime ?? 0
        // Always halt before dropping the reference — releasing alone is not enough
        // to guarantee the previous file goes silent.
        stopMusicPlayback()
        musicPlayer = nil
        loadedMusicPath = nil
        if let path = activeTheme.musicPlayingPath,
           let url = try? resources.url(at: path),
           let player = try? AVAudioPlayer(contentsOf: url)
        {
            player.numberOfLoops = -1
            player.prepareToPlay()
            // Keep position only when reloading the same file (e.g. cue refresh).
            if path == previousPath {
                player.currentTime = min(previousTime, player.duration)
            }
            musicPlayer = player
            loadedMusicPath = path
        }
    }

    @discardableResult
    private func playFileCue(url: URL) -> Bool {
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return false }
        player.volume = outputSettings.effectiveEffectsGain
        player.prepareToPlay()
        guard player.play() else { return false }
        fileCuePlayers.append(player)
        fileCuePlayers.removeAll { !$0.isPlaying && $0 !== player }
        return true
    }

    private func startThemeMusicIfNeeded() {
        musicPlayer?.volume = effectiveMusicVolume
        if effectiveMusicVolume > 0 {
            musicPlayer?.play()
        }
    }

    private func applyGains() {
        effectPlayer.volume = outputSettings.effectiveEffectsGain
        for player in fileCuePlayers where player.isPlaying {
            player.volume = outputSettings.effectiveEffectsGain
        }
        // Leave volume alone while a win fade is in progress.
        guard !isMusicFading else { return }
        musicPlayer?.volume = effectiveMusicVolume
        guard currentMusic == .themeLoop else { return }

        if effectiveMusicVolume > 0 {
            if musicPlayer?.isPlaying == false {
                musicPlayer?.play()
            }
        } else {
            musicPlayer?.pause()
        }
    }

    private func fadeOutMusic(duration: TimeInterval) {
        musicFadeTask?.cancel()
        musicFadeTask = nil
        guard let player = musicPlayer, player.isPlaying, duration > 0 else {
            isMusicFading = false
            stopMusicPlayback()
            return
        }
        isMusicFading = true
        let startVolume = player.volume
        let steps = 24
        let stepNanos = UInt64((duration / Double(steps)) * 1_000_000_000)
        musicFadeTask = Task { @MainActor in
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: stepNanos)
                guard !Task.isCancelled else { return }
                let t = Float(step) / Float(steps)
                player.volume = startVolume * (1 - t)
            }
            guard !Task.isCancelled else { return }
            self.stopMusicPlayback()
            self.isMusicFading = false
            self.musicFadeTask = nil
        }
    }

    private func cancelMusicFade() {
        musicFadeTask?.cancel()
        musicFadeTask = nil
        isMusicFading = false
    }

    private func stopMusicPlayback() {
        musicPlayer?.stop()
        musicPlayer?.currentTime = 0
        musicPlayer?.volume = effectiveMusicVolume
    }

    #if DEBUG
    /// Test-only: path currently loaded for looping music, if any.
    var loadedMusicPathForTesting: String? { loadedMusicPath }
    #endif

    @discardableResult
    private func startEngineIfNeeded() -> Bool {
        if engineRunning { return true }
        do {
            try engine.start()
            engineRunning = true
            return true
        } catch {
            engineRunning = false
            return false
        }
    }

    // MARK: - Procedural fallbacks

    private static func makeProceduralBuffers(format: AVAudioFormat) -> [AudioCue: AVAudioPCMBuffer] {
        [
            .movementStep: toneBuffer(frequency: 420, duration: 0.04, amplitude: 0.12, format: format),
            .movementBlocked: toneBuffer(frequency: 160, duration: 0.05, amplitude: 0.1, format: format),
            .objectPushed: toneBuffer(frequency: 280, duration: 0.07, amplitude: 0.14, format: format),
            .objectLanded: toneBuffer(frequency: 200, duration: 0.06, amplitude: 0.12, format: format),
            .collectiblePickedUp: toneBuffer(frequency: 660, duration: 0.12, amplitude: 0.16, format: format),
            .goalLeft: toneBuffer(frequency: 360, duration: 0.1, amplitude: 0.1, format: format),
            .exitOpened: toneBuffer(frequency: 740, duration: 0.22, amplitude: 0.15, format: format),
            .playerDied: toneBuffer(frequency: 120, duration: 0.28, amplitude: 0.14, format: format),
            .timeExpired: toneBuffer(frequency: 180, duration: 0.2, amplitude: 0.13, format: format),
            .objectiveCompleted: chordBuffer(
                frequencies: [523.25, 659.25, 783.99],
                duration: 0.45,
                amplitude: 0.14,
                format: format
            ),
        ]
    }

    private static func toneBuffer(
        frequency: Double,
        duration: Double,
        amplitude: Float,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else { return buffer }

        let twoPi = 2.0 * Double.pi
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var sample = Float(sin(twoPi * frequency * t)) * amplitude
            let attack = min(1.0, t / 0.005)
            let release = min(1.0, (duration - t) / 0.01)
            sample *= Float(attack * release)
            channel[i] = sample
        }
        return buffer
    }

    private static func chordBuffer(
        frequencies: [Double],
        duration: Double,
        amplitude: Float,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else { return buffer }

        let twoPi = 2.0 * Double.pi
        let voiceAmplitude = amplitude / Float(max(frequencies.count, 1))
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var sample: Float = 0
            for frequency in frequencies {
                sample += Float(sin(twoPi * frequency * t)) * voiceAmplitude
            }
            let attack = min(1.0, t / 0.01)
            let release = min(1.0, (duration - t) / 0.08)
            channel[i] = sample * Float(attack * release)
        }
        return buffer
    }
}
