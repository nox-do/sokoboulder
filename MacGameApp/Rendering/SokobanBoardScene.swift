import GameCore
import SpriteKit

/// SpriteKit board scene for the Sokoban rendering spike.
///
/// Nodes are presentation-only. Authoritative state stays in ``GameSession``.
/// ``SKScene.update`` does **not** drain the session move queue.
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

    #if DEBUG
    /// When true, the in-flight animate step never settles on its own.
    var holdAnimationsForTesting = false
    #endif

    private struct QueuedAnimate {
        let snapshot: RenderSnapshot
        let targetRevision: UInt64
    }

    private let boardRoot = SKNode()
    private let terrainLayer = SKNode()
    private let entityLayer = SKNode()

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
        backgroundColor = SKColor(calibratedWhite: 0.12, alpha: 1)
        boardRoot.name = "boardRoot"
        terrainLayer.name = "terrainLayer"
        entityLayer.name = "entityLayer"
        addChild(boardRoot)
        boardRoot.addChild(terrainLayer)
        boardRoot.addChild(entityLayer)
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
        terrainLayer.removeAllChildren()
        entityLayer.removeAllChildren()
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
            QueuedAnimate(snapshot: update.snapshot, targetRevision: update.targetRevision)
        )
        pumpAnimationQueue()
    }

    private func pumpAnimationQueue() {
        guard !isAnimating else { return }
        guard !animationQueue.isEmpty else { return }

        let next = animationQueue.removeFirst()
        isAnimating = true
        let generation = animationGeneration

        animate(toward: next.snapshot) { [weak self] in
            guard let self else { return }
            guard generation == self.animationGeneration else { return }
            self.isAnimating = false
            self.snapEntities(to: next.snapshot)
            self.markSettled(next.targetRevision)
            self.pumpAnimationQueue()
        }
    }

    private func hardResync(to update: RenderUpdate) {
        cancelAnimationsAndPending()
        rebuild(from: update.snapshot)
        appliedRevision = update.targetRevision
        appliedSnapshot = update.snapshot
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
    }

    // MARK: - Node build / layout

    private func rebuild(from snapshot: RenderSnapshot) {
        terrainLayer.removeAllChildren()
        entityLayer.removeAllChildren()
        terrainNodes.removeAll(keepingCapacity: true)
        entityNodes.removeAll(keepingCapacity: true)
        playerNode = nil

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
                terrainLayer.addChild(node)
                terrainNodes.append(node)
            }
        }

        for entity in snapshot.entities {
            let node = makeEntityNode(kind: entity.ref.kind)
            node.position = geometry.center(for: entity.position)
            node.size = entitySize()
            entityLayer.addChild(node)
            entityNodes[entity.ref.id] = node
        }

        let player = makeEntityNode(kind: .player)
        player.position = geometry.center(for: snapshot.player.position)
        player.size = entitySize()
        entityLayer.addChild(player)
        playerNode = player
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
                index += 1
            }
        }

        for entity in snapshot.entities {
            guard let node = entityNodes[entity.ref.id] else { continue }
            node.position = geometry.center(for: entity.position)
            node.size = entitySize()
        }

        playerNode?.position = geometry.center(for: snapshot.player.position)
        playerNode?.size = entitySize()
    }

    private func snapEntities(to snapshot: RenderSnapshot) {
        for entity in snapshot.entities {
            guard let node = entityNodes[entity.ref.id] else { continue }
            node.position = geometry.center(for: entity.position)
        }
        playerNode?.position = geometry.center(for: snapshot.player.position)
    }

    private func animate(toward snapshot: RenderSnapshot, completion: @escaping () -> Void) {
        #if DEBUG
        if holdAnimationsForTesting {
            return
        }
        #endif

        let duration = Self.moveAnimationDuration
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

        if scheduled {
            group.notify(queue: .main, execute: completion)
        } else {
            completion()
        }
    }

    private func entitySize() -> CGSize {
        let inset = geometry.tileSize * 0.15
        let edge = max(1, geometry.tileSize - inset)
        return CGSize(width: edge, height: edge)
    }

    private func makeTerrainNode(_ terrain: RenderTerrain) -> SKSpriteNode {
        let node = SKSpriteNode(color: color(for: terrain), size: .zero)
        node.name = "terrain.\(terrain)"
        node.zPosition = 0
        return node
    }

    private func makeEntityNode(kind: EntityKind) -> SKSpriteNode {
        let node = SKSpriteNode(color: color(for: kind), size: .zero)
        node.name = "entity.\(kind)"
        node.zPosition = kind == .player ? 2 : 1
        return node
    }

    private func color(for terrain: RenderTerrain) -> SKColor {
        switch terrain {
        case .void:
            SKColor(calibratedWhite: 0.05, alpha: 1)
        case .floor:
            SKColor(calibratedRed: 0.22, green: 0.28, blue: 0.24, alpha: 1)
        case .wall:
            SKColor(calibratedRed: 0.45, green: 0.40, blue: 0.35, alpha: 1)
        case .goal:
            SKColor(calibratedRed: 0.20, green: 0.45, blue: 0.55, alpha: 1)
        }
    }

    private func color(for kind: EntityKind) -> SKColor {
        switch kind {
        case .player:
            SKColor(calibratedRed: 0.95, green: 0.75, blue: 0.20, alpha: 1)
        case .crate:
            SKColor(calibratedRed: 0.75, green: 0.35, blue: 0.20, alpha: 1)
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
        markSettled(appliedRevision)
    }

    var terrainNodeCountForTesting: Int { terrainNodes.count }
    var entityNodeCountForTesting: Int { entityNodes.count + (playerNode == nil ? 0 : 1) }
    var geometryForTesting: GridGeometry { geometry }
    var playerPositionForTesting: CGPoint? { playerNode?.position }
    var isAnimatingForTesting: Bool { isAnimating }
    var queuedAnimationCountForTesting: Int { animationQueue.count }
    #endif
}
