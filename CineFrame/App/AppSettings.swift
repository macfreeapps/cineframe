import Foundation
import Observation

enum BarColor: String, CaseIterable, Identifiable, Sendable {
    case black
    case white

    var id: String { rawValue }
}

enum CropAnchor: String, CaseIterable, Identifiable, Sendable {
    case center
    case smart
    var id: String { rawValue }
}

enum OutputFormat: String, CaseIterable, Identifiable, Sendable {
    case sameAsInput
    case jpeg
    case heic
    case png
    case tiff
    var id: String { rawValue }
}

enum OutputLocation: String, CaseIterable, Identifiable, Sendable {
    case pictures
    case nextToOriginal
    case custom
    var id: String { rawValue }
}

/// One persistent settings model. `SettingsView` binds its controls to this model;
/// every property writes through to UserDefaults under a single namespaced key.
@Observable @MainActor
final class AppSettings {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    var quickMode: Bool { didSet { save(quickMode, "quickMode") } }
    var cropAnchor: CropAnchor { didSet { save(cropAnchor.rawValue, "cropAnchor") } }
    var barColor: BarColor { didSet { save(barColor.rawValue, "barColor") } }
    var outputLocation: OutputLocation { didSet { save(outputLocation.rawValue, "outputLocation") } }
    var outputSuffix: String { didSet { save(outputSuffix, "outputSuffix") } }
    var outputFormat: OutputFormat { didSet { save(outputFormat.rawValue, "outputFormat") } }
    var lossyQuality: Double { didSet { save(lossyQuality, "lossyQuality") } }
    var revealAfterExport: Bool { didSet { save(revealAfterExport, "revealAfterExport") } }
    var stripGPS: Bool { didSet { save(stripGPS, "stripGPS") } }
    var addCinematicKeyword: Bool { didSet { save(addCinematicKeyword, "addCinematicKeyword") } }
    var preserveFileDates: Bool { didSet { save(preserveFileDates, "preserveFileDates") } }
    var maxConcurrentExports: Int { didSet { save(maxConcurrentExports, "maxConcurrentExports") } }
    var outputFolderBookmark: Data? { didSet { defaults.set(outputFolderBookmark, forKey: key("outputFolderBookmark")) } }
    var nextToOriginalBookmarks: [String: Data] {
        didSet { defaults.set(nextToOriginalBookmarks, forKey: key("nextToOriginalBookmarks")) }
    }

    private init() {
        let count = ProcessInfo.processInfo.activeProcessorCount
        let defaults = UserDefaults.standard
        quickMode = defaults.bool(forKey: Self.key("quickMode"))
        cropAnchor = CropAnchor(rawValue: defaults.string(forKey: Self.key("cropAnchor")) ?? "center") ?? .center
        barColor = BarColor(rawValue: defaults.string(forKey: Self.key("barColor")) ?? "black") ?? .black
        outputLocation = OutputLocation(rawValue: defaults.string(forKey: Self.key("outputLocation")) ?? "pictures") ?? .pictures
        outputSuffix = defaults.string(forKey: Self.key("outputSuffix")) ?? "_cinematic"
        outputFormat = OutputFormat(rawValue: defaults.string(forKey: Self.key("outputFormat")) ?? "sameAsInput") ?? .sameAsInput
        lossyQuality = defaults.object(forKey: Self.key("lossyQuality")) as? Double ?? 0.95
        revealAfterExport = defaults.object(forKey: Self.key("revealAfterExport")) as? Bool ?? true
        stripGPS = defaults.bool(forKey: Self.key("stripGPS"))
        addCinematicKeyword = defaults.bool(forKey: Self.key("addCinematicKeyword"))
        preserveFileDates = defaults.object(forKey: Self.key("preserveFileDates")) as? Bool ?? true
        maxConcurrentExports = defaults.object(forKey: Self.key("maxConcurrentExports")) as? Int ?? min(4, max(1, count / 2))
        outputFolderBookmark = defaults.data(forKey: Self.key("outputFolderBookmark"))
        nextToOriginalBookmarks = defaults.dictionary(forKey: Self.key("nextToOriginalBookmarks")) as? [String: Data] ?? [:]
    }

    private static func key(_ name: String) -> String { "app.cineframe.settings.\(name)" }
    private func key(_ name: String) -> String { Self.key(name) }
    private func save<T>(_ value: T, _ name: String) { defaults.set(value, forKey: key(name)) }
}
