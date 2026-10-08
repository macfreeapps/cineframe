import SwiftUI

@main
struct CineFrameApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var queue = QueueModel.shared
    @State private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(queue)
                .environment(settings)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") { ContentView.openFiles(using: queue) }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandMenu("Crop") {
                Button("Reset Crop") { queue.resetActiveCrop() }
                    .keyboardShortcut("r", modifiers: [])
                Button("Nudge Left") { queue.nudgeActiveCrop(dx: -nudgeX, dy: 0) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Nudge Right") { queue.nudgeActiveCrop(dx: nudgeX, dy: 0) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Button("Nudge Up") { queue.nudgeActiveCrop(dx: 0, dy: -nudgeY) }
                    .keyboardShortcut(.upArrow, modifiers: [])
                Button("Nudge Down") { queue.nudgeActiveCrop(dx: 0, dy: nudgeY) }
                    .keyboardShortcut(.downArrow, modifiers: [])
                Button("Nudge Left 10 px") { queue.nudgeActiveCrop(dx: -10 * nudgeX, dy: 0) }
                    .keyboardShortcut(.leftArrow, modifiers: [.shift])
                Button("Nudge Right 10 px") { queue.nudgeActiveCrop(dx: 10 * nudgeX, dy: 0) }
                    .keyboardShortcut(.rightArrow, modifiers: [.shift])
                Button("Nudge Up 10 px") { queue.nudgeActiveCrop(dx: 0, dy: -10 * nudgeY) }
                    .keyboardShortcut(.upArrow, modifiers: [.shift])
                Button("Nudge Down 10 px") { queue.nudgeActiveCrop(dx: 0, dy: 10 * nudgeY) }
                    .keyboardShortcut(.downArrow, modifiers: [.shift])
                Divider()
                Button("Shrink Crop by 10 px") { queue.resizeActiveCrop(by: -10) }
                    .keyboardShortcut("[", modifiers: [])
                Button("Grow Crop by 10 px") { queue.resizeActiveCrop(by: 10) }
                    .keyboardShortcut("]", modifiers: [])
                Divider()
                Button("Toggle Result Preview") { queue.resultPreviewRequested.toggle() }
                    .keyboardShortcut(.space, modifiers: [])
            }
        }
        Settings { SettingsView(settings: settings) }
    }

    private var nudgeX: Double { queue.activeItem.map { 1 / Double(max(1, $0.preview?.width ?? 1)) } ?? 0.001 }
    private var nudgeY: Double { queue.activeItem.map { 1 / Double(max(1, $0.preview?.height ?? 1)) } ?? 0.001 }
}
