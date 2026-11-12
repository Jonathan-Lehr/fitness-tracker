import Foundation

/// Editable ride values for the add/edit form, independent of SwiftUI so they can be tested.
struct WorkoutDraft: Equatable {
    var title: String = ""
    var date: Date = .now
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
    var notes: String = ""
    var photoData: Data? = nil

    /// Shown when adding a ride by hand, with no photo and no existing workout.
    static var manualEntry: WorkoutDraft {
        WorkoutDraft(
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

    init(title: String = "", date: Date = .now,
         durationMinutes: Double = 0, distanceMiles: Double = 0,
         calories: Int = 0, elevationFeet: Int = 0,
         avgRPM: Int = 0, avgWatts: Int = 0,
         inclineAvg: Double = 0, inclineMax: Double = 0,
         resistanceAvg: Int = 0, resistanceMax: Int = 0,
         notes: String = "", photoData: Data? = nil) {
        self.title = title
        self.date = date
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
        self.photoData = photoData
    }

    /// Missing parser fields become 0 (or an empty title / the current date).
    init(summary: IFitSummary, photoData: Data? = nil) {
        self.init(
            title: summary.title ?? "",
            date: summary.date ?? .now,
            durationMinutes: summary.durationMinutes ?? 0,
            distanceMiles: summary.distanceMiles ?? 0,
            calories: summary.calories ?? 0,
            elevationFeet: summary.elevationFeet ?? 0,
            avgRPM: summary.avgRPM ?? 0,
            avgWatts: summary.avgWatts ?? 0,
            inclineAvg: summary.inclineAvg ?? 0,
            inclineMax: summary.inclineMax ?? 0,
            resistanceAvg: summary.resistanceAvg ?? 0,
            resistanceMax: summary.resistanceMax ?? 0,
            photoData: photoData
        )
    }

    init(workout: Workout) {
        self.init(
            title: workout.title,
            date: workout.date,
            durationMinutes: workout.durationMinutes,
            distanceMiles: workout.distanceMiles,
            calories: workout.calories,
            elevationFeet: workout.elevationFeet,
            avgRPM: workout.avgRPM,
            avgWatts: workout.avgWatts,
            inclineAvg: workout.inclineAvg,
            inclineMax: workout.inclineMax,
            resistanceAvg: workout.resistanceAvg,
            resistanceMax: workout.resistanceMax,
            notes: workout.notes ?? "",
            photoData: workout.photoData
        )
    }

    /// Copies date, stats, and notes onto `workout`. Program and photo are applied by the form.
    func apply(to workout: Workout) {
        workout.date = date
        workout.durationMinutes = durationMinutes
        workout.distanceMiles = distanceMiles
        workout.calories = calories
        workout.elevationFeet = elevationFeet
        workout.avgRPM = avgRPM
        workout.avgWatts = avgWatts
        workout.inclineAvg = inclineAvg
        workout.inclineMax = inclineMax
        workout.resistanceAvg = resistanceAvg
        workout.resistanceMax = resistanceMax
        workout.notes = notes.isEmpty ? nil : notes
    }
}
