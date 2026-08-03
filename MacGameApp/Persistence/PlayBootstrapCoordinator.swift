import Foundation

/// Pure copy for run-restore failures shown in recovery UI.
enum SokobanRunRestoreMessages {
    static func text(for error: Error) -> String {
        if let failure = error as? SokobanRunRestoreFailure {
            switch failure {
            case .unknownSchemaVersion(let version):
                return "Run file schema version \(version) is not supported."
            case .unknownCheckpointSchemaVersion(let version):
                return "Checkpoint schema version \(version) is not supported."
            case .unknownLevelID(let id):
                return "Saved level “\(id)” is unknown."
            case .contentHashMismatch:
                return "Saved level content no longer matches this build."
            case .ruleVersionMismatch(let found, let expected):
                return "Rule version \(found) is incompatible (expected \(expected))."
            case .tooManyCommands(let count):
                return "Run file has too many commands (\(count))."
            case .cursorOutOfRange(let cursor, let count):
                return "Run file cursor \(cursor) is outside 0...\(count)."
            case .checkpointInvalid(let detail):
                return "Saved checkpoint is invalid: \(detail)"
            case .commandBlockedDuringReplay(let index):
                return "Saved move \(index) is blocked and cannot be replayed."
            case .commandAfterTerminal(let index):
                return "Saved move \(index) appears after the level already finished."
            case .engineFault(let detail):
                return "Could not restore run: \(detail)"
            }
        }
        return "Could not restore run: \(error.localizedDescription)"
    }
}

/// Decides whether a content-hash mismatch may restart the level in place.
enum SokobanRunContentChangePolicy {
    static func canRestartAfterContentChange(
        file: SokobanRunFileV1,
        error: Error,
        levelExists: Bool,
        restartableSupersededHashes: [String: Set<String>]
    ) -> Bool {
        guard let failure = error as? SokobanRunRestoreFailure,
            failure == .contentHashMismatch,
            levelExists
        else { return false }

        if restartableSupersededHashes[file.levelID]?.contains(file.contentHash) == true {
            return true
        }

        return file.commands.isEmpty
            && file.cursor == 0
            && file.checkpoint.moveCount == 0
            && file.checkpoint.pushCount == 0
            && file.checkpoint.status == .playing
    }
}

/// Boot decision after reading the run store (before mutating the shell).
enum PlayBootstrapDecision: Equatable, Sendable {
    case openGameSelection
    case restoreRun(SokobanRunFileV1)
    case enterRecovery(message: String)
}

enum PlayBootstrapCoordinator {
    static func decide(
        loadResult: SokobanRunLoadOutcome,
        isFreshCampaign: Bool
    ) -> PlayBootstrapDecision {
        switch loadResult {
        case .absent:
            return .openGameSelection
        case .loaded(let file):
            if isFreshCampaign {
                // Mid-first-tutorial resume: still a fresh campaign, restore directly.
                return .restoreRun(file)
            }
            // Non-fresh campaigns land on game selection; Sokoban hub via Continue.
            return .openGameSelection
        case .invalid(let message, _):
            return .enterRecovery(message: message)
        case .readFailed(let message):
            // Do not move the file; still allow a fresh start via recovery UI.
            return .enterRecovery(message: message)
        }
    }
}
