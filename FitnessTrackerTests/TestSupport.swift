import Foundation
import SwiftData
@testable import FitnessTracker

/// Shared in-memory container, date, and workout helpers for unit tests.
enum TestSupport {
    static func inMemoryContainer() throws -> ModelContainer {
        let schema = Schema([Program.self, Workout.self])
        return try ModelContainer(
            for: schema,
            configurations: [
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            ]
        )
    }

    static func context(on container: ModelContainer, autosaveEnabled: Bool = true) -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = autosaveEnabled
        return context
    }

    static func inMemoryContext(autosaveEnabled: Bool = true) throws -> ModelContext {
        context(on: try inMemoryContainer(), autosaveEnabled: autosaveEnabled)
    }

    static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12,
        minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func workout(
        date: Date,
        program: Program? = nil,
        durationMinutes: Double = 30,
        distanceMiles: Double = 10,
        calories: Int = 300,
        elevationFeet: Int = 500,
        avgRPM: Int = 75,
        avgWatts: Int = 85,
        inclineAvg: Double = 0,
        inclineMax: Double = 0,
        resistanceAvg: Int = 10,
        resistanceMax: Int = 15,
        notes: String? = nil,
        isSimulated: Bool = false
    ) -> Workout {
        Workout(
            date: date,
            program: program,
            durationMinutes: durationMinutes,
            distanceMiles: distanceMiles,
            calories: calories,
            elevationFeet: elevationFeet,
            avgRPM: avgRPM,
            avgWatts: avgWatts,
            inclineAvg: inclineAvg,
            inclineMax: inclineMax,
            resistanceAvg: resistanceAvg,
            resistanceMax: resistanceMax,
            notes: notes,
            isSimulated: isSimulated
        )
    }
}
