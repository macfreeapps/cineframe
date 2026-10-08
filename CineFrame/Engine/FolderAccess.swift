import AppKit
import Foundation

@MainActor
enum FolderAccess {
    struct OutputFolder {
        let url: URL
        let usedFallback: Bool
    }

    static func chooseFolder(message: String, initialDirectory: URL? = nil) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Allow"
        panel.message = message
        panel.directoryURL = initialDirectory
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    static func saveBookmark(for folder: URL, settings: AppSettings) throws {
        settings.outputFolderBookmark = try folder.bookmarkData(options: .withSecurityScope,
                                                                 includingResourceValuesForKeys: nil,
                                                                 relativeTo: nil)
    }

    static func resolveBookmark(from settings: AppSettings) -> URL? {
        guard let bookmark = settings.outputFolderBookmark else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope,
                                 relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale, let refreshed = try? url.bookmarkData(options: .withSecurityScope,
                                                        includingResourceValuesForKeys: nil, relativeTo: nil) {
            settings.outputFolderBookmark = refreshed
        }
        return url
    }

    static func outputFolder(for input: URL, settings: AppSettings) -> OutputFolder {
        switch settings.outputLocation {
        case .pictures:
            let folder = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Pictures", isDirectory: true)
                .appendingPathComponent("CineFrame", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return OutputFolder(url: folder, usedFallback: false)
        case .custom:
            if let folder = resolveBookmark(from: settings) { return OutputFolder(url: folder, usedFallback: false) }
            return OutputFolder(url: picturesFolder(), usedFallback: true)
        case .nextToOriginal:
            let originalFolder = input.deletingLastPathComponent().standardizedFileURL
            let key = originalFolder.path
            if let bookmark = settings.nextToOriginalBookmarks[key], let folder = resolve(bookmark) {
                return OutputFolder(url: folder, usedFallback: false)
            }
            if let selected = chooseFolder(message: "Allow CineFrame to save into this folder",
                                           initialDirectory: originalFolder) {
                if let bookmark = try? selected.bookmarkData(options: .withSecurityScope,
                                                             includingResourceValuesForKeys: nil, relativeTo: nil) {
                    settings.nextToOriginalBookmarks[key] = bookmark
                }
                return OutputFolder(url: selected, usedFallback: false)
            }
            return OutputFolder(url: picturesFolder(), usedFallback: true)
        }
    }

    private static func picturesFolder() -> URL {
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures/CineFrame", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private static func resolve(_ bookmark: Data) -> URL? {
        var stale = false
        return try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope,
                        relativeTo: nil, bookmarkDataIsStale: &stale)
    }
}
