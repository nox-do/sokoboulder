import Foundation
import GameCore

/// Why a run file cannot be restored.
enum SokobanRunRestoreFailure: Error, Equatable, Sendable {
    case unknownSchemaVersion(Int)
    case unknownCheckpointSchemaVersion(Int)
    case unknownLevelID(String)
    case contentHashMismatch
    case ruleVersionMismatch(found: Int, expected: Int)
    case tooManyCommands(Int)
    case cursorOutOfRange(cursor: Int, commandCount: Int)
    case checkpointInvalid(String)
    case commandBlockedDuringReplay(index: Int)
    case commandAfterTerminal(index: Int)
    case engineFault(String)
}

/// Reconstructed session pieces after a successful deterministic replay.
struct SokobanRunRestoreResult: Equatable, Sendable {
    let level: SokobanLevel
    let levelID: String
    let contentHash: String
    let initialState: SokobanState
    let currentState: SokobanState
    let checkpoint: SokobanCheckpoint
    let commands: [Direction]
    let cursor: Int
    let undoStack: [SokobanState]
    let redoStack: [SokobanState]
    /// True when a legacy run was truncated to the last state before a
    /// mathematically certain static crate deadlock.
    let recoveredStaticDeadlock: Bool
}

/// Validates a V1 run file and rebuilds state + undo/redo exclusively by replay.
enum SokobanRunRestorer {
    static let commandLimit = 1_000

    static func restore(
        _ file: SokobanRunFileV1,
        catalogLookup: (String) -> SokobanLevelDescriptor? = { SokobanLevelCatalog.descriptor(id: $0) },
        rules: SokobanRules = SokobanRules()
    ) throws -> SokobanRunRestoreResult {
        guard file.schemaVersion == SokobanRunFileV1.currentSchemaVersion else {
            throw SokobanRunRestoreFailure.unknownSchemaVersion(file.schemaVersion)
        }
        guard file.checkpoint.schemaVersion == SokobanCheckpointV1.currentSchemaVersion else {
            throw SokobanRunRestoreFailure.unknownCheckpointSchemaVersion(file.checkpoint.schemaVersion)
        }
        guard file.ruleVersion == SokobanRules.ruleVersion else {
            throw SokobanRunRestoreFailure.ruleVersionMismatch(
                found: file.ruleVersion,
                expected: SokobanRules.ruleVersion
            )
        }
        guard file.commands.count <= commandLimit else {
            throw SokobanRunRestoreFailure.tooManyCommands(file.commands.count)
        }
        guard file.cursor >= 0, file.cursor <= file.commands.count else {
            throw SokobanRunRestoreFailure.cursorOutOfRange(
                cursor: file.cursor,
                commandCount: file.commands.count
            )
        }

        guard let descriptor = catalogLookup(file.levelID) else {
            throw SokobanRunRestoreFailure.unknownLevelID(file.levelID)
        }
        guard descriptor.contentHash == file.contentHash else {
            throw SokobanRunRestoreFailure.contentHashMismatch
        }

        let level = descriptor.makeLevel()

        let initialState: SokobanState
        do {
            initialState = try rules.start(level: level)
        } catch let fault as EngineFault {
            throw SokobanRunRestoreFailure.engineFault(faultDetail(fault))
        } catch {
            throw SokobanRunRestoreFailure.engineFault(String(describing: error))
        }

        let semanticCheckpoint = file.checkpoint.semantic
        let checkpointState: SokobanState
        do {
            checkpointState = try rules.restore(level: level, checkpoint: semanticCheckpoint)
        } catch let fault as EngineFault {
            throw SokobanRunRestoreFailure.checkpointInvalid(faultDetail(fault))
        } catch {
            throw SokobanRunRestoreFailure.checkpointInvalid(String(describing: error))
        }

        let directions = file.commands.map(\.direction)
        var state = checkpointState
        var states: [SokobanState] = [checkpointState]
        var sawTerminal = checkpointState.status != .playing

        for (index, direction) in directions.enumerated() {
            if sawTerminal {
                throw SokobanRunRestoreFailure.commandAfterTerminal(index: index)
            }
            let transition: Transition<SokobanState>
            do {
                transition = try rules.move(direction, in: state)
            } catch let fault as EngineFault {
                throw SokobanRunRestoreFailure.engineFault(faultDetail(fault))
            } catch {
                throw SokobanRunRestoreFailure.engineFault(String(describing: error))
            }

            switch transition.outcome {
            case .changed:
                break
            case .terminal:
                sawTerminal = true
            case .blocked:
                throw SokobanRunRestoreFailure.commandBlockedDuringReplay(index: index)
            }

            state = transition.state
            states.append(state)
        }

        let deadSquares = SokobanStaticDeadlockAnalyzer.staticDeadSquares(in: level)
        let firstDeadStateIndex = states.firstIndex { state in
            containsCrate(in: state, onAny: deadSquares)
        }

        if firstDeadStateIndex == 0 {
            // Journal compaction can put an old deadlock into the checkpoint,
            // beyond available undo history. Restarting is the only safe state.
            let freshCheckpoint = rules.checkpoint(from: initialState)
            return SokobanRunRestoreResult(
                level: level,
                levelID: descriptor.id,
                contentHash: descriptor.contentHash,
                initialState: initialState,
                currentState: initialState,
                checkpoint: freshCheckpoint,
                commands: [],
                cursor: 0,
                undoStack: [],
                redoStack: [],
                recoveredStaticDeadlock: true
            )
        }

        // State N is the result of command N - 1. Exclude the command that
        // first entered a dead square, including when it currently lives in
        // redo history after an undo.
        let safeCommandCount = firstDeadStateIndex.map { $0 - 1 } ?? directions.count
        let recoveredStaticDeadlock = firstDeadStateIndex != nil
        let cursor = min(file.cursor, safeCommandCount)
        let current = states[cursor]
        let commands = recoveredStaticDeadlock
            ? Array(directions.prefix(safeCommandCount))
            : directions
        let undoStack = Array(states[0..<cursor])
        let redoStack = cursor < safeCommandCount
            ? Array(states[(cursor + 1)...safeCommandCount].reversed())
            : []

        return SokobanRunRestoreResult(
            level: level,
            levelID: descriptor.id,
            contentHash: descriptor.contentHash,
            initialState: initialState,
            currentState: current,
            checkpoint: semanticCheckpoint,
            commands: commands,
            cursor: cursor,
            undoStack: undoStack,
            redoStack: redoStack,
            recoveredStaticDeadlock: recoveredStaticDeadlock
        )
    }

    private static func containsCrate(
        in state: SokobanState,
        onAny positions: Set<GridPosition>
    ) -> Bool {
        positions.contains { position in
            if case .crate = state.grid[position].occupant { return true }
            return false
        }
    }

    private static func faultDetail(_ fault: EngineFault) -> String {
        switch fault {
        case .invariantViolated(let detail):
            return detail
        }
    }
}
