import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        QueueModel.shared.importURLs(urls)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
