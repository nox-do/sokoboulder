import Foundation

/// Stable string IDs for UI chrome (menus, HUD, overlays).
///
/// Level titles and tutorial hints live in
/// `Resources/Localization/ContentStrings.de.json` via ``ContentStringTable``.
enum AppStringID: String, CaseIterable, Sendable {
    // Level intro
    case uiIntroContinue = "ui.intro.continue"
    case uiIntroSkipHint = "ui.intro.skip_hint"
    case uiIntroClose = "ui.intro.close"
    case uiCaveIntroStart = "ui.cave.intro.start"
    case uiCaveIntroDiamonds = "ui.cave.intro.diamonds"
    case uiCaveIntroTime = "ui.cave.intro.time"
    case uiCaveIntroReadyHint = "ui.cave.intro.ready_hint"

    // Outcome
    case uiOutcomeLevelComplete = "ui.outcome.level_complete"
    case uiOutcomeTutorialComplete = "ui.outcome.tutorial_complete"
    case uiOutcomeNextLevel = "ui.outcome.next_level"
    case uiOutcomePlayAgain = "ui.outcome.play_again"
    case uiOutcomeUndo = "ui.outcome.undo"
    case uiOutcomeBack = "ui.outcome.back"
    case uiOutcomeMenu = "ui.outcome.menu"
    case uiOutcomeLevelSelect = "ui.outcome.level_select"
    case uiOutcomeHintNext = "ui.outcome.hint_next"
    case uiOutcomeHintAgain = "ui.outcome.hint_again"
    case uiOutcomeHintBack = "ui.outcome.hint_back"
    case uiOutcomeHintCave = "ui.outcome.hint_cave"
    case uiOutcomeCaveFailed = "ui.outcome.cave_failed"
    case uiOutcomeNewRecordMoves = "ui.outcome.new_record_moves"
    case uiOutcomeNewRecordPushes = "ui.outcome.new_record_pushes"
    case uiOutcomeNewRecordScore = "ui.outcome.new_record_score"
    case uiOutcomeNewRecordTime = "ui.outcome.new_record_time"
    case uiOutcomeBestMoves = "ui.outcome.best_moves"
    case uiOutcomeBestPushes = "ui.outcome.best_pushes"
    case uiOutcomeBestScore = "ui.outcome.best_score"
    case uiOutcomeBestTime = "ui.outcome.best_time"

    // Launch / level select
    case uiGameSelectTitle = "ui.game_select.title"
    case uiGameSelectSubtitle = "ui.game_select.subtitle"
    case uiGameSelectSokoban = "ui.game_select.sokoban"
    case uiGameSelectCave = "ui.game_select.cave"
    case uiGameSelectCaveComingSoon = "ui.game_select.cave_coming_soon"
    case uiGameSelectCaveDemoHint = "ui.game_select.cave_demo_hint"
    case uiCaveDemoHint = "ui.cave.demo_hint"
    case uiLaunchTitle = "ui.launch.title"
    case uiLaunchTitleCave = "ui.launch.title_cave"
    case uiCheatLevelsUnlocked = "ui.cheat.levels_unlocked"
    case uiLaunchContinue = "ui.launch.continue"
    case uiLaunchSelectLevel = "ui.launch.select_level"
    case uiLaunchHelp = "ui.launch.help"
    case uiLaunchSettings = "ui.launch.settings"
    case uiLaunchResetProgress = "ui.launch.reset_progress"
    case uiLaunchBackToGames = "ui.launch.back_to_games"
    case uiLevelSelectTitle = "ui.level_select.title"
    case uiLevelSelectBack = "ui.level_select.back"
    case uiLevelSelectLocked = "ui.level_select.locked"
    case uiLevelSelectAvailable = "ui.level_select.available"
    case uiLevelSelectCompleted = "ui.level_select.completed"

    // HUD
    case uiHudMoves = "ui.hud.moves"
    case uiHudPushes = "ui.hud.pushes"
    case uiHudGoals = "ui.hud.goals"
    case uiHudDiamonds = "ui.hud.diamonds"
    case uiHudTime = "ui.hud.time"
    case uiHudScore = "ui.hud.score"
    case uiHudUndo = "ui.hud.undo"
    case uiHudRedo = "ui.hud.redo"
    case uiHudAvailable = "ui.hud.available"
    case uiHudUnavailable = "ui.hud.unavailable"
    case uiBoardLabel = "ui.board.label"
    case uiBoardPlayer = "ui.board.player"
    case uiBoardColumn = "ui.board.column"
    case uiBoardRow = "ui.board.row"
    case uiBoardUnavailable = "ui.board.unavailable"
    case uiDeadlockPrevented = "ui.deadlock.prevented"
    case uiDeadlockRecovered = "ui.deadlock.recovered"

    // Pause
    case uiPauseTitle = "ui.pause.title"
    case uiPauseHint = "ui.pause.hint"
    case uiPauseHintCave = "ui.pause.hint_cave"
    case uiPauseResume = "ui.pause.resume"
    case uiPauseRestart = "ui.pause.restart"
    case uiPauseLevelSelect = "ui.pause.level_select"
    case uiPauseHelp = "ui.pause.help"
    case uiPauseSettings = "ui.pause.settings"

    // Help
    case uiHelpTitle = "ui.help.title"
    case uiHelpBack = "ui.help.back"
    case uiHelpControlsTitle = "ui.help.controls_title"
    case uiHelpMoveTitle = "ui.help.move.title"
    case uiHelpMoveDetail = "ui.help.move.detail"
    case uiHelpWaitTitle = "ui.help.wait.title"
    case uiHelpWaitDetail = "ui.help.wait.detail"
    case uiHelpUndoRedoTitle = "ui.help.undo_redo.title"
    case uiHelpUndoRedoDetail = "ui.help.undo_redo.detail"
    case uiHelpRestartTitle = "ui.help.restart.title"
    case uiHelpRestartDetail = "ui.help.restart.detail"
    case uiHelpPauseTitle = "ui.help.pause.title"
    case uiHelpPauseDetail = "ui.help.pause.detail"
    case uiHelpTutorialSection = "ui.help.tutorial_section"

    // Settings
    case uiSettingsTitle = "ui.settings.title"
    case uiSettingsBack = "ui.settings.back"
    case uiSettingsTheme = "ui.settings.theme"
    case uiSettingsThemeHint = "ui.settings.theme_hint"
    case uiSettingsReduceMotion = "ui.settings.reduce_motion"
    case uiSettingsReduceMotionDetail = "ui.settings.reduce_motion_detail"
    case uiSettingsMusicTrack = "ui.settings.music_track"
    case uiSettingsMusicTrackSokoban = "ui.settings.music_track_sokoban"
    case uiSettingsMusicTrackCave = "ui.settings.music_track_cave"
    case uiSettingsMusicTrackHint = "ui.settings.music_track_hint"
    case uiSettingsMusicVolume = "ui.settings.music_volume"
    case uiSettingsEffectsVolume = "ui.settings.effects_volume"
    case uiSettingsMute = "ui.settings.mute"

    // Themes
    case themeStandardName = "theme.standard.name"
    case themeDungeonName = "theme.dungeon.name"
    case themeKenneyName = "theme.kenney.name"

    // Music tracks
    case musicSokobanPuzzlingName = "music.sokoban.puzzling.name"
    case musicSokobanPreludeName = "music.sokoban.prelude.name"
    case musicCaveWonderName = "music.cave.wonder.name"
    case musicCaveTinkeringName = "music.cave.tinkering.name"

    // Recovery / fault
    case uiRecoveryTitle = "ui.recovery.title"
    case uiRecoveryFallback = "ui.recovery.fallback"
    case uiRecoveryStartFresh = "ui.recovery.start_fresh"
    case uiFaultTitle = "ui.fault.title"
    case uiFaultReload = "ui.fault.reload"

    // Menus
    case uiMenuUndo = "ui.menu.undo"
    case uiMenuRedo = "ui.menu.redo"
    case uiMenuGame = "ui.menu.game"
    case uiMenuPause = "ui.menu.pause"
    case uiMenuResume = "ui.menu.resume"
    case uiMenuRestartLevel = "ui.menu.restart_level"
}

/// Lookup table for ``AppStringID``. Missing dynamic IDs fall back to the raw key.
enum AppStrings {
    private static let german: [String: String] = [
        AppStringID.uiIntroContinue.rawValue: "Weiter",
        AppStringID.uiIntroSkipHint.rawValue: "Return, Leertaste oder Escape startet",
        AppStringID.uiIntroClose.rawValue: "Schließen",
        AppStringID.uiCaveIntroStart.rawValue: "Starten",
        AppStringID.uiCaveIntroDiamonds.rawValue: "Diamanten",
        AppStringID.uiCaveIntroTime.rawValue: "Zeit",
        AppStringID.uiCaveIntroReadyHint.rawValue:
            "Return, Leertaste oder Escape — danach startet die Höhle mit der ersten Bewegung",

        AppStringID.uiOutcomeLevelComplete.rawValue: "Level geschafft",
        AppStringID.uiOutcomeTutorialComplete.rawValue: "Tutorial geschafft",
        AppStringID.uiOutcomeNextLevel.rawValue: "Nächstes Level",
        AppStringID.uiOutcomePlayAgain.rawValue: "Noch einmal",
        AppStringID.uiOutcomeUndo.rawValue: "Letzten Zug rückgängig",
        AppStringID.uiOutcomeBack.rawValue: "Zur Übersicht",
        AppStringID.uiOutcomeMenu.rawValue: "Zur Übersicht",
        AppStringID.uiOutcomeLevelSelect.rawValue: "Levelauswahl",
        AppStringID.uiOutcomeHintNext.rawValue:
            "Return/Space bestätigt die markierte Aktion · Z: Undo",
        AppStringID.uiOutcomeHintAgain.rawValue:
            "Return/Space bestätigt die markierte Aktion · Z: Undo",
        AppStringID.uiOutcomeHintBack.rawValue:
            "Return/Space bestätigt die markierte Aktion · Z: Undo",
        AppStringID.uiOutcomeHintCave.rawValue:
            "Return/Space bestätigt die markierte Aktion",
        AppStringID.uiOutcomeCaveFailed.rawValue: "Höhle gescheitert",
        AppStringID.uiOutcomeNewRecordMoves.rawValue: "Neuer Zugrekord",
        AppStringID.uiOutcomeNewRecordPushes.rawValue: "Neuer Schubrekord",
        AppStringID.uiOutcomeNewRecordScore.rawValue: "Neuer Punkte-Rekord",
        AppStringID.uiOutcomeNewRecordTime.rawValue: "Neuer Zeit-Rekord",
        AppStringID.uiOutcomeBestMoves.rawValue: "Beste Züge",
        AppStringID.uiOutcomeBestPushes.rawValue: "Beste Schübe",
        AppStringID.uiOutcomeBestScore.rawValue: "Beste Punkte",
        AppStringID.uiOutcomeBestTime.rawValue: "Beste Restzeit",

        AppStringID.uiGameSelectTitle.rawValue: "SokoBoulder",
        AppStringID.uiGameSelectSubtitle.rawValue: "Spielauswahl",
        AppStringID.uiGameSelectSokoban.rawValue: "Sokoban",
        AppStringID.uiGameSelectCave.rawValue: "Höhle",
        AppStringID.uiGameSelectCaveComingSoon.rawValue: "Demnächst",
        AppStringID.uiGameSelectCaveDemoHint.rawValue: "Tutorials frei · danach freischalten",
        AppStringID.uiCaveDemoHint.rawValue:
            "Sammle Diamanten und erreiche den Ausgang. Leertaste = warten.",
        AppStringID.uiLaunchTitle.rawValue: "Sokoban",
        AppStringID.uiLaunchTitleCave.rawValue: "Höhle",
        AppStringID.uiCheatLevelsUnlocked.rawValue: "Alle Level freigeschaltet",
        AppStringID.uiLaunchContinue.rawValue: "Fortsetzen",
        AppStringID.uiLaunchSelectLevel.rawValue: "Levelauswahl",
        AppStringID.uiLaunchHelp.rawValue: "Hilfe",
        AppStringID.uiLaunchSettings.rawValue: "Einstellungen",
        AppStringID.uiLaunchResetProgress.rawValue: "Spielstand zurücksetzen",
        AppStringID.uiLaunchBackToGames.rawValue: "Spielauswahl",
        AppStringID.uiLevelSelectTitle.rawValue: "Levelauswahl",
        AppStringID.uiLevelSelectBack.rawValue: "Zurück",
        AppStringID.uiLevelSelectLocked.rawValue: "Gesperrt",
        AppStringID.uiLevelSelectAvailable.rawValue: "Verfügbar",
        AppStringID.uiLevelSelectCompleted.rawValue: "Geschafft",

        AppStringID.uiHudMoves.rawValue: "Züge",
        AppStringID.uiHudPushes.rawValue: "Schübe",
        AppStringID.uiHudGoals.rawValue: "Ziele",
        AppStringID.uiHudDiamonds.rawValue: "Diamanten",
        AppStringID.uiHudTime.rawValue: "Zeit",
        AppStringID.uiHudScore.rawValue: "Punkte",
        AppStringID.uiHudUndo.rawValue: "Undo",
        AppStringID.uiHudRedo.rawValue: "Redo",
        AppStringID.uiHudAvailable.rawValue: "verfügbar",
        AppStringID.uiHudUnavailable.rawValue: "nicht verfügbar",
        AppStringID.uiBoardLabel.rawValue: "Spielfeld",
        AppStringID.uiBoardPlayer.rawValue: "Spielerposition:",
        AppStringID.uiBoardColumn.rawValue: "Spalte",
        AppStringID.uiBoardRow.rawValue: "Zeile",
        AppStringID.uiBoardUnavailable.rawValue: "Spielfeld wird geladen.",
        AppStringID.uiDeadlockPrevented.rawValue:
            "Dieser Schub würde die Kiste dauerhaft festsetzen und wurde verhindert.",
        AppStringID.uiDeadlockRecovered.rawValue:
            "Festgefahrenen Spielstand bis vor den letzten irreversiblen Schub zurückgesetzt.",

        AppStringID.uiPauseTitle.rawValue: "Pause",
        AppStringID.uiPauseHint.rawValue: "Escape → Spielauswahl · Fortsetzen im Menü",
        AppStringID.uiPauseHintCave.rawValue: "Escape → Spielauswahl · Fortsetzen im Menü",
        AppStringID.uiPauseResume.rawValue: "Fortsetzen",
        AppStringID.uiPauseRestart.rawValue: "Neu starten",
        AppStringID.uiPauseLevelSelect.rawValue: "Levelauswahl",
        AppStringID.uiPauseHelp.rawValue: "Hilfe",
        AppStringID.uiPauseSettings.rawValue: "Einstellungen",

        AppStringID.uiHelpTitle.rawValue: "Hilfe & Steuerung",
        AppStringID.uiHelpBack.rawValue: "Zurück",
        AppStringID.uiHelpControlsTitle.rawValue: "Steuerung",
        AppStringID.uiHelpMoveTitle.rawValue: "Bewegung",
        AppStringID.uiHelpMoveDetail.rawValue: "Pfeiltasten oder WASD",
        AppStringID.uiHelpWaitTitle.rawValue: "Warten",
        AppStringID.uiHelpWaitDetail.rawValue: "Leertaste lässt einen Tick ohne Bewegung verstreichen",
        AppStringID.uiHelpUndoRedoTitle.rawValue: "Undo und Redo",
        AppStringID.uiHelpUndoRedoDetail.rawValue: "Z oder ⌘Z · Redo mit ⇧⌘Z",
        AppStringID.uiHelpRestartTitle.rawValue: "Neustart",
        AppStringID.uiHelpRestartDetail.rawValue: "R startet das Level neu",
        AppStringID.uiHelpPauseTitle.rawValue: "Pause / Zurück",
        AppStringID.uiHelpPauseDetail.rawValue: "Escape öffnet Pause oder geht zurück",
        AppStringID.uiHelpTutorialSection.rawValue: "Tutorial-Hinweise",

        AppStringID.uiSettingsTitle.rawValue: "Einstellungen",
        AppStringID.uiSettingsBack.rawValue: "Zurück",
        AppStringID.uiSettingsTheme.rawValue: "Darstellung",
        AppStringID.uiSettingsThemeHint.rawValue: "Pfeiltasten wechseln das Theme",
        AppStringID.uiSettingsReduceMotion.rawValue: "Bewegung reduzieren",
        AppStringID.uiSettingsReduceMotionDetail.rawValue:
            "Wirkt zusätzlich zur Systemeinstellung (nur Darstellung)",
        AppStringID.uiSettingsMusicTrack.rawValue: "Hintergrundmusik",
        AppStringID.uiSettingsMusicTrackSokoban.rawValue: "Sokoban-Musik",
        AppStringID.uiSettingsMusicTrackCave.rawValue: "Höhlen-Musik",
        AppStringID.uiSettingsMusicTrackHint.rawValue: "Pfeiltasten wechseln den Track",
        AppStringID.uiSettingsMusicVolume.rawValue: "Musiklautstärke",
        AppStringID.uiSettingsEffectsVolume.rawValue: "Effektlautstärke",
        AppStringID.uiSettingsMute.rawValue: "Stummschalten",

        AppStringID.themeStandardName.rawValue: "Standard",
        AppStringID.themeDungeonName.rawValue: "Dungeon",
        AppStringID.themeKenneyName.rawValue: "Kenney",

        AppStringID.musicSokobanPuzzlingName.rawValue: "Puzzling",
        AppStringID.musicSokobanPreludeName.rawValue: "Prelude",
        AppStringID.musicCaveWonderName.rawValue: "Cave Wonder",
        AppStringID.musicCaveTinkeringName.rawValue: "Tinkering Cave",

        AppStringID.uiRecoveryTitle.rawValue: "Spielstand nicht ladbar",
        AppStringID.uiRecoveryFallback.rawValue: "Der gespeicherte Lauf ist nicht nutzbar.",
        AppStringID.uiRecoveryStartFresh.rawValue: "Neu beginnen",
        AppStringID.uiFaultTitle.rawValue: "Etwas ist schiefgelaufen",
        AppStringID.uiFaultReload.rawValue: "Level neu laden",

        AppStringID.uiMenuUndo.rawValue: "Widerrufen",
        AppStringID.uiMenuRedo.rawValue: "Wiederholen",
        AppStringID.uiMenuGame.rawValue: "Spiel",
        AppStringID.uiMenuPause.rawValue: "Pause",
        AppStringID.uiMenuResume.rawValue: "Fortsetzen",
        AppStringID.uiMenuRestartLevel.rawValue: "Level neu starten",
    ]

    static func text(_ id: AppStringID) -> String {
        text(id: id.rawValue)
    }

    /// Resolves a raw localization key for UI chrome.
    ///
    /// Level titles and hints use ``ContentStringTable`` instead.
    static func text(id: String) -> String {
        german[id] ?? id
    }
}
