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

        let cursor = file.cursor
        let current = states[cursor]
        let undoStack = Array(states[0..<cursor])
        let redoStack = Array(states[(cursor + 1)...].reversed())

        return SokobanRunRestoreResult(
            level: level,
            levelID: descriptor.id,
            contentHash: descriptor.contentHash,
            initialState: initialState,
            currentState: current,
            checkpoint: semanticCheckpoint,
            commands: directions,
            cursor: cursor,
            undoStack: undoStack,
            redoStack: redoStack
        )
    }

    private static func faultDetail(_ fault: EngineFault) -> String {
        switch fault {
        case .invariantViolated(let detail):
            return detail
        }
    }
}
