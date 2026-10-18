import AppKit
import GameCore

// View models and result-overlay actions.
extension SokobanPlayController {
    var levelIntroPresentation: LevelIntroPresentation {
        if isCaveMode {
            return PresentationFactory.caveLevelIntro(
                title: levelTitle,
                requiredDiamonds: caveSession?.requiredDiamonds ?? 0,
                timeLimitTicks: caveSession?.remainingTicks ?? 0,
                hint: tutorialHintText
            )
        }
        return PresentationFactory.levelIntro(title: levelTitle, body: tutorialHintText)
    }

    var pausePresentation: PausePresentation {
        PresentationFactory.pause(isCaveMode: isCaveMode || shellCampaign == .cave)
    }

    var levelSelectionRows: [LevelSelectionRow] {
        switch shellCampaign {
        case .sokoban:
            return catalog.levels.map { descriptor in
                LevelSelectionRow(
                    id: descriptor.id,
                    title: catalog.title(for: descriptor),
                    availability: levelAvailability(for: descriptor)
                )
            }
        case .cave:
            return caveCatalog.levels.map { descriptor in
                LevelSelectionRow(
                    id: descriptor.id,
                    title: caveCatalog.title(for: descriptor),
                    availability: caveLevelAvailability(for: descriptor)
                )
            }
        }
    }

    var helpPresentation: HelpPresentation {
        PresentationFactory.help(
            isCaveMode: isCaveMode || shellCampaign == .cave,
            catalog: catalog
        )
    }

    var outcomePresentation: OutcomePresentation {
        PresentationFactory.outcome(
            PresentationFactory.OutcomeInput(
                title: outcome.title,
                hint: outcome.hint,
                primaryTitle: outcome.primaryTitle,
                metrics: metrics,
                canRestart: canRestart,
                canUndo: canUndo,
                records: outcome.records
            )
        )
    }

    var boardAccessibilityLabel: String {
        PresentationFactory.boardAccessibilityLabel(levelTitle: levelTitle)
    }

    var boardAccessibilityValue: String {
        PresentationFactory.boardAccessibilityValue(
            snapshot: scene.currentSnapshot,
            isCaveMode: isCaveMode
        )
    }

    func performOutcomePrimaryAction() {
        guard presentationPhase == .outcomeAwaitingChoice else { return }
        switch outcome.primaryAction {
        case .nextLevel(let id):
            if isCaveMode {
                startCaveLevel(id: id)
            } else {
                // Variant B: only show intro when the next hint is still unseen.
                startSelectedLevel(id: id)
            }
        case .openLaunchMenu:
            if !isCaveMode { runPersistence.removeRunFile() }
            openGameSelection()
        case .playAgain:
            restart()
        }
    }

    /// Confirms the currently focused result-overlay action (Return / Space).
    func performFocusedOutcomeAction() {
        guard presentationPhase == .outcomeAwaitingChoice else { return }
        switch menuFocus.outcome {
        case .primary:
            performOutcomePrimaryAction()
        case .again:
            restartFromOutcomeOverlay()
        case .undo:
            guard canUndo else { return }
            undoFromOutcomeOverlay()
        case .levelSelection:
            openLevelSelectionFromOutcome()
        }
    }

    func restartFromOutcomeOverlay() {
        restart()
    }

    func undoFromOutcomeOverlay() {
        guard canUndo else { return }
        undo()
    }

    func openLevelSelectionFromOutcome() {
        guard presentationPhase == .outcomeAwaitingChoice else { return }
        shellCampaign = isCaveMode ? .cave : .sokoban
        openLevelSelection()
    }

    func scheduleShowOutcome() {
        cancelShowOutcome()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.activePlay?.isOutcomePresenting == true else { return }
            guard self.presentationPhase != .outcomeAwaitingChoice else { return }
            self.enterOutcomeAwaitingChoice()
        }
        showOutcomeWorkItem = work
        // Let the win/death jingle breathe; cave WAV is ~1.35s.
        let delay = activePlay?.outcomeOverlayDelay ?? 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func cancelShowOutcome() {
        showOutcomeWorkItem?.cancel()
        showOutcomeWorkItem = nil
    }

    func enterOutcomeAwaitingChoice() {
        cancelShowOutcome()
        presentationPhase = .outcomeAwaitingChoice
        if router.mode != .outcomePresenting {
            router.enterOutcomePresenting()
        }
        // Open confirm gate; still-held keys stay in pressedKeyCodes so they are
        // not treated as a fresh Return/Space confirm.
        router.releaseOutcomeLocksPreservingPressedKeys()
        if !isCaveMode {
            outcome.configure(game: .sokoban, nextLevelID: catalog.descriptor(after: currentLevelID)?.id)
        }
        resetOverlayFocus(for: .outcomeAwaitingChoice)
        refreshPublishedState()
    }
}
