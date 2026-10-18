import AppKit
import GameCore

// Menu keyboard navigation and focus.
extension SokobanPlayController {
    /// Menu navigation / activate / cancel owned by the local key monitor path.
    func handleOverlayMenuKeyEvent(_ event: NSEvent) -> Bool {
        if handleUnlockCheatKey(event) {
            return true
        }
        guard let command = OverlayMenuCommandMapper.command(from: event) else {
            return false
        }
        let result = OverlayMenuNavigator.resolve(
            phase: presentationPhase,
            command: command,
            isRepeat: event.isARepeat,
            focus: menuFocus,
            context: overlayNavigationContext(for: presentationPhase)
        )
        return applyOverlayNavigationResult(result)
    }

    /// Debug/cheat: `U` unlocks all levels for the active shell campaign.
    @discardableResult
    private func handleUnlockCheatKey(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, !event.isARepeat else { return false }
        guard event.keyCode == KeyCode.u else { return false }
        let blocking: NSEvent.ModifierFlags = [.command, .control, .option]
        guard event.modifierFlags.intersection(blocking).isEmpty else { return false }

        switch presentationPhase {
        case .launchMenu, .levelSelection:
            unlockAllLevelsForShellCampaign()
            return true
        case .playing, .paused, .levelIntro, .outcomePresenting, .outcomeAwaitingChoice:
            unlockAllLevelsForShellCampaign()
            return true
        default:
            return false
        }
    }

    private func unlockAllLevelsForShellCampaign() {
        switch shellCampaign {
        case .sokoban:
            progressPersistence.unlockAllLevels(catalog.levels.map(\.id))
        case .cave:
            progressPersistence.unlockAllCaveLevels(caveCatalog.levels.map(\.id))
        }
        gameplayNotice = AppStrings.text(.uiCheatLevelsUnlocked)
        if presentationPhase == .levelSelection {
            menuFocus.levelSelectionID =
                levelSelectionFocusOrder.first ?? Self.levelSelectionBackID
        }
        refreshPublishedState()
    }

    private func overlayNavigationContext(for phase: GamePresentationPhase) -> OverlayNavigationContext {
        OverlayNavigationContext(
            levelSelectionOrder: phase == .levelSelection ? levelSelectionFocusOrder : [],
            settingsOrder: phase == .settings ? settingsFocusOrder : [],
            outcomeOrder: phase == .outcomeAwaitingChoice ? outcomeFocusOrder : [],
            musicTrackFocusGames: phase == .settings
                ? Dictionary(
                    uniqueKeysWithValues: settings.presentation.musicTrackGroups.map { ($0.id, $0.game) }
                ) : [:],
            levelSelectionBackID: Self.levelSelectionBackID
        )
    }

    private var outcomeFocusOrder: [OutcomeFocusedAction] {
        var actions: [OutcomeFocusedAction] = [.primary]
        if canRestart {
            actions.append(.again)
        }
        if canUndo {
            actions.append(.undo)
        }
        actions.append(.levelSelection)
        return actions
    }

    private var levelSelectionFocusOrder: [String] {
        levelSelectionRows.compactMap { row in
            row.availability == .locked ? nil : row.id
        } + [Self.levelSelectionBackID]
    }

    private var settingsFocusOrder: [String] {
        SettingsFocusID.keyboardFocusOrder(
            showsThemePicker: settings.themeCatalog.selectableThemes.count > 1,
            musicTrackFocusIDs: settings.presentation.musicTrackGroups.map(\.id)
        )
    }

    private static let levelSelectionBackID = "navigation.back"

    @discardableResult
    private func applyOverlayNavigationResult(_ result: OverlayNavigationResult) -> Bool {
        switch result {
        case .unhandled:
            return false
        case .consumed:
            return true
        case .updateFocus(let focus):
            applyOverlayFocus(focus)
            return true
        case .action(let action):
            applyOverlayNavigationAction(action)
            return true
        }
    }

    private func applyOverlayFocus(_ focus: OverlayFocusState) {
        menuFocus = focus
        setFocusedOutcomeAction(focus.outcome)
    }

    private func applyOverlayNavigationAction(_ action: OverlayNavigationAction) {
        switch action {
        case .activateGameSelection:
            performFocusedGameSelectionAction()
        case .activateLaunch:
            performFocusedLaunchAction()
        case .activatePause:
            performFocusedPauseAction()
        case .activateLevelSelection:
            performFocusedLevelSelectionAction()
        case .cycleTheme(let offset):
            settings.cycleTheme(by: offset)
        case .cycleMusicTrack(let game, let offset):
            settings.cycleMusicTrack(for: game, by: offset)
        case .toggleReduceMotion:
            settings.updateReduceMotionEnabled(!settings.store.reduceMotionEnabled)
        case .toggleMute:
            settings.updateMuted(!settings.store.isMuted)
        case .dismissHelpOrSettings:
            dismissHelpOrSettings()
        case .cancelPauseToGameSelection:
            openGameSelection()
        case .cancelLaunchToGameSelection:
            returnToGameSelectionFromLaunchMenu()
        case .cancelLevelSelectionToLaunch:
            returnToLaunchMenu()
        case .performOutcomePrimary:
            performOutcomePrimaryAction()
        }
    }

    private func performFocusedGameSelectionAction() {
        switch menuFocus.gameSelection {
        case .sokoban:
            selectSokobanFromGameSelection()
        case .cave:
            selectCaveFromGameSelection()
        case .help:
            openHelpFromGameSelection()
        case .settings:
            openSettingsFromGameSelection()
        }
    }

    private func performFocusedLaunchAction() {
        switch menuFocus.launch {
        case .continueCampaign:
            continueCampaign()
        case .selectLevel:
            openLevelSelection()
        case .help:
            openHelpFromLaunchMenu()
        case .settings:
            openSettingsFromLaunchMenu()
        case .resetProgress:
            resetCampaignProgressFromLaunchMenu()
        case .backToGameSelection:
            returnToGameSelectionFromLaunchMenu()
        }
    }

    private func performFocusedPauseAction() {
        switch menuFocus.pause {
        case .resume:
            resumeFromPauseOverlay()
        case .restart:
            restartFromPauseOverlay()
        case .settings:
            openSettingsFromPause()
        case .levelSelection:
            openLevelSelectionFromPauseOverlay()
        case .help:
            openHelpFromPause()
        }
    }

    private func performFocusedLevelSelectionAction() {
        if menuFocus.levelSelectionID == Self.levelSelectionBackID {
            returnToLaunchMenu()
        } else {
            startSelectedLevel(id: menuFocus.levelSelectionID)
        }
    }

    func resetOverlayFocus(for phase: GamePresentationPhase) {
        applyOverlayFocus(
            OverlayMenuNavigator.resetFocus(
                for: phase,
                focus: menuFocus,
                context: overlayNavigationContext(for: phase)
            )
        )
    }

    /// Keeps router confirm and overlay selection aligned.
    func setFocusedOutcomeAction(_ action: OutcomeFocusedAction) {
        if action == .undo, !canUndo {
            menuFocus.outcome = .primary
            return
        }
        menuFocus.outcome = action
    }

    func setFocusedGameSelectionAction(_ action: GameSelectionAction) {
        guard action.isEnabled else { return }
        menuFocus.gameSelection = action
    }

    func setFocusedLaunchAction(_ action: LaunchMenuAction) {
        menuFocus.launch = action
    }

    func setFocusedPauseAction(_ action: PauseMenuAction) {
        menuFocus.pause = action
    }

    func setFocusedLevelSelectionID(_ id: String) {
        menuFocus.levelSelectionID = id
    }

    func setFocusedSettingsID(_ id: String) {
        menuFocus.settingsID = id
    }
}
