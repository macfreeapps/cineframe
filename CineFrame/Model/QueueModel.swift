import AppKit
import Foundation
import Observation

@Observable @MainActor
final class QueueModel {
    static let shared = QueueModel(settings: .shared)

    let settings: AppSettings
    var items: [PhotoItem] = []
    var selectedIDs: Set<UUID> = []
    var activeItemID: UUID?
    var isExporting = false
    var progressCompleted = 0
    var progressTotal = 0
    var lastExportURL: URL?
    var statusMessage: String?
    var quickRunCount = 0
    var resultPreviewRequested = false
    private var exportTask: Task<Void, Never>?

    init(settings: AppSettings) { self.settings = settings }

    var activeItem: PhotoItem? { items.first { $0.id == activeItemID } ?? items.first }

    func importURLs(_ inputURLs: [URL], forceQuickMode: Bool? = nil) {
        let urls = expand(inputURLs)
        let quick = forceQuickMode ?? settings.quickMode
        var imported: [PhotoItem] = []
        for url in urls {
            let key = url.standardizedFileURL
            guard !items.contains(where: { $0.url.standardizedFileURL == key }),
                  ImageLoader.isSupportedImage(url) else { continue }
            let item = PhotoItem(url: url)
            items.append(item)
            imported.append(item)
            let anchor = quick ? CropAnchor.center : settings.cropAnchor
            let itemID = item.id
            let model = self
            Task.detached(priority: .userInitiated) {
                guard let preview = try? ImageLoader.loadPreview(from: url) else {
                    await MainActor.run {
                        model.items.first { $0.id == itemID }?.status = .error("Could not load preview")
                    }
                    return
                }
                let previewSize = preview.previewSize
                let crop: PixelRect = anchor == .smart
                    ? SmartCrop.crop(in: preview.image)
                    : CinematicGeometry.centeredCrop(in: previewSize)
                let normalized = CinematicGeometry.normalized(crop, in: previewSize)
                await MainActor.run {
                    guard let item = model.items.first(where: { $0.id == itemID }) else { return }
                    item.preview = preview.image
                    item.orientedSize = preview.sourceSize
                    item.autoCropNormalized = normalized
                }
            }
        }
        if activeItemID == nil { activeItemID = imported.first?.id }
        if quick, !imported.isEmpty {
            quickRunCount += imported.count
            Task { await export(items: imported, centerOnly: true, revealOnce: imported.count > 1) }
        }
    }

    func setSelection(_ selection: Set<UUID>) {
        selectedIDs = selection
        if let first = items.first(where: { selection.contains($0.id) }) { activeItemID = first.id }
    }

    func removeSelected() {
        removeItems(ids: selectedIDs)
    }

    func removeItems(ids: Set<UUID>) {
        let removed = items.filter { ids.contains($0.id) }.map(\.id)
        items.removeAll { ids.contains($0.id) }
        selectedIDs.removeAll()
        if removed.contains(activeItemID ?? UUID()) { activeItemID = items.first?.id }
    }

    func resetActiveCrop() { activeItem?.resetCrop() }

    func nudgeActiveCrop(dx: Double, dy: Double) {
        guard let item = activeItem else { return }
        var rect = item.crop
        rect.x = min(max(0, rect.x + dx), max(0, 1 - rect.width))
        rect.y = min(max(0, rect.y + dy), max(0, 1 - rect.height))
        item.setCrop(rect)
    }

    func scaleActiveCrop(factor: Double) {
        guard let item = activeItem, item.orientedSize.isPositive, factor > 0 else { return }
        let desiredWidth = Int((item.crop.width * Double(item.orientedSize.width) / factor).rounded())
        setActiveCropWidth(desiredWidth)
    }

    func resizeActiveCrop(by pixels: Int) {
        guard let item = activeItem, item.orientedSize.isPositive else { return }
        setActiveCropWidth(Int((item.crop.width * Double(item.orientedSize.width)).rounded()) + pixels)
    }

    private func setActiveCropWidth(_ requestedWidth: Int) {
        guard let item = activeItem, item.orientedSize.isPositive else { return }
        let source = item.orientedSize
        let maximum = CinematicGeometry.maximumCropSize(in: source)
        let minimum = min(maximum.width, max(320, Int((Double(source.width) * 0.10).rounded())))
        let width = min(max(minimum, requestedWidth), maximum.width)
        let widthNorm = Double(width) / Double(source.width)
        let heightNorm = Double(width) / CinematicGeometry.cropRatio / Double(source.height)
        item.setCrop(NormalizedRect(x: min(max(0, item.crop.x + (item.crop.width - widthNorm) / 2), 1 - widthNorm),
                                    y: min(max(0, item.crop.y + (item.crop.height - heightNorm) / 2), 1 - heightNorm),
                                    width: widthNorm, height: heightNorm))
    }

    func applyCropPositionToSelected() {
        guard let activeItem else { return }
        for item in items where selectedIDs.contains(item.id) && item.id != activeItem.id {
            var crop = item.crop
            crop.x = min(activeItem.crop.x, max(0, 1 - crop.width))
            crop.y = min(activeItem.crop.y, max(0, 1 - crop.height))
            item.setCrop(crop)
        }
    }

    func exportSelected() async {
        let targets = items.filter { selectedIDs.contains($0.id) }
        await export(items: targets.isEmpty ? activeItem.map { [$0] } ?? [] : targets,
                     centerOnly: false, revealOnce: targets.count > 1)
    }

    func exportAll() async { await export(items: items, centerOnly: false, revealOnce: true) }

    func cancelExport() { exportTask?.cancel() }

    func revealLastExport() {
        guard let url = lastExportURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func export(items exportItems: [PhotoItem], centerOnly: Bool, revealOnce: Bool) async {
        guard !exportItems.isEmpty, !isExporting else { return }
        isExporting = true
        progressCompleted = 0
        progressTotal = exportItems.count
        statusMessage = nil
        lastExportURL = nil
        let configuration = ExportConfiguration(
            suffix: settings.outputSuffix,
            format: settings.outputFormat,
            quality: settings.lossyQuality,
            preserveFileDates: settings.preserveFileDates,
            metadataOptions: MetadataOptions(stripGPS: settings.stripGPS,
                                             addCinematicKeyword: settings.addCinematicKeyword)
        )
        var requests: [ExportRequest] = []
        var usedFallbackFolder = false
        for item in exportItems {
            let outputFolder = FolderAccess.outputFolder(for: item.url, settings: settings)
            usedFallbackFolder = usedFallbackFolder || outputFolder.usedFallback
            let crop: NormalizedRect? = item.orientedSize.width == 0 ? nil : (centerOnly
                ? CinematicGeometry.normalized(CinematicGeometry.centeredCrop(in: item.orientedSize), in: item.orientedSize)
                : item.crop)
            item.status = .exporting
            requests.append(ExportRequest(itemID: item.id, sourceURL: item.url, crop: crop,
                                          barColor: item.barColorOverride ?? settings.barColor,
                                          outputDirectory: outputFolder.url, configuration: configuration))
        }
        let maxConcurrent = min(settings.maxConcurrentExports, max(1, requests.count))
        let model = self
        exportTask = Task {
            await ExportService.shared.run(requests, maxConcurrent: maxConcurrent) { [model] outcome in
                await model.complete(outcome)
            }
            model.isExporting = false
            if revealOnce, model.settings.revealAfterExport, let url = model.lastExportURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url.deletingLastPathComponent()])
            }
            if usedFallbackFolder {
                model.statusMessage = "Folder access was declined or expired. Saved to Pictures/CineFrame."
            }
        }
        await exportTask?.value
    }

    private func complete(_ outcome: ExportOutcome) {
        progressCompleted += 1
        guard let item = items.first(where: { $0.id == outcome.itemID }) else { return }
        if let url = outcome.outputURL {
            item.status = .exported(url)
            lastExportURL = url
            statusMessage = "Saved \(url.lastPathComponent)"
            if progressTotal == 1, settings.revealAfterExport {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        } else if let error = outcome.errorMessage, error != "Cancelled" {
            item.status = .error(error)
            statusMessage = error
        } else {
            item.status = .autoCrop
        }
    }

    private func expand(_ urls: [URL]) -> [URL] {
        var result: [URL] = []
        for url in urls {
            let scope = url.startAccessingSecurityScopedResource()
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            if exists, isDirectory.boolValue {
                let children = (try? FileManager.default.contentsOfDirectory(at: url,
                                                                            includingPropertiesForKeys: [.isRegularFileKey],
                                                                            options: [.skipsHiddenFiles])) ?? []
                let imageChildren = children.filter { ImageLoader.isSupportedImage($0) }
                if scope { url.stopAccessingSecurityScopedResource() }
                result.append(contentsOf: imageChildren)
            } else {
                if scope { url.stopAccessingSecurityScopedResource() }
                result.append(url)
            }
        }
        return result
    }
}
