import XCTest
import CoreGraphics
import SwiftData
@testable import FitnessTracker

final class ThumbnailCropMathTests: XCTestCase {
    /// Scenic band of a 1600×1200 photo in pixels: x 96–1504, y 60–480.
    private let bandPixels = CGRect(x: 96, y: 60, width: 1408, height: 420)

    private func crop(aspect: Double, focus: CGRect?) throws -> CGRect {
        try XCTUnwrap(ThumbnailCropper.cropRect(width: 1600, height: 1200, aspect: aspect, focus: focus))
    }

    func testFocusedCropKeepsAspectAndStaysInsideBand() throws {
        let focuses = [CGRect(x: 0, y: 0, width: 0.05, height: 0.05), CGRect(x: 0.4, y: 0.1, width: 0.2, height: 0.25),
                       CGRect(x: 0.9, y: 0.3, width: 0.1, height: 0.1), CGRect(x: 0, y: 0, width: 1, height: 1)]
        for aspect in [2.0, 4.0 / 3.0, 5.0] {
            for focus in focuses {
                let rect = try crop(aspect: aspect, focus: focus)
                // Rounding to whole pixels can add a pixel to the height, so allow 1% of the aspect.
                XCTAssertEqual(rect.width / rect.height, aspect, accuracy: aspect * 0.01, "aspect \(aspect), focus \(focus)")
                XCTAssertTrue(bandPixels.insetBy(dx: -1, dy: -1).contains(rect), "aspect \(aspect), focus \(focus): \(rect)")
            }
        }
    }

    func testFocusedCropIsAsLargeAsTheBandAllows() throws {
        // 4:3 is limited by band height; 5:1 by band width.
        XCTAssertEqual(try crop(aspect: 4.0 / 3.0, focus: CGRect(x: 0.3, y: 0.1, width: 0.1, height: 0.1)).height, 420, accuracy: 1)
        XCTAssertEqual(try crop(aspect: 5, focus: CGRect(x: 0.3, y: 0.1, width: 0.1, height: 0.1)).width, 1408, accuracy: 1)
    }

    func testFocusedCropCentersOnFocusWhenThereIsRoom() throws {
        // Focus centered at x = 0.3 (480 px); the 560 px wide crop can center there.
        let rect = try crop(aspect: 4.0 / 3.0, focus: CGRect(x: 0.25, y: 0.1, width: 0.1, height: 0.2))
        XCTAssertEqual(rect.midX, 480, accuracy: 1)
    }

    func testFocusedCropClampsAtBandEdges() throws {
        let left = try crop(aspect: 4.0 / 3.0, focus: CGRect(x: 0, y: 0.1, width: 0.04, height: 0.1))
        XCTAssertEqual(left.minX, bandPixels.minX, accuracy: 1)
        let right = try crop(aspect: 4.0 / 3.0, focus: CGRect(x: 0.96, y: 0.1, width: 0.04, height: 0.1))
        XCTAssertEqual(right.maxX, bandPixels.maxX, accuracy: 1)
    }

    func testWideCropMovesVerticallyTowardFocus() throws {
        // A 5:1 crop is shorter than the band, so a low focus pulls it down to the band bottom.
        let rect = try crop(aspect: 5, focus: CGRect(x: 0.4, y: 0.33, width: 0.1, height: 0.05))
        XCTAssertEqual(rect.maxY, bandPixels.maxY, accuracy: 1)
        XCTAssertGreaterThan(rect.minY, bandPixels.minY + 50)
    }

    func testWithoutFocusFallsBackToFixedBandFraming() throws {
        // Anchored to the band top, centered at 62% of the width: 0.62 × 1600 − 280 = 712.
        let rect = try crop(aspect: 4.0 / 3.0, focus: nil)
        XCTAssertEqual(rect.minX, 712, accuracy: 1)
        XCTAssertEqual(rect.minY, 60, accuracy: 1)
        XCTAssertEqual(rect.width, 560, accuracy: 1)
        XCTAssertEqual(rect.height, 420, accuracy: 1)
        XCTAssertEqual(ThumbnailCropper.cropRect(width: 1600, height: 1200, aspect: 2), try crop(aspect: 2, focus: nil))
    }

    func testDegenerateSizesStillReturnNilWithFocus() {
        let focus = CGRect(x: 0.4, y: 0.1, width: 0.2, height: 0.2)
        XCTAssertNil(ThumbnailCropper.cropRect(width: 10, height: 10, aspect: 2, focus: focus))
        XCTAssertNil(ThumbnailCropper.cropRect(width: 800, height: 600, aspect: 0, focus: focus))
    }

    func testLargestSize() {
        XCTAssertEqual(ThumbnailCropper.largestSize(aspect: 2, fitting: CGSize(width: 1000, height: 300)),
                       CGSize(width: 600, height: 300))
        XCTAssertEqual(ThumbnailCropper.largestSize(aspect: 2, fitting: CGSize(width: 400, height: 300)),
                       CGSize(width: 400, height: 200))
    }

    func testStoreKeyIncludesFocus() {
        let data = Data([1, 2, 3])
        let focused = ThumbnailStore.key(id: "a", data: data, aspect: 2, focus: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2))
        let moved = ThumbnailStore.key(id: "a", data: data, aspect: 2, focus: CGRect(x: 0.3, y: 0.1, width: 0.2, height: 0.2))
        let unfocused = ThumbnailStore.key(id: "a", data: data, aspect: 2)
        XCTAssertNotEqual(focused, moved)
        XCTAssertNotEqual(focused, unfocused)
    }
}

final class ThumbnailFocusFinderTests: XCTestCase {
    private let band = ThumbnailCropper.band

    private func assertEqual(_ actual: CGRect?, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("expected \(expected), got nil", file: file, line: line) }
        XCTAssertEqual(actual.minX, expected.minX, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(actual.width, expected.width, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: 1e-9, file: file, line: line)
    }

    func testWholeAnalyzedImageMapsToTheRegion() {
        assertEqual(ThumbnailFocusFinder.imageRect(fromVision: CGRect(x: 0, y: 0, width: 1, height: 1), within: band), band)
    }

    func testVisionBottomLeftOriginIsFlipped() {
        // Vision's bottom-right quadrant is the bottom-right quadrant of the band in top-left space.
        let box = CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        let expected = CGRect(x: band.minX + band.width / 2, y: band.minY + band.height / 2,
                              width: band.width / 2, height: band.height / 2)
        assertEqual(ThumbnailFocusFinder.imageRect(fromVision: box, within: band), expected)

        // A box hugging Vision's top edge lands at the top of the band.
        let top = ThumbnailFocusFinder.imageRect(fromVision: CGRect(x: 0, y: 0.9, width: 1, height: 0.1), within: band)
        XCTAssertEqual(top?.minY ?? -1, band.minY, accuracy: 1e-9)
    }

    func testBoxesOutsideTheImageAreClampedOrDropped() {
        let partial = ThumbnailFocusFinder.imageRect(fromVision: CGRect(x: -0.2, y: 0.5, width: 0.4, height: 0.7), within: band)
        assertEqual(partial, CGRect(x: band.minX, y: band.minY, width: band.width * 0.2, height: band.height * 0.5))
        XCTAssertNil(ThumbnailFocusFinder.imageRect(fromVision: CGRect(x: 1.2, y: 0, width: 0.2, height: 0.2), within: band))
    }

    func testNormalizedRect() {
        let rect = ThumbnailFocusFinder.normalizedRect(CGRect(x: 96, y: 60, width: 1408, height: 420),
                                                       in: CGRect(x: 0, y: 0, width: 1600, height: 1200))
        assertEqual(rect, band)
    }

    func testPeoplePreferredOverSaliency() {
        let person = CGRect(x: 0.5, y: 0.2, width: 0.2, height: 0.6)
        let face = CGRect(x: 0.55, y: 0.6, width: 0.1, height: 0.15)
        let salient = CGRect(x: 0, y: 0.4, width: 0.3, height: 0.2)
        XCTAssertEqual(ThumbnailFocusCandidates(humans: [person], faces: [face], salientObjects: [salient]).preferredRegion, person)
        XCTAssertEqual(ThumbnailFocusCandidates(faces: [face], salientObjects: [salient]).preferredRegion, face)
        XCTAssertEqual(ThumbnailFocusCandidates(salientObjects: [salient]).preferredRegion, salient)
        XCTAssertNil(ThumbnailFocusCandidates().preferredRegion)
    }

    func testMultipleRegionsAreUnited() throws {
        let candidates = ThumbnailFocusCandidates(humans: [CGRect(x: 0.1, y: 0.1, width: 0.1, height: 0.1),
                                                           CGRect(x: 0.6, y: 0.5, width: 0.2, height: 0.2)])
        let region = try XCTUnwrap(candidates.preferredRegion)
        XCTAssertEqual(region.minX, 0.1, accuracy: 1e-9)
        XCTAssertEqual(region.minY, 0.1, accuracy: 1e-9)
        XCTAssertEqual(region.maxX, 0.8, accuracy: 1e-9)
        XCTAssertEqual(region.maxY, 0.7, accuracy: 1e-9)
    }

    func testIsNormalized() {
        XCTAssertTrue(ThumbnailFocusFinder.isNormalized(CGRect(x: 0.2, y: 0.1, width: 0.3, height: 0.2)))
        XCTAssertFalse(ThumbnailFocusFinder.isNormalized(CGRect(x: 0.2, y: 0.1, width: 0, height: 0.2)))
        XCTAssertFalse(ThumbnailFocusFinder.isNormalized(CGRect(x: 0.9, y: 0.1, width: 0.5, height: 0.2)))
        XCTAssertFalse(ThumbnailFocusFinder.isNormalized(CGRect(x: .nan, y: 0.1, width: 0.5, height: 0.2)))
    }

    func testUnreadablePhotoCountsAsAnalyzedWithoutFocus() {
        XCTAssertEqual(ThumbnailFocusFinder.analyze(photoData: Data([1, 2, 3])), ThumbnailFocusAnalysis(focus: nil))
    }

    /// Sanity check on the real iFit screenshots: Vision runs, and any focus it finds sits in the scenic band.
    func testSamplePhotosFocusInsideScenicBand() throws {
        let bundle = Bundle(for: Self.self)
        for name in ["ride-2026-10-12", "ride-2026-10-15", "ride-2026-10-18", "ride-2026-10-20"] {
            let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "jpg"))
            let stored = try XCTUnwrap(ImageTools.storageJPEG(from: try Data(contentsOf: url)))
            let analysis = try XCTUnwrap(ThumbnailFocusFinder.analyze(photoData: stored), "\(name): Vision failed")
            print("Thumbnail focus \(name): \(analysis.focus.map { String(describing: $0) } ?? "none")")
            if let focus = analysis.focus {
                XCTAssertTrue(band.insetBy(dx: -0.001, dy: -0.001).contains(focus), "\(name): \(focus)")
            }
            let thumbnail = try XCTUnwrap(ThumbnailCropper.thumbnail(from: stored, aspect: 2, focus: analysis.focus))
            XCTAssertEqual(Double(thumbnail.width) / Double(thumbnail.height), 2, accuracy: 0.03)
        }
    }
}

@MainActor
final class WorkoutThumbnailFocusTests: XCTestCase {
    private var container: ModelContainer!

    private func makeWorkout() throws -> Workout {
        container = try TestSupport.inMemoryContainer()
        let workout = TestSupport.ride(
            date: .now,
            durationMinutes: 30,
            distanceMiles: 8,
            calories: 300,
            elevationFeet: 500,
            avgRPM: 75,
            avgWatts: 90,
            inclineAvg: 2,
            inclineMax: 8,
            resistanceAvg: 10,
            resistanceMax: 14
        )
        container.mainContext.insert(workout)
        return workout
    }

    private let focus = CGRect(x: 0.5, y: 0.1, width: 0.2, height: 0.25)

    func testFocusRoundTripsThroughStoredScalars() throws {
        let workout = try makeWorkout()
        XCTAssertNil(workout.thumbnailFocus)
        workout.thumbnailFocus = focus
        XCTAssertEqual(workout.thumbnailFocus, focus)
        XCTAssertEqual(workout.thumbnailFocusWidth, 0.2)
        workout.thumbnailFocus = nil
        XCTAssertNil(workout.thumbnailFocusX)
    }

    func testInvalidStoredFocusReadsAsNil() throws {
        let workout = try makeWorkout()
        workout.thumbnailFocus = focus
        workout.thumbnailFocusWidth = 3
        XCTAssertNil(workout.thumbnailFocus)
    }

    func testNewPhotoAppliesImportAnalysis() throws {
        let workout = try makeWorkout()
        workout.replacePhoto(with: Data([1]), analysis: ThumbnailFocusAnalysis(focus: focus))
        XCTAssertEqual(workout.thumbnailFocus, focus)
        XCTAssertEqual(workout.thumbnailFocusAnalysisVersion, ThumbnailFocusFinder.analysisVersion)
        XCTAssertFalse(workout.needsThumbnailFocusAnalysis)
    }

    func testPhotoWithoutAnalysisNeedsBackfill() throws {
        let workout = try makeWorkout()
        workout.replacePhoto(with: Data([1]), analysis: ThumbnailFocusAnalysis(focus: focus))
        workout.replacePhoto(with: Data([2]))
        XCTAssertNil(workout.thumbnailFocus)
        XCTAssertEqual(workout.thumbnailFocusAnalysisVersion, 0)
        XCTAssertTrue(workout.needsThumbnailFocusAnalysis)
    }

    func testRemovingPhotoClearsFocusAndUnchangedPhotoKeepsIt() throws {
        let workout = try makeWorkout()
        workout.replacePhoto(with: Data([1]), analysis: ThumbnailFocusAnalysis(focus: focus))
        workout.replacePhoto(with: Data([1]))
        XCTAssertEqual(workout.thumbnailFocus, focus, "an unchanged photo keeps its focus")
        workout.replacePhoto(with: nil)
        XCTAssertNil(workout.thumbnailFocus)
        XCTAssertFalse(workout.needsThumbnailFocusAnalysis)
    }

    func testAnalysisWithNothingFoundIsNotRepeated() throws {
        let workout = try makeWorkout()
        workout.photoData = Data([1])
        XCTAssertTrue(workout.needsThumbnailFocusAnalysis)
        workout.apply(ThumbnailFocusAnalysis(focus: nil))
        XCTAssertFalse(workout.needsThumbnailFocusAnalysis)
        XCTAssertTrue(ThumbnailFocusBackfill.pendingWorkouts(container.mainContext).isEmpty)
    }

    func testBackfillAnalyzesPendingPhotos() async throws {
        let workout = try makeWorkout()
        workout.photoData = Data([1, 2, 3])   // unreadable, so it is marked analyzed with no focus
        XCTAssertEqual(ThumbnailFocusBackfill.pendingWorkouts(container.mainContext).count, 1)
        await ThumbnailFocusBackfill.run(container.mainContext)
        XCTAssertEqual(workout.thumbnailFocusAnalysisVersion, ThumbnailFocusFinder.analysisVersion)
        XCTAssertNil(workout.thumbnailFocus)
        XCTAssertTrue(ThumbnailFocusBackfill.pendingWorkouts(container.mainContext).isEmpty)
    }
}
