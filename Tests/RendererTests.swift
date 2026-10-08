import CoreGraphics
import XCTest
@testable import CineFrame

final class RendererTests: XCTestCase {
    func testCropPixelsAreCopiedAndBarsAreBlack() throws {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: nil, width: 12, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                                space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        for x in 0..<12 {
            context.setFillColor(red: CGFloat(x) / 11, green: 0.4, blue: 0.8, alpha: 1)
            context.fill(CGRect(x: x, y: 0, width: 1, height: 8))
        }
        let input = context.makeImage()!
        let crop = PixelRect(x: 0, y: 0, width: 12, height: 5)
        let output = try CinematicRenderer.render(orientedImage: input, crop: crop, barColor: .black)

        XCTAssertEqual(output.width, 12)
        XCTAssertEqual(output.height, 7)
        XCTAssertEqual(output.bitsPerPixel, input.bitsPerPixel)

        let bytesPerRow = output.width * 4
        let pixels = rgbaPixels(output)
        let sourcePixels = rgbaPixels(input)
        XCTAssertEqual(Array(pixels[0..<3]), [0, 0, 0])
        XCTAssertEqual(Array(pixels[(bytesPerRow * 6)..<(bytesPerRow * 6 + 3)]), [0, 0, 0])
        // The image rows are a 1:1 copy: each output column has the exact
        // same decoded RGBA bytes as the corresponding source column.
        let sourceRow = 3 * input.width * 4
        for y in 1..<6 {
            for x in 0..<output.width {
                let outputOffset = y * bytesPerRow + x * 4
                let inputOffset = sourceRow + x * 4
                XCTAssertEqual(Array(pixels[outputOffset..<(outputOffset + 4)]),
                               Array(sourcePixels[inputOffset..<(inputOffset + 4)]))
            }
        }
    }

    func testWhiteBarColor() throws {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: nil, width: 20, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                                space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 8))
        let output = try CinematicRenderer.render(orientedImage: context.makeImage()!,
                                                 crop: PixelRect(x: 0, y: 0, width: 20, height: 8),
                                                 barColor: .white)
        XCTAssertEqual(output.height, 11)
        XCTAssertEqual(Array(rgbaPixels(output)[0..<3]), [255, 255, 255])
    }

    private func rgbaPixels(_ image: CGImage) -> [UInt8] {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let bytesPerRow = image.width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
        pixels.withUnsafeMutableBytes { storage in
            guard let base = storage.baseAddress,
                  let context = CGContext(data: base, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                          space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return pixels
    }
}
