import Foundation
import SwiftData

enum SeedData {
    /// Persisted UserDefaults key; keeps its original "ride" name so existing devices don't re-seed.
    private static let seededKey = "didSeedRealRides"

    struct SeedWorkout {
        let date: String, title: String
        let minutes: Double, miles: Double, calories: Int, elevationFeet: Int, rpm: Int, watts: Int
        let inclineAvg: Double, inclineMax: Double, resistanceAvg: Int, resistanceMax: Int
    }

    static let realWorkouts: [SeedWorkout] = [
        SeedWorkout(date: "2026-10-12 14:54", title: "Green River Recovery Ride", minutes: 42, miles: 10.02, calories: 310, elevationFeet: 599, rpm: 79, watts: 79, inclineAvg: 1.0, inclineMax: 9.0, resistanceAvg: 11, resistanceMax: 16),
        SeedWorkout(date: "2026-10-15 12:34", title: "Hurrah Pass Endurance Ride", minutes: 65, miles: 13.88, calories: 499, elevationFeet: 1745, rpm: 77, watts: 85, inclineAvg: 2.6, inclineMax: 10.0, resistanceAvg: 10, resistanceMax: 16),
        SeedWorkout(date: "2026-10-18 15:35", title: "Devils Garden Interval Ride", minutes: 46, miles: 9.50, calories: 385, elevationFeet: 1543, rpm: 74, watts: 97, inclineAvg: 3.7, inclineMax: 12.0, resistanceAvg: 9, resistanceMax: 15),
        SeedWorkout(date: "2026-10-20 16:06", title: "Mineral Bottom Endurance Ride", minutes: 48, miles: 9.85, calories: 376, elevationFeet: 1542, rpm: 75, watts: 88, inclineAvg: 3.6, inclineMax: 10.0, resistanceAvg: 8, resistanceMax: 15),
    ]

    /// Inserts the real workouts once per device (tracked in UserDefaults so deleting them doesn't
    /// re-seed). With iCloud sync, another device may already have them, so each workout is skipped
    /// if a workout with the same date and title exists; DataDeduper cleans up any race.
    static func seedIfNeeded(_ context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        insertRealWorkouts(context)
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    /// Parses the fixed `yyyy-MM-dd HH:mm` seed timestamps in America/New_York.
    /// A static formatter is required here because the seed strings are machine-readable, not locale-formatted.
    private static let workoutDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    static func insertRealWorkouts(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        let existingKeys = Set(existing.map(DataDeduper.key))
        for seed in realWorkouts {
            let date = workoutDateFormatter.date(from: seed.date) ?? .now
            if existingKeys.contains(DataDeduper.key(title: seed.title, date: date)) { continue }
            let program = Program.findOrCreate(title: seed.title, in: context)
            let workout = Workout(date: date, program: program,
                            durationMinutes: seed.minutes, distanceMiles: seed.miles, calories: seed.calories,
                            elevationFeet: seed.elevationFeet, avgRPM: seed.rpm, avgWatts: seed.watts,
                            inclineAvg: seed.inclineAvg, inclineMax: seed.inclineMax,
                            resistanceAvg: seed.resistanceAvg, resistanceMax: seed.resistanceMax)
            context.insert(workout)
        }
        try? context.save()
    }
}
