import Foundation

/// Applies paired render/audio emissions so Scene and AudioDirector stay on the same revision.
@MainActor
struct EmissionApplicator {
    let scene: SokobanBoardScene
    let audioDirector: AudioDirector

    func apply(_ emission: SessionEmission) {
        scene.apply(emission.render)
        audioDirector.apply(emission.audio)
    }
}
