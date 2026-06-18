import AppKit
import SwiftUI

@main
struct VoiceFlickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var permissionCoordinator = PermissionCoordinator()
    @StateObject private var profileStore = GestureProfileStore()
    @StateObject private var cameraService = CameraService()
    private let keyboardActionService = KeyboardActionService()

    var body: some Scene {
        WindowGroup("VoiceFlick", id: "main") {
            ContentView()
                .environmentObject(permissionCoordinator)
                .environmentObject(profileStore)
                .environmentObject(cameraService)
                .environment(\.keyboardActionService, keyboardActionService)
                .frame(minWidth: 980, minHeight: 680)
                .task {
                    await permissionCoordinator.refresh()
                    cameraService.configure(
                        profileStore: profileStore,
                        actionService: keyboardActionService
                    )
                }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Permissions") {
                    Task { await permissionCoordinator.refresh() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(permissionCoordinator)
                .environmentObject(profileStore)
                .environmentObject(cameraService)
                .environment(\.keyboardActionService, keyboardActionService)
                .padding()
                .frame(width: 520)
        }

        MenuBarExtra("VoiceFlick", systemImage: "hand.raised") {
            Button(cameraService.isRunning ? "Pause Camera" : "Start Camera") {
                cameraService.toggleRunning()
            }
            Button("Refresh Permissions") {
                Task { await permissionCoordinator.refresh() }
            }
            Divider()
            Text(cameraService.currentEvent.displayTitle)
            Text(cameraService.powerMode.displayName)
            Divider()
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
