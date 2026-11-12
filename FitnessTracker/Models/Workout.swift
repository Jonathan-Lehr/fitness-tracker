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

    init(date: Date, program: Program?, durationMinutes: Double, distanceMiles: Double,
         calories: Int, elevationFeet: Int, avgRPM: Int, avgWatts: Int,
         inclineAvg: Double, inclineMax: Double, resistanceAvg: Int, resistanceMax: Int,
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

// MARK: - Grouping

enum GroupingPeriod: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    var id: String { rawValue }

    var component: Calendar.Component {
        switch self {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }

    /// Start of the calendar week (Monday), month or year containing `date`.
    func start(of date: Date, calendar: Calendar = .app) -> Date {
        calendar.dateInterval(of: component, for: date)?.start ?? date
    }

    func label(for start: Date, calendar: Calendar = .app) -> String {
        switch self {
        case .week: "Week of " + start.formatted(Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).month(.abbreviated).day().year())
        case .month: start.formatted(.dateTime.month(.wide).year())
        case .year: start.formatted(.dateTime.year())
        }
    }
}

struct Totals {
    var count = 0
    var minutes = 0.0
    var miles = 0.0
    var calories = 0
    var feet = 0
    var wattSum = 0

    // Averages over rides that have the value (> 0), time-weighted by duration.
    private var wattWeighted = 0.0, wattWeight = 0.0, wattSimple = 0, wattRides = 0
    private var rpmWeighted = 0.0, rpmWeight = 0.0, rpmSimple = 0, rpmRides = 0

    init(_ workouts: [Workout]) {
        for w in workouts {
            count += 1; minutes += w.durationMinutes; miles += w.distanceMiles
            calories += w.calories; feet += w.elevationFeet; wattSum += w.avgWatts
            let weight = max(w.durationMinutes, 0)
            if w.avgWatts > 0 {
                wattRides += 1; wattSimple += w.avgWatts
                wattWeighted += Double(w.avgWatts) * weight; wattWeight += weight
            }
            if w.avgRPM > 0 {
                rpmRides += 1; rpmSimple += w.avgRPM
                rpmWeighted += Double(w.avgRPM) * weight; rpmWeight += weight
            }
        }
    }

    /// Duration-weighted average of avg watts over rides that recorded watts; nil if none.
    /// Falls back to a simple mean if none of those rides has a duration.
    var averageWatts: Double? {
        Self.average(weighted: wattWeighted, weight: wattWeight, simple: wattSimple, rides: wattRides)
    }

    /// Duration-weighted average of avg RPM over rides that recorded RPM; nil if none.
    var averageRPM: Double? {
        Self.average(weighted: rpmWeighted, weight: rpmWeight, simple: rpmSimple, rides: rpmRides)
    }

    private static func average(weighted: Double, weight: Double, simple: Int, rides: Int) -> Double? {
        guard rides > 0 else { return nil }
        return weight > 0 ? weighted / weight : Double(simple) / Double(rides)
    }

    var avgWatts: Double { count == 0 ? 0 : Double(wattSum) / Double(count) }
}
