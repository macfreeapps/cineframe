import Foundation

/// Integer pixel dimensions in upright, EXIF-oriented image coordinates.
struct PixelSize: Equatable, Sendable {
    var width: Int
    var height: Int

    var isPositive: Bool { width > 0 && height > 0 }
}

/// Integer pixel rectangle whose origin is measured from the top-left.
struct PixelRect: Equatable, Sendable {
    var x: Int
    var y: Int
    var width: Int
    var height: Int

    var maxX: Int { x + width }
    var maxY: Int { y + height }
    var size: PixelSize { PixelSize(width: width, height: height) }
}

/// Crop coordinates normalized to the upright source image.
struct NormalizedRect: Equatable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let unit = NormalizedRect(x: 0, y: 0, width: 1, height: 1)
}

struct CinematicFrame: Equatable, Sendable {
    let crop: PixelRect
    let output: PixelSize
    let topBar: Int
    let bottomBar: Int

    var barTotal: Int { topBar + bottomBar }
}

/// Pure integer geometry used by previews, the crop editor, and final renders.
enum CinematicGeometry {
    static let cropRatio = 2.39
    static let canvasRatio = 16.0 / 9.0

    static func maximumCropSize(in source: PixelSize) -> PixelSize {
        guard source.isPositive else { return PixelSize(width: 0, height: 0) }

        let width: Int
        let height: Int
        if Double(source.width) / Double(source.height) >= cropRatio {
            height = source.height
            width = Int((Double(height) * cropRatio).rounded())
        } else {
            width = source.width
            height = Int((Double(width) / cropRatio).rounded())
        }
        return PixelSize(width: min(width, source.width), height: min(height, source.height))
    }

    static func centeredCrop(in source: PixelSize) -> PixelRect {
        let maximum = maximumCropSize(in: source)
        return PixelRect(
            x: Int((Double(source.width - maximum.width) / 2).rounded()),
            y: Int((Double(source.height - maximum.height) / 2).rounded()),
            width: maximum.width,
            height: maximum.height
        )
    }

    static func frame(in source: PixelSize, crop requestedCrop: PixelRect? = nil) -> CinematicFrame {
        let bounds = source.isPositive ? source : PixelSize(width: 1, height: 1)
        let maximum = maximumCropSize(in: bounds)
        let request = requestedCrop ?? centeredCrop(in: bounds)
        let width = min(max(1, request.width), maximum.width)
        let height = min(max(1, request.height), maximum.height)
        let x = min(max(0, request.x), bounds.width - width)
        let y = min(max(0, request.y), bounds.height - height)
        let crop = parityAdjustedCrop(
            PixelRect(x: x, y: y, width: width, height: height),
            idealHeight: Double(width) / cropRatio,
            source: bounds
        )
        let outputHeight = max(1, Int((Double(crop.width) / canvasRatio).rounded()))
        let barTotal = max(0, outputHeight - crop.height)
        let top = barTotal / 2
        return CinematicFrame(crop: crop, output: PixelSize(width: crop.width, height: outputHeight),
                              topBar: top, bottomBar: barTotal - top)
    }

    static func frame(in source: PixelSize, normalizedCrop: NormalizedRect) -> CinematicFrame {
        let maxSize = maximumCropSize(in: source)
        let minWidth = min(maxSize.width, max(1, max(320, Int((Double(source.width) * 0.10).rounded()))))
        let normalizedWidth = min(1, max(0, normalizedCrop.width)) * Double(source.width)
        let desiredWidth = Int(normalizedWidth.rounded())
        let width = min(max(minWidth, desiredWidth), maxSize.width)
        let height = min(maxSize.height, max(1, Int((Double(width) / cropRatio).rounded())))
        let x = Int((min(max(0, normalizedCrop.x), 1) * Double(source.width)).rounded())
        let y = Int((min(max(0, normalizedCrop.y), 1) * Double(source.height)).rounded())
        return frame(in: source, crop: PixelRect(x: x, y: y, width: width, height: height))
    }

    static func normalized(_ crop: PixelRect, in source: PixelSize) -> NormalizedRect {
        guard source.isPositive else { return .unit }
        return NormalizedRect(
            x: Double(crop.x) / Double(source.width),
            y: Double(crop.y) / Double(source.height),
            width: Double(crop.width) / Double(source.width),
            height: Double(crop.height) / Double(source.height)
        )
    }

    static func resized(_ crop: PixelRect, width requestedWidth: Int, in source: PixelSize) -> PixelRect {
        let maxSize = maximumCropSize(in: source)
        let minWidth = min(maxSize.width, max(1, max(320, Int((Double(source.width) * 0.10).rounded()))))
        let width = min(max(minWidth, requestedWidth), maxSize.width)
        let height = max(1, Int((Double(width) / cropRatio).rounded()))
        let centered = PixelRect(x: crop.x + (crop.width - width) / 2,
                                 y: crop.y + (crop.height - height) / 2,
                                 width: width, height: height)
        return frame(in: source, crop: centered).crop
    }

    private static func parityAdjustedCrop(_ crop: PixelRect, idealHeight: Double, source: PixelSize) -> PixelRect {
        let outputHeight = Int((Double(crop.width) / canvasRatio).rounded())
        guard (outputHeight - crop.height).isMultiple(of: 2) else {
            let candidates = [crop.height - 1, crop.height + 1]
                .filter { $0 > 0 && $0 <= source.height && $0 <= outputHeight }
            guard let chosen = candidates.min(by: { abs(Double($0) - idealHeight) < abs(Double($1) - idealHeight) }) else {
                return crop
            }
            let shift = Int((Double(crop.height - chosen) / 2).rounded())
            let y = min(max(0, crop.y + shift), source.height - chosen)
            return PixelRect(x: crop.x, y: y, width: crop.width, height: chosen)
        }
        return crop
    }
}
