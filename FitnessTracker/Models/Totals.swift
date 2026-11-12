import Foundation

struct Totals {
    var count = 0
    var minutes = 0.0
    var miles = 0.0
    var calories = 0
    var feet = 0

    // Averages over rides that have the value (> 0), time-weighted by duration.
    private var wattWeighted = 0.0, wattWeight = 0.0, wattSimple = 0, wattRides = 0
    private var rpmWeighted = 0.0, rpmWeight = 0.0, rpmSimple = 0, rpmRides = 0

    init(_ workouts: [Workout]) {
        for w in workouts {
            count += 1; minutes += w.durationMinutes; miles += w.distanceMiles
            calories += w.calories; feet += w.elevationFeet
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
}
