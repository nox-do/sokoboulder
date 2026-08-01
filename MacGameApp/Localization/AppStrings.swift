import Foundation

/// Stable string IDs for UI and tutorial copy.
///
/// German is the current locale table. Keys match catalog `tutorialHintID`s and
/// are ready to migrate into a String Catalog later without renaming call sites.
enum AppStringID: String, CaseIterable, Sendable {
    // Tutorial hints (also used as `SokobanLevelDescriptor.tutorialHintID`)
    case hintSokobanMoveAndPush = "hint.sokoban.move_and_push"
    case hintSokobanWalkAroundAndUndo = "hint.sokoban.walk_around_and_undo"
    case hintSokobanCrateBlocking = "hint.sokoban.crate_blocking"

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
    case uiOutcomeHintNext = "ui.outcome.hint_next"
    case uiOutcomeHintAgain = "ui.outcome.hint_again"
    case uiOutcomeHintBack = "ui.outcome.hint_back"
    case uiOutcomeAnimatingTitle = "ui.outcome.animating_title"
    case uiOutcomeAnimatingBody = "ui.outcome.animating_body"
    case uiOutcomeSkip = "ui.outcome.skip"

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
        AppStringID.hintSokobanMoveAndPush.rawValue:
            "Pfeiltasten bewegen. In eine Kiste laufen schiebt sie — ziehen geht nicht. Stelle sie auf das Ziel.",
        AppStringID.hintSokobanWalkAroundAndUndo.rawValue:
            "Lauf um Hindernisse herum, bevor du schiebst. Falscher Schub? Z = Undo, ⇧⌘Z = Redo.",
        AppStringID.hintSokobanCrateBlocking.rawValue:
            "Zwei Kisten blockieren einander. Plane die Schübe — sonst klemmen sie sich fest.",

        AppStringID.uiIntroContinue.rawValue: "Weiter",
        AppStringID.uiIntroSkipHint.rawValue: "Return, Space oder Escape startet",

        AppStringID.uiOutcomeLevelComplete.rawValue: "Level geschafft",
        AppStringID.uiOutcomeTutorialComplete.rawValue: "Tutorial geschafft",
        AppStringID.uiOutcomeNextLevel.rawValue: "Nächstes Level",
        AppStringID.uiOutcomePlayAgain.rawValue: "Noch einmal",
        AppStringID.uiOutcomeUndo.rawValue: "Letzten Zug rückgängig",
        AppStringID.uiOutcomeBack.rawValue: "Tutorial von vorn",
        AppStringID.uiOutcomeHintNext.rawValue: "Return/Space bestätigt die markierte Aktion · Z: Undo",
        AppStringID.uiOutcomeHintAgain.rawValue: "Return/Space bestätigt die markierte Aktion · Z: Undo",
        AppStringID.uiOutcomeHintBack.rawValue: "Return/Space bestätigt die markierte Aktion · Z: Undo",
        AppStringID.uiOutcomeAnimatingTitle.rawValue: "Level geschafft",
        AppStringID.uiOutcomeAnimatingBody.rawValue: "Zug wird beendet… Return oder Space überspringt",
        AppStringID.uiOutcomeSkip.rawValue: "Überspringen",

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

    /// Resolves a raw localization key (e.g. catalog `tutorialHintID`).
    static func text(id: String) -> String {
        german[id] ?? id
    }
}
