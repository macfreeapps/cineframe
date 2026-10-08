import CoreGraphics
import Foundation

enum CinematicRenderer {
    static func render(orientedImage: CGImage, crop: PixelRect, barColor: BarColor) throws -> CGImage {
        let source = PixelSize(width: orientedImage.width, height: orientedImage.height)
        let frame = CinematicGeometry.frame(in: source, crop: crop)
        let rect = CGRect(x: frame.crop.x, y: frame.crop.y,
                          width: frame.crop.width, height: frame.crop.height)
        guard let cropped = orientedImage.cropping(to: rect) else { throw CineFrameError.renderFailed }

        let sourceSpace = orientedImage.colorSpace
        let model = sourceSpace?.model ?? .rgb
        let preferredSpace = sourceSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let bits = supportedBits(orientedImage.bitsPerComponent)
        let alphaInfo = normalizedAlphaInfo(orientedImage.alphaInfo)
        var bitmapInfo = CGBitmapInfo(rawValue: alphaInfo.rawValue)
        if bits == 16 { bitmapInfo.formUnion(.byteOrder16Little) }
        if orientedImage.bitmapInfo.contains(.floatComponents) && bits >= 16 {
            bitmapInfo.formUnion(.floatComponents)
        }

        let context = CGContext(data: nil, width: frame.output.width, height: frame.output.height,
                                bitsPerComponent: bits, bytesPerRow: 0,
                                space: preferredSpace, bitmapInfo: bitmapInfo.rawValue)
        let fallback = context == nil ? fallbackContext(size: frame.output, bits: bits,
                                                        alphaInfo: alphaInfo, sourceModel: model,
                                                        isFloat: orientedImage.bitmapInfo.contains(.floatComponents)) : nil
        let renderContext = context ?? fallback?.context
        let outputSpace = context == nil ? (fallback?.colorSpace ?? preferredSpace) : preferredSpace
        guard let context = renderContext else { throw CineFrameError.renderFailed }

        let component: CGFloat = barColor == .white ? 1 : 0
        let fill: CGColor
        if outputSpace.model == .monochrome {
            fill = CGColor(colorSpace: outputSpace, components: [component, 1])!
        } else {
            fill = CGColor(colorSpace: outputSpace, components: [component, component, component, 1])!
        }
        context.setFillColor(fill)
        context.fill(CGRect(x: 0, y: 0, width: frame.output.width, height: frame.output.height))
        context.interpolationQuality = .none
        context.setBlendMode(.copy)
        context.draw(cropped, in: CGRect(x: 0, y: frame.bottomBar,
                                         width: frame.crop.width, height: frame.crop.height))
        guard let result = context.makeImage() else { throw CineFrameError.renderFailed }
        return result
    }

    private static func supportedBits(_ sourceBits: Int) -> Int {
        [8, 16, 32].contains(sourceBits) ? sourceBits : 8
    }

    private static func normalizedAlphaInfo(_ info: CGImageAlphaInfo) -> CGImageAlphaInfo {
        switch info {
        case .none: .none
        case .noneSkipFirst: .noneSkipFirst
        case .noneSkipLast, .alphaOnly: .noneSkipLast
        case .premultipliedFirst, .premultipliedLast, .first, .last: .premultipliedLast
        @unknown default: .premultipliedLast
        }
    }

    private static func fallbackContext(size: PixelSize, bits: Int, alphaInfo: CGImageAlphaInfo,
                                        sourceModel: CGColorSpaceModel, isFloat: Bool) -> (context: CGContext, colorSpace: CGColorSpace)? {
        var info = alphaInfo.rawValue | (bits == 16 ? CGBitmapInfo.byteOrder16Little.rawValue : 0)
        if isFloat && bits >= 16 { info |= CGBitmapInfo.floatComponents.rawValue }
        if sourceModel == .monochrome,
           let gray = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2),
           let context = CGContext(data: nil, width: size.width, height: size.height,
                                   bitsPerComponent: bits, bytesPerRow: 0, space: gray,
                                   bitmapInfo: info) {
            return (context, gray)
        }
        guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let context = CGContext(data: nil, width: size.width, height: size.height,
                                      bitsPerComponent: bits, bytesPerRow: 0, space: sRGB,
                                      bitmapInfo: info) else {
            return nil
        }
        return (context, sRGB)
    }
}
