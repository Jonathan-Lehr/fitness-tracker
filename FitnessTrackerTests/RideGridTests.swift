import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import FitnessTracker

final class RideGridTests: XCTestCase {
    private let cal = Calendar.app

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func testDayGroupsNewestFirstWithRidesNewestFirst() {
        let dates = [date(2025, 3, 10, 9), date(2025, 3, 14, 7), date(2025, 3, 14, 18), date(2025, 3, 13, 12)]
        let groups = DayGroup.group(dates, date: { $0 }, calendar: cal)
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
            let r = try XCTUnwrap(ThumbnailCropper.cropRect(width: 1600, height: 1200, aspect: aspect))
            // Starts near the top (heads) and uses the full band height.
            XCTAssertEqual(r.minY, 1200 * ThumbnailCropper.bandTop, accuracy: 1)
            XCTAssertEqual(r.height, 1200 * (ThumbnailCropper.bandBottom - ThumbnailCropper.bandTop), accuracy: 1)
            XCTAssertLessThanOrEqual(r.minY, 1200 * 0.05 + 1)
            XCTAssertEqual(r.width / r.height, aspect, accuracy: 0.02)
            XCTAssertEqual(r.midX, 1600 * ThumbnailCropper.centerX, accuracy: 1)
            XCTAssertGreaterThanOrEqual(r.minX, 1600 * ThumbnailCropper.sideInset - 1)
            XCTAssertLessThanOrEqual(r.maxX, 1600 * (1 - ThumbnailCropper.sideInset) + 1)
        }
    }

    func testCropRectIsTallerThanPreviousNarrowBand() throws {
        // Previous framing kept only 10–36% of height (312 px of 1200).
        let r = try XCTUnwrap(ThumbnailCropper.cropRect(width: 1600, height: 1200, aspect: 2))
        XCTAssertGreaterThan(r.height, 1200 * 0.26 + 50)
        XCTAssertLessThan(r.minY, 1200 * 0.10)
    }

    func testCropRectClampsInsideBandForWideCrops() throws {
        // A very wide aspect is limited by band width and stays inside the side insets.
        let r = try XCTUnwrap(ThumbnailCropper.cropRect(width: 1600, height: 1200, aspect: 5))
        XCTAssertEqual(r.minX, 1600 * ThumbnailCropper.sideInset, accuracy: 1)
        XCTAssertEqual(r.maxX, 1600 * (1 - ThumbnailCropper.sideInset), accuracy: 1)
    }

    func testCropRectPortraitImageAndDegenerate() throws {
        let r = try XCTUnwrap(ThumbnailCropper.cropRect(width: 900, height: 1600, aspect: 4.0 / 3.0))
        XCTAssertLessThanOrEqual(r.maxY, 1600 * ThumbnailCropper.bandBottom + 1)
        XCTAssertEqual(r.width / r.height, 4.0 / 3.0, accuracy: 0.05)
        XCTAssertNil(ThumbnailCropper.cropRect(width: 10, height: 10, aspect: 2))
        XCTAssertNil(ThumbnailCropper.cropRect(width: 800, height: 600, aspect: 0))
    }

    private func image(_ fill: (Int, Int) -> UInt8, w: Int = 64, h: Int = 64) -> CGImage {
        var px = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h { for x in 0..<w {
            let value = fill(x, y)
            let index = (y * w + x) * 4
            px[index] = value
            px[index + 1] = value
            px[index + 2] = value
        } }
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return ctx.makeImage()!
    }

    func testUsabilityRejectsBlackAndFlatAcceptsDetail() {
        XCTAssertFalse(ThumbnailCropper.isUsable(image { _, _ in 0 }))
        XCTAssertFalse(ThumbnailCropper.isUsable(image { _, _ in 128 }))
        XCTAssertTrue(ThumbnailCropper.isUsable(image { x, y in UInt8((x * 4 + y * 2) % 256) }))
    }

    private func jpeg(_ img: CGImage) -> Data {
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
        return out as Data
    }

    func testThumbnailFallsBackForUnreadableOrDarkPhoto() {
        XCTAssertNil(ThumbnailCropper.thumbnail(from: Data([1, 2, 3]), aspect: 2))
        XCTAssertNil(ThumbnailCropper.thumbnail(from: jpeg(image({ _, _ in 2 }, w: 400, h: 300)), aspect: 2))
    }

    func testThumbnailCropsDetailedPhoto() throws {
        let data = jpeg(image({ x, y in UInt8((x * 3 + y * 5) % 256) }, w: 800, h: 600))
        let t = try XCTUnwrap(ThumbnailCropper.thumbnail(from: data, aspect: 2))
        XCTAssertEqual(Double(t.width) / Double(t.height), 2, accuracy: 0.05)
        XCTAssertLessThan(t.height, 600)
    }

    func testStoreCachesResultIncludingFailures() async {
        let store = ThumbnailStore()
        let bad = Data([9, 9, 9])
        let a = await store.thumbnail(id: "x", data: bad, aspect: 2)
        let b = await store.thumbnail(id: "x", data: bad, aspect: 2)
        XCTAssertNil(a)
        XCTAssertNil(b)
        let good = jpeg(image({ x, y in UInt8((x * 3 + y * 5) % 256) }, w: 800, h: 600))
        let c = await store.thumbnail(id: "y", data: good, aspect: 2)
        let d = await store.thumbnail(id: "y", data: good, aspect: 2)
        XCTAssertNotNil(c)
        XCTAssertTrue(c === d, "second lookup should return the cached image")
    }

    func testSampleScreenshotsProduceUsableCropsAtCardAspects() throws {
        let bundle = Bundle(for: Self.self)
        let urls = ["ride-2026-10-12", "ride-2026-10-15", "ride-2026-10-18", "ride-2026-10-20"]
            .compactMap { bundle.url(forResource: $0, withExtension: "jpg") }
        XCTAssertEqual(urls.count, 4, "sample photos should be bundled")
        for url in urls {
            let stored = try XCTUnwrap(ImageTools.storageJPEG(from: try Data(contentsOf: url)))
            for aspect in [2.0, 4.0 / 3.0] {
                let t = try XCTUnwrap(ThumbnailCropper.thumbnail(from: stored, aspect: aspect),
                                      "\(url.lastPathComponent) should yield a usable crop")
                XCTAssertEqual(Double(t.width) / Double(t.height), aspect, accuracy: 0.03)
            }
        }
    }
}
