import CoreGraphics
import Vision

enum SmartCrop {
    /// Finds the union of Vision's attention rectangles and centers the maximum
    /// crop there. Any Vision failure falls back to the deterministic center crop.
    static func crop(in image: CGImage) -> PixelRect {
        let source = PixelSize(width: image.width, height: image.height)
        let fallback = CinematicGeometry.centeredCrop(in: source)
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        request.revision = VNGenerateAttentionBasedSaliencyImageRequestRevision2
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
            guard let boxes = request.results?.first?.salientObjects, !boxes.isEmpty else { return fallback }
            let union = boxes.reduce(CGRect.null) { $0.union($1.boundingBox) }
            guard !union.isNull, !union.isEmpty else { return fallback }
            let cropWidth = Double(fallback.width)
            let cropHeight = Double(fallback.height)
            let centerX = (union.midX * Double(image.width)).rounded()
            let centerY = ((1 - union.midY) * Double(image.height)).rounded()
            let rect = PixelRect(x: Int(centerX - cropWidth / 2), y: Int(centerY - cropHeight / 2),
                                 width: fallback.width, height: fallback.height)
            return CinematicGeometry.frame(in: source, crop: rect).crop
        } catch {
            return fallback
        }
    }
}
