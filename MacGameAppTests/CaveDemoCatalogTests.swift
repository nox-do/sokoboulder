import Testing
@testable import MacGameApp
import GameCore

@Suite("Cave demo catalog")
struct CaveDemoCatalogTests {
    @Test("three demos parse and keep diamond requirements")
    func catalogParses() throws {
        #expect(CaveDemoCatalog.levels.count == 3)
        for descriptor in CaveDemoCatalog.levels {
            let level = try descriptor.makeLevel()
            #expect(level.requiredDiamonds == descriptor.requiredDiamonds)
            #expect(level.width >= 8)
            #expect(level.height >= 6)
            #expect(CaveDemoCatalog.descriptor(id: descriptor.id)?.id == descriptor.id)
        }
        #expect(CaveDemoCatalog.descriptor(after: "cave.demo.001")?.id == "cave.demo.002")
        #expect(CaveDemoCatalog.descriptor(after: "cave.demo.002")?.id == "cave.demo.003")
        #expect(CaveDemoCatalog.descriptor(after: "cave.demo.003") == nil)
    }

    @Test("compatibility alias still loads the first demo")
    func firstAlias() throws {
        #expect(CaveDemoLevel.id == "cave.demo.001")
        let level = try CaveDemoLevel.makeLevel()
        #expect(level.requiredDiamonds == 1)
    }
}
