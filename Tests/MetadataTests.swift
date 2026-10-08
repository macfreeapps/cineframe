import ImageIO
import XCTest
@testable import CineFrame

final class MetadataTests: XCTestCase {
    func testCineFrameMetadataFieldsAreWritten() {
        let metadata = MetadataProcessor.update(nil, properties: [:],
                                                outputSize: PixelSize(width: 6000, height: 3375),
                                                crop: PixelRect(x: 0, y: 744, width: 6000, height: 2511),
                                                sourceURL: URL(fileURLWithPath: "/tmp/source.jpg"),
                                                barColor: .black,
                                                options: MetadataOptions(addCinematicKeyword: true),
                                                now: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertNotNil(value(metadata, "cineframe:SourceFile"))
        XCTAssertEqual(value(metadata, "cineframe:CropRect") as? String, "0,744,6000,2511")
        XCTAssertEqual(value(metadata, "cineframe:BarColor") as? String, "black")
        XCTAssertEqual(integer(metadata, "tiff:Orientation"), 1)
        XCTAssertEqual(integer(metadata, "exif:PixelXDimension"), 6000)
        XCTAssertNotNil(value(metadata, "xmp:ModifyDate"))
        XCTAssertNotNil(value(metadata, "xmpMM:History[0].stEvt:action"))
        XCTAssertNotNil(value(metadata, "dc:subject[0]"))
    }

    func testPropertyDimensionsAndOrientationAreUpdated() {
        let original: [String: Any] = [
            kCGImagePropertyTIFFDictionary as String: [kCGImagePropertyTIFFOrientation as String: 6],
            kCGImagePropertyExifDictionary as String: [kCGImagePropertyExifSubjectArea as String: [1, 2, 3]]
        ]
        let updated = MetadataProcessor.outputProperties(from: original,
                                                         outputSize: PixelSize(width: 6000, height: 3375),
                                                         options: MetadataOptions())
        let tiff = updated[kCGImagePropertyTIFFDictionary as String] as! [String: Any]
        let exif = updated[kCGImagePropertyExifDictionary as String] as! [String: Any]
        XCTAssertEqual(tiff[kCGImagePropertyTIFFOrientation as String] as? Int, 1)
        XCTAssertEqual(tiff["ImageWidth"] as? Int, 6000)
        XCTAssertEqual(exif[kCGImagePropertyExifPixelYDimension as String] as? Int, 3375)
        XCTAssertNil(exif[kCGImagePropertyExifSubjectArea as String])
    }

    private func value(_ metadata: CGMutableImageMetadata, _ path: String) -> Any? {
        if let tag = CGImageMetadataCopyTagWithPath(metadata, nil, path as CFString),
           let value = CGImageMetadataTagCopyValue(tag) { return value }
        let pair = path.split(separator: ":", maxSplits: 1).map(String.init)
        guard pair.count == 2 else { return nil }
        let tags = CGImageMetadataCopyTags(metadata) as? [CGImageMetadataTag] ?? []
        let tag = tags.last {
            (CGImageMetadataTagCopyPrefix($0) as String?) == pair[0]
                && (CGImageMetadataTagCopyName($0) as String?) == pair[1]
        }
        return tag.flatMap(CGImageMetadataTagCopyValue)
    }

    private func integer(_ metadata: CGMutableImageMetadata, _ path: String) -> Int? {
        guard let rawValue = value(metadata, path) else { return nil }
        if let string = rawValue as? String { return Int(string) }
        if let number = rawValue as? NSNumber { return number.intValue }
        return nil
    }
}
