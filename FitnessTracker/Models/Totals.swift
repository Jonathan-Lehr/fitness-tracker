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
        for workout in workouts {
            count += 1
            minutes += workout.durationMinutes
            miles += workout.distanceMiles
            calories += workout.calories
            feet += workout.elevationFeet
            let weight = max(workout.durationMinutes, 0)
            if workout.avgWatts > 0 {
                wattRides += 1
                wattSimple += workout.avgWatts
                wattWeighted += Double(workout.avgWatts) * weight
                wattWeight += weight
            }
            if workout.avgRPM > 0 {
                rpmRides += 1
                rpmSimple += workout.avgRPM
                rpmWeighted += Double(workout.avgRPM) * weight
                rpmWeight += weight
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
