import Foundation
import SwiftData

enum SeedData {
    private static let seededKey = "didSeedRealRides"

    struct Ride {
        let date: String, title: String
        let minutes: Double, miles: Double, cal: Int, feet: Int, rpm: Int, watts: Int
        let incAvg: Double, incMax: Double, resAvg: Int, resMax: Int
    }

    static let realRides: [Ride] = [
        Ride(date: "2026-10-12 14:54", title: "Green River Recovery Ride", minutes: 42, miles: 10.02, cal: 310, feet: 599, rpm: 79, watts: 79, incAvg: 1.0, incMax: 9.0, resAvg: 11, resMax: 16),
        Ride(date: "2026-10-15 12:34", title: "Hurrah Pass Endurance Ride", minutes: 65, miles: 13.88, cal: 499, feet: 1745, rpm: 77, watts: 85, incAvg: 2.6, incMax: 10.0, resAvg: 10, resMax: 16),
        Ride(date: "2026-10-18 15:35", title: "Devils Garden Interval Ride", minutes: 46, miles: 9.50, cal: 385, feet: 1543, rpm: 74, watts: 97, incAvg: 3.7, incMax: 12.0, resAvg: 9, resMax: 15),
        Ride(date: "2026-10-20 16:06", title: "Mineral Bottom Endurance Ride", minutes: 48, miles: 9.85, cal: 376, feet: 1542, rpm: 75, watts: 88, incAvg: 3.6, incMax: 10.0, resAvg: 8, resMax: 15),
    ]

    /// Inserts the real rides once (tracked in UserDefaults so deleting them doesn't re-seed).
    static func seedIfNeeded(_ context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        insertRealRides(context)
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    static func insertRealRides(_ context: ModelContext) {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "America/New_York")
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        for r in realRides {
            let program = Program.findOrCreate(title: r.title, in: context)
            let w = Workout(date: fmt.date(from: r.date) ?? .now, program: program,
                            durationMinutes: r.minutes, distanceMiles: r.miles, calories: r.cal,
                            elevationFeet: r.feet, avgRPM: r.rpm, avgWatts: r.watts,
                            inclineAvg: r.incAvg, inclineMax: r.incMax,
                            resistanceAvg: r.resAvg, resistanceMax: r.resMax)
            context.insert(w)
        }
        try? context.save()
    }

    static func deleteAll(_ context: ModelContext, simulatedOnly: Bool = false) {
        let workouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        for w in workouts where !simulatedOnly || w.isSimulated { context.delete(w) }
        let programs = (try? context.fetch(FetchDescriptor<Program>())) ?? []
        for p in programs where (p.workouts ?? []).allSatisfy({ !simulatedOnly || $0.isSimulated }) {
            context.delete(p)
        }
        try? context.save()
    }
}
