import AppKit
import GameCore

// Opening and closing overlays.
extension SokobanPlayController {
    func openLevelSelectionFromPauseOverlay() {
        guard presentationPhase == .paused else { return }
        if isCaveMode {
            shellCampaign = .cave
            openLevelSelection()
        } else {
            openGameSelection()
        }
    }

    func openHelpFromPause() {
        guard presentationPhase == .paused else { return }
        openHelp(returningTo: .paused)
    }

    func openSettingsFromPause() {
        guard presentationPhase == .paused else { return }
        openSettings(returningTo: .paused)
    }

    func openHelpFromGameSelection() {
        guard presentationPhase == .gameSelection else { return }
        openHelp(returningTo: .gameSelection)
    }

    func openSettingsFromGameSelection() {
        guard presentationPhase == .gameSelection else { return }
        openSettings(returningTo: .gameSelection)
    }

    func openHelpFromLaunchMenu() {
        guard presentationPhase == .launchMenu else { return }
        openHelp(returningTo: .launchMenu)
    }

    func openSettingsFromLaunchMenu() {
        guard presentationPhase == .launchMenu else { return }
        openSettings(returningTo: .launchMenu)
    }

    func dismissHelpOrSettings() {
        guard presentationPhase == .help || presentationPhase == .settings else { return }
        guard let origin = overlayReturnOrigin else {
            openGameSelection()
            return
        }
        overlayReturnOrigin = nil
        switch origin {
        case .gameSelection:
            enterPresentation(.gameSelection)
        case .launchMenu:
            enterPresentation(.launchMenu)
        case .paused:
            enterPresentation(.paused)
        }
        refreshPublishedState()
    }

    func openGameSelection() {
        teardownSessionForNavigation(phase: .gameSelection)
    }

    func openLaunchMenu() {
        teardownSessionForNavigation(phase: .launchMenu)
    }

    func returnToGameSelectionFromLaunchMenu() {
        guard presentationPhase == .launchMenu else { return }
        openGameSelection()
    }

    func openLevelSelection() {
        teardownSessionForNavigation(phase: .levelSelection)
    }

    func returnToLaunchMenu() {
        guard presentationPhase == .levelSelection else { return }
        enterPresentation(.launchMenu)
        refreshPublishedState()
    }

    func enterLevelIntro() {
        enterPresentation(.levelIntro)
    }

    private func openHelp(returningTo origin: OverlayReturnOrigin) {
        overlayReturnOrigin = origin
        enterPresentation(.help)
        refreshPublishedState()
    }

    private func openSettings(returningTo origin: OverlayReturnOrigin) {
        overlayReturnOrigin = origin
        enterPresentation(.settings)
        refreshPublishedState()
    }

    private func teardownSessionForNavigation(phase: GamePresentationPhase) {
        clearMoveHold()
        cancelShowOutcome()
        activePlay = nil
        scene.prepareForNewSession()
        audioDirector.reset()
        settings.applyAudio()
        enterPresentation(phase)
        overlayReturnOrigin = nil
        refreshPublishedState()
    }
}
