import Foundation
import GameCore

/// Pure mapping from controller/session state into overlay presentation models.
enum PresentationFactory {
    static func levelIntro(title: String, body: String) -> LevelIntroPresentation {
        LevelIntroPresentation(
            title: title,
            body: body,
            continueTitle: AppStrings.text(.uiIntroClose),
            skipHint: AppStrings.text(.uiIntroSkipHint)
        )
    }

    static func pause(isCaveMode: Bool) -> PausePresentation {
        PausePresentation(
            title: AppStrings.text(.uiPauseTitle),
            hint: AppStrings.text(isCaveMode ? .uiPauseHintCave : .uiPauseHint),
            resumeTitle: AppStrings.text(.uiPauseResume),
            restartTitle: AppStrings.text(.uiPauseRestart),
            settingsTitle: AppStrings.text(.uiPauseSettings),
            levelSelectTitle: AppStrings.text(.uiLaunchBackToGames),
            helpTitle: AppStrings.text(.uiPauseHelp)
        )
    }

    static func help(isCaveMode: Bool, catalog: SokobanContentCatalog) -> HelpPresentation {
        if isCaveMode {
            return HelpPresentation(
                title: AppStrings.text(.uiHelpTitle),
                backTitle: AppStrings.text(.uiHelpBack),
                controls: [
                    HelpControlRow(
                        id: "move",
                        title: AppStrings.text(.uiHelpMoveTitle),
                        detail: AppStrings.text(.uiHelpMoveDetail)
                    ),
                    HelpControlRow(
                        id: "wait",
                        title: AppStrings.text(.uiHelpWaitTitle),
                        detail: AppStrings.text(.uiHelpWaitDetail)
                    ),
                    HelpControlRow(
                        id: "restart",
                        title: AppStrings.text(.uiHelpRestartTitle),
                        detail: AppStrings.text(.uiHelpRestartDetail)
                    ),
                    HelpControlRow(
                        id: "pause",
                        title: AppStrings.text(.uiHelpPauseTitle),
                        detail: AppStrings.text(.uiHelpPauseDetail)
                    ),
                ],
                tutorialSectionTitle: "",
                tutorialHints: []
            )
        }
        return HelpPresentation(
            title: AppStrings.text(.uiHelpTitle),
            backTitle: AppStrings.text(.uiHelpBack),
            controls: [
                HelpControlRow(
                    id: "move",
                    title: AppStrings.text(.uiHelpMoveTitle),
                    detail: AppStrings.text(.uiHelpMoveDetail)
                ),
                HelpControlRow(
                    id: "undo_redo",
                    title: AppStrings.text(.uiHelpUndoRedoTitle),
                    detail: AppStrings.text(.uiHelpUndoRedoDetail)
                ),
                HelpControlRow(
                    id: "restart",
                    title: AppStrings.text(.uiHelpRestartTitle),
                    detail: AppStrings.text(.uiHelpRestartDetail)
                ),
                HelpControlRow(
                    id: "pause",
                    title: AppStrings.text(.uiHelpPauseTitle),
                    detail: AppStrings.text(.uiHelpPauseDetail)
                ),
            ],
            tutorialSectionTitle: AppStrings.text(.uiHelpTutorialSection),
            tutorialHints: catalog.levels.compactMap { descriptor in
                guard let hintID = descriptor.tutorialHintID, !hintID.isEmpty else { return nil }
                return HelpTutorialHint(
                    id: hintID,
                    title: catalog.title(for: descriptor),
                    body: catalog.tutorialHint(for: descriptor)
                )
            }
        )
    }

    static func settings(
        snapshot: AppSettingsSnapshot,
        musicTrackCatalog: MusicTrackCatalog,
        themeCatalog: ThemeCatalog,
        selectedThemeID: String
    ) -> SettingsPresentation {
        let musicGroups: [SettingsPresentation.MusicTrackGroup] = AudioGameMode.allCases.compactMap {
            game in
            let options = musicTrackCatalog.selectableTracks(for: game)
            guard options.count > 1 else { return nil }
            let selected =
                musicTrackCatalog.resolvedTrack(
                    preferredID: snapshot.musicTrackID(for: game),
                    for: game
                ) ?? options.first
            let title: String
            switch game {
            case .sokoban:
                title = AppStrings.text(.uiSettingsMusicTrackSokoban)
            case .cave:
                title = AppStrings.text(.uiSettingsMusicTrackCave)
            }
            return SettingsPresentation.MusicTrackGroup(
                id: SettingsOverlay.musicTrackFocusID(for: game),
                game: game,
                title: title,
                hint: AppStrings.text(.uiSettingsMusicTrackHint),
                options: options.map {
                    SettingsPresentation.MusicTrackOption(
                        id: $0.id,
                        title: AppStrings.text(id: $0.displayNameID)
                    )
                },
                selectedTrackID: selected?.id ?? snapshot.musicTrackID(for: game),
                creditSummary: selected?.credit.summaryLine ?? "",
                attributionNotice: selected?.credit.attributionNotice
            )
        }
        return SettingsPresentation(
            title: AppStrings.text(.uiSettingsTitle),
            backTitle: AppStrings.text(.uiSettingsBack),
            themeTitle: AppStrings.text(.uiSettingsTheme),
            themeOptions: themeCatalog.selectableThemes.map {
                SettingsPresentation.ThemeOption(
                    id: $0.id,
                    title: AppStrings.text(id: $0.displayNameID)
                )
            },
            selectedThemeID: selectedThemeID,
            musicTrackGroups: musicGroups,
            reduceMotionTitle: AppStrings.text(.uiSettingsReduceMotion),
            reduceMotionDetail: AppStrings.text(.uiSettingsReduceMotionDetail),
            reduceMotionEnabled: snapshot.reduceMotionEnabled,
            musicVolumeTitle: AppStrings.text(.uiSettingsMusicVolume),
            musicVolume: snapshot.musicVolume,
            effectsVolumeTitle: AppStrings.text(.uiSettingsEffectsVolume),
            effectsVolume: snapshot.effectsVolume,
            muteTitle: AppStrings.text(.uiSettingsMute),
            isMuted: snapshot.isMuted
        )
    }

    struct OutcomeInput: Equatable, Sendable {
        var isCaveMode: Bool
        var title: String
        var hint: String
        var primaryTitle: String
        var moveCount: Int
        var pushCount: Int
        var completedGoalCount: Int
        var totalGoalCount: Int
        var canRestart: Bool
        var canUndo: Bool
        var bestMoveCount: Int?
        var bestPushCount: Int?
        var newBestMoves: Bool
        var newBestPushes: Bool
    }

    static func outcome(_ input: OutcomeInput) -> OutcomePresentation {
        if input.isCaveMode {
            return OutcomePresentation(
                title: input.title,
                metrics: [
                    OutcomeMetricLine(
                        id: "diamonds",
                        title: AppStrings.text(.uiHudDiamonds),
                        value: "\(input.completedGoalCount)/\(input.totalGoalCount)"
                    ),
                    OutcomeMetricLine(
                        id: "time",
                        title: AppStrings.text(.uiHudTime),
                        value: String(input.moveCount)
                    ),
                    OutcomeMetricLine(
                        id: "score",
                        title: AppStrings.text(.uiHudScore),
                        value: String(input.pushCount)
                    ),
                ],
                records: [],
                hint: input.hint,
                primaryTitle: input.primaryTitle,
                playAgainTitle: AppStrings.text(.uiOutcomePlayAgain),
                playAgainEnabled: input.canRestart,
                undoTitle: AppStrings.text(.uiOutcomeUndo),
                undoEnabled: false,
                levelSelectTitle: AppStrings.text(.uiLaunchBackToGames)
            )
        }

        var records: [OutcomeRecordLine] = []
        if let bestMoves = input.bestMoveCount {
            records.append(
                OutcomeRecordLine(
                    title: AppStrings.text(.uiOutcomeBestMoves),
                    value: String(bestMoves),
                    isNewRecord: input.newBestMoves,
                    newRecordTitle: AppStrings.text(.uiOutcomeNewRecordMoves)
                )
            )
        }
        if let bestPushes = input.bestPushCount {
            records.append(
                OutcomeRecordLine(
                    title: AppStrings.text(.uiOutcomeBestPushes),
                    value: String(bestPushes),
                    isNewRecord: input.newBestPushes,
                    newRecordTitle: AppStrings.text(.uiOutcomeNewRecordPushes)
                )
            )
        }
        return OutcomePresentation(
            title: input.title,
            metrics: [
                OutcomeMetricLine(
                    id: "moves",
                    title: AppStrings.text(.uiHudMoves),
                    value: String(input.moveCount)
                ),
                OutcomeMetricLine(
                    id: "pushes",
                    title: AppStrings.text(.uiHudPushes),
                    value: String(input.pushCount)
                ),
                OutcomeMetricLine(
                    id: "goals",
                    title: AppStrings.text(.uiHudGoals),
                    value: "\(input.completedGoalCount)/\(input.totalGoalCount)"
                ),
            ],
            records: records,
            hint: input.hint,
            primaryTitle: input.primaryTitle,
            playAgainTitle: AppStrings.text(.uiOutcomePlayAgain),
            playAgainEnabled: input.canRestart,
            undoTitle: AppStrings.text(.uiOutcomeUndo),
            undoEnabled: input.canUndo,
            levelSelectTitle: AppStrings.text(.uiOutcomeLevelSelect)
        )
    }

    static func boardAccessibilityLabel(levelTitle: String) -> String {
        "\(levelTitle), \(AppStrings.text(.uiBoardLabel))"
    }

    static func boardAccessibilityValue(
        snapshot: RenderSnapshot?,
        isCaveMode: Bool
    ) -> String {
        guard let snapshot else {
            return AppStrings.text(.uiBoardUnavailable)
        }
        let player = snapshot.player.position
        let position =
            "\(AppStrings.text(.uiBoardPlayer)) "
            + "\(AppStrings.text(.uiBoardColumn)) \(player.column + 1), "
            + "\(AppStrings.text(.uiBoardRow)) \(player.row + 1). "
        if isCaveMode {
            return position
                + "\(AppStrings.text(.uiHudDiamonds)) "
                + "\(snapshot.completedGoalCount) von \(snapshot.totalGoalCount). "
                + "\(AppStrings.text(.uiHudTime)) \(snapshot.moveCount), "
                + "\(AppStrings.text(.uiHudScore)) \(snapshot.pushCount)."
        }
        return position
            + "\(AppStrings.text(.uiHudGoals)) "
            + "\(snapshot.completedGoalCount) von \(snapshot.totalGoalCount). "
            + "\(AppStrings.text(.uiHudMoves)) \(snapshot.moveCount), "
            + "\(AppStrings.text(.uiHudPushes)) \(snapshot.pushCount)."
    }
}
