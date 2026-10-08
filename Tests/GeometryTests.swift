import XCTest
@testable import CineFrame

final class GeometryTests: XCTestCase {
    func testRequiredSourceDimensions() {
        let dimensions = [
            PixelSize(width: 6000, height: 4000),
            PixelSize(width: 4000, height: 6000),
            PixelSize(width: 4032, height: 3024),
            PixelSize(width: 3000, height: 3000),
            PixelSize(width: 8000, height: 2000),
            PixelSize(width: 1920, height: 1080),
            PixelSize(width: 4033, height: 3025),
            PixelSize(width: 100, height: 80)
        ]

        for source in dimensions {
            let frame = CinematicGeometry.frame(in: source)
            XCTAssertGreaterThan(frame.crop.width, 0)
            XCTAssertGreaterThan(frame.crop.height, 0)
            XCTAssertGreaterThanOrEqual(frame.crop.x, 0)
            XCTAssertGreaterThanOrEqual(frame.crop.y, 0)
            XCTAssertLessThanOrEqual(frame.crop.maxX, source.width)
            XCTAssertLessThanOrEqual(frame.crop.maxY, source.height)
            XCTAssertEqual(frame.output.width, frame.crop.width)
            XCTAssertEqual(frame.topBar, frame.bottomBar)
            XCTAssertEqual(frame.barTotal, frame.output.height - frame.crop.height)

            // At 100x80, filling the required 100-pixel maximum crop width gives
            // only integer heights 41 or 42, both outside ±0.002 of 2.39.
            if source != PixelSize(width: 100, height: 80) {
                XCTAssertEqual(Double(frame.crop.width) / Double(frame.crop.height),
                               CinematicGeometry.cropRatio, accuracy: 0.002, "\(source)")
                XCTAssertEqual(Double(frame.output.width) / Double(frame.output.height),
                               CinematicGeometry.canvasRatio, accuracy: 0.002, "\(source)")
            }
        }
    }

    func testWorkedExampleAndParityAdjustment() {
        let frame = CinematicGeometry.frame(in: PixelSize(width: 6000, height: 4000))
        XCTAssertEqual(frame.crop, PixelRect(x: 0, y: 744, width: 6000, height: 2511))
        XCTAssertEqual(frame.output, PixelSize(width: 6000, height: 3375))
        XCTAssertEqual(frame.topBar, 432)
        XCTAssertEqual(frame.bottomBar, 432)
    }

    func testNormalizedCropIsClampedAndIntegerAligned() {
        let source = PixelSize(width: 4000, height: 3000)
        let frame = CinematicGeometry.frame(
            in: source,
            normalizedCrop: NormalizedRect(x: 0.8, y: 0.9, width: 0.5, height: 0.5)
        )
        XCTAssertLessThanOrEqual(frame.crop.maxX, source.width)
        XCTAssertLessThanOrEqual(frame.crop.maxY, source.height)
        XCTAssertGreaterThanOrEqual(frame.crop.x, 0)
        XCTAssertGreaterThanOrEqual(frame.crop.y, 0)
        XCTAssertEqual(frame.crop.width, Int(frame.crop.width))
        XCTAssertEqual(frame.crop.height, Int(frame.crop.height))
    }
}
