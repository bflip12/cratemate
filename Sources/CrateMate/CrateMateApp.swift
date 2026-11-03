// App entry point: a single window, File › Open Playlist Export… (⌘O) and a Settings window (⌘,).

import SwiftUI

@main
struct CrateMateApp: App {
    // One model for the app's single window. (No @State: in the macOS 27 SDK it's a macro
    // whose plugin only ships with full Xcode, and this builds with the Command Line Tools.)
    private let model = AppModel.shared

    var body: some Scene {
        Window("CrateMate", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 820, minHeight: 480)
                .task { model.start() }
        }
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Playlist Export…") { model.openExportFile() }
                    .keyboardShortcut("o")
            }
        }

        Settings {
            SettingsView().environment(model)
        }
    }
}
