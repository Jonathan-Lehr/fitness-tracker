import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import FitnessTracker

final class RideGridTests: XCTestCase {
    private let calendar = Calendar.app

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        TestSupport.date(year: year, month: month, day: day, hour: hour, calendar: calendar)
    }

    func testDayGroupsNewestFirstWithRidesNewestFirst() {
        let dates = [date(2025, 3, 10, 9), date(2025, 3, 14, 7), date(2025, 3, 14, 18), date(2025, 3, 13, 12)]
        let groups = DayGroup.group(dates, date: { $0 }, calendar: calendar)
        XCTAssertEqual(groups.map(\.day), [date(2025, 3, 14, 0), date(2025, 3, 13, 0), date(2025, 3, 10, 0)])
        XCTAssertEqual(groups[0].items, [date(2025, 3, 14, 18), date(2025, 3, 14, 7)])
        XCTAssertEqual(groups.flatMap(\.items).count, 4)
    }

    func testDayGroupsEmpty() {
        XCTAssertTrue(DayGroup<Date>.group([], date: { $0 }).isEmpty)
    }

    func testLayoutRawValuesStableForStorage() {
        XCTAssertEqual(LogLayout(rawValue: "list"), .list)
        XCTAssertEqual(LogLayout(rawValue: "grid"), .grid)
    }

    func testGridIsTheFirstLayoutSegment() {
        XCTAssertEqual(LogLayout.allCases, [.grid, .list])
    }

    func testCropRectIsTopAnchoredTallAndRightOfCenter() throws {
        for aspect in [2.0, 4.0 / 3.0] {
            let crop = try XCTUnwrap(ThumbnailCropper.cropRect(width: 1600, height: 1200, aspect: aspect))
            // Starts near the top (heads) and uses the full band height.
            XCTAssertEqual(crop.minY, 1200 * ThumbnailCropper.bandTop, accuracy: 1)
            XCTAssertEqual(crop.height, 1200 * (ThumbnailCropper.bandBottom - ThumbnailCropper.bandTop), accuracy: 1)
            XCTAssertLessThanOrEqual(crop.minY, 1200 * 0.05 + 1)
            XCTAssertEqual(crop.width / crop.height, aspect, accuracy: 0.02)
            XCTAssertEqual(crop.midX, 1600 * ThumbnailCropper.centerX, accuracy: 1)
            XCTAssertGreaterThanOrEqual(crop.minX, 1600 * ThumbnailCropper.sideInset - 1)
            XCTAssertLessThanOrEqual(crop.maxX, 1600 * (1 - ThumbnailCropper.sideInset) + 1)
        }
    }

    func testCropRectIsTallerThanPreviousNarrowBand() throws {
        // Previous framing kept only 10–36% of height (312 px of 1200).
        let crop = try XCTUnwrap(ThumbnailCropper.cropRect(width: 1600, height: 1200, aspect: 2))
        XCTAssertGreaterThan(crop.height, 1200 * 0.26 + 50)
        XCTAssertLessThan(crop.minY, 1200 * 0.10)
    }

    func testCropRectClampsInsideBandForWideCrops() throws {
        // A very wide aspect is limited by band width and stays inside the side insets.
        let crop = try XCTUnwrap(ThumbnailCropper.cropRect(width: 1600, height: 1200, aspect: 5))
        XCTAssertEqual(crop.minX, 1600 * ThumbnailCropper.sideInset, accuracy: 1)
        XCTAssertEqual(crop.maxX, 1600 * (1 - ThumbnailCropper.sideInset), accuracy: 1)
    }

    func testCropRectPortraitImageAndDegenerate() throws {
        let crop = try XCTUnwrap(ThumbnailCropper.cropRect(width: 900, height: 1600, aspect: 4.0 / 3.0))
        XCTAssertLessThanOrEqual(crop.maxY, 1600 * ThumbnailCropper.bandBottom + 1)
        XCTAssertEqual(crop.width / crop.height, 4.0 / 3.0, accuracy: 0.05)
        XCTAssertNil(ThumbnailCropper.cropRect(width: 10, height: 10, aspect: 2))
        XCTAssertNil(ThumbnailCropper.cropRect(width: 800, height: 600, aspect: 0))
    }

    private func image(_ fill: (Int, Int) -> UInt8, width: Int = 64, height: Int = 64) -> CGImage {
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let value = fill(x, y)
                let index = (y * width + x) * 4
                pixels[index] = value
                pixels[index + 1] = value
                pixels[index + 2] = value
            }
        }
        let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }

    func testUsabilityRejectsBlackAndFlatAcceptsDetail() {
        XCTAssertFalse(ThumbnailCropper.isUsable(image { _, _ in 0 }))
        XCTAssertFalse(ThumbnailCropper.isUsable(image { _, _ in 128 }))
        XCTAssertTrue(ThumbnailCropper.isUsable(image { x, y in UInt8((x * 4 + y * 2) % 256) }))
    }

    private func jpeg(_ image: CGImage) -> Data {
        let jpegData = NSMutableData()
        let destination = CGImageDestinationCreateWithData(jpegData, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return jpegData as Data
    }

    func testThumbnailFallsBackForUnreadableOrDarkPhoto() {
        XCTAssertNil(ThumbnailCropper.thumbnail(from: Data([1, 2, 3]), aspect: 2))
        XCTAssertNil(ThumbnailCropper.thumbnail(from: jpeg(image({ _, _ in 2 }, width: 400, height: 300)), aspect: 2))
    }

    func testThumbnailCropsDetailedPhoto() throws {
        let data = jpeg(image({ x, y in UInt8((x * 3 + y * 5) % 256) }, width: 800, height: 600))
        let thumbnail = try XCTUnwrap(ThumbnailCropper.thumbnail(from: data, aspect: 2))
        XCTAssertEqual(Double(thumbnail.width) / Double(thumbnail.height), 2, accuracy: 0.05)
        XCTAssertLessThan(thumbnail.height, 600)
    }

    func testStoreCachesResultIncludingFailures() async {
        let store = ThumbnailStore()
        let bad = Data([9, 9, 9])
        let failed = await store.thumbnail(id: "x", data: bad, aspect: 2)
        let failedAgain = await store.thumbnail(id: "x", data: bad, aspect: 2)
        XCTAssertNil(failed)
        XCTAssertNil(failedAgain)
        let good = jpeg(image({ x, y in UInt8((x * 3 + y * 5) % 256) }, width: 800, height: 600))
        let thumbnail = await store.thumbnail(id: "y", data: good, aspect: 2)
        let cached = await store.thumbnail(id: "y", data: good, aspect: 2)
        XCTAssertNotNil(thumbnail)
        XCTAssertTrue(thumbnail === cached, "second lookup should return the cached image")
    }

    func testSampleScreenshotsProduceUsableCropsAtCardAspects() throws {
        let bundle = Bundle(for: Self.self)
        let urls = ["ride-2026-10-12", "ride-2026-10-15", "ride-2026-10-18", "ride-2026-10-20"]
            .compactMap { bundle.url(forResource: $0, withExtension: "jpg") }
        XCTAssertEqual(urls.count, 4, "sample photos should be bundled")
        for url in urls {
            let stored = try XCTUnwrap(ImageTools.storageJPEG(from: try Data(contentsOf: url)))
            for aspect in [2.0, 4.0 / 3.0] {
                let thumbnail = try XCTUnwrap(ThumbnailCropper.thumbnail(from: stored, aspect: aspect),
                                      "\(url.lastPathComponent) should yield a usable crop")
                XCTAssertEqual(Double(thumbnail.width) / Double(thumbnail.height), aspect, accuracy: 0.03)
            }
        }
    }
}
