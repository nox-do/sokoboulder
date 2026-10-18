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
            presentationPhase = .gameSelection
            router.enterModalBlocked()
            resetOverlayFocus(for: .gameSelection)
        case .launchMenu:
            presentationPhase = .launchMenu
            router.enterModalBlocked()
            resetOverlayFocus(for: .launchMenu)
        case .paused:
            presentationPhase = .paused
            router.enterPaused()
            requestPauseOverlayFocus()
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
        presentationPhase = .launchMenu
        router.enterModalBlocked()
        resetOverlayFocus(for: .launchMenu)
        refreshPublishedState()
    }

    func enterLevelIntro() {
        clearMoveHold()
        presentationPhase = .levelIntro
        router.enterLevelIntro()
    }

    private func openHelp(returningTo origin: OverlayReturnOrigin) {
        overlayReturnOrigin = origin
        presentationPhase = .help
        router.enterModalBlocked()
        refreshPublishedState()
    }

    private func openSettings(returningTo origin: OverlayReturnOrigin) {
        overlayReturnOrigin = origin
        presentationPhase = .settings
        router.enterModalBlocked()
        resetOverlayFocus(for: .settings)
        refreshPublishedState()
    }

    private func teardownSessionForNavigation(phase: GamePresentationPhase) {
        clearMoveHold()
        cancelShowOutcome()
        activePlay = nil
        scene.prepareForNewSession()
        audioDirector.reset()
        settings.applyAudio()
        presentationPhase = phase
        overlayReturnOrigin = nil
        router.enterModalBlocked()
        resetOverlayFocus(for: phase)
        refreshPublishedState()
    }
}
