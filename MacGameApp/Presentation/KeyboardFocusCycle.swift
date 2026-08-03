import Foundation

/// Deterministic focus traversal used by game-style menus.
///
/// The app owns this traversal instead of depending on the macOS
/// "Full Keyboard Access" setting. Overlay key events are handled by
/// ``SokobanPlayController`` via the window local monitor / ``OverlayMenuNavigator``.
enum KeyboardFocusCycle {
    static func move<Item: Equatable>(
        from current: Item?,
        in items: [Item],
        offset: Int
    ) -> Item? {
        guard !items.isEmpty else { return nil }
        guard offset != 0 else { return current ?? items[0] }

        guard let currentIndex = current.flatMap(items.firstIndex(of:)) else {
            return items[0]
        }
        let nextIndex = (currentIndex + offset).modulo(items.count)
        return items[nextIndex]
    }
}

extension Int {
    fileprivate func modulo(_ divisor: Int) -> Int {
        let remainder = self % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
