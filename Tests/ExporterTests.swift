import CoreGraphics
import ImageIO
import XCTest
@testable import CineFrame

final class ExporterTests: XCTestCase {
    func testPNGExportUsesUniqueNamesAndKeepsOriginal() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let output = root.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("sample.png")
        try makePNG(at: source, width: 32, height: 24)
        let originalBytes = try Data(contentsOf: source)
        let configuration = ExportConfiguration(suffix: "_cinematic", format: .sameAsInput,
                                                 quality: 0.95, preserveFileDates: false,
                                                 metadataOptions: MetadataOptions())
        let first = try ImageExporter.export(sourceURL: source, normalizedCrop: nil, barColor: .black,
                                             outputDirectory: output, configuration: configuration)
        let second = try ImageExporter.export(sourceURL: source, normalizedCrop: nil, barColor: .black,
                                              outputDirectory: output, configuration: configuration)
        XCTAssertEqual(first.outputURL.lastPathComponent, "sample_cinematic.png")
        XCTAssertEqual(second.outputURL.lastPathComponent, "sample_cinematic 2.png")
        XCTAssertEqual(first.outputSize.width, 32)
        XCTAssertEqual(try Data(contentsOf: source), originalBytes)
        let outputSource = try XCTUnwrap(CGImageSourceCreateWithURL(first.outputURL as CFURL, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(outputSource, 0, nil) as? [String: Any])
        XCTAssertEqual(properties[kCGImagePropertyPixelWidth as String] as? Int, 32)
        XCTAssertEqual(properties[kCGImagePropertyPixelHeight as String] as? Int, 18)
        let exif = try XCTUnwrap(properties[kCGImagePropertyExifDictionary as String] as? [String: Any])
        XCTAssertEqual(exif[kCGImagePropertyExifDateTimeOriginal as String] as? String, "2020:01:02 03:04:05")
        XCTAssertNotNil(properties[kCGImagePropertyGPSDictionary as String])
        let metadata = try XCTUnwrap(CGImageSourceCopyMetadataAtIndex(outputSource, 0, nil))
        XCTAssertNotNil(CGImageMetadataCopyTagWithPath(metadata, nil, "cineframe:BarColor" as CFString))
        XCTAssertNotNil(CGImageMetadataCopyTagWithPath(metadata, nil, "cineframe:CropRect" as CFString))
    }

    private func makePNG(at url: URL, width: Int, height: Int) throws {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 0.7)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = context.makeImage()!
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            XCTFail("Could not create test PNG")
            return
        }
        let properties: [String: Any] = [
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifDateTimeOriginal as String: "2020:01:02 03:04:05"
            ],
            kCGImagePropertyGPSDictionary as String: [
                kCGImagePropertyGPSLatitude as String: 37.3317,
                kCGImagePropertyGPSLatitudeRef as String: "N",
                kCGImagePropertyGPSLongitude as String: 122.0301,
                kCGImagePropertyGPSLongitudeRef as String: "W"
            ]
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
