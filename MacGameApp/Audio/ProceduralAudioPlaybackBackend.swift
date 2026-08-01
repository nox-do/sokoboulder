import AVFoundation
import Foundation

/// Quiet procedural beeps / loop via ``AVAudioEngine``. No bundle assets.
///
/// Failures to start the engine degrade to silence; they never propagate.
@MainActor
final class ProceduralAudioPlaybackBackend: AudioPlaybackBackend {
    private let engine = AVAudioEngine()
    private let effectPlayer = AVAudioPlayerNode()
    private let musicPlayer = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var engineRunning = false
    private var currentMusic: MusicPlaybackState = .stopped

    private lazy var cueBuffers: [AudioCue: AVAudioPCMBuffer] = [
        .step: Self.toneBuffer(frequency: 420, duration: 0.04, amplitude: 0.12, format: format),
        .blocked: Self.toneBuffer(frequency: 160, duration: 0.05, amplitude: 0.1, format: format),
        .cratePushed: Self.toneBuffer(frequency: 280, duration: 0.07, amplitude: 0.14, format: format),
        .goalEntered: Self.toneBuffer(frequency: 660, duration: 0.12, amplitude: 0.16, format: format),
        .goalLeft: Self.toneBuffer(frequency: 360, duration: 0.1, amplitude: 0.1, format: format),
        .levelCompleted: Self.chordBuffer(
            frequencies: [523.25, 659.25, 783.99],
            duration: 0.45,
            amplitude: 0.14,
            format: format
        ),
    ]

    private lazy var musicBuffer: AVAudioPCMBuffer = Self.toneBuffer(
        frequency: 196,
        duration: 2.0,
        amplitude: 0.03,
        format: format,
        softAttack: true
    )

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1)
            ?? AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        engine.attach(effectPlayer)
        engine.attach(musicPlayer)
        engine.connect(effectPlayer, to: engine.mainMixerNode, format: format)
        engine.connect(musicPlayer, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.8
        startEngineIfNeeded()
    }

    func playEffect(_ cue: AudioCue) {
        guard startEngineIfNeeded(), let buffer = cueBuffers[cue] else { return }
        effectPlayer.scheduleBuffer(buffer, completionHandler: nil)
        if !effectPlayer.isPlaying {
            effectPlayer.play()
        }
    }

    func setMusic(_ state: MusicPlaybackState) {
        guard state != currentMusic else { return }
        currentMusic = state
        musicPlayer.stop()
        guard state == .sokobanLoop, startEngineIfNeeded() else { return }
        musicPlayer.scheduleBuffer(musicBuffer, at: nil, options: .loops, completionHandler: nil)
        musicPlayer.play()
    }

    func stopAllEffects() {
        effectPlayer.stop()
    }

    func stopAll() {
        effectPlayer.stop()
        musicPlayer.stop()
        currentMusic = .stopped
    }

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

    // MARK: - Buffer synthesis

    private static func toneBuffer(
        frequency: Double,
        duration: Double,
        amplitude: Float,
        format: AVAudioFormat,
        softAttack: Bool = false
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
            if softAttack {
                let attack = min(1.0, t / 0.08)
                let release = min(1.0, (duration - t) / 0.08)
                sample *= Float(attack * release)
            } else {
                let attack = min(1.0, t / 0.005)
                let release = min(1.0, (duration - t) / 0.01)
                sample *= Float(attack * release)
            }
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
