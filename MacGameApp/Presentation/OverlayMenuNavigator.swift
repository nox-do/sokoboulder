import Foundation

/// Current keyboard focus across overlay menus.
struct OverlayFocusState: Equatable, Sendable {
    var gameSelection: GameSelectionAction
    var launch: LaunchMenuAction
    var pause: PauseMenuAction
    var levelSelectionID: String
    var settingsID: String
    var outcome: OutcomeFocusedAction
}

/// Phase-specific lists needed to move focus.
struct OverlayNavigationContext: Equatable, Sendable {
    var levelSelectionOrder: [String]
    var settingsOrder: [String]
    var outcomeOrder: [OutcomeFocusedAction]
    /// Focus ids that map to a music-track cycle (e.g. `musicTrack.sokoban`).
    var musicTrackFocusGames: [String: AudioGameMode]
    var levelSelectionBackID: String
}

/// Side-effect-free navigation result for overlay keyboard handling.
enum OverlayNavigationResult: Equatable, Sendable {
    /// Key is irrelevant for the current overlay phase.
    case unhandled
    /// Key was consumed without further work (e.g. activate while isARepeat).
    case consumed
    case updateFocus(OverlayFocusState)
    case action(OverlayNavigationAction)
}

/// Imperative overlay actions the play controller performs after navigation resolve.
enum OverlayNavigationAction: Equatable, Sendable {
    case activateGameSelection
    case activateLaunch
    case activatePause
    case activateLevelSelection
    case cycleTheme(by: Int)
    case cycleMusicTrack(AudioGameMode, by: Int)
    case toggleReduceMotion
    case toggleMute
    case dismissHelpOrSettings
    case cancelPauseToGameSelection
    case cancelLaunchToGameSelection
    case cancelLevelSelectionToLaunch
    case performOutcomePrimary
}

/// Pure overlay keyboard navigation: focus movement and action selection.
enum OverlayMenuNavigator {
    static func resolve(
        phase: GamePresentationPhase,
        command: OverlayMenuCommand,
        isRepeat: Bool,
        focus: OverlayFocusState,
        context: OverlayNavigationContext
    ) -> OverlayNavigationResult {
        switch phase {
        case .gameSelection:
            return resolveGameSelection(command, isRepeat: isRepeat, focus: focus)
        case .launchMenu:
            return resolveLaunch(command, isRepeat: isRepeat, focus: focus)
        case .paused:
            return resolvePause(command, isRepeat: isRepeat, focus: focus)
        case .levelSelection:
            return resolveLevelSelection(command, isRepeat: isRepeat, focus: focus, context: context)
        case .settings:
            return resolveSettings(command, isRepeat: isRepeat, focus: focus, context: context)
        case .help:
            return resolveHelp(command, isRepeat: isRepeat)
        case .outcomeAwaitingChoice:
            return resolveOutcome(command, isRepeat: isRepeat, focus: focus, context: context)
        default:
            return .unhandled
        }
    }

    /// Default focus after entering an overlay phase.
    static func resetFocus(
        for phase: GamePresentationPhase,
        focus: OverlayFocusState,
        context: OverlayNavigationContext
    ) -> OverlayFocusState {
        var next = focus
        switch phase {
        case .gameSelection:
            next.gameSelection = .sokoban
        case .launchMenu:
            next.launch = .continueCampaign
        case .paused:
            next.pause = .resume
        case .levelSelection:
            next.levelSelectionID =
                context.levelSelectionOrder.first ?? context.levelSelectionBackID
        case .settings:
            next.settingsID = context.settingsOrder.first ?? "back"
        case .outcomeAwaitingChoice:
            next.outcome = .primary
        default:
            break
        }
        return next
    }

    // MARK: - Per-phase

    private static func resolveGameSelection(
        _ command: OverlayMenuCommand,
        isRepeat: Bool,
        focus: OverlayFocusState
    ) -> OverlayNavigationResult {
        var next = focus
        switch command {
        case .moveUp, .moveLeft:
            next.gameSelection =
                KeyboardFocusCycle.move(
                    from: focus.gameSelection,
                    in: GameSelectionAction.focusOrder,
                    offset: -1
                ) ?? .sokoban
            return .updateFocus(next)
        case .moveDown, .moveRight:
            next.gameSelection =
                KeyboardFocusCycle.move(
                    from: focus.gameSelection,
                    in: GameSelectionAction.focusOrder,
                    offset: 1
                ) ?? .sokoban
            return .updateFocus(next)
        case .activate:
            guard !isRepeat else { return .consumed }
            return .action(.activateGameSelection)
        case .cancel:
            return .unhandled
        }
    }

    private static func resolveLaunch(
        _ command: OverlayMenuCommand,
        isRepeat: Bool,
        focus: OverlayFocusState
    ) -> OverlayNavigationResult {
        var next = focus
        switch command {
        case .moveUp, .moveLeft:
            next.launch =
                KeyboardFocusCycle.move(
                    from: focus.launch,
                    in: LaunchMenuAction.allCases,
                    offset: -1
                ) ?? .continueCampaign
            return .updateFocus(next)
        case .moveDown, .moveRight:
            next.launch =
                KeyboardFocusCycle.move(
                    from: focus.launch,
                    in: LaunchMenuAction.allCases,
                    offset: 1
                ) ?? .continueCampaign
            return .updateFocus(next)
        case .activate:
            guard !isRepeat else { return .consumed }
            return .action(.activateLaunch)
        case .cancel:
            guard !isRepeat else { return .consumed }
            return .action(.cancelLaunchToGameSelection)
        }
    }

    private static func resolvePause(
        _ command: OverlayMenuCommand,
        isRepeat: Bool,
        focus: OverlayFocusState
    ) -> OverlayNavigationResult {
        var next = focus
        switch command {
        case .moveUp, .moveLeft:
            next.pause =
                KeyboardFocusCycle.move(
                    from: focus.pause,
                    in: PauseMenuAction.allCases,
                    offset: -1
                ) ?? .resume
            return .updateFocus(next)
        case .moveDown, .moveRight:
            next.pause =
                KeyboardFocusCycle.move(
                    from: focus.pause,
                    in: PauseMenuAction.allCases,
                    offset: 1
                ) ?? .resume
            return .updateFocus(next)
        case .activate:
            guard !isRepeat else { return .consumed }
            return .action(.activatePause)
        case .cancel:
            guard !isRepeat else { return .consumed }
            return .action(.cancelPauseToGameSelection)
        }
    }

    private static func resolveLevelSelection(
        _ command: OverlayMenuCommand,
        isRepeat: Bool,
        focus: OverlayFocusState,
        context: OverlayNavigationContext
    ) -> OverlayNavigationResult {
        let order = context.levelSelectionOrder
        var next = focus
        switch command {
        case .moveUp, .moveLeft:
            next.levelSelectionID =
                KeyboardFocusCycle.move(
                    from: focus.levelSelectionID,
                    in: order,
                    offset: -1
                ) ?? order.first ?? context.levelSelectionBackID
            return .updateFocus(next)
        case .moveDown, .moveRight:
            next.levelSelectionID =
                KeyboardFocusCycle.move(
                    from: focus.levelSelectionID,
                    in: order,
                    offset: 1
                ) ?? order.first ?? context.levelSelectionBackID
            return .updateFocus(next)
        case .activate:
            guard !isRepeat else { return .consumed }
            return .action(.activateLevelSelection)
        case .cancel:
            guard !isRepeat else { return .consumed }
            return .action(.cancelLevelSelectionToLaunch)
        }
    }

    private static func resolveSettings(
        _ command: OverlayMenuCommand,
        isRepeat: Bool,
        focus: OverlayFocusState,
        context: OverlayNavigationContext
    ) -> OverlayNavigationResult {
        let order = context.settingsOrder
        var next = focus
        switch command {
        case .moveUp:
            next.settingsID =
                KeyboardFocusCycle.move(from: focus.settingsID, in: order, offset: -1)
                ?? order.first ?? "back"
            return .updateFocus(next)
        case .moveDown:
            next.settingsID =
                KeyboardFocusCycle.move(from: focus.settingsID, in: order, offset: 1)
                ?? order.first ?? "back"
            return .updateFocus(next)
        case .moveLeft:
            if focus.settingsID == "theme" {
                return .action(.cycleTheme(by: -1))
            }
            if let game = context.musicTrackFocusGames[focus.settingsID] {
                return .action(.cycleMusicTrack(game, by: -1))
            }
            next.settingsID =
                KeyboardFocusCycle.move(from: focus.settingsID, in: order, offset: -1)
                ?? order.first ?? "back"
            return .updateFocus(next)
        case .moveRight:
            if focus.settingsID == "theme" {
                return .action(.cycleTheme(by: 1))
            }
            if let game = context.musicTrackFocusGames[focus.settingsID] {
                return .action(.cycleMusicTrack(game, by: 1))
            }
            next.settingsID =
                KeyboardFocusCycle.move(from: focus.settingsID, in: order, offset: 1)
                ?? order.first ?? "back"
            return .updateFocus(next)
        case .activate:
            guard !isRepeat else { return .consumed }
            return settingsActivateAction(focusedID: focus.settingsID, context: context)
        case .cancel:
            guard !isRepeat else { return .consumed }
            return .action(.dismissHelpOrSettings)
        }
    }

    private static func settingsActivateAction(
        focusedID: String,
        context: OverlayNavigationContext
    ) -> OverlayNavigationResult {
        switch focusedID {
        case "theme":
            return .action(.cycleTheme(by: 1))
        case "reduceMotion":
            return .action(.toggleReduceMotion)
        case "mute":
            return .action(.toggleMute)
        case "back":
            return .action(.dismissHelpOrSettings)
        default:
            if let game = context.musicTrackFocusGames[focusedID] {
                return .action(.cycleMusicTrack(game, by: 1))
            }
            return .unhandled
        }
    }

    private static func resolveHelp(
        _ command: OverlayMenuCommand,
        isRepeat: Bool
    ) -> OverlayNavigationResult {
        switch command {
        case .activate, .cancel:
            guard !isRepeat else { return .consumed }
            return .action(.dismissHelpOrSettings)
        case .moveUp, .moveDown, .moveLeft, .moveRight:
            return .unhandled
        }
    }

    private static func resolveOutcome(
        _ command: OverlayMenuCommand,
        isRepeat: Bool,
        focus: OverlayFocusState,
        context: OverlayNavigationContext
    ) -> OverlayNavigationResult {
        switch command {
        case .moveUp, .moveLeft:
            var next = focus
            if let moved = KeyboardFocusCycle.move(
                from: focus.outcome,
                in: context.outcomeOrder,
                offset: -1
            ) {
                next.outcome = moved
                return .updateFocus(next)
            }
            return .consumed
        case .moveDown, .moveRight:
            var next = focus
            if let moved = KeyboardFocusCycle.move(
                from: focus.outcome,
                in: context.outcomeOrder,
                offset: 1
            ) {
                next.outcome = moved
                return .updateFocus(next)
            }
            return .consumed
        case .activate:
            // Return/Space confirm is owned by ``GameplayInputRouter``.
            return .unhandled
        case .cancel:
            guard !isRepeat else { return .consumed }
            return .action(.performOutcomePrimary)
        }
    }
}
