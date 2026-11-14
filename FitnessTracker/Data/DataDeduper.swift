import Foundation
import SwiftData

/// CloudKit can't enforce uniqueness, so two devices can create the same Program or
/// Workout (e.g. both seed the real workouts before syncing). This merges them.
enum DataDeduper {
    static func key(title: String, date: Date) -> String {
        // Minute precision: workouts are entered from a screen that shows minutes only.
        let minute = Int(date.timeIntervalSinceReferenceDate / 60)
        return Program.normalizedTitleKey(title) + "|\(minute)"
    }

    static func key(_ workout: Workout) -> String { key(title: workout.title, date: workout.date) }

    static func run(_ context: ModelContext) {
        var changed = false

        // 1. Programs with the same title (case-insensitive): keep the one with most workouts.
        let programs = (try? context.fetch(FetchDescriptor<Program>())) ?? []
        let byTitle = Dictionary(grouping: programs) { Program.normalizedTitleKey($0.title) }
        for (_, group) in byTitle where group.count > 1 {
            let sorted = group.sorted { ($0.workouts?.count ?? 0) > ($1.workouts?.count ?? 0) }
            let keeper = sorted[0]
            for duplicate in sorted.dropFirst() {
                for workout in duplicate.workouts ?? [] { workout.program = keeper }
                duplicate.workouts = []
                context.delete(duplicate)
                changed = true
            }
        }

        // 2. Workouts with the same title + start minute: keep the richest one.
        let workouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        for (_, group) in Dictionary(grouping: workouts, by: key) where group.count > 1 {
            let sorted = group.sorted { score($0) > score($1) }
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
                changed = true
            }
        }

        if changed { try? context.save() }
    }

    private static func score(_ workout: Workout) -> Int {
        (workout.photoData != nil ? 2 : 0) + ((workout.notes?.isEmpty == false) ? 1 : 0)
    }
}
