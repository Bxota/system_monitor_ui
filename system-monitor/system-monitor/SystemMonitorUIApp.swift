import Combine
import SwiftUI

// ---------------------------------------------------------------------------
// AppState — source de vérité partagée entre la fenêtre principale et le menu bar.
// Tous les singletons longs-vivants (service, licence, disk VM) sont ici.
// ---------------------------------------------------------------------------

@MainActor
final class AppState: ObservableObject {
  let service        = SysmonService()
  let licenseManager = LicenseManager()
  let diskViewModel  = DiskViewModel()   // Persiste entre les changements de navigation

  init() {
    service.start()
  }
}

// ---------------------------------------------------------------------------
// AppDelegate — utilisé uniquement pour fixer la politique d'activation.
// NSApp est nil dans le init() du struct App, il faut passer par le delegate.
// ---------------------------------------------------------------------------

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationWillFinishLaunching(_ notification: Notification) {
    // Sans .regular, macOS traite l'app comme "accessory" (pas de Dock, pas de Cmd+Tab)
    // quand elle possède un MenuBarExtra.
    NSApp.setActivationPolicy(.regular)
  }
}

// ---------------------------------------------------------------------------
// App entry point
// ---------------------------------------------------------------------------

@main
struct SystemMonitorUIApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var appState = AppState()

  var body: some Scene {
    // Fenêtre principale
    WindowGroup {
      ContentView()
        .environmentObject(appState.service)
        .environmentObject(appState.licenseManager)
        .environmentObject(appState.diskViewModel)
        .onAppear {
          // S'assure que la fenêtre devient key pour que les TextField
          // acceptent le clavier (nécessaire avec MenuBarExtra .window).
          DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first { $0.canBecomeKey }?.makeKeyAndOrderFront(nil)
          }
        }
    }
    .windowToolbarStyle(.unified)
    .defaultSize(width: 1100, height: 720)

    // Icône dans la top bar macOS avec métrique configurable en live
    MenuBarExtra {
      MenuBarView()
        .environmentObject(appState.service)
    } label: {
      MenuBarLabel(service: appState.service)
    }
    .menuBarExtraStyle(.window)
  }
}
