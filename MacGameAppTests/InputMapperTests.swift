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

    @Test("plain Z maps to undo via character, not ANSI keyCode")
    func plainZUndo() {
        #expect(InputMapper.intent(from: TestKeyEvent.keyDown(KeyCode.z, characters: "z")) == .undo)
    }

    @Test("German QWERTZ labeled Z key (ANSI Y keyCode) undoes")
    func germanQWERTZCommandZ() {
        // On QWERTZ the key labeled Z is kVK_ANSI_Y (16); characters are still "z".
        let plain = TestKeyEvent.keyDown(KeyCode.y, characters: "z")
        #expect(InputMapper.intent(from: plain) == .undo)

        let commandZ = TestKeyEvent.keyDown(KeyCode.y, characters: "z", modifiers: .command)
        #expect(InputMapper.intent(from: commandZ) == .undo)

        let redo = TestKeyEvent.keyDown(
            KeyCode.y,
            characters: "Z",
            modifiers: [.command, .shift]
        )
        #expect(InputMapper.intent(from: redo) == .redo)

        // Physical ANSI-Z key produces "y" on QWERTZ — must not steal Undo.
        #expect(InputMapper.intent(from: TestKeyEvent.keyDown(KeyCode.z, characters: "y")) == nil)
    }

    @Test("R maps to restart")
    func rRestart() {
        #expect(InputMapper.intent(from: TestKeyEvent.keyDown(KeyCode.r, characters: "r")) == .restart)
    }

    @Test("M maps to goal-marker toggle via character")
    func mTogglesGoalMarker() {
        #expect(
            InputMapper.intent(from: TestKeyEvent.keyDown(KeyCode.m, characters: "m"))
                == .toggleGoalMarker
        )
        #expect(
            InputMapper.intent(
                from: TestKeyEvent.keyDown(KeyCode.m, characters: "m", modifiers: .command)
            ) == nil
        )
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

    @Test("Command-Z maps to undo via local-monitor path")
    func commandZUndo() {
        let event = TestKeyEvent.keyDown(
            KeyCode.z,
            characters: "z",
            modifiers: .command
        )
        #expect(InputMapper.intent(from: event) == .undo)
    }

    @Test("Shift-Command-Z maps to redo via local-monitor path")
    func shiftCommandZRedo() {
        let event = TestKeyEvent.keyDown(
            KeyCode.z,
            characters: "z",
            modifiers: [.command, .shift]
        )
        #expect(InputMapper.intent(from: event) == .redo)
    }

    @Test("Command-R maps to restart via local-monitor path")
    func commandRRestart() {
        let event = TestKeyEvent.keyDown(
            KeyCode.r,
            characters: "r",
            modifiers: .command
        )
        #expect(InputMapper.intent(from: event) == .restart)
    }

    @Test("Command-Option-Z and Control-Z stay ignored")
    func exoticModifierCombosIgnored() {
        #expect(
            InputMapper.intent(
                from: TestKeyEvent.keyDown(
                    KeyCode.z,
                    characters: "z",
                    modifiers: [.command, .option]
                )
            ) == nil
        )
        #expect(
            InputMapper.intent(
                from: TestKeyEvent.keyDown(
                    KeyCode.z,
                    characters: "z",
                    modifiers: .control
                )
            ) == nil
        )
    }

    @Test("Space maps to wait; unsupported keys are ignored")
    func unsupportedIgnored() {
        #expect(InputMapper.intent(from: TestKeyEvent.keyDown(KeyCode.space)) == .wait)
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
