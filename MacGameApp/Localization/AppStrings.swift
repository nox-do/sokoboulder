import Foundation

/// Stable string IDs for UI chrome (menus, HUD, overlays).
///
/// Level titles and tutorial hints live in
/// `Resources/Localization/ContentStrings.de.json` via ``ContentStringTable``.
enum AppStringID: String, CaseIterable, Sendable {
    // Level intro
    case uiIntroContinue = "ui.intro.continue"
    case uiIntroSkipHint = "ui.intro.skip_hint"

    // Outcome
    case uiOutcomeLevelComplete = "ui.outcome.level_complete"
    case uiOutcomeTutorialComplete = "ui.outcome.tutorial_complete"
    case uiOutcomeNextLevel = "ui.outcome.next_level"
    case uiOutcomePlayAgain = "ui.outcome.play_again"
    case uiOutcomeUndo = "ui.outcome.undo"
    case uiOutcomeBack = "ui.outcome.back"
    case uiOutcomeMenu = "ui.outcome.menu"
    case uiOutcomeHintNext = "ui.outcome.hint_next"
    case uiOutcomeHintAgain = "ui.outcome.hint_again"
    case uiOutcomeHintBack = "ui.outcome.hint_back"
    case uiOutcomeNewRecordMoves = "ui.outcome.new_record_moves"
    case uiOutcomeNewRecordPushes = "ui.outcome.new_record_pushes"
    case uiOutcomeBestMoves = "ui.outcome.best_moves"
    case uiOutcomeBestPushes = "ui.outcome.best_pushes"
    case uiOutcomeAnimatingTitle = "ui.outcome.animating_title"
    case uiOutcomeAnimatingBody = "ui.outcome.animating_body"
    case uiOutcomeSkip = "ui.outcome.skip"

    // Launch / level select
    case uiLaunchTitle = "ui.launch.title"
    case uiLaunchContinue = "ui.launch.continue"
    case uiLaunchSelectLevel = "ui.launch.select_level"
    case uiLevelSelectTitle = "ui.level_select.title"
    case uiLevelSelectBack = "ui.level_select.back"
    case uiLevelSelectLocked = "ui.level_select.locked"
    case uiLevelSelectAvailable = "ui.level_select.available"
    case uiLevelSelectCompleted = "ui.level_select.completed"

    // HUD
    case uiHudMoves = "ui.hud.moves"
    case uiHudPushes = "ui.hud.pushes"
    case uiHudGoals = "ui.hud.goals"
    case uiHudUndo = "ui.hud.undo"
    case uiHudRedo = "ui.hud.redo"
    case uiHudAvailable = "ui.hud.available"
    case uiHudUnavailable = "ui.hud.unavailable"

    // Pause
    case uiPauseTitle = "ui.pause.title"
    case uiPauseHint = "ui.pause.hint"
    case uiPauseResume = "ui.pause.resume"
    case uiPauseRestart = "ui.pause.restart"
    case uiPauseLevelSelect = "ui.pause.level_select"

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
        AppStringID.uiIntroSkipHint.rawValue: "Return, Space oder Escape startet",

        AppStringID.uiOutcomeLevelComplete.rawValue: "Level geschafft",
        AppStringID.uiOutcomeTutorialComplete.rawValue: "Tutorial geschafft",
        AppStringID.uiOutcomeNextLevel.rawValue: "Nächstes Level",
        AppStringID.uiOutcomePlayAgain.rawValue: "Noch einmal",
        AppStringID.uiOutcomeUndo.rawValue: "Letzten Zug rückgängig",
        AppStringID.uiOutcomeBack.rawValue: "Zur Übersicht",
        AppStringID.uiOutcomeMenu.rawValue: "Zur Übersicht",
        AppStringID.uiOutcomeHintNext.rawValue: "Return/Space bestätigt die markierte Aktion · Z: Undo",
        AppStringID.uiOutcomeHintAgain.rawValue: "Return/Space bestätigt die markierte Aktion · Z: Undo",
        AppStringID.uiOutcomeHintBack.rawValue: "Return/Space bestätigt die markierte Aktion · Z: Undo",
        AppStringID.uiOutcomeNewRecordMoves.rawValue: "Neuer Zugrekord",
        AppStringID.uiOutcomeNewRecordPushes.rawValue: "Neuer Schubrekord",
        AppStringID.uiOutcomeBestMoves.rawValue: "Beste Züge",
        AppStringID.uiOutcomeBestPushes.rawValue: "Beste Schübe",
        AppStringID.uiOutcomeAnimatingTitle.rawValue: "Level geschafft",
        AppStringID.uiOutcomeAnimatingBody.rawValue: "Zug wird beendet… Return oder Space überspringt",
        AppStringID.uiOutcomeSkip.rawValue: "Überspringen",

        AppStringID.uiLaunchTitle.rawValue: "SokoBoulder",
        AppStringID.uiLaunchContinue.rawValue: "Fortsetzen",
        AppStringID.uiLaunchSelectLevel.rawValue: "Levelauswahl",
        AppStringID.uiLevelSelectTitle.rawValue: "Levelauswahl",
        AppStringID.uiLevelSelectBack.rawValue: "Zurück",
        AppStringID.uiLevelSelectLocked.rawValue: "Gesperrt",
        AppStringID.uiLevelSelectAvailable.rawValue: "Verfügbar",
        AppStringID.uiLevelSelectCompleted.rawValue: "Geschafft",

        AppStringID.uiHudMoves.rawValue: "Züge",
        AppStringID.uiHudPushes.rawValue: "Schübe",
        AppStringID.uiHudGoals.rawValue: "Ziele",
        AppStringID.uiHudUndo.rawValue: "Undo",
        AppStringID.uiHudRedo.rawValue: "Redo",
        AppStringID.uiHudAvailable.rawValue: "verfügbar",
        AppStringID.uiHudUnavailable.rawValue: "nicht verfügbar",

        AppStringID.uiPauseTitle.rawValue: "Pause",
        AppStringID.uiPauseHint.rawValue: "Escape setzt fort · Spielzug-Eingabe gesperrt",
        AppStringID.uiPauseResume.rawValue: "Fortsetzen",
        AppStringID.uiPauseRestart.rawValue: "Neu starten",
        AppStringID.uiPauseLevelSelect.rawValue: "Levelauswahl",

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
