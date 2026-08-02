import AppKit
import Foundation

/// Testable probe for assistive reading that must not auto-dismiss level intros.
protocol AssistiveReadingProbe: AnyObject {
    /// When true, intro Variant B waits for an explicit dismiss (no 5s timer).
    var preventsIntroAutoDismiss: Bool { get }
}

/// Production probe: VoiceOver running implies no intro auto-dismiss.
final class VoiceOverAssistiveReadingProbe: AssistiveReadingProbe {
    var preventsIntroAutoDismiss: Bool {
        NSWorkspace.shared.isVoiceOverEnabled
    }
}

/// Injectable probe for unit tests.
final class ManualAssistiveReadingProbe: AssistiveReadingProbe {
    var preventsIntroAutoDismiss: Bool

    init(preventsIntroAutoDismiss: Bool = false) {
        self.preventsIntroAutoDismiss = preventsIntroAutoDismiss
    }
}
