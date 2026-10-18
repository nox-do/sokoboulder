import AppKit
import GameCore

// Level loading, campaign selection, and current-run restore.
extension SokobanPlayController {
    /// Loads a catalog level without consulting the run file (explicit next / recovery).
    ///
    /// Shows an explicit-dismiss level intro for an unseen tutorial hint. In-session
    /// restart keeps the existing session and does not call this path.
    func startLevel(id: String? = nil, showIntro: Bool? = nil) {
        clearMoveHold()
        cancelShowOutcome()
        audioDirector.reset()
        settings.applyAudio()
        scene.prepareForNewSession()
        recoveryMessage = nil
        gameplayNotice = nil
        shellCampaign = .sokoban
        refreshPersistenceDiagnostic()

        let levelID = id ?? currentLevelID
        guard let descriptor = catalog.descriptor(id: levelID) else {
            activePlay = nil
            enterPresentation(.faulted)
            faultMessage = "Unknown level: \(levelID)"
            audioDirector.reset()
            refreshPublishedState()
            return
        }

        do {
            let level = descriptor.makeLevel()
            let newSession = try GameSession(
                level: level,
                levelID: descriptor.id,
                contentHash: descriptor.contentHash,
                saveSink: runPersistence
            )
            let resolvedShowIntro = shouldShowIntro(for: descriptor, override: showIntro)
            bootstrapSession(newSession, descriptor: descriptor, showIntro: resolvedShowIntro)
        } catch {
            activePlay = nil
            enterPresentation(.faulted)
            faultMessage = "Failed to load level: \(error)"
            audioDirector.reset()
            refreshPublishedState()
        }
    }

    /// Clears a bad run and starts catalog level 1.
    func beginFreshRunFromRecovery() {
        runPersistence.removeRunFile()
        recoveryMessage = nil
        guard let first = catalog.levels.first else {
            enterPresentation(.faulted)
            faultMessage = "No levels available."
            return
        }
        currentLevelID = first.id
        startLevel(id: first.id, showIntro: true)
    }

    /// Dismisses the level-intro overlay and begins accepting moves.
    ///
    /// Cave sessions stay in ``SessionPhase/ready`` until the first gameplay
    /// intent; Sokoban enters ``SessionPhase/playing`` via the existing session.
    func dismissLevelIntro() {
        guard presentationPhase == .levelIntro else { return }
        if !isCaveMode {
            markCurrentIntroHintSeen()
        }
        enterPlayingPresentation()
        refreshPublishedState()
    }

    /// Enters Sokoban from the top-level picker.
    func selectSokobanFromGameSelection() {
        guard presentationPhase == .gameSelection else { return }
        shellCampaign = .sokoban
        activePlay = nil
        if progressPersistence.file.isFreshCampaign {
            startLevel(id: catalog.first.id, showIntro: true)
        } else {
            openLaunchMenu()
        }
    }

    /// Enters Cave from the top-level picker.
    func selectCaveFromGameSelection() {
        guard presentationPhase == .gameSelection else { return }
        shellCampaign = .cave
        activePlay = nil
        if progressPersistence.isFreshCaveCampaign {
            startCaveLevel(id: caveCatalog.first.id)
        } else {
            openLaunchMenu()
        }
    }

    func startCaveLevel(id: String) {
        guard let descriptor = caveCatalog.descriptor(id: id) else {
            activePlay = nil
            faultMessage = "Unknown cave level: \(id)"
            enterPresentation(.faulted)
            refreshPublishedState()
            return
        }

        do {
            let level = descriptor.makeLevel()
            let newSession = try CaveSession(level: level, levelID: descriptor.id)
            clearMoveHold()
            cancelShowOutcome()
            outcome.reset()
            scene.prepareForNewSession()
            scene.presentsCaveContent = true
            audioDirector.reset()
            settings.applyAudio()

            let emission = newSession.start()
            activePlay = .cave(newSession)
            shellCampaign = .cave
            currentLevelID = descriptor.id
            levelTitle = caveCatalog.title(for: descriptor)
            tutorialHintText = caveCatalog.tutorialHint(for: descriptor)
            faultMessage = nil
            recoveryMessage = nil
            overlayReturnOrigin = nil
            progressPersistence.selectCaveLevel(descriptor.id)
            outcome.configure(game: .cave, nextLevelID: caveCatalog.descriptor(after: descriptor.id)?.id)

            applyEmission(emission)
            enterLevelIntro()
            refreshPublishedState()
        } catch {
            activePlay = nil
            faultMessage = "Höhle konnte nicht geladen werden: \(error)"
            enterPresentation(.faulted)
            refreshPublishedState()
        }
    }

    func continueCampaign() {
        switch shellCampaign {
        case .sokoban:
            continueSokobanCampaign()
        case .cave:
            continueCaveCampaign()
        }
    }

    private func continueSokobanCampaign() {
        switch runPersistence.load() {
        case .loaded(let file):
            restoreRun(file)
        case .absent:
            let levelID =
                progressPersistence.file.lastSelectedLevelID
                .flatMap { progressPersistence.file.isUnlocked($0) ? $0 : nil }
                ?? catalog.levels.first(where: { progressPersistence.file.isUnlocked($0.id) })?.id
                ?? catalog.first.id
            startSelectedLevel(id: levelID)
        case .invalid(let message, _):
            enterRunRecovery(message: message)
        case .readFailed(let message):
            enterRunRecovery(message: message)
        }
    }

    private func continueCaveCampaign() {
        let levelID =
            progressPersistence.file.lastSelectedCaveLevelID
            .flatMap { progressPersistence.file.isCaveUnlocked($0) ? $0 : nil }
            ?? caveCatalog.levels.first(where: {
                progressPersistence.file.isCaveUnlocked($0.id)
            })?.id
            ?? caveCatalog.first.id
        startSelectedLevel(id: levelID)
    }

    /// Wipes run + campaign progress for the active shell campaign and restarts.
    func resetCampaignProgressFromLaunchMenu() {
        guard presentationPhase == .launchMenu else { return }
        switch shellCampaign {
        case .sokoban:
            runPersistence.removeRunFile()
            progressPersistence.resetToFresh(firstLevelID: catalog.first.id)
            outcome.reset()
            startLevel(id: catalog.first.id, showIntro: true)
        case .cave:
            progressPersistence.resetCaveToFresh(
                tutorialLevelIDs: caveCatalog.tutorialLevelIDs
            )
            outcome.reset()
            startCaveLevel(id: caveCatalog.first.id)
        }
    }

    func startSelectedLevel(id: String, showIntro: Bool? = nil) {
        switch shellCampaign {
        case .sokoban:
            guard progressPersistence.availability(for: id, in: catalog) != .locked else { return }
            progressPersistence.selectLevel(id)
            startLevel(id: id, showIntro: showIntro)
        case .cave:
            guard progressPersistence.caveAvailability(for: id, in: caveCatalog) != .locked else {
                return
            }
            progressPersistence.selectCaveLevel(id)
            startCaveLevel(id: id)
        }
    }

    func levelAvailability(for descriptor: SokobanLevelDescriptor) -> LevelAvailability {
        progressPersistence.availability(for: descriptor.id, in: catalog)
    }

    func caveLevelAvailability(for descriptor: CaveLevelDescriptor) -> LevelAvailability {
        progressPersistence.caveAvailability(for: descriptor.id, in: caveCatalog)
    }

    private func shouldShowIntro(
        for descriptor: SokobanLevelDescriptor,
        override: Bool?
    ) -> Bool {
        if let override { return override }
        guard let hintID = descriptor.tutorialHintID, !hintID.isEmpty else { return false }
        return !progressPersistence.file.hasSeenHint(hintID)
    }

    func bootstrapFromPersistence() {
        let decision = PlayBootstrapCoordinator.decide(
            loadResult: runPersistence.load(),
            isFreshCampaign: progressPersistence.file.isFreshCampaign
        )
        switch decision {
        case .openGameSelection:
            openGameSelection()
        case .restoreRun(let file):
            restoreRun(file)
        case .enterRecovery(let message):
            enterRunRecovery(message: message)
        }
    }

    private func restoreRun(_ file: SokobanRunFileV1) {
        do {
            let restored = try SokobanRunRestorer.restore(
                file,
                catalogLookup: { [catalog] in catalog.descriptor(id: $0) }
            )
            let newSession = GameSession(restored: restored, saveSink: runPersistence)
            guard let descriptor = catalog.descriptor(id: restored.levelID) else {
                enterRunRecovery(message: "Saved level is no longer in the catalog.")
                return
            }
            cancelShowOutcome()
            audioDirector.reset()
            settings.applyAudio()
            scene.prepareForNewSession()
            // Mid-run restore skips the intro; the player already knows the level.
            bootstrapSession(newSession, descriptor: descriptor, showIntro: false)
        } catch {
            if let failure = error as? SokobanRunRestoreFailure {
                switch failure {
                case .contentHashMismatch, .ruleVersionMismatch, .unknownSchemaVersion, .unknownCheckpointSchemaVersion:
                    // Incompatible saves start fresh; there is no migration path.
                    startLevel(id: catalog.descriptor(id: file.levelID)?.id ?? catalog.first.id)
                    return
                default:
                    break
                }
            }
            let message = SokobanRunRestoreMessages.text(for: error)
            _ = runPersistence.quarantineLoadedInvalidFile(message: message)
            enterRunRecovery(message: message)
        }
    }

    private func bootstrapSession(
        _ newSession: GameSession,
        descriptor: SokobanLevelDescriptor,
        showIntro: Bool
    ) {
        let emission = newSession.start()
        activePlay = .sokoban(newSession)
        scene.presentsCaveContent = false
        outcome.reset()
        currentLevelID = descriptor.id
        faultMessage = nil
        recoveryMessage = nil
        overlayReturnOrigin = nil
        levelTitle = catalog.title(for: descriptor)
        tutorialHintText = catalog.tutorialHint(for: descriptor)
        outcome.configure(game: .sokoban, nextLevelID: catalog.descriptor(after: descriptor.id)?.id)
        applyEmission(emission)
        applyEmissionSideEffects(emission)
        // Restored/completed runs use synchronize (no completion jingle).
        if newSession.phase == .outcomePresenting {
            // Hard-resync has no animation; land on the choice overlay promptly.
            enterOutcomeAwaitingChoice()
        } else if showIntro {
            enterLevelIntro()
        } else {
            enterPlayingPresentation()
        }
        refreshPublishedState()
    }

    private func markCurrentIntroHintSeen() {
        if let hintID = catalog.descriptor(id: currentLevelID)?.tutorialHintID {
            progressPersistence.markHintSeen(hintID)
        }
    }

    private func enterRunRecovery(message: String) {
        activePlay = nil
        enterPresentation(.runRecovery)
        recoveryMessage = message
        faultMessage = nil
        overlayReturnOrigin = nil
        audioDirector.reset()
        refreshPublishedState()
    }

    func refreshPersistenceDiagnostic() {
        if let reason = runPersistence.disabledReason {
            persistenceDiagnostic = reason
        } else if let reason = progressPersistence.disabledReason {
            persistenceDiagnostic = reason
        } else if let diagnostic = progressPersistence.loadDiagnostic {
            persistenceDiagnostic = diagnostic
        } else {
            persistenceDiagnostic = nil
        }
    }
}
