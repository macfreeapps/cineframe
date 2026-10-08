import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ExportConfiguration: Sendable {
    var suffix: String
    var format: OutputFormat
    var quality: Double
    var preserveFileDates: Bool
    var metadataOptions: MetadataOptions
}

struct ExportResult: @unchecked Sendable {
    let outputURL: URL
    let outputSize: PixelSize
    let frame: CinematicFrame
}

enum ImageExporter {
    static func export(sourceURL: URL, normalizedCrop: NormalizedRect?, barColor: BarColor,
                       outputDirectory: URL, configuration: ExportConfiguration) throws -> ExportResult {
        try autoreleasepool {
            let outputScope = outputDirectory.startAccessingSecurityScopedResource()
            defer { if outputScope { outputDirectory.stopAccessingSecurityScopedResource() } }
            let source = try ImageLoader.loadOriginalForExport(from: sourceURL)
            let orientedSize = PixelSize(width: source.image.width, height: source.image.height)
            let frame = normalizedCrop.map { CinematicGeometry.frame(in: orientedSize, normalizedCrop: $0) }
                ?? CinematicGeometry.frame(in: orientedSize)
            let rendered = try CinematicRenderer.render(orientedImage: source.image, crop: frame.crop, barColor: barColor)
            let hasAlpha = source.image.alphaInfo == .first || source.image.alphaInfo == .last
                || source.image.alphaInfo == .premultipliedFirst || source.image.alphaInfo == .premultipliedLast
            let outputFormat = resolveFormat(configuration.format, sourceURL: sourceURL,
                                             raw: source.isRAW, imageHasAlpha: hasAlpha)
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            let outputURL = try uniqueOutputURL(source: sourceURL, directory: outputDirectory,
                                                suffix: configuration.suffix, format: outputFormat)
            guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, outputFormat.type, 1, nil) else {
                try? FileManager.default.removeItem(at: outputURL)
                throw CineFrameError.destinationCreationFailed(outputURL)
            }

            let metadataOptions = configuration.metadataOptions
            let metadata = MetadataProcessor.update(source.metadata, properties: source.properties,
                                                    outputSize: frame.output, crop: frame.crop,
                                                    sourceURL: sourceURL, barColor: barColor,
                                                    options: metadataOptions)
            let properties = MetadataProcessor.outputProperties(from: source.properties,
                                                                 outputSize: frame.output,
                                                                 options: metadataOptions)
            CGImageDestinationSetProperties(destination, properties as CFDictionary)
            var options: [CFString: Any] = [:]
            if outputFormat.isLossy {
                options[kCGImageDestinationLossyCompressionQuality] = min(1, max(0.8, configuration.quality))
            }
            if outputFormat == .jpeg { options[kCGImageDestinationEmbedThumbnail] = true }
            // TODO: crop & reattach HDR gain map. Auxiliary images and portrait
            // mattes are invalidated by this geometry change and are dropped in v1.
            CGImageDestinationAddImageAndMetadata(destination, rendered, metadata, options as CFDictionary)
            guard CGImageDestinationFinalize(destination) else {
                try? FileManager.default.removeItem(at: outputURL)
                throw CineFrameError.exportFailed(sourceURL)
            }

            if configuration.preserveFileDates,
               let attributes = try? FileManager.default.attributesOfItem(atPath: sourceURL.path) {
                var outputAttributes: [FileAttributeKey: Any] = [:]
                if let creation = attributes[.creationDate] { outputAttributes[.creationDate] = creation }
                if let modification = attributes[.modificationDate] { outputAttributes[.modificationDate] = modification }
                try? FileManager.default.setAttributes(outputAttributes, ofItemAtPath: outputURL.path)
            }
            return ExportResult(outputURL: outputURL, outputSize: frame.output, frame: frame)
        }
    }

    private enum ResolvedFormat: Equatable {
        case jpeg, heic, png, tiff
        var type: CFString {
            switch self {
            case .jpeg: return UTType.jpeg.identifier as CFString
            case .heic: return UTType.heic.identifier as CFString
            case .png: return UTType.png.identifier as CFString
            case .tiff: return UTType.tiff.identifier as CFString
            }
        }
        var fileExtension: String {
            switch self { case .jpeg: "jpg"; case .heic: "heic"; case .png: "png"; case .tiff: "tiff" }
        }
        var isLossy: Bool { self == .jpeg || self == .heic }
    }

    private static func resolveFormat(_ requested: OutputFormat, sourceURL: URL, raw: Bool,
                                      imageHasAlpha: Bool) -> ResolvedFormat {
        if raw, requested == .sameAsInput { return .tiff }
        switch requested {
        case .jpeg: return .jpeg
        case .heic: return .heic
        case .png: return .png
        case .tiff: return .tiff
        case .sameAsInput:
            switch sourceURL.pathExtension.lowercased() {
            case "jpg", "jpeg": return .jpeg
            case "heic", "heif": return .heic
            case "png": return .png
            case "tif", "tiff": return .tiff
            default: return imageHasAlpha ? .png : .jpeg
            }
        }
    }

    private static func uniqueOutputURL(source: URL, directory: URL, suffix: String,
                                       format: ResolvedFormat) throws -> URL {
        let name = source.deletingPathExtension().lastPathComponent
        let safeSuffix = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        var index = 1
        while true {
            let collision = index == 1 ? "" : " \(index)"
            let fileName = "\(name)\(safeSuffix)\(collision).\(format.fileExtension)"
            let candidate = directory.appendingPathComponent(fileName)
            // Exclusive creation reserves this path before bounded-concurrency workers write it.
            if FileManager.default.fileExists(atPath: candidate.path) {
                index += 1
                continue
            }
            if FileManager.default.createFile(atPath: candidate.path, contents: Data()) { return candidate }
            if FileManager.default.fileExists(atPath: candidate.path) {
                index += 1
                continue
            }
            throw CineFrameError.destinationCreationFailed(candidate)
        }
    }
}
