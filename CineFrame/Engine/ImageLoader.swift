import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImagePreview: @unchecked Sendable {
    let image: CGImage
    let sourceSize: PixelSize

    var previewSize: PixelSize { PixelSize(width: image.width, height: image.height) }
}

struct ImageSourceData: @unchecked Sendable {
    let image: CGImage
    let metadata: CGImageMetadata?
    let properties: [String: Any]
    let originalProperties: [String: Any]
    let isRAW: Bool
}

enum ImageLoader {
    static let previewMaxDimension = 2048
    private static let rawExtensions: Set<String> = [
        "3fr", "ari", "arw", "bay", "cap", "cr2", "cr3", "dcs", "dcr", "dng", "drf", "eip",
        "erf", "fff", "gpr", "iiq", "k25", "kdc", "mdc", "mef", "mos", "mrw", "nef", "nrw",
        "obm", "orf", "ori", "pef", "ptx", "pxn", "raf", "raw", "rwl", "rw2", "rwz", "srw", "sti", "x3f"
    ]

    static func isSupportedImage(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if rawExtensions.contains(ext) { return true }
        let scope = url.startAccessingSecurityScopedResource()
        defer { if scope { url.stopAccessingSecurityScopedResource() } }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source) else { return false }
        return UTType(type as String)?.conforms(to: .image) ?? false
    }

    static func loadPreview(from url: URL) throws -> ImagePreview {
        let scope = url.startAccessingSecurityScopedResource()
        defer { if scope { url.stopAccessingSecurityScopedResource() } }
        let source = try imageSource(url)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: previewMaxDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let preview = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw CineFrameError.unreadableImage(url)
        }
        let properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]) ?? [:]
        var width = properties[kCGImagePropertyPixelWidth as String] as? Int ?? preview.width
        var height = properties[kCGImagePropertyPixelHeight as String] as? Int ?? preview.height
        let orientation = properties[kCGImagePropertyOrientation as String] as? Int
            ?? (properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any])?[kCGImagePropertyTIFFOrientation as String] as? Int
            ?? 1
        if (5...8).contains(orientation) { swap(&width, &height) }
        return ImagePreview(image: preview, sourceSize: PixelSize(width: width, height: height))
    }

    /// Full-resolution decode is called only inside the export worker.
    static func loadOriginalForExport(from url: URL) throws -> ImageSourceData {
        let source = try imageSource(url)
        let properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]) ?? [:]
        let raw = rawExtensions.contains(url.pathExtension.lowercased())
        let image: CGImage

        if raw {
            guard let filter = CIRAWFilter(imageURL: url) else {
                throw CineFrameError.unreadableImage(url)
            }
            let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
            let rawOrientation = properties[kCGImagePropertyOrientation as String] as? Int
                ?? tiff[kCGImagePropertyTIFFOrientation as String] as? Int
                ?? 1
            filter.orientation = CGImagePropertyOrientation(rawValue: UInt32(rawOrientation)) ?? .up
            guard let output = filter.outputImage else { throw CineFrameError.unreadableImage(url) }
            let context = CIContext(options: [.cacheIntermediates: false])
            guard let decoded = context.createCGImage(output, from: output.extent, format: .RGBAh, colorSpace: output.colorSpace) else {
                throw CineFrameError.unreadableImage(url)
            }
            image = decoded
        } else {
            let dimensions = properties[kCGImagePropertyPixelWidth as String] as? Int ?? 2048
            let height = properties[kCGImagePropertyPixelHeight as String] as? Int ?? dimensions
            // ImageIO applies the EXIF transform and keeps native dimensions here.
            let maxDimension = max(dimensions, height)
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                throw CineFrameError.unreadableImage(url)
            }
            image = decoded
        }

        let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil)
        return ImageSourceData(image: image, metadata: metadata,
                               properties: properties, originalProperties: properties, isRAW: raw)
    }

    static func sourceProperties(from url: URL) throws -> [String: Any] {
        let source = try imageSource(url)
        return (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]) ?? [:]
    }

    private static func imageSource(_ url: URL) throws -> CGImageSource {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0 else { throw CineFrameError.unreadableImage(url) }
        return source
    }
}
