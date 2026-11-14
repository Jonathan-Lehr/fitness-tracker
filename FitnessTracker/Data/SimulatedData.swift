#if DEBUG
import Foundation
import SwiftData

/// Debug-only generator: ~18 months of workouts, 3–5 per week, ~20 programs,
/// with a few favorites ridden many times and slowly improving watts.
enum SimulatedData {
    static let programs: [(title: String, baseWatts: Double, minutes: Double, favorite: Bool)] = [
        ("Hurrah Pass Endurance Ride", 80, 65, true),
        ("Devils Garden Interval Ride", 90, 46, true),
        ("Green River Recovery Ride", 72, 42, true),
        ("Mineral Bottom Endurance Ride", 82, 48, true),
        ("Delicate Arch Climb", 92, 35, false),
        ("Fiery Furnace Interval Ride", 95, 30, false),
        ("Shafer Trail Climb", 94, 55, false),
        ("White Rim Endurance Ride", 78, 75, false),
        ("Dead Horse Point Tempo Ride", 88, 40, false),
        ("Island in the Sky Endurance Ride", 80, 60, false),
        ("Goblin Valley Recovery Ride", 68, 30, false),
        ("Capitol Reef Tempo Ride", 86, 45, false),
        ("Bryce Canyon Rim Climb", 93, 50, false),
        ("Zion Canyon Endurance Ride", 79, 60, false),
        ("Moab Slickrock Interval Ride", 98, 35, false),
        ("Castle Valley Recovery Ride", 70, 35, false),
        ("Fisher Towers Tempo Ride", 87, 40, false),
        ("Needles District Endurance Ride", 81, 55, false),
        ("Gemini Bridges Interval Ride", 96, 40, false),
        ("San Rafael Swell Endurance Ride", 79, 70, false),
    ]

    static func generate(into context: ModelContext, months: Int = 18) {
        var generator = SystemRandomNumberGenerator()
        let calendar = Calendar.app
        let end = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .month, value: -months, to: end) else { return }
        let totalDays = Double(calendar.dateComponents([.day], from: start, to: end).day ?? 1)

        let programModels = programs.map { Program.findOrCreate(title: $0.title, in: context) }

        var weekStart = start
        while weekStart < end {
            // Occasional off week
            let workoutsThisWeek = Double.random(in: 0..<1, using: &generator) < 0.07 ? Int.random(in: 0...1, using: &generator)
                                                                             : Int.random(in: 3...5, using: &generator)
            let days = Array(0..<7).shuffled(using: &generator).prefix(workoutsThisWeek)
            for dayOffset in days {
                guard var date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart), date < end else { continue }
                date = calendar.date(bySettingHour: Int.random(in: 6...19, using: &generator),
                                minute: Int.random(in: 0...59, using: &generator), second: 0, of: date) ?? date

                // Favorites get ~40% of workouts (≈15–30 each over 18 months)
                let programIndex: Int
                if Double.random(in: 0..<1, using: &generator) < 0.4 {
                    programIndex = Int.random(in: 0..<4, using: &generator)
                } else {
                    programIndex = Int.random(in: 4..<programs.count, using: &generator)
                }
                let program = programs[programIndex]
                let progress = Double(calendar.dateComponents([.day], from: start, to: date).day ?? 0) / totalDays
                let watts = max(50, program.baseWatts * (0.88 + 0.2 * progress) + Double.random(in: -6...6, using: &generator))
                let minutes = program.minutes
                let rpm = Double.random(in: 70...84, using: &generator)
                let miles = minutes / 60 * (watts / 6.5) * Double.random(in: 0.95...1.05, using: &generator)
                let calories = watts * minutes * 60 / 1000 * 1.1 / 0.24 / 4.184 // approx kcal
                let inclineAvg = Double.random(in: 0.5...4.5, using: &generator)
                let resistanceAvg = Int.random(in: 7...12, using: &generator)
                let workout = Workout(date: date, program: programModels[programIndex],
                                durationMinutes: minutes,
                                distanceMiles: (miles * 100).rounded() / 100,
                                calories: Int(calories),
                                elevationFeet: Int(inclineAvg * minutes * Double.random(in: 9...11, using: &generator)),
                                avgRPM: Int(rpm), avgWatts: Int(watts),
                                inclineAvg: (inclineAvg * 10).rounded() / 10,
                                inclineMax: Double(Int.random(in: Int(inclineAvg) + 4...14, using: &generator)),
                                resistanceAvg: resistanceAvg, resistanceMax: resistanceAvg + Int.random(in: 3...7, using: &generator),
                                isSimulated: true)
                context.insert(workout)
            }
            guard let next = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = next
        }
        try? context.save()
    }
}
#endif
