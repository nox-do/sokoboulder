import AppKit
import GameCore
import SpriteKit

/// SpriteKit board scene for Sokoban and the cave demo.
///
/// Nodes are presentation-only. Authoritative state stays in the session.
/// ``SKScene.update`` wakes the cave simulation clock via ``onSimulationFrame``;
/// it does **not** drain the Sokoban move queue.
///
/// Animate updates are applied FIFO: at most one movement action runs at a time.
/// If a new update arrives while an action is running, it is queued. Exceeding
/// ``animationBudget`` (or a revision gap / hard-resync delivery) aborts the
/// queue and snaps to the newest snapshot.
@MainActor
final class SokobanBoardScene: SKScene {
    /// Max queued + in-flight animate steps before forcing a hard catch-up.
    static let animationBudget = 3
    static let moveAnimationDuration: TimeInterval = 0.12
    /// Near-instant duration when effective reduce motion is on.
    static let reducedMoveAnimationDuration: TimeInterval = 0.01
    static let pushFeedbackDuration: TimeInterval = 0.18
    static let completionCelebrationDuration: TimeInterval = 0.5

    /// Effective reduce motion from settings / accessibility. Presentation only.
    var prefersReducedMotion = false

    /// When true, draw cave-specific tiles/entities with distinct procedural look
    /// instead of Sokoban pixel textures (crates/goals).
    var presentsCaveContent = false

    /// Called each frame with SpriteKit's display time; cave session maps this
    /// through the injected monotonic clock instead of using the raw value.
    var onSimulationFrame: (() -> Void)?

    /// Active visual theme (board tokens). Defaults to the built-in standard theme.
    private(set) var theme: VisualTheme = BuiltInThemes.standard

    #if DEBUG
        /// When true, the in-flight animate step never settles on its own.
        var holdAnimationsForTesting = false
    #endif

    private struct QueuedAnimate {
        let snapshot: RenderSnapshot
        let events: [GameEvent]
        let targetRevision: UInt64
    }

    private let boardRoot = SKNode()
    private let terrainLayer = SKNode()
    private let entityLayer = SKNode()
    private let effectLayer = SKNode()
    private let frameNode = SKShapeNode()

    private var geometry = GridGeometry(
        availableSize: .zero,
        gridWidth: 0,
        gridHeight: 0
    )
    private var terrainNodes: [SKSpriteNode] = []
    private var entityNodes: [EntityID: SKSpriteNode] = [:]
    private var playerNode: SKSpriteNode?
    private var appliedSnapshot: RenderSnapshot?

    private var animationQueue: [QueuedAnimate] = []
    private var isAnimating = false
    /// Generation token so cancelled action completions cannot touch counters.
    private var animationGeneration: UInt64 = 0
    /// True while goal tiles / frame still show completion celebration visuals.
    private var celebrationVisualsActive = false
    private var textureCache: [String: SKTexture] = [:]

    private(set) var appliedRevision: UInt64 = 0
    /// Last revision whose presentation has visually settled (or hard-synced).
    private(set) var settledRevision: UInt64 = 0

    private struct SettlementWaiter {
        let revision: UInt64
        let action: @MainActor () -> Void
    }

    private var settlementWaiters: [SettlementWaiter] = []

    /// Queued animate steps plus the one currently running, if any.
    var pendingAnimationCount: Int {
        animationQueue.count + (isAnimating ? 1 : 0)
    }

    /// Last accepted snapshot (authoritative target, may still be animating toward).
    var currentSnapshot: RenderSnapshot? { appliedSnapshot }

    /// Runs `action` once presentation has settled at least through `revision`.
    ///
    /// Fires immediately when already settled. Hard-resync and aborted presentation
    /// also settle to the accepted revision.
    func whenSettled(revision: UInt64, perform action: @escaping @MainActor () -> Void) {
        if settledRevision >= revision {
            action()
            return
        }
        settlementWaiters.append(SettlementWaiter(revision: revision, action: action))
    }

    private func markSettled(_ revision: UInt64) {
        settledRevision = max(settledRevision, revision)
        let due = settlementWaiters.filter { $0.revision <= settledRevision }
        settlementWaiters.removeAll { $0.revision <= settledRevision }
        for waiter in due {
            waiter.action()
        }
    }

    override func update(_ currentTime: TimeInterval) {
        _ = currentTime
        onSimulationFrame?()
    }

    override init(size: CGSize) {
        super.init(size: size)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        anchorPoint = .zero
        scaleMode = .resizeFill
        backgroundColor = theme.board.background.skColor
        boardRoot.name = "boardRoot"
        terrainLayer.name = "terrainLayer"
        entityLayer.name = "entityLayer"
        effectLayer.name = "effectLayer"
        frameNode.name = "completionFrame"
        frameNode.zPosition = 5
        frameNode.lineWidth = 4
        frameNode.fillColor = .clear
        frameNode.alpha = 0
        frameNode.isHidden = true
        addChild(boardRoot)
        boardRoot.addChild(terrainLayer)
        boardRoot.addChild(entityLayer)
        boardRoot.addChild(effectLayer)
        boardRoot.addChild(frameNode)
    }

    /// Applies a visual theme. Rebuilds from the last snapshot when one exists.
    func apply(theme: VisualTheme) {
        self.theme = theme
        textureCache.removeAll(keepingCapacity: true)
        syncGeometryProfile()
        backgroundColor = theme.board.background.skColor
        guard let snapshot = appliedSnapshot else { return }
        cancelAnimationsAndPending()
        rebuild(from: snapshot)
        markSettled(appliedRevision)
    }

    private var usesPixelTextures: Bool {
        theme.rendering.profile == .pixelNearest
    }

    private func syncGeometryProfile() {
        geometry.renderingProfile = theme.rendering.profile
        geometry.baseTilePoints = theme.rendering.baseTilePoints
        geometry.maxIntegerScale = theme.rendering.maxIntegerScale
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        resize(to: size)
    }

    /// Updates letterboxing only. Does not touch session state or revision.
    ///
    /// Aborts in-flight presentation and snaps nodes to the last accepted snapshot
    /// so cancelled SKActions cannot leave ``pendingAnimationCount`` stranded.
    func resize(to availableSize: CGSize) {
        geometry.availableSize = availableSize
        guard let snapshot = appliedSnapshot else { return }
        geometry.gridWidth = snapshot.width
        geometry.gridHeight = snapshot.height
        cancelAnimationsAndPending()
        relayoutExistingNodes(using: snapshot)
        clearCelebrationPresentation(using: snapshot)
        markSettled(appliedRevision)
    }

    /// Aborts in-flight presentation and snaps to the last accepted snapshot.
    /// Does not change ``appliedRevision`` or session state.
    func discardPendingPresentation() {
        guard let snapshot = appliedSnapshot else {
            cancelAnimationsAndPending()
            markSettled(appliedRevision)
            return
        }
        cancelAnimationsAndPending()
        snapEntities(to: snapshot)
        clearCelebrationPresentation(using: snapshot)
        markSettled(appliedRevision)
    }

    /// Resets revision stream, waiters, and presentation nodes for a **new** session.
    ///
    /// Call before bootstrapping a replacement ``GameSession``. Do **not** call for
    /// in-session restart / undo / redo — those continue the same revision stream.
    func prepareForNewSession() {
        cancelAnimationsAndPending()
        settlementWaiters.removeAll(keepingCapacity: true)
        appliedRevision = 0
        settledRevision = 0
        appliedSnapshot = nil
        presentsCaveContent = false
        terrainLayer.removeAllChildren()
        entityLayer.removeAllChildren()
        effectLayer.removeAllChildren()
        applyCompletionFrame(visible: false, animated: false)
        celebrationVisualsActive = false
        terrainNodes.removeAll(keepingCapacity: true)
        entityNodes.removeAll(keepingCapacity: true)
        playerNode = nil
    }

    /// Applies one ordered ``RenderUpdate`` according to the revision contract.
    func apply(_ update: RenderUpdate) {
        switch update.delivery {
        case .hardResync:
            hardResync(to: update)
        case .animate:
            applyAnimate(update)
        }
    }

    /// Applies a sequence of emissions in array order (no coalescing).
    func apply(emissions: [SessionEmission]) {
        for emission in emissions {
            apply(emission.render)
        }
    }

    // MARK: - Revision handling

    private func applyAnimate(_ update: RenderUpdate) {
        guard update.baseRevision == appliedRevision else {
            hardResync(to: update)
            return
        }

        if pendingAnimationCount >= Self.animationBudget {
            hardResync(to: update)
            return
        }

        // Accept the revision immediately so ordered follow-ups chain correctly.
        appliedRevision = update.targetRevision
        appliedSnapshot = update.snapshot
        animationQueue.append(
            QueuedAnimate(
                snapshot: update.snapshot,
                events: update.events,
                targetRevision: update.targetRevision
            )
        )
        #if DEBUG
            lastEventsForTesting = update.events
        #endif
        pumpAnimationQueue()
    }

    private func pumpAnimationQueue() {
        guard !isAnimating else { return }
        guard !animationQueue.isEmpty else { return }

        let next = animationQueue.removeFirst()
        isAnimating = true
        let generation = animationGeneration

        animate(toward: next.snapshot, events: next.events) { [weak self] in
            guard let self else { return }
            guard generation == self.animationGeneration else { return }
            self.isAnimating = false
            self.snapEntities(to: next.snapshot)
            // Celebration may recolor goals temporarily; settle back to snapshot colors
            // unless another celebration step is about to run.
            if next.events.contains(where: {
                if case .levelCompleted = $0 { return true }
                return false
            }) {
                self.clearCelebrationPresentation(using: next.snapshot)
            }
            self.markSettled(next.targetRevision)
            self.pumpAnimationQueue()
        }
    }

    private func hardResync(to update: RenderUpdate) {
        cancelAnimationsAndPending()
        rebuild(from: update.snapshot)
        appliedRevision = update.targetRevision
        appliedSnapshot = update.snapshot
        // Hard-resync never replays historical celebration effects and must match
        // the target snapshot exactly (no leftover goal highlights / frame).
        clearCelebrationPresentation(using: update.snapshot)
        markSettled(update.targetRevision)
    }

    private func cancelAnimationsAndPending() {
        animationGeneration &+= 1
        animationQueue.removeAll(keepingCapacity: true)
        isAnimating = false

        entityLayer.removeAllActions()
        playerNode?.removeAllActions()
        for node in entityNodes.values {
            node.removeAllActions()
        }
        effectLayer.removeAllActions()
        effectLayer.removeAllChildren()
        frameNode.removeAllActions()
    }

    // MARK: - Node build / layout

    private func rebuild(from snapshot: RenderSnapshot) {
        terrainLayer.removeAllChildren()
        entityLayer.removeAllChildren()
        effectLayer.removeAllChildren()
        terrainNodes.removeAll(keepingCapacity: true)
        entityNodes.removeAll(keepingCapacity: true)
        playerNode = nil

        syncGeometryProfile()
        geometry.gridWidth = snapshot.width
        geometry.gridHeight = snapshot.height
        if geometry.availableSize == .zero {
            geometry.availableSize = size
        }

        terrainNodes.reserveCapacity(snapshot.cells.count)
        for row in 0..<snapshot.height {
            for column in 0..<snapshot.width {
                let position = GridPosition(column: column, row: row)
                guard let cell = snapshot.cell(at: position) else { continue }
                let node = makeTerrainNode(cell.terrain)
                node.position = geometry.center(for: position)
                node.size = CGSize(width: geometry.tileSize, height: geometry.tileSize)
                updateStroke(for: node, tileSize: geometry.tileSize)
                resizeSemanticMarkers(in: node, tileSize: geometry.tileSize)
                terrainLayer.addChild(node)
                terrainNodes.append(node)
            }
        }

        for entity in snapshot.entities {
            let node = makeEntityNode(kind: entity.ref.kind)
            node.position = geometry.center(for: entity.position)
            node.size = entitySize()
            updateStroke(for: node, tileSize: geometry.tileSize)
            resizeSemanticMarkers(in: node, tileSize: geometry.tileSize)
            entityLayer.addChild(node)
            entityNodes[entity.ref.id] = node
        }

        let player = makeEntityNode(kind: .player)
        player.position = geometry.center(for: snapshot.player.position)
        player.size = entitySize()
        updateStroke(for: player, tileSize: geometry.tileSize)
        resizeSemanticMarkers(in: player, tileSize: geometry.tileSize)
        entityLayer.addChild(player)
        playerNode = player
        updateGoalStateMarkers(using: snapshot)
        layoutCompletionFrame()
    }

    private func relayoutExistingNodes(using snapshot: RenderSnapshot) {
        var index = 0
        for row in 0..<snapshot.height {
            for column in 0..<snapshot.width {
                let position = GridPosition(column: column, row: row)
                guard index < terrainNodes.count else { return }
                let node = terrainNodes[index]
                node.position = geometry.center(for: position)
                node.size = CGSize(width: geometry.tileSize, height: geometry.tileSize)
                updateStroke(for: node, tileSize: geometry.tileSize)
                resizeSemanticMarkers(in: node, tileSize: geometry.tileSize)
                index += 1
            }
        }

        for entity in snapshot.entities {
            guard let node = entityNodes[entity.ref.id] else { continue }
            node.position = geometry.center(for: entity.position)
            node.size = entitySize()
            updateStroke(for: node, tileSize: geometry.tileSize)
            resizeSemanticMarkers(in: node, tileSize: geometry.tileSize)
        }

        playerNode?.position = geometry.center(for: snapshot.player.position)
        playerNode?.size = entitySize()
        if let playerNode {
            updateStroke(for: playerNode, tileSize: geometry.tileSize)
            resizeSemanticMarkers(in: playerNode, tileSize: geometry.tileSize)
        }
        updateGoalStateMarkers(using: snapshot)
        layoutCompletionFrame()
    }

    private func snapEntities(to snapshot: RenderSnapshot) {
        for entity in snapshot.entities {
            guard let node = entityNodes[entity.ref.id] else { continue }
            node.position = geometry.center(for: entity.position)
            node.setScale(1)
        }
        playerNode?.position = geometry.center(for: snapshot.player.position)
        playerNode?.setScale(1)
        updateGoalStateMarkers(using: snapshot)
    }

    private func animate(
        toward snapshot: RenderSnapshot,
        events: [GameEvent],
        completion: @escaping () -> Void
    ) {
        #if DEBUG
            if holdAnimationsForTesting {
                return
            }
        #endif

        let duration =
            prefersReducedMotion
            ? Self.reducedMoveAnimationDuration
            : Self.moveAnimationDuration
        let group = DispatchGroup()
        var scheduled = false

        for entity in snapshot.entities {
            guard let node = entityNodes[entity.ref.id] else { continue }
            let target = geometry.center(for: entity.position)
            guard node.position != target else { continue }
            group.enter()
            scheduled = true
            node.run(SKAction.move(to: target, duration: duration)) {
                group.leave()
            }
        }

        if let playerNode {
            let target = geometry.center(for: snapshot.player.position)
            if playerNode.position != target {
                group.enter()
                scheduled = true
                playerNode.run(SKAction.move(to: target, duration: duration)) {
                    group.leave()
                }
            }
        }

        for event in events {
            switch event {
            case .movementBlocked(let position):
                scheduleFeedbackSymbol(
                    theme.board.feedback.blockedSymbol,
                    at: position,
                    color: theme.board.feedback.blockedColor.skColor,
                    group: group
                )
                scheduled = true
            case .objectPushed(let entity, _, _):
                if let node = entityNodes[entity.id] {
                    schedulePushPulse(on: node, group: group)
                    scheduled = true
                }
            case .crateEnteredGoal(_, let position, _, _):
                scheduleFeedbackSymbol(
                    theme.board.feedback.goalEnteredSymbol,
                    at: position,
                    color: theme.board.feedback.goalEnteredColor.skColor,
                    group: group
                )
                scheduled = true
            case .crateLeftGoal(_, let position, _, _):
                scheduleFeedbackSymbol(
                    theme.board.feedback.goalLeftSymbol,
                    at: position,
                    color: theme.board.feedback.goalLeftColor.skColor,
                    group: group
                )
                scheduled = true
            case .levelCompleted:
                scheduleCompletionCelebration(using: snapshot, group: group)
                scheduled = true
            default:
                break
            }
        }

        if scheduled {
            group.notify(queue: .main, execute: completion)
        } else {
            completion()
        }
    }

    private func entitySize() -> CGSize {
        if usesPixelTextures {
            let edge = max(1, geometry.tileSize)
            return CGSize(width: edge, height: edge)
        }
        let inset = geometry.tileSize * 0.15
        let edge = max(1, geometry.tileSize - inset)
        return CGSize(width: edge, height: edge)
    }

    private func makeTerrainNode(_ terrain: RenderTerrain) -> SKSpriteNode {
        let cave = presentsCaveContent
        if !cave, usesPixelTextures, let texture = terrainTexture(for: terrain) {
            let node = SKSpriteNode(texture: texture, size: .zero)
            node.name = "terrain.\(terrain)"
            node.zPosition = 0
            node.color = .white
            node.colorBlendFactor = 0
            return node
        }

        let tokens = theme.board.terrain
        let fill: ThemeColor
        let stroke: ThemeColor?
        let symbol: String?
        if cave {
            switch terrain {
            case .void:
                fill = tokens.voidFill
                stroke = nil
                symbol = nil
            case .floor:
                // Dug tunnel — near-black, clearly empty.
                fill = ThemeColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1)
                stroke = ThemeColor(red: 0.18, green: 0.16, blue: 0.14, alpha: 1)
                symbol = nil
            case .dirt:
                // Sand / earth — warm tan, dotted.
                fill = ThemeColor(red: 0.72, green: 0.55, blue: 0.28, alpha: 1)
                stroke = ThemeColor(red: 0.45, green: 0.32, blue: 0.12, alpha: 1)
                symbol = "∷"
            case .wall:
                fill = ThemeColor(red: 0.35, green: 0.32, blue: 0.28, alpha: 1)
                stroke = ThemeColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1)
                symbol = nil
            case .steelWall:
                fill = ThemeColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)
                stroke = ThemeColor(red: 0.25, green: 0.28, blue: 0.32, alpha: 1)
                symbol = nil
            case .goal:
                fill = tokens.goalFill
                stroke = tokens.goalStroke
                symbol = tokens.goalSymbol
            case .exitClosed:
                fill = ThemeColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1)
                stroke = ThemeColor(red: 0.45, green: 0.55, blue: 0.75, alpha: 1)
                symbol = "E"
            case .exitOpen:
                fill = ThemeColor(red: 0.12, green: 0.55, blue: 0.32, alpha: 1)
                stroke = ThemeColor(red: 0.75, green: 1.0, blue: 0.85, alpha: 1)
                symbol = "E"
            }
        } else {
            switch terrain {
            case .void:
                fill = tokens.voidFill
                stroke = nil
                symbol = nil
            case .floor:
                fill = tokens.floorFill
                stroke = tokens.floorStroke
                symbol = nil
            case .wall, .steelWall:
                fill = tokens.wallFill
                stroke = tokens.wallStroke
                symbol = tokens.wallSymbol
            case .dirt:
                fill = tokens.floorFill
                stroke = tokens.wallStroke
                symbol = "·"
            case .goal:
                fill = tokens.goalFill
                stroke = tokens.goalStroke
                symbol = tokens.goalSymbol
            case .exitOpen:
                fill = tokens.goalFill
                stroke = tokens.goalStroke
                symbol = "E"
            case .exitClosed:
                fill = tokens.wallFill
                stroke = tokens.goalStroke
                symbol = "E"
            }
        }

        let node = SKSpriteNode(color: fill.skColor, size: .zero)
        node.name = "terrain.\(terrain)"
        node.zPosition = 0
        node.texture = nil
        if let stroke {
            node.addChild(makeStrokeNode(color: stroke.skColor))
        }
        if let symbol {
            let color: NSColor
            switch terrain {
            case .exitOpen:
                color = NSColor(calibratedRed: 0.85, green: 1.0, blue: 0.9, alpha: 1)
            case .dirt:
                color = NSColor(calibratedRed: 0.4, green: 0.28, blue: 0.1, alpha: 1)
            default:
                color = stroke?.skColor ?? theme.board.terrain.wallStroke.skColor
            }
            node.addChild(makeSemanticLabel(text: symbol, color: color))
        }
        return node
    }

    private func makeEntityNode(kind: EntityKind) -> SKSpriteNode {
        let cave = presentsCaveContent

        // Cave player reuses the Sokoban player sprite when a pixel theme is active.
        if cave, kind == .player, usesPixelTextures, let texture = entityTexture(for: .player, onGoal: false) {
            let node = SKSpriteNode(texture: texture, size: .zero)
            node.name = "entity.\(kind)"
            node.zPosition = 2
            node.color = .white
            node.colorBlendFactor = 0
            return node
        }

        if !cave, usesPixelTextures, let texture = entityTexture(for: kind, onGoal: false) {
            let node = SKSpriteNode(texture: texture, size: .zero)
            node.name = "entity.\(kind)"
            node.zPosition = kind == .player ? 2 : 1
            node.color = .white
            node.colorBlendFactor = 0
            return node
        }

        let tokens = theme.board.entities
        let fill: ThemeColor
        let stroke: ThemeColor
        let symbol: String
        switch kind {
        case .player:
            fill = tokens.playerFill
            stroke = tokens.playerStroke
            symbol = tokens.playerSymbol
        case .crate:
            fill = tokens.crateFill
            stroke = tokens.crateStroke
            symbol = tokens.crateSymbol
        case .boulder:
            // Gray rock — never a wooden crate.
            fill = ThemeColor(red: 0.62, green: 0.62, blue: 0.65, alpha: 1)
            stroke = ThemeColor(red: 0.22, green: 0.22, blue: 0.25, alpha: 1)
            symbol = "●"
        case .diamond:
            fill = ThemeColor(red: 0.15, green: 0.85, blue: 0.95, alpha: 1)
            stroke = ThemeColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
            symbol = "◆"
        }

        let node = SKSpriteNode(color: fill.skColor, size: .zero)
        node.name = "entity.\(kind)"
        node.zPosition = kind == .player ? 2 : 1
        node.texture = nil
        node.addChild(makeStrokeNode(color: stroke.skColor))
        node.addChild(makeSemanticLabel(text: symbol, color: stroke.skColor))
        if !cave {
            let goalMarker = makeSemanticLabel(
                text: kind == .player
                    ? theme.board.stateMarkers.playerOnGoalSymbol
                    : theme.board.stateMarkers.crateOnGoalSymbol,
                color: kind == .player
                    ? theme.board.stateMarkers.playerOnGoalColor.skColor
                    : theme.board.stateMarkers.crateOnGoalColor.skColor
            )
            goalMarker.name = "goalStateMarker"
            goalMarker.alpha = 0
            goalMarker.zPosition = 2
            node.addChild(goalMarker)
        }
        return node
    }

    private func terrainTexture(for terrain: RenderTerrain) -> SKTexture? {
        guard let paths = theme.rendering.textures else { return nil }
        switch terrain {
        case .void: return nil
        case .floor, .dirt: return cachedTexture(at: paths.floor)
        case .wall, .steelWall, .exitClosed: return cachedTexture(at: paths.wall)
        case .goal, .exitOpen: return cachedTexture(at: paths.goal)
        }
    }

    private func entityTexture(for kind: EntityKind, onGoal: Bool) -> SKTexture? {
        guard let paths = theme.rendering.textures else { return nil }
        switch kind {
        case .player:
            return cachedTexture(at: paths.player)
        case .crate, .boulder:
            return cachedTexture(at: onGoal ? paths.crateOnGoal : paths.crate)
        case .diamond:
            return cachedTexture(at: paths.goal)
        }
    }

    private func cachedTexture(at path: String) -> SKTexture? {
        if let cached = textureCache[path] { return cached }
        let resources = BundleContentResources(bundle: Bundle(for: SokobanBoardScene.self))
        guard let url = try? resources.url(at: path),
            let image = NSImage(contentsOf: url)
        else {
            return nil
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        textureCache[path] = texture
        return texture
    }

    private func makeStrokeNode(color: SKColor) -> SKShapeNode {
        let stroke = SKShapeNode(rectOf: CGSize(width: 1, height: 1))
        stroke.name = "stroke"
        stroke.fillColor = .clear
        stroke.strokeColor = color
        stroke.lineWidth = 2
        stroke.zPosition = 0.5
        stroke.isAntialiased = false
        return stroke
    }

    private func updateStroke(for node: SKSpriteNode, tileSize: CGFloat) {
        guard let stroke = node.childNode(withName: "stroke") as? SKShapeNode else { return }
        let inset = max(1, tileSize * 0.04)
        let edge = max(1, node.size.width - inset)
        stroke.path = CGPath(
            rect: CGRect(x: -edge / 2, y: -edge / 2, width: edge, height: edge),
            transform: nil
        )
        stroke.lineWidth = max(1.5, tileSize * 0.045)
    }

    private func makeSemanticLabel(text: String, color: SKColor) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.name = "semanticMarker"
        label.text = text
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 1
        return label
    }

    private func resizeSemanticMarkers(in node: SKNode, tileSize: CGFloat) {
        for case let label as SKLabelNode in node.children {
            label.fontSize = max(
                8,
                tileSize * (label.name == "goalStateMarker" ? 0.34 : 0.48)
            )
        }
    }

    private func updateGoalStateMarkers(using snapshot: RenderSnapshot) {
        // Cave entities are not Sokoban crates — never swap in crate textures.
        guard !presentsCaveContent else { return }

        for entity in snapshot.entities {
            guard let node = entityNodes[entity.ref.id] else { continue }
            let onGoal = snapshot.cell(at: entity.position)?.terrain == .goal
            if usesPixelTextures {
                if let texture = entityTexture(for: .crate, onGoal: onGoal) {
                    node.texture = texture
                }
            } else if let marker = node.childNode(withName: "goalStateMarker") as? SKLabelNode {
                marker.alpha = onGoal ? 1 : 0
            }
        }

        // Pixel themes: no separate player-on-goal marker; goal terrain shows through.
        if !usesPixelTextures,
           let marker = playerNode?.childNode(withName: "goalStateMarker") as? SKLabelNode
        {
            marker.alpha = snapshot.cell(at: snapshot.player.position)?.terrain == .goal ? 1 : 0
        }
    }

    private func scheduleFeedbackSymbol(
        _ symbol: String,
        at position: GridPosition,
        color: SKColor,
        group: DispatchGroup
    ) {
        let label = makeSemanticLabel(text: symbol, color: color)
        label.name = "eventFeedback"
        label.fontSize = max(10, geometry.tileSize * 0.62)
        label.position = geometry.center(for: position)
        label.zPosition = 4
        label.alpha = 0
        effectLayer.addChild(label)

        let visibleDuration = prefersReducedMotion ? 0.08 : 0.22
        group.enter()
        label.run(
            .sequence([
                .fadeIn(withDuration: prefersReducedMotion ? 0 : 0.02),
                .wait(forDuration: visibleDuration),
                .fadeOut(withDuration: prefersReducedMotion ? 0 : 0.06),
                .removeFromParent(),
            ])
        ) {
            group.leave()
        }
    }

    private func schedulePushPulse(on node: SKSpriteNode, group: DispatchGroup) {
        let highlight = theme.board.feedback.pushHighlight.skColor
        let usesTexture = node.texture != nil
        let originalColor = node.color
        let originalBlend = node.colorBlendFactor
        group.enter()

        let applyHighlight = {
            node.color = highlight
            node.colorBlendFactor = usesTexture ? 0.55 : 1
        }
        let restore = {
            node.color = originalColor
            node.colorBlendFactor = originalBlend
        }

        if prefersReducedMotion {
            applyHighlight()
            node.run(
                .sequence([
                    .wait(forDuration: 0.06),
                    .run(restore),
                ])
            ) {
                group.leave()
            }
            return
        }

        let duration = Self.pushFeedbackDuration
        node.run(
            .group([
                .sequence([
                    .scale(to: 0.88, duration: duration * 0.35),
                    .scale(to: 1.0, duration: duration * 0.65),
                ]),
                .sequence([
                    .run(applyHighlight),
                    .wait(forDuration: duration * 0.45),
                    .run(restore),
                ]),
            ])
        ) {
            node.setScale(1)
            restore()
            group.leave()
        }
    }

    private func scheduleCompletionCelebration(
        using snapshot: RenderSnapshot,
        group: DispatchGroup
    ) {
        layoutCompletionFrame()
        celebrationVisualsActive = true
        group.enter()

        if prefersReducedMotion {
            applyCompletionFrame(visible: true, animated: false)
            pulseGoalTiles(using: snapshot, animated: false)
            group.leave()
            return
        }

        applyCompletionFrame(visible: true, animated: true)
        pulseGoalTiles(using: snapshot, animated: true)
        frameNode.run(.wait(forDuration: Self.completionCelebrationDuration)) {
            group.leave()
        }
    }

    /// Restores terrain fills and hides the success frame so presentation matches snapshot.
    private func clearCelebrationPresentation(using snapshot: RenderSnapshot) {
        restoreTerrainColors(using: snapshot)
        applyCompletionFrame(visible: false, animated: false)
        celebrationVisualsActive = false
    }

    private func restoreTerrainColors(using snapshot: RenderSnapshot) {
        let cave = presentsCaveContent
        var index = 0
        for row in 0..<snapshot.height {
            for column in 0..<snapshot.width {
                defer { index += 1 }
                guard index < terrainNodes.count else { return }
                let position = GridPosition(column: column, row: row)
                guard let cell = snapshot.cell(at: position) else { continue }
                let node = terrainNodes[index]
                node.removeAction(forKey: "goalPulse")
                if cave {
                    // Never re-apply Sokoban pixel floor/wall onto cave dirt/tunnels.
                    node.texture = nil
                    node.colorBlendFactor = 1
                    node.color = fillColor(for: cell.terrain).skColor
                } else if usesPixelTextures {
                    node.color = .white
                    node.colorBlendFactor = 0
                    if let texture = terrainTexture(for: cell.terrain) {
                        node.texture = texture
                    }
                } else {
                    node.color = fillColor(for: cell.terrain).skColor
                }
            }
        }
    }

    private func fillColor(for terrain: RenderTerrain) -> ThemeColor {
        if presentsCaveContent {
            switch terrain {
            case .void: return theme.board.terrain.voidFill
            case .floor: return ThemeColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1)
            case .dirt: return ThemeColor(red: 0.72, green: 0.55, blue: 0.28, alpha: 1)
            case .wall: return ThemeColor(red: 0.35, green: 0.32, blue: 0.28, alpha: 1)
            case .steelWall: return ThemeColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)
            case .goal: return theme.board.terrain.goalFill
            case .exitOpen: return ThemeColor(red: 0.12, green: 0.55, blue: 0.32, alpha: 1)
            case .exitClosed: return ThemeColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1)
            }
        }
        switch terrain {
        case .void: return theme.board.terrain.voidFill
        case .floor, .dirt: return theme.board.terrain.floorFill
        case .wall, .steelWall, .exitClosed: return theme.board.terrain.wallFill
        case .goal, .exitOpen: return theme.board.terrain.goalFill
        }
    }

    private func layoutCompletionFrame() {
        let board = CGRect(
            origin: geometry.boardOrigin,
            size: geometry.boardSize
        ).insetBy(dx: -4, dy: -4)
        frameNode.path = CGPath(rect: board, transform: nil)
        frameNode.strokeColor = theme.board.feedback.completionFrame.skColor
        frameNode.lineWidth = max(3, geometry.tileSize * 0.08)
        frameNode.zPosition = 5
    }

    private func applyCompletionFrame(visible: Bool, animated: Bool) {
        layoutCompletionFrame()
        frameNode.isHidden = false
        frameNode.removeAllActions()
        if !animated || prefersReducedMotion {
            frameNode.alpha = visible ? 1 : 0
            if !visible {
                frameNode.isHidden = true
            }
            return
        }
        if visible {
            frameNode.alpha = 0
            frameNode.run(
                .sequence([
                    .fadeIn(withDuration: 0.08),
                    .repeat(
                        .sequence([
                            .fadeAlpha(to: 0.45, duration: 0.12),
                            .fadeAlpha(to: 1.0, duration: 0.12),
                        ]),
                        count: 2
                    ),
                ])
            )
        } else {
            frameNode.run(
                .sequence([
                    .fadeOut(withDuration: 0.05),
                    .run { [weak self] in self?.frameNode.isHidden = true },
                ])
            )
        }
    }

    private func pulseGoalTiles(using snapshot: RenderSnapshot, animated: Bool) {
        var index = 0
        for row in 0..<snapshot.height {
            for column in 0..<snapshot.width {
                defer { index += 1 }
                guard index < terrainNodes.count else { return }
                let position = GridPosition(column: column, row: row)
                guard snapshot.cell(at: position)?.terrain == .goal else { continue }
                let node = terrainNodes[index]
                node.removeAction(forKey: "goalPulse")
                let highlight = theme.board.feedback.completionFrame.skColor
                let goalFill = theme.board.terrain.goalFill.skColor
                let usesTexture = usesPixelTextures && node.texture != nil
                let applyHighlight = {
                    node.color = highlight
                    node.colorBlendFactor = usesTexture ? 0.45 : 1
                }
                let restore = {
                    if usesTexture {
                        node.color = .white
                        node.colorBlendFactor = 0
                    } else {
                        node.color = goalFill
                        node.colorBlendFactor = 0
                    }
                }
                if !animated || prefersReducedMotion {
                    applyHighlight()
                    continue
                }
                node.run(
                    .sequence([
                        .run(applyHighlight),
                        .wait(forDuration: 0.12),
                        .run(restore),
                        .wait(forDuration: 0.12),
                        .run(applyHighlight),
                        .wait(forDuration: 0.12),
                        .run(restore),
                    ]),
                    withKey: "goalPulse"
                )
            }
        }
    }

    #if DEBUG
        /// Test helper: force-settle the held in-flight step and drain the queue instantly.
        func settleAnimationsForTesting() {
            guard let snapshot = appliedSnapshot else {
                cancelAnimationsAndPending()
                markSettled(appliedRevision)
                return
            }
            cancelAnimationsAndPending()
            snapEntities(to: snapshot)
            clearCelebrationPresentation(using: snapshot)
            markSettled(appliedRevision)
        }

        var terrainNodeCountForTesting: Int { terrainNodes.count }
        var entityNodeCountForTesting: Int { entityNodes.count + (playerNode == nil ? 0 : 1) }
        var geometryForTesting: GridGeometry { geometry }
        var playerPositionForTesting: CGPoint? { playerNode?.position }
        var isAnimatingForTesting: Bool { isAnimating }
        var queuedAnimationCountForTesting: Int { animationQueue.count }
        private(set) var lastEventsForTesting: [GameEvent] = []
        var crateGoalMarkerCountForTesting: Int {
            entityNodes.values.filter { node in
                node.childNode(withName: "goalStateMarker")?.alpha == 1
            }.count
        }
        var completionFrameVisibleForTesting: Bool {
            !frameNode.isHidden && frameNode.alpha > 0.01
        }
        var themeIDForTesting: String { theme.id }
        var renderingProfileForTesting: BoardRenderingProfile { theme.rendering.profile }
        var celebrationVisualsActiveForTesting: Bool { celebrationVisualsActive }
    #endif
}
