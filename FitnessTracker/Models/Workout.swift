import Foundation
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

// MARK: - Grouping

enum GroupingPeriod: String, CaseIterable, Identifiable {
    case week = "Week", month = "Month", year = "Year"
    var id: String { rawValue }

    var component: Calendar.Component {
        switch self {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }

    func start(of date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: component, for: date)?.start ?? date
    }

    func label(for start: Date) -> String {
        switch self {
        case .week: "Week of " + start.formatted(.dateTime.month(.abbreviated).day().year())
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

    init(_ workouts: [Workout]) {
        for w in workouts {
            count += 1; minutes += w.durationMinutes; miles += w.distanceMiles
            calories += w.calories; feet += w.elevationFeet; wattSum += w.avgWatts
        }
    }

    var avgWatts: Double { count == 0 ? 0 : Double(wattSum) / Double(count) }
}
