import Foundation

struct Totals {
    var count = 0
    var minutes = 0.0
    var miles = 0.0
    var calories = 0
    var feet = 0

    // Averages over workouts that have the value (> 0), time-weighted by duration.
    private var wattWeighted = 0.0, wattWeight = 0.0, wattSimple = 0, wattWorkouts = 0
    private var rpmWeighted = 0.0, rpmWeight = 0.0, rpmSimple = 0, rpmWorkouts = 0

    init(_ workouts: [Workout]) {
        for workout in workouts {
            count += 1
            minutes += workout.durationMinutes
            miles += workout.distanceMiles
            calories += workout.calories
            feet += workout.elevationFeet
            let weight = max(workout.durationMinutes, 0)
            if workout.avgWatts > 0 {
                wattWorkouts += 1
                wattSimple += workout.avgWatts
                wattWeighted += Double(workout.avgWatts) * weight
                wattWeight += weight
            }
            if workout.avgRPM > 0 {
                rpmWorkouts += 1
                rpmSimple += workout.avgRPM
                rpmWeighted += Double(workout.avgRPM) * weight
                rpmWeight += weight
            }
        }
    }

    /// Duration-weighted average of avg watts over workouts that recorded watts; nil if none.
    /// Falls back to a simple mean if none of those workouts has a duration.
    var averageWatts: Double? {
        Self.average(weighted: wattWeighted, weight: wattWeight, simple: wattSimple, workoutCount: wattWorkouts)
    }

    /// Duration-weighted average of avg RPM over workouts that recorded RPM; nil if none.
    var averageRPM: Double? {
        Self.average(weighted: rpmWeighted, weight: rpmWeight, simple: rpmSimple, workoutCount: rpmWorkouts)
    }

    private static func average(weighted: Double, weight: Double, simple: Int, workoutCount: Int) -> Double? {
        guard workoutCount > 0 else { return nil }
        return weight > 0 ? weighted / weight : Double(simple) / Double(workoutCount)
    }
}
