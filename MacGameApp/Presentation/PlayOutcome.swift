import GameCore

/// Result copy and completion records for the current attempt.
@MainActor
struct PlayOutcome {
    private(set) var title = AppStrings.text(.uiOutcomeLevelComplete)
    private(set) var hint = ""
    private(set) var primaryAction: OutcomePrimaryAction = .openLaunchMenu
    private(set) var primaryTitle = AppStrings.text(.uiOutcomeBack)
    private(set) var records: [OutcomeRecordLine] = []
    private var completionRecorded = false

    mutating func configure(game: ShellCampaign, nextLevelID: String?) {
        primaryAction = nextLevelID.map { .nextLevel(id: $0) } ?? .openLaunchMenu
        if game == .cave {
            title = AppStrings.text(.uiOutcomeLevelComplete)
            hint = AppStrings.text(.uiOutcomeHintCave)
            primaryTitle = AppStrings.text(nextLevelID == nil ? .uiLaunchBackToGames : .uiOutcomeNextLevel)
        } else {
            title = AppStrings.text(nextLevelID == nil ? .uiOutcomeTutorialComplete : .uiOutcomeLevelComplete)
            hint = AppStrings.text(nextLevelID == nil ? .uiOutcomeHintBack : .uiOutcomeHintNext)
            primaryTitle = AppStrings.text(nextLevelID == nil ? .uiOutcomeBack : .uiOutcomeNextLevel)
        }
    }

    mutating func failCave() {
        title = AppStrings.text(.uiOutcomeCaveFailed)
        primaryAction = .playAgain
        primaryTitle = AppStrings.text(.uiOutcomePlayAgain)
        hint = AppStrings.text(.uiOutcomeHintCave)
    }

    mutating func reset() {
        completionRecorded = false
        records = []
    }

    mutating func recordSokoban(
        snapshot: RenderSnapshot, levelID: String,
        catalog: SokobanContentCatalog, progress: ProgressPersistence
    ) {
        guard !completionRecorded,
            let counters = snapshot.metrics.sokoban,
            let descriptor = catalog.descriptor(id: levelID)
        else { return }
        let delta = progress.recordCompletion(
            levelID: descriptor.id, contentHash: descriptor.contentHash,
            ruleVersion: SokobanRules.ruleVersion,
            moveCount: counters.moveCount, pushCount: counters.pushCount,
            nextLevelID: catalog.descriptor(after: levelID)?.id
        )
        completionRecorded = true
        records = PresentationFactory.outcomeRecords(for: delta)
    }

    mutating func recordCave(
        snapshot: RenderSnapshot, levelID: String,
        catalog: CaveContentCatalog, progress: ProgressPersistence
    ) {
        guard !completionRecorded,
            let counters = snapshot.metrics.cave,
            let descriptor = catalog.descriptor(id: levelID)
        else { return }
        let delta = progress.recordCaveCompletion(
            levelID: descriptor.id, contentHash: descriptor.contentHash,
            ruleVersion: CaveRules.ruleVersion,
            score: counters.score, remainingTicks: counters.remainingTicks,
            nextLevelID: catalog.descriptor(after: levelID)?.id
        )
        completionRecorded = true
        records = PresentationFactory.outcomeRecords(for: delta)
    }
}
