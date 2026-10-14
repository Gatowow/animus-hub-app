import SwiftUI
import AppKit
import Combine
import Sparkle

@MainActor
final class UpdateController: ObservableObject {
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    var updater: SPUUpdater {
        updaterController.updater
    }
}

struct SettingsView: View {
    @ObservedObject var updates: UpdateController

    @State private var automaticUpdates = true

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            as? String ?? "Desconocida"
    }

    var body: some View {
        Form {
            Section("Actualizaciones") {
                Toggle(
                    "Buscar actualizaciones automáticamente",
                    isOn: $automaticUpdates
                )
                .onChange(of: automaticUpdates) { _, enabled in
                    updates.updater.automaticallyChecksForUpdates = enabled
                }

                Button("Buscar actualizaciones ahora") {
                    updates.checkForUpdates()
                }
                .disabled(!updates.canCheckForUpdates)
            }

            Section("Información") {
                LabeledContent("Versión instalada", value: version)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 260)
        .onAppear {
            automaticUpdates =
                updates.updater.automaticallyChecksForUpdates
        }
    }
}

@main
struct MyApp: App {

    @StateObject private var updates = UpdateController()

    init() {
        if let iconURL = Bundle.main.url(
            forResource: "AnimusHub",
            withExtension: "icns"
        ),
        let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }

        if UserDefaults.standard.object(
            forKey: "SUEnableAutomaticChecks"
        ) == nil {
            UserDefaults.standard.set(
                true,
                forKey: "SUEnableAutomaticChecks"
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Buscar actualizaciones…") {
                    updates.checkForUpdates()
                }
                .disabled(!updates.canCheckForUpdates)
            }
        }

        Settings {
            SettingsView(updates: updates)
        }
    }
}
