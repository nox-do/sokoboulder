import AppKit
import Combine
import Foundation

/// Supplies the macOS “Reduce Motion” accessibility flag without owning persistence.
protocol SystemReduceMotionSource: AnyObject {
    var systemReduceMotionEnabled: Bool { get }
    /// Fires when the system accessibility display setting may have changed.
    var systemReduceMotionDidChange: AnyPublisher<Void, Never> { get }
}

/// Live `NSWorkspace` reduce-motion observation.
final class WorkspaceReduceMotionSource: SystemReduceMotionSource {
    private let notificationCenter: NotificationCenter

    /// Production uses ``NSWorkspace/shared``'s notification center.
    /// Tests may inject another center to prove delivery without relying on
    /// `NotificationCenter.default` (which does not receive this notification).
    init(notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter) {
        self.notificationCenter = notificationCenter
    }

    var systemReduceMotionEnabled: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    var systemReduceMotionDidChange: AnyPublisher<Void, Never> {
        // Must use the workspace notification center — Apple documents that this
        // notification is not delivered to NotificationCenter.default.
        notificationCenter.publisher(
            for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
        )
        .map { _ in () }
        .eraseToAnyPublisher()
    }
}

/// Test double with a manually toggled system flag.
final class ManualReduceMotionSource: SystemReduceMotionSource {
    private let subject = PassthroughSubject<Void, Never>()
    /// Optional sync hook so tests can observe without waiting for RunLoop delivery.
    var onChange: (() -> Void)?

    var systemReduceMotionEnabled: Bool {
        didSet {
            guard oldValue != systemReduceMotionEnabled else { return }
            onChange?()
            subject.send(())
        }
    }

    var systemReduceMotionDidChange: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    init(systemReduceMotionEnabled: Bool = false) {
        self.systemReduceMotionEnabled = systemReduceMotionEnabled
    }
}

/// Effective reduce motion = system setting OR app toggle. Never writes the system flag.
@MainActor
final class ReduceMotionProvider: ObservableObject {
    private let settings: AppSettingsStore
    private let systemSource: any SystemReduceMotionSource
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var isReduceMotionEffective: Bool

    /// Called synchronously whenever the effective value may have changed.
    var onEffectiveChange: ((Bool) -> Void)?

    init(
        settings: AppSettingsStore,
        systemSource: any SystemReduceMotionSource = WorkspaceReduceMotionSource()
    ) {
        self.settings = settings
        self.systemSource = systemSource
        self.isReduceMotionEffective =
            systemSource.systemReduceMotionEnabled || settings.reduceMotionEnabled

        _ = settings.addChangeHandler { [weak self] in
            self?.refresh()
        }

        systemSource.systemReduceMotionDidChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    func refresh() {
        let next = systemSource.systemReduceMotionEnabled || settings.reduceMotionEnabled
        if next != isReduceMotionEffective {
            isReduceMotionEffective = next
        }
        onEffectiveChange?(isReduceMotionEffective)
    }
}
