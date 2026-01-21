import SwiftUI

@main
struct SystemMonitorUIApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .windowToolbarStyle(.unified)
    .defaultSize(width: 1100, height: 720)
  }
}
