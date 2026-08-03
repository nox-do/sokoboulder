import Foundation
import Testing
@testable import GameCore

/// One-shot solvability sweep: A* over crate pushes on a lightweight board.
///
/// Not a production feature — run manually, then remove if desired.
@Suite("Campaign solvability one-shot", .serialized)
struct CampaignSolvabilityOneShotTests {
    private let levelsDirectory = URL(fileURLWithPath:
        "/Users/ddeuter/dev/playground/BoulderDash/MacGameApp/Resources/Levels"
    )
    private let logURL = URL(fileURLWithPath: "/tmp/sokoban-solvability.log")
    private let stateBudget = 3_000_000
    private let timeBudgetSeconds: TimeInterval = 45

    @Test("solve or budget-out every campaign level 001-090")
    func solveCampaignLevels() throws {
        try "start \(Date())\n".write(to: logURL, atomically: true, encoding: .utf8)

        let files = try FileManager.default.contentsOfDirectory(
            at: levelsDirectory,
            includingPropertiesForKeys: nil
        )
        .filter {
            $0.lastPathComponent.hasPrefix("sokoban.campaign.") && $0.pathExtension == "json"
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        #expect(files.count == 90)
        appendLog("found \(files.count) campaign files")

        var solved: [String] = []
        var timeouts: [String] = []
        var failed: [(String, String)] = []
        let rules = SokobanRules()
        let wallStart = Date()

        for fileURL in files {
            let id = fileURL.deletingPathExtension().lastPathComponent
            let levelStart = Date()
            let data = try Data(contentsOf: fileURL)
            let decoded = try SokobanLevelJSONCodec.decode(data)
            let start = try rules.start(level: decoded.level)
            if start.status == .completed {
                solved.append("\(id) (0)")
                appendLog("checked \(id): already completed")
                continue
            }

            let board = Board(state: start, level: decoded.level)
            let result = board.solve(stateBudget: stateBudget, timeBudgetSeconds: timeBudgetSeconds)
            let elapsed = String(format: "%.2fs", Date().timeIntervalSince(levelStart))
            switch result {
            case .solved(let pushes):
                solved.append("\(id) (\(pushes)p)")
            case .budgetExceeded(let visited):
                timeouts.append("\(id)(\(visited))")
            case .exhausted(let visited):
                failed.append((id, "exhausted after \(visited)"))
            }
            appendLog("checked \(id): \(result) [\(elapsed)]")
        }

        let report = """
        SOLVED \(solved.count)/\(files.count) in \(String(format: "%.1fs", Date().timeIntervalSince(wallStart)))
        TIMEOUT \(timeouts.count): \(timeouts.joined(separator: ", "))
        UNSOLVED \(failed.count): \(failed.map { "\($0.0)=\($0.1)" }.joined(separator: "; "))
        """
        appendLog(report)

        #expect(failed.isEmpty, Comment(rawValue: report))
        if !timeouts.isEmpty {
            Issue.record(Comment(rawValue: "Budget timeouts (inconclusive): \(timeouts.joined(separator: ", "))"))
        }
    }

    private func appendLog(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        }
    }
}

// MARK: - Lightweight push A*

private enum SolveResult: CustomStringConvertible {
    case solved(pushes: Int)
    case budgetExceeded(visited: Int)
    case exhausted(visited: Int)

    var description: String {
        switch self {
        case .solved(let pushes): "solved in \(pushes) pushes"
        case .budgetExceeded(let n): "timeout/budget after \(n) states"
        case .exhausted(let n): "exhausted after \(n) states"
        }
    }
}

/// Compact Sokoban board for push-only A*. Cells packed as row * width + column.
private struct Board {
    let width: Int
    let height: Int
    let walkable: [Bool]
    let goals: [Int]
    let dead: [Bool]
    let startPlayer: Int
    let startCrates: [Int]

    init(state: SokobanState, level: SokobanLevel) {
        width = state.grid.width
        height = state.grid.height
        let deadSet = SokobanStaticDeadlockAnalyzer.staticDeadSquares(in: level)
        var walkable = Array(repeating: false, count: width * height)
        var goals: [Int] = []
        var dead = Array(repeating: false, count: width * height)
        var crates: [Int] = []
        for row in 0..<height {
            for column in 0..<width {
                let pos = GridPosition(column: column, row: row)
                let idx = row * width + column
                let cell = state.grid[pos]
                walkable[idx] = cell.isWalkable
                if cell.isGoal { goals.append(idx) }
                if deadSet.contains(pos) { dead[idx] = true }
                if case .crate = cell.occupant { crates.append(idx) }
            }
        }
        self.walkable = walkable
        self.goals = goals
        self.dead = dead
        self.startPlayer = state.playerPosition.row * width + state.playerPosition.column
        self.startCrates = crates.sorted()
    }

    func solve(stateBudget: Int, timeBudgetSeconds: TimeInterval) -> SolveResult {
        if isSolved(startCrates) {
            return .solved(pushes: 0)
        }

        let deadline = Date().addingTimeInterval(timeBudgetSeconds)
        let half = Date().addingTimeInterval(timeBudgetSeconds * 0.4)
        let reverse = solveReverse(stateBudget: stateBudget / 2, deadline: half)
        if case .solved = reverse {
            return reverse
        }
        let forward = solveForwardGreedy(stateBudget: stateBudget / 2, deadline: deadline)
        switch (reverse, forward) {
        case (_, .solved):
            return forward
        case (.budgetExceeded(let a), .budgetExceeded(let b)):
            return .budgetExceeded(visited: a + b)
        case (.budgetExceeded(let a), .exhausted):
            return .budgetExceeded(visited: a)
        case (.exhausted, .budgetExceeded(let b)):
            return .budgetExceeded(visited: b)
        case (.exhausted, .exhausted):
            return .exhausted(visited: 0)
        default:
            return forward
        }
    }

    /// Pull-BFS starting from all crates on goals.
    private func solveReverse(stateBudget: Int, deadline: Date) -> SolveResult {
        let goalCrates = goals.sorted()
        let startTarget = StateKey(
            crates: startCrates,
            player: normalizedPlayer(player: startPlayer, crates: Set(startCrates))
        )

        var visited = Set<StateKey>()
        var queue: [(player: Int, crates: [Int], depth: Int)] = []
        let goalCrateSet = Set(goalCrates)

        // One seed per connected component of free cells with crates on goals.
        for idx in 0..<(width * height) where walkable[idx] && !goalCrateSet.contains(idx) {
            let key = StateKey(
                crates: goalCrates,
                player: normalizedPlayer(player: idx, crates: goalCrateSet)
            )
            if visited.insert(key).inserted {
                queue.append((idx, goalCrates, 0))
            }
        }
        if queue.isEmpty {
            return .exhausted(visited: 0)
        }

        var head = 0
        while head < queue.count {
            if Date() > deadline || visited.count >= stateBudget {
                return .budgetExceeded(visited: visited.count)
            }

            let node = queue[head]
            head += 1

            let key = StateKey(
                crates: node.crates,
                player: normalizedPlayer(player: node.player, crates: Set(node.crates))
            )
            if key == startTarget {
                return .solved(pushes: node.depth)
            }

            let crateSet = Set(node.crates)
            let reach = reachable(from: node.player, crates: crateSet)

            for crate in node.crates {
                for dir in 0..<4 {
                    let pullTo = neighbor(crate, dir: dir)
                    let playerEnd = neighbor(pullTo, dir: dir)
                    guard pullTo >= 0, playerEnd >= 0 else { continue }
                    guard walkable[pullTo], walkable[playerEnd] else { continue }
                    guard !crateSet.contains(pullTo), !crateSet.contains(playerEnd) else { continue }
                    guard reach.contains(pullTo) else { continue }

                    var nextCrates = node.crates
                    if let idx = nextCrates.firstIndex(of: crate) {
                        nextCrates[idx] = pullTo
                        nextCrates.sort()
                    }

                    let nextPlayer = playerEnd
                    let nextKey = StateKey(
                        crates: nextCrates,
                        player: normalizedPlayer(player: nextPlayer, crates: Set(nextCrates))
                    )
                    if nextKey == startTarget {
                        return .solved(pushes: node.depth + 1)
                    }
                    if visited.insert(nextKey).inserted {
                        queue.append((nextPlayer, nextCrates, node.depth + 1))
                    }
                }
            }
        }

        return .exhausted(visited: visited.count)
    }

    private func solveForwardGreedy(stateBudget: Int, deadline: Date) -> SolveResult {
        let goalSet = Set(goals)
        var visited = Set<StateKey>()
        var heap = GreedyHeap()
        let startKey = StateKey(
            crates: startCrates,
            player: normalizedPlayer(player: startPlayer, crates: Set(startCrates))
        )
        visited.insert(startKey)
        heap.push(GreedyNode(h: heuristic(startCrates), player: startPlayer, crates: startCrates, depth: 0))

        while let node = heap.pop() {
            if Date() > deadline || visited.count >= stateBudget {
                return .budgetExceeded(visited: visited.count)
            }
            if isSolved(node.crates) {
                return .solved(pushes: node.depth)
            }

            let crateSet = Set(node.crates)
            let reach = reachable(from: node.player, crates: crateSet)

            for crate in node.crates {
                for dir in 0..<4 {
                    let pushFrom = neighbor(crate, dir: opposite(dir))
                    let pushTo = neighbor(crate, dir: dir)
                    guard pushFrom >= 0, reach.contains(pushFrom) else { continue }
                    guard pushTo >= 0, walkable[pushTo], !crateSet.contains(pushTo) else { continue }
                    if dead[pushTo], !goalSet.contains(pushTo) { continue }

                    var nextCrates = node.crates
                    if let idx = nextCrates.firstIndex(of: crate) {
                        nextCrates[idx] = pushTo
                        nextCrates.sort()
                    }

                    if isSolved(nextCrates) {
                        return .solved(pushes: node.depth + 1)
                    }

                    let nextPlayer = crate
                    let nextKey = StateKey(
                        crates: nextCrates,
                        player: normalizedPlayer(player: nextPlayer, crates: Set(nextCrates))
                    )
                    if visited.insert(nextKey).inserted {
                        heap.push(GreedyNode(
                            h: heuristic(nextCrates),
                            player: nextPlayer,
                            crates: nextCrates,
                            depth: node.depth + 1
                        ))
                    }
                }
            }
        }

        return .exhausted(visited: visited.count)
    }

    private func heuristic(_ crates: [Int]) -> Int {
        var total = 0
        for crate in crates {
            let cr = crate / width
            let cc = crate % width
            var best = Int.max
            for goal in goals {
                let d = abs(cr - goal / width) + abs(cc - goal % width)
                if d < best { best = d }
            }
            total += best == Int.max ? 0 : best
        }
        return total
    }

    private func isSolved(_ crates: [Int]) -> Bool {
        let set = Set(crates)
        return goals.allSatisfy { set.contains($0) }
    }

    private func normalizedPlayer(player: Int, crates: Set<Int>) -> Int {
        let reach = reachable(from: player, crates: crates)
        return reach.min() ?? player
    }

    private func reachable(from start: Int, crates: Set<Int>) -> Set<Int> {
        var seen: Set<Int> = [start]
        var queue = [start]
        var head = 0
        while head < queue.count {
            let cur = queue[head]
            head += 1
            for dir in 0..<4 {
                let next = neighbor(cur, dir: dir)
                guard next >= 0, walkable[next], !crates.contains(next) else { continue }
                if seen.insert(next).inserted {
                    queue.append(next)
                }
            }
        }
        return seen
    }

    private func neighbor(_ index: Int, dir: Int) -> Int {
        let row = index / width
        let col = index % width
        let nr: Int
        let nc: Int
        switch dir {
        case 0: nr = row - 1; nc = col
        case 1: nr = row + 1; nc = col
        case 2: nr = row; nc = col - 1
        default: nr = row; nc = col + 1
        }
        guard nr >= 0, nr < height, nc >= 0, nc < width else { return -1 }
        return nr * width + nc
    }

    private func opposite(_ dir: Int) -> Int {
        switch dir {
        case 0: 1
        case 1: 0
        case 2: 3
        default: 2
        }
    }

    private struct StateKey: Hashable {
        let crates: [Int]
        let player: Int
    }

    private struct GreedyNode {
        let h: Int
        let player: Int
        let crates: [Int]
        let depth: Int
    }

    private struct GreedyHeap {
        private var storage: [GreedyNode] = []

        mutating func push(_ node: GreedyNode) {
            storage.append(node)
            var i = storage.count - 1
            while i > 0 {
                let p = (i - 1) / 2
                if storage[p].h <= storage[i].h { break }
                storage.swapAt(p, i)
                i = p
            }
        }

        mutating func pop() -> GreedyNode? {
            guard let first = storage.first else { return nil }
            if storage.count == 1 {
                storage.removeLast()
                return first
            }
            storage[0] = storage.removeLast()
            var i = 0
            while true {
                let l = 2 * i + 1
                let r = 2 * i + 2
                var s = i
                if l < storage.count, storage[l].h < storage[s].h { s = l }
                if r < storage.count, storage[r].h < storage[s].h { s = r }
                if s == i { break }
                storage.swapAt(i, s)
                i = s
            }
            return first
        }
    }
}
