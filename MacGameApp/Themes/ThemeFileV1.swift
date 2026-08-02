import Foundation

/// Theme catalog index (paths only).
struct ThemeManifestV1: Equatable, Codable, Sendable {
    static let currentSchemaVersion = 1
    static let resourcePath = "Themes/manifest.json"

    let schemaVersion: Int
    let themes: [String]
    let defaultThemeID: String
}

/// Versioned visual theme document (DTO).
struct ThemeFileV1: Equatable, Codable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let id: String
    let displayNameID: String
    let board: BoardDTO
    let ui: UIDTO

    struct BoardDTO: Equatable, Codable, Sendable {
        let background: String
        let terrain: TerrainDTO
        let entities: EntitiesDTO
        let stateMarkers: StateMarkersDTO
        let feedback: FeedbackDTO
    }

    struct TerrainDTO: Equatable, Codable, Sendable {
        let voidFill: String
        let floorFill: String
        let floorStroke: String
        let wallFill: String
        let wallStroke: String
        let wallSymbol: String
        let goalFill: String
        let goalStroke: String
        let goalSymbol: String
    }

    struct EntitiesDTO: Equatable, Codable, Sendable {
        let playerFill: String
        let playerStroke: String
        let playerSymbol: String
        let crateFill: String
        let crateStroke: String
        let crateSymbol: String
    }

    struct StateMarkersDTO: Equatable, Codable, Sendable {
        let crateOnGoalSymbol: String
        let crateOnGoalColor: String
        let playerOnGoalSymbol: String
        let playerOnGoalColor: String
        let emptyGoalAccent: String
    }

    struct FeedbackDTO: Equatable, Codable, Sendable {
        let blockedSymbol: String
        let blockedColor: String
        let goalEnteredSymbol: String
        let goalEnteredColor: String
        let goalLeftSymbol: String
        let goalLeftColor: String
        let pushHighlight: String
        let completionFrame: String
    }

    struct UIDTO: Equatable, Codable, Sendable {
        let focusRing: String
        let focusBackground: String
        let focusBorder: String
        let focusForeground: String
        let primaryFill: String
        let primaryForeground: String
        let secondaryFill: String
        let secondaryForeground: String
        let disabledFill: String
        let disabledForeground: String
        let success: String
        let warning: String
        let error: String
        let overlayScrim: String
        let panelBackground: String
        let panelForeground: String
        let panelSecondary: String
        let hudBackground: String
        let hudForeground: String
        let hudSecondary: String
    }

    func makeVisualTheme() throws -> VisualTheme {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ThemeDecodeError.unsupportedSchemaVersion(schemaVersion)
        }
        guard !id.isEmpty else { throw ThemeDecodeError.emptyID }
        guard !displayNameID.isEmpty else { throw ThemeDecodeError.emptyDisplayNameID }

        return VisualTheme(
            id: id,
            displayNameID: displayNameID,
            board: .init(
                background: try ThemeColor.parse(board.background),
                terrain: .init(
                    voidFill: try ThemeColor.parse(board.terrain.voidFill),
                    floorFill: try ThemeColor.parse(board.terrain.floorFill),
                    floorStroke: try ThemeColor.parse(board.terrain.floorStroke),
                    wallFill: try ThemeColor.parse(board.terrain.wallFill),
                    wallStroke: try ThemeColor.parse(board.terrain.wallStroke),
                    wallSymbol: board.terrain.wallSymbol,
                    goalFill: try ThemeColor.parse(board.terrain.goalFill),
                    goalStroke: try ThemeColor.parse(board.terrain.goalStroke),
                    goalSymbol: board.terrain.goalSymbol
                ),
                entities: .init(
                    playerFill: try ThemeColor.parse(board.entities.playerFill),
                    playerStroke: try ThemeColor.parse(board.entities.playerStroke),
                    playerSymbol: board.entities.playerSymbol,
                    crateFill: try ThemeColor.parse(board.entities.crateFill),
                    crateStroke: try ThemeColor.parse(board.entities.crateStroke),
                    crateSymbol: board.entities.crateSymbol
                ),
                stateMarkers: .init(
                    crateOnGoalSymbol: board.stateMarkers.crateOnGoalSymbol,
                    crateOnGoalColor: try ThemeColor.parse(board.stateMarkers.crateOnGoalColor),
                    playerOnGoalSymbol: board.stateMarkers.playerOnGoalSymbol,
                    playerOnGoalColor: try ThemeColor.parse(board.stateMarkers.playerOnGoalColor),
                    emptyGoalAccent: try ThemeColor.parse(board.stateMarkers.emptyGoalAccent)
                ),
                feedback: .init(
                    blockedSymbol: board.feedback.blockedSymbol,
                    blockedColor: try ThemeColor.parse(board.feedback.blockedColor),
                    goalEnteredSymbol: board.feedback.goalEnteredSymbol,
                    goalEnteredColor: try ThemeColor.parse(board.feedback.goalEnteredColor),
                    goalLeftSymbol: board.feedback.goalLeftSymbol,
                    goalLeftColor: try ThemeColor.parse(board.feedback.goalLeftColor),
                    pushHighlight: try ThemeColor.parse(board.feedback.pushHighlight),
                    completionFrame: try ThemeColor.parse(board.feedback.completionFrame)
                )
            ),
            ui: .init(
                focusRing: try ThemeColor.parse(ui.focusRing),
                focusBackground: try ThemeColor.parse(ui.focusBackground),
                focusBorder: try ThemeColor.parse(ui.focusBorder),
                focusForeground: try ThemeColor.parse(ui.focusForeground),
                primaryFill: try ThemeColor.parse(ui.primaryFill),
                primaryForeground: try ThemeColor.parse(ui.primaryForeground),
                secondaryFill: try ThemeColor.parse(ui.secondaryFill),
                secondaryForeground: try ThemeColor.parse(ui.secondaryForeground),
                disabledFill: try ThemeColor.parse(ui.disabledFill),
                disabledForeground: try ThemeColor.parse(ui.disabledForeground),
                success: try ThemeColor.parse(ui.success),
                warning: try ThemeColor.parse(ui.warning),
                error: try ThemeColor.parse(ui.error),
                overlayScrim: try ThemeColor.parse(ui.overlayScrim),
                panelBackground: try ThemeColor.parse(ui.panelBackground),
                panelForeground: try ThemeColor.parse(ui.panelForeground),
                panelSecondary: try ThemeColor.parse(ui.panelSecondary),
                hudBackground: try ThemeColor.parse(ui.hudBackground),
                hudForeground: try ThemeColor.parse(ui.hudForeground),
                hudSecondary: try ThemeColor.parse(ui.hudSecondary)
            )
        )
    }
}

enum StrictThemeJSON {
    static func validateManifestKeys(_ data: Data) throws {
        try validateKeys(
            data,
            allowed: ["schemaVersion", "themes", "defaultThemeID"],
            required: ["schemaVersion", "themes", "defaultThemeID"]
        )
    }

    static func validateThemeKeys(_ data: Data) throws {
        let object = try jsonObject(data)
        try validateObjectKeys(
            object,
            allowed: ["schemaVersion", "id", "displayNameID", "board", "ui"],
            required: ["schemaVersion", "id", "displayNameID", "board", "ui"]
        )

        guard let board = object["board"] as? [String: Any] else {
            throw ThemeDecodeError.missingKeys(["board"])
        }
        try validateObjectKeys(
            board,
            allowed: ["background", "terrain", "entities", "stateMarkers", "feedback"],
            required: ["background", "terrain", "entities", "stateMarkers", "feedback"]
        )
        try validateObjectKeys(
            nested(board, "terrain"),
            allowed: [
                "voidFill", "floorFill", "floorStroke",
                "wallFill", "wallStroke", "wallSymbol",
                "goalFill", "goalStroke", "goalSymbol",
            ],
            required: [
                "voidFill", "floorFill", "floorStroke",
                "wallFill", "wallStroke", "wallSymbol",
                "goalFill", "goalStroke", "goalSymbol",
            ]
        )
        try validateObjectKeys(
            nested(board, "entities"),
            allowed: [
                "playerFill", "playerStroke", "playerSymbol",
                "crateFill", "crateStroke", "crateSymbol",
            ],
            required: [
                "playerFill", "playerStroke", "playerSymbol",
                "crateFill", "crateStroke", "crateSymbol",
            ]
        )
        try validateObjectKeys(
            nested(board, "stateMarkers"),
            allowed: [
                "crateOnGoalSymbol", "crateOnGoalColor",
                "playerOnGoalSymbol", "playerOnGoalColor",
                "emptyGoalAccent",
            ],
            required: [
                "crateOnGoalSymbol", "crateOnGoalColor",
                "playerOnGoalSymbol", "playerOnGoalColor",
                "emptyGoalAccent",
            ]
        )
        try validateObjectKeys(
            nested(board, "feedback"),
            allowed: [
                "blockedSymbol", "blockedColor",
                "goalEnteredSymbol", "goalEnteredColor",
                "goalLeftSymbol", "goalLeftColor",
                "pushHighlight", "completionFrame",
            ],
            required: [
                "blockedSymbol", "blockedColor",
                "goalEnteredSymbol", "goalEnteredColor",
                "goalLeftSymbol", "goalLeftColor",
                "pushHighlight", "completionFrame",
            ]
        )

        guard let ui = object["ui"] as? [String: Any] else {
            throw ThemeDecodeError.missingKeys(["ui"])
        }
        try validateObjectKeys(
            ui,
            allowed: [
                "focusRing", "focusBackground", "focusBorder", "focusForeground",
                "primaryFill", "primaryForeground",
                "secondaryFill", "secondaryForeground",
                "disabledFill", "disabledForeground",
                "success", "warning", "error",
                "overlayScrim",
                "panelBackground", "panelForeground", "panelSecondary",
                "hudBackground", "hudForeground", "hudSecondary",
            ],
            required: [
                "focusRing", "focusBackground", "focusBorder", "focusForeground",
                "primaryFill", "primaryForeground",
                "secondaryFill", "secondaryForeground",
                "disabledFill", "disabledForeground",
                "success", "warning", "error",
                "overlayScrim",
                "panelBackground", "panelForeground", "panelSecondary",
                "hudBackground", "hudForeground", "hudSecondary",
            ]
        )
    }

    private static func validateKeys(
        _ data: Data,
        allowed: Set<String>,
        required: Set<String>
    ) throws {
        try validateObjectKeys(try jsonObject(data), allowed: allowed, required: required)
    }

    private static func validateObjectKeys(
        _ object: [String: Any],
        allowed: Set<String>,
        required: Set<String>
    ) throws {
        let keys = Set(object.keys)
        let unknown = keys.subtracting(allowed).sorted()
        guard unknown.isEmpty else { throw ThemeDecodeError.unknownKeys(unknown) }
        let missing = required.subtracting(keys).sorted()
        guard missing.isEmpty else { throw ThemeDecodeError.missingKeys(missing) }
    }

    private static func nested(_ object: [String: Any], _ key: String) throws -> [String: Any] {
        guard let nested = object[key] as? [String: Any] else {
            throw ThemeDecodeError.missingKeys([key])
        }
        return nested
    }

    private static func jsonObject(_ data: Data) throws -> [String: Any] {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw ThemeDecodeError.notAnObject
        }
        guard let dict = object as? [String: Any] else {
            throw ThemeDecodeError.notAnObject
        }
        return dict
    }
}

enum ThemeFileCodec {
    private static let decoder = JSONDecoder()

    static func decodeManifest(_ data: Data) throws -> ThemeManifestV1 {
        try StrictThemeJSON.validateManifestKeys(data)
        let manifest = try decoder.decode(ThemeManifestV1.self, from: data)
        guard manifest.schemaVersion == ThemeManifestV1.currentSchemaVersion else {
            throw ThemeDecodeError.unsupportedSchemaVersion(manifest.schemaVersion)
        }
        guard !manifest.defaultThemeID.isEmpty else {
            throw ThemeDecodeError.emptyID
        }
        return manifest
    }

    static func decodeTheme(_ data: Data) throws -> VisualTheme {
        try StrictThemeJSON.validateThemeKeys(data)
        let file = try decoder.decode(ThemeFileV1.self, from: data)
        return try file.makeVisualTheme()
    }
}
