import AppKit
import Testing
@testable import GameCore
@testable import MacGameApp

@Suite("InputMapper")
struct InputMapperTests {
    @Test("arrows and WASD map to movement")
    func arrowsAndWASD() {
        #expect(InputMapper.intent(from: TestKeyEvent.keyDown(KeyCode.upArrow)) == .move(.up))
        #expect(InputMapper.intent(from: TestKeyEvent.keyDown(KeyCode.downArrow)) == .move(.down))
        #expect(InputMapper.intent(from: TestKeyEvent.keyDown(KeyCode.leftArrow)) == .move(.left))
        #expect(InputMapper.intent(from: TestKeyEvent.keyDown(KeyCode.rightArrow)) == .move(.right))
        #expect(InputMapper.intent(from: TestKeyEvent.keyDown(KeyCode.w, characters: "w")) == .move(.up))
        #expect(InputMapper.intent(from: TestKeyEvent.keyDown(KeyCode.a, characters: "a")) == .move(.left))
        #expect(InputMapper.intent(from: TestKeyEvent.keyDown(KeyCode.s, characters: "s")) == .move(.down))
        #expect(InputMapper.intent(from: TestKeyEvent.keyDown(KeyCode.d, characters: "d")) == .move(.right))
    }

    @Test("plain Z maps to undo")
    func plainZUndo() {
        #expect(InputMapper.intent(from: TestKeyEvent.keyDown(KeyCode.z, characters: "z")) == .undo)
    }

    @Test("R maps to restart")
    func rRestart() {
        #expect(InputMapper.intent(from: TestKeyEvent.keyDown(KeyCode.r, characters: "r")) == .restart)
    }

    @Test("Escape maps to pause")
    func escapePause() {
        #expect(InputMapper.intent(from: TestKeyEvent.keyDown(KeyCode.escape)) == .pause)
    }

    @Test("isARepeat is discarded")
    func discardsRepeat() {
        let event = TestKeyEvent.keyDown(KeyCode.rightArrow, isARepeat: true)
        #expect(InputMapper.intent(from: event) == nil)
    }

    @Test("Command-Z is ignored by gameplay mapper")
    func commandZIgnored() {
        let event = TestKeyEvent.keyDown(
            KeyCode.z,
            characters: "z",
            modifiers: .command
        )
        #expect(InputMapper.intent(from: event) == nil)
    }

    @Test("Shift-Command-Z is ignored by gameplay mapper")
    func shiftCommandZIgnored() {
        let event = TestKeyEvent.keyDown(
            KeyCode.z,
            characters: "z",
            modifiers: [.command, .shift]
        )
        #expect(InputMapper.intent(from: event) == nil)
    }

    @Test("unsupported keys are ignored")
    func unsupportedIgnored() {
        #expect(InputMapper.intent(from: TestKeyEvent.keyDown(KeyCode.space)) == nil)
        #expect(InputMapper.intent(from: TestKeyEvent.keyDown(9, characters: "v")) == nil)
    }

    @Test("Caps Lock does not block; Control/Option do")
    func modifiers() {
        #expect(
            InputMapper.intent(
                from: TestKeyEvent.keyDown(KeyCode.rightArrow, modifiers: .capsLock)
            ) == .move(.right)
        )
        #expect(
            InputMapper.intent(
                from: TestKeyEvent.keyDown(KeyCode.rightArrow, modifiers: .control)
            ) == nil
        )
        #expect(
            InputMapper.intent(
                from: TestKeyEvent.keyDown(KeyCode.rightArrow, modifiers: .option)
            ) == nil
        )
        #expect(
            InputMapper.intent(
                from: TestKeyEvent.keyDown(KeyCode.w, characters: "w", modifiers: .command)
            ) == nil
        )
    }

    @Test("key-up produces no intent")
    func keyUpIgnored() {
        #expect(InputMapper.intent(from: TestKeyEvent.keyUp(KeyCode.rightArrow)) == nil)
    }
}
