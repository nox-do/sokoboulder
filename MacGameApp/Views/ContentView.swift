import GameCore
import SwiftUI

/// Minimal shell that proves the app target links `GameCore`.
struct ContentView: View {
    var body: some View {
        Text("SokoBoulder")
            .font(.largeTitle)
            .padding()
            .accessibilityIdentifier("app.root")
            // Touch a GameCore type so the package dependency stays wired.
            .onAppear { _ = Direction.up }
    }
}

#Preview {
    ContentView()
}
