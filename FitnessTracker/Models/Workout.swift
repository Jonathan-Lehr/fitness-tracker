import Foundation
import CoreGraphics
import SwiftData

@Model
final class Workout {
    var date: Date = Date()
    var durationMinutes: Double = 0
    var distanceMiles: Double = 0
    var calories: Int = 0
    var elevationFeet: Int = 0
    var avgRPM: Int = 0
    var avgWatts: Int = 0
    var inclineAvg: Double = 0
    var inclineMax: Double = 0
    var resistanceAvg: Int = 0
    var resistanceMax: Int = 0
    var notes: String?
    @Attribute(.externalStorage) var photoData: Data?
    /// Region of `photoData` that thumbnails frame, as fractions of the image with a top-left origin.
    /// Read and write it through `thumbnailFocus`. Separate scalars keep the schema CloudKit-friendly.
    var thumbnailFocusX: Double?
    var thumbnailFocusY: Double?
    var thumbnailFocusWidth: Double?
    var thumbnailFocusHeight: Double?
    /// `ThumbnailFocusFinder.analysisVersion` that produced the focus; 0 means not analyzed yet.
    /// Tracked separately so photos where Vision found nothing aren't analyzed again.
    var thumbnailFocusAnalysisVersion: Int = 0
    var isSimulated: Bool = false
    var program: Program?

    init(date: Date, program: Program?, durationMinutes: Double = 0, distanceMiles: Double = 0,
         calories: Int = 0, elevationFeet: Int = 0, avgRPM: Int = 0, avgWatts: Int = 0,
         inclineAvg: Double = 0, inclineMax: Double = 0, resistanceAvg: Int = 0, resistanceMax: Int = 0,
         notes: String? = nil, isSimulated: Bool = false) {
        self.date = date
        self.program = program
        self.durationMinutes = durationMinutes
        self.distanceMiles = distanceMiles
        self.calories = calories
        self.elevationFeet = elevationFeet
        self.avgRPM = avgRPM
        self.avgWatts = avgWatts
        self.inclineAvg = inclineAvg
        self.inclineMax = inclineMax
        self.resistanceAvg = resistanceAvg
        self.resistanceMax = resistanceMax
        self.notes = notes
        self.isSimulated = isSimulated
    }

    /// Hand-entry defaults (45 min, 10 mi, and so on) used when adding a ride without a photo.
    convenience init(forManualEntry date: Date = .now) {
        self.init(
            date: date,
            program: nil,
            durationMinutes: 45,
            distanceMiles: 10,
            calories: 350,
            elevationFeet: 1000,
            avgRPM: 75,
            avgWatts: 85,
            inclineAvg: 2,
            inclineMax: 10,
            resistanceAvg: 10,
            resistanceMax: 15
        )
    }

    /// Values parsed from a photo; missing fields are 0, or the current date.
    convenience init(summary: IFitSummary) {
        self.init(
            date: summary.date ?? .now,
            program: nil,
            durationMinutes: summary.durationMinutes ?? 0,
            distanceMiles: summary.distanceMiles ?? 0,
            calories: summary.calories ?? 0,
            elevationFeet: summary.elevationFeet ?? 0,
            avgRPM: summary.avgRPM ?? 0,
            avgWatts: summary.avgWatts ?? 0,
            inclineAvg: summary.inclineAvg ?? 0,
            inclineMax: summary.inclineMax ?? 0,
            resistanceAvg: summary.resistanceAvg ?? 0,
            resistanceMax: summary.resistanceMax ?? 0
        )
    }

    var title: String { program?.title ?? "Untitled Ride" }
    var type: WorkoutType { program?.type ?? .other }
}

// MARK: - Thumbnail focus

extension Workout {
    /// Region thumbnails center on (fractions of the photo, top-left origin), or nil to use the fixed
    /// band framing. Invalid stored values read as nil.
    var thumbnailFocus: CGRect? {
        get {
            guard let thumbnailFocusX, let thumbnailFocusY, let thumbnailFocusWidth, let thumbnailFocusHeight else {
                return nil
            }
            let focus = CGRect(x: thumbnailFocusX, y: thumbnailFocusY,
                               width: thumbnailFocusWidth, height: thumbnailFocusHeight)
            return ThumbnailFocusFinder.isNormalized(focus) ? focus : nil
        }
        set {
            thumbnailFocusX = newValue.map { Double($0.minX) }
            thumbnailFocusY = newValue.map { Double($0.minY) }
            thumbnailFocusWidth = newValue.map { Double($0.width) }
            thumbnailFocusHeight = newValue.map { Double($0.height) }
        }
    }

    /// True when the ride has a photo that the current analysis hasn't looked at.
    var needsThumbnailFocusAnalysis: Bool {
        thumbnailFocusAnalysisVersion < ThumbnailFocusFinder.analysisVersion && photoData != nil
    }

    func apply(_ analysis: ThumbnailFocusAnalysis) {
        thumbnailFocus = analysis.focus
        thumbnailFocusAnalysisVersion = ThumbnailFocusFinder.analysisVersion
    }

    /// Sets the photo and keeps the focus in step with it: the import's `analysis` when given,
    /// otherwise cleared so the backfill analyzes the new photo. Unchanged photos keep their focus.
    func replacePhoto(with data: Data?, analysis: ThumbnailFocusAnalysis? = nil) {
        guard data != photoData else { return }
        photoData = data
        if data != nil, let analysis {
            apply(analysis)
        } else {
            thumbnailFocus = nil
            thumbnailFocusAnalysisVersion = 0
        }
    }
}
